import Foundation
import SwiftZarr
import Vapor

struct DownloadWeatherNext3Command: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run", help: "Main run initialization (00, 06, 12 or 18 UTC)") var run: String?
        @Option(name: "concurrent-download", help: "Maximum concurrent chunk download/decoding tasks (default: 8)")
        var concurrentDownload: Int?
        @Option(name: "concurrent", help: "Maximum concurrent temporal OM conversion tasks (default: 1)")
        var concurrent: Int?
        @Option(name: "upload-s3-bucket") var uploadS3Bucket: String?
    }

    var help: String { "Download WeatherNext 3 hourly surface statistics on both native grids" }

    func run(using context: CommandContext, signature: Signature) async throws {
        Process.alarm(seconds: 5 * 60 * 60)
        defer { Process.alarm(seconds: 0) }

        let app = context.application
        let logger = context.application.logger
        logger.info("WeatherNext 3: starting downloader; runtime limit 5 hours")
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

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? WeatherNext3Domain.latestRun()
        guard run.hour % 6 == 0 else {
            throw Abort(.badRequest, reason: "WeatherNext 3 supports only main runs at 00, 06, 12 or 18 UTC")
        }

        logger.info(
            "WeatherNext 3: selected run \(run.iso8601_YYYY_MM_dd_HH_mm), download concurrency \(downloadConcurrency), conversion concurrency \(conversionConcurrency); obtaining Google access token"
        )
        let handles = try await download(application: app, run: run, downloadConcurrency: downloadConcurrency)
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
            writeUpdateJson: true,
            uploadQueues: queues,
            generateFullRun: false
        )

        logger.info("WeatherNext 3: completed run \(run.iso8601_YYYY_MM_dd_HH_mm)")
    }

    func download(application: Application, run: Timestamp, downloadConcurrency: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let auth = GoogleCloudStorageAuth(client: .shared, logger: logger)
        let prefix = WeatherNext3Domain.path(run: run)

        var initialStorage = try await auth.storage(bucket: "weathernext3_statistics_spatial")
        logger.info("WeatherNext 3: checking success marker at \(prefix)success")
        while try await !initialStorage.exists(path: prefix + "success") {
            logger.info("WeatherNext 3: run \(run.iso8601_YYYY_MM_dd_HH_mm) is not complete; retrying in 60 seconds")
            try await Task.sleep(for: .seconds(60))
            initialStorage = try await auth.storage(bucket: "weathernext3_statistics_spatial")
        }

        let hours = WeatherNext3Domain.hours
        logger.info(
            "WeatherNext 3: success marker found; validating Zarr metadata (\(hours) forecast hours)"
        )
        let root = try await ZarrGroup(storage: initialStorage, path: prefix + "predictions.zarr/")
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

        var handles = [GenericVariableHandle]()
        for domain in WeatherNext3Domain.allCases {
            let grid = domain.grid
            let suffix = domain.coordinateSuffix
            let root = try await ZarrGroup(
                storage: auth.storage(bucket: "weathernext3_statistics_spatial"),
                path: prefix + "predictions.zarr/"
            )
            logger.info("WeatherNext 3: loading and validating \(domain.rawValue) field metadata")
            let variables = WeatherNext3Field.allCases.filter { $0.domain == domain }.flatMap { field in
                field.statistics.map {
                    WeatherNext3Variable(field: field, statistic: $0)
                }
            }
            let arrays = try await variables.mapConcurrent(nConcurrent: downloadConcurrency) { variable in
                let name = variable.field.source + "_" + variable.statistic.rawValue
                let array = try await root.openArray(name: name)
                guard case .v3(let metadata) = array.metadata,
                    metadata.dataType == "float32",
                    metadata.dimensionNames == ["lead_time", "lat_" + suffix, "lon_" + suffix],
                    metadata.attributes?["units"]?.stringValue == variable.field.sourceUnit,
                    array.chunkShape == [1, grid.ny, grid.nx],
                    array.shape == [hours, grid.ny, grid.nx]
                else {
                    throw Abort(.badRequest, reason: "Unexpected WeatherNext 3 shape: \(name)")
                }

                return (variable: variable, array: array)
            }

            let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: logger)
            let chunks = arrays.indices.flatMap { arrayIndex in (0..<hours).map { ($0, arrayIndex) } }
            logger.info("WeatherNext 3: downloading \(chunks.count) \(domain.rawValue) chunks with concurrency \(downloadConcurrency)")
            try await chunks.foreachConcurrent(nConcurrent: downloadConcurrency) { index, arrayIndex in
                let (variable, template) = arrays[arrayIndex]
                let field = variable.field
                let array = try await ZarrArray(
                    metadata: template.metadata,
                    storage: auth.storage(bucket: "weathernext3_statistics_spatial"),
                    path: template.path
                )
                let readStarted = DispatchTime.now().uptimeNanoseconds
                var data: [Float] = try await array.retrieveArraySubset([
                    index..<index + 1, 0..<grid.ny, 0..<grid.nx,
                ])
                let transformStarted = DispatchTime.now().uptimeNanoseconds
                data.shift180Longitude(nt: 1, ny: grid.ny, nx: grid.nx)
                if let multiplyAdd = field.multiplyAdd {
                    data.multiplyAdd(multiply: multiplyAdd.multiply, add: multiplyAdd.add)
                }
                let writeStarted = DispatchTime.now().uptimeNanoseconds
                try await writer.write(
                    time: run.add(hours: index + 1),
                    member: 0,
                    variable: variable,
                    data: data
                )
                let finished = DispatchTime.now().uptimeNanoseconds
                logger.info("WeatherNext 3: completed hour \(index + 1)/\(hours), \(domain.rawValue), \(variable.rawValue)")
                logger.debug(
                    """
                    WeatherNext 3: hour \(index + 1)/\(hours), \(variable.rawValue): \
                    read/decode \((transformStarted - readStarted) / 1_000_000)ms, \
                    transform \((writeStarted - transformStarted) / 1_000_000)ms, \
                    writer wait/write \((finished - writeStarted) / 1_000_000)ms
                    """
                )
            }

            handles += try await writer.finalise()
        }

        return handles
    }
}
