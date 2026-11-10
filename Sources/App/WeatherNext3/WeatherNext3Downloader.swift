import AsyncHTTPClient
import Foundation
import SwiftZarr
import Vapor

struct DownloadWeatherNext3Command: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run") var run: String?
        @Option(name: "concurrent-download", help: "Maximum concurrent chunk download/decoding tasks (default: 8)")
        var concurrentDownload: Int?
        @Option(name: "concurrent", help: "Maximum concurrent temporal OM conversion tasks (default: 1)")
        var concurrent: Int?
        @Option(name: "upload-s3-bucket") var uploadS3Bucket: String?
    }

    var help: String { "Download WeatherNext 3 hourly surface statistics on both native grids" }

    func run(using context: CommandContext, signature: Signature) async throws {
        Process.alarm(seconds: 60 * 60)
        defer { Process.alarm(seconds: 0) }

        let app = context.application
        let logger = context.application.logger
        logger.info("WeatherNext 3: starting downloader; runtime limit 60 minutes")
        let downloadConcurrency = signature.concurrentDownload ?? 8
        let conversionConcurrency = signature.concurrent ?? 1
        guard downloadConcurrency > 0 else {
            throw Abort(.badRequest, reason: "concurrent-download must be positive")
        }
        guard conversionConcurrency > 0 else {
            throw Abort(.badRequest, reason: "concurrent must be positive")
        }

        let queues = await app.s3SyncManager.getQueues(
            bucketsOpt: signature.uploadS3Bucket,
            rollingBucketsOpt: nil,
            onlyProbabilityTimeSeries: false
        )

        let run: Timestamp
        if let specified = signature.run {
            run = try Timestamp.fromRunHourOrYYYYMMDD(specified)
        } else {
            run = WeatherNext3Domain.latestRun()
        }

        let oldSurface = try await WeatherNext3Domain.surface.getMetaJson()
        let oldStation = try await WeatherNext3Domain.station.getMetaJson()

        let httpConfiguration = HTTPClient.Configuration(
            redirectConfiguration: .follow(max: 5, allowCycles: false),
            timeout: .init(connect: .seconds(30), read: .minutes(5)),
            connectionPool: .init(
                idleTimeout: .minutes(10),
                concurrentHTTP1ConnectionsPerHostSoftLimit: max(8, downloadConcurrency)
            )
        )
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(app.eventLoopGroup),
            configuration: httpConfiguration,
            backgroundActivityLogger: logger
        )
        defer {
            httpClient.shutdown { error in
                if let error {
                    logger.warning("WeatherNext 3: HTTP client shutdown failed: \(error)")
                }
            }
        }

        let auth = GoogleCloudStorageAuth(client: httpClient, logger: logger)
        let prefix = WeatherNext3Domain.path(run: run)

        @Sendable func storage() async throws -> S3CompatibleStorage {
            let token = try await auth.getAccessToken()
            return try S3CompatibleStorage(
                baseURL: "https://storage.googleapis.com/weathernext3_statistics_spatial",
                retryingClient: .init(
                    httpClient: httpClient,
                    config: .init(
                        maxAttempts: 5,
                        baseDelay: .milliseconds(500),
                        maxDelay: .seconds(60),
                        jitter: 0.2,
                        timeout: .seconds(180)
                    )
                ),
                additionalHeaders: ["Authorization": "Bearer \(token)"]
            )
        }
        logger.info(
            "WeatherNext 3: selected run \(run.iso8601_YYYY_MM_dd_HH_mm), download concurrency \(downloadConcurrency), conversion concurrency \(conversionConcurrency); obtaining Google access token"
        )
        var initialStorage = try await storage()
        logger.info("WeatherNext 3: checking success marker at \(prefix)success")
        while try await !initialStorage.exists(path: prefix + "success") {
            logger.info("WeatherNext 3: run \(run.iso8601_YYYY_MM_dd_HH_mm) is not complete; retrying in 60 seconds")
            try await Task.sleep(for: .seconds(60))
            initialStorage = try await storage()
        }

        let hours = WeatherNext3Domain.hours(run: run)
        logger.info(
            "WeatherNext 3: success marker found; validating Zarr metadata and coordinates (\(hours) forecast hours)"
        )
        let root = try await ZarrGroup(storage: initialStorage, path: prefix + "predictions.zarr/")
        for domain in WeatherNext3Domain.allCases {
            let suffix = domain == .surface ? "0p1" : "0p05"
            let step: Float = domain == .surface ? 0.1 : 0.05
            for (coordinate, count, start) in [
                ("lat_", domain.grid.ny, Float(-90)), ("lon_", domain.grid.nx, Float(0)),
            ] {
                let array = try await root.openArray(name: coordinate + suffix)
                guard array.shape == [count] else {
                    throw Abort(.badRequest, reason: "Unexpected WeatherNext 3 coordinate shape")
                }
                let values: [Float] = try await array.retrieveArraySubset([0..<count])
                guard
                    values.enumerated().allSatisfy({ abs($0.element - (start + Float($0.offset) * step)) < 0.0001 })
                else {
                    throw Abort(.badRequest, reason: "Unexpected WeatherNext 3 coordinate ordering")
                }
            }
        }

        let datetime = try await root.openArray(name: "datetime")
        let firstTime: [Int64] = try await datetime.retrieveArraySubset([0..<1])
        guard firstTime == [Int64(run.add(hours: 1).timeIntervalSince1970) * 1_000_000_000] else {
            throw Abort(.badRequest, reason: "WeatherNext 3 initialization does not match requested run")
        }

        let leads = try await root.openArray(name: "lead_time")
        guard case .v3(let leadMetadata) = leads.metadata, leadMetadata.attributes?["units"]?.stringValue == "hours"
        else {
            throw Abort(.badRequest, reason: "WeatherNext 3 lead_time must be expressed in hours")
        }

        let leadValues: [Int64] = try await leads.retrieveArraySubset([0..<hours])
        guard leads.shape == [hours], leadValues == (1...hours).map(Int64.init) else {
            throw Abort(.badRequest, reason: "Unexpected WeatherNext 3 hourly lead coordinates")
        }

        logger.info("WeatherNext 3: loading and validating field metadata")
        let statistics = WeatherNext3Variable.fields.flatMap { field in
            WeatherNext3Variable.Statistic.allCases.map { (field, $0) }
        }
        let arrays = try await statistics.mapConcurrent(nConcurrent: downloadConcurrency) { field, statistic in
            let name = field.source + "_" + statistic.rawValue
            let array = try await root.openArray(name: name)
            let domain = field.domain
            let suffix = domain == .surface ? "0p1" : "0p05"
            let expectedUnit: String
            switch field.unit {
            case .celsius: expectedUnit = "K"
            case .hectopascal: expectedUnit = "Pa"
            case .millimetre: expectedUnit = "m"
            case .percentage: expectedUnit = "(0 - 1)"
            case .wattPerSquareMetre: expectedUnit = "J m**-2"
            default: expectedUnit = "m s**-1"
            }

            guard case .v3(let metadata) = array.metadata,
                metadata.dataType == "float32",
                metadata.dimensionNames == ["lead_time", "lat_" + suffix, "lon_" + suffix],
                metadata.attributes?["units"]?.stringValue == expectedUnit,
                array.chunkShape == [1, domain.grid.ny, domain.grid.nx],
                array.shape == [hours, domain.grid.ny, domain.grid.nx]
            else {
                throw Abort(.badRequest, reason: "Unexpected WeatherNext 3 shape: \(name)")
            }

            let variableName = statistic == .mean ? field.name : field.name + "_" + statistic.rawValue
            return (field: field, variable: WeatherNext3Variable(rawValue: variableName)!, array: array)
        }

        let writers = Dictionary(
            uniqueKeysWithValues: WeatherNext3Domain.allCases.map { domain in
                (
                    domain,
                    (0..<hours).map { index in
                        OmSpatialTimestepWriter(
                            domain: domain,
                            run: run,
                            time: run.add(hours: index + 1),
                            storeOnDisk: false,
                            realm: nil,
                            logger: logger
                        )
                    }
                )
            }
        )
        let chunks = arrays.indices.flatMap { arrayIndex in (0..<hours).map { ($0, arrayIndex) } }
        logger.info("WeatherNext 3: downloading \(chunks.count) chunks with concurrency \(downloadConcurrency)")
        try await chunks.foreachConcurrent(nConcurrent: downloadConcurrency) { index, arrayIndex in
            let (field, variable, template) = arrays[arrayIndex]
            let domain = field.domain
            logger.debug("WeatherNext 3: hour \(index + 1)/\(hours), \(domain.rawValue), \(variable.rawValue)")
            let array = try await ZarrArray(metadata: template.metadata, storage: storage(), path: template.path)
            let readStarted = DispatchTime.now().uptimeNanoseconds
            var data: [Float] = try await array.retrieveArraySubset([
                index..<index + 1, 0..<domain.grid.ny, 0..<domain.grid.nx,
            ])
            let transformStarted = DispatchTime.now().uptimeNanoseconds
            data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
            if field.scale != 1 || field.offset != 0 {
                data.multiplyAdd(multiply: field.scale, add: field.offset)
            }
            let writeStarted = DispatchTime.now().uptimeNanoseconds
            try await writers[domain]![index].write(member: 0, variable: variable, data: data)
            let finished = DispatchTime.now().uptimeNanoseconds
            logger.info(
                """
                WeatherNext 3: hour \(index + 1)/\(hours), \(variable.rawValue): \
                read/decode \((transformStarted - readStarted) / 1_000_000)ms, \
                transform \((writeStarted - transformStarted) / 1_000_000)ms, \
                writer wait/write \((finished - writeStarted) / 1_000_000)ms
                """
            )
        }

        var handles = [GenericVariableHandle]()
        for domain in WeatherNext3Domain.allCases {
            for writer in writers[domain]! {
                handles += try await writer.finalise()
            }
        }

        logger.info(
            "WeatherNext 3: downloads complete; converting \(handles.count) variable handles to time series"
        )
        try await GenericVariableHandle.convert(
            application: app,
            domain: WeatherNext3Domain.surface,
            createNetcdf: false,
            run: run,
            handles: handles,
            concurrent: conversionConcurrency,
            writeUpdateJson: false,
            uploadQueues: queues,
            generateFullRun: false
        )

        logger.info("WeatherNext 3: conversion complete; publishing run metadata")
        for domain in WeatherNext3Domain.allCases {
            let old = domain == .surface ? oldSurface : oldStation
            if let old, run.timeIntervalSince1970 < old.last_run_initialisation_time {
                continue
            }
            let end = max(run.add(hours: hours + 1).timeIntervalSince1970, old?.data_end_time ?? 0)
            let metadata = try ModelUpdateMetaJson.update(domain: domain, run: run, end: Timestamp(end))
            for queue in queues {
                await queue.upload(
                    data: metadata,
                    objectName: "data/\(domain.domainRegistry.rawValue)/static/meta.json",
                    contentType: "application/json",
                    lastModified: .now()
                )
            }
        }

        logger.info("WeatherNext 3: completed run \(run.iso8601_YYYY_MM_dd_HH_mm)")
    }
}
