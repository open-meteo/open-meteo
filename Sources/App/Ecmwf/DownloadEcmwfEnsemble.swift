import Foundation
import NIOCore
import OmFileIO
import Vapor

extension DownloadEcmwfCommand {
    struct EnsembleInventory: Sendable {
        let hour: Int
        let url: String
        let entries: [Curl.EcmwfIndexEntry]
    }

    struct EnsembleDownload: Sendable {
        let hour: Int
        let member: Int
        let url: String
        let range: Range<Int>
    }

    struct DecodedEnsembleField: Sendable {
        let hour: Int
        let member: Int
        let shortName: String
        let stepType: String
        let stepRange: String
        var grib: GribArray2D
    }

    /// Member-major ordering keeps only one member's previous accumulation in memory.
    static func ensembleDownloads<V: EcmwfEnsembleVariable>(inventories: [EnsembleInventory], variable: V, memberCount: Int) throws -> [EnsembleDownload] {
        var downloads = [EnsembleDownload]()
        for inventory in inventories {
            if inventory.hour == 0 && variable.skipHourZero { continue }
            for entry in inventory.entries where variable.matches(entry) {
                guard let member = Int(entry.number ?? "0"), (0..<memberCount).contains(member),
                      entry._offset >= 0, entry._length > 0, entry._offset <= Int.max - entry._length else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                downloads.append(EnsembleDownload(hour: inventory.hour, member: member, url: inventory.url, range: entry._offset..<entry._offset + entry._length))
            }
        }
        return downloads.sorted {
            if $0.member != $1.member { return $0.member < $1.member }
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            return $0.range.lowerBound < $1.range.lowerBound
        }
    }

    /// Fetch inventories once, then overlap bounded variable downloads with statistics writing and conversion.
    func downloadEnsembleVariables<V: EcmwfEnsembleVariable>(application: Application, signature: Signature, domain: EcmwfDomain, base: String, run: Timestamp, variables: [V], concurrent: Int, downloadConcurrent: Int, uploadQueues: [S3UploadQueue]) async throws {
        guard !variables.isEmpty else { throw CurlError.didNotFindAllVariablesInGribIndex }
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5, retryUnauthorized: true, prepareRequest: EcmwfAzureAccess.prepareRequest(base: base, client: application.dedicatedHttpClient))
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        let hours = domain.getDownloadForecastSteps(run: run.hour).filter { $0 <= (signature.maxForecastHour ?? Int.max) }
        let files = hours.flatMap { hour in domain.getUrl(base: base, run: run, hour: hour).map { (hour: hour, url: $0) } }
        var inventories = [EnsembleInventory]()
        for try await inventory in files.mapStream(nConcurrent: downloadConcurrent, nBuffered: 2 * downloadConcurrent, body: { file in
            let request = try EcmwfOpenDataSource.prepareDownload(url: file.url)
            let entries = try await curl.downloadInMemoryAsync(url: request.indexURL, minSize: nil, quiet: true).readEcmwfIndexEntries()
            return EnsembleInventory(hour: file.hour, url: request.url, entries: entries)
        }) {
            inventories.append(inventory)
        }

        let allInventories = inventories
        let createNetcdf = signature.createNetcdf
        let generateTimeSeries = !signature.skipTimeseries
        let variablesConcurrent = signature.variablesConcurrent ?? 1
        let downloadedVariables = variables.mapStream(nConcurrent: variablesConcurrent, body: { variable in
            let downloads = try Self.ensembleDownloads(inventories: allInventories, variable: variable, memberCount: domain.countEnsembleMember)
            logger.info("Downloading \(variable.rawValue): \(downloads.count) fields")
            return try await downloadEnsembleVariable(domain: domain, run: run, variable: variable, downloads: downloads, curl: curl, concurrent: concurrent, downloadConcurrent: downloadConcurrent)
        })
        let ends = try await downloadedVariables.mapConcurrent(nConcurrent: variablesConcurrent) { downloaded -> Timestamp? in
            var handles = downloaded.handles
            guard let first = handles.first else { return nil }
            // mapStream has already started the next variable download.
            if let statistics = downloaded.statistics, let meanDomain = domain.ensembleMeanDomain {
                let statisticsStart = DispatchTime.now()
                handles += try await statistics.writeTimeSeries(variable: first.variable, time: first.time, domain: meanDomain)
                logger.info("Statistics write \(first.variable.rawValue): total=\(statisticsStart.timeElapsedPretty())")
            }
            let conversionStart = DispatchTime.now()
            try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: false, generateTimeSeries: generateTimeSeries)
            logger.info("Convert \(first.variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
            return handles.map { $0.time.range.upperBound }.max()
        }
        guard let end = ends.compactMap({ $0 }).max() else { throw CurlError.didNotFindAllVariablesInGribIndex }
        // Publish the run only after all available variables have been converted.
        if !signature.skipTimeseries && signature.timeinterval == nil && domain.generateTimeSeries {
            for outputDomain in [domain, domain.ensembleMeanDomain].compactMap({ $0 }) {
                let data = try ModelUpdateMetaJson.update(domain: outputDomain, run: run, end: end, now: .now())
                for queue in uploadQueues {
                    await queue.upload(data: data, objectName: "data/\(outputDomain.domainRegistry.rawValue)/static/meta.json", contentType: "application/json", lastModified: .now())
                }
            }
        }
        await curl.printStatistics()
    }

    private func downloadEnsembleVariable<V: EcmwfEnsembleVariable>(domain: EcmwfDomain, run: Timestamp, variable: V, downloads: [EnsembleDownload], curl: Curl, concurrent: Int, downloadConcurrent: Int) async throws -> (handles: [GenericVariableHandle], statistics: ArrayMeanStdDevSampler?) {
        // Note: directly generate rolling.om instead of Gerneric handle is not faster, because for every member it has to read the entire rolling file
        // TODO: implement precip probability

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: downloads.reduce(0) { $0 + $1.range.count }, name: "Download \(variable.rawValue)")
        // Match the converter's member count, including control-only selections.
        let nMembers = downloads.contains { $0.member > 0 } ? domain.countEnsembleMember : 1
        let chunkLocations = min(domain.grid.nx, OmFileSplitter(domain, nMembers: nMembers).chunknLocations)
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        var handles = [GenericVariableHandle]()
        var writeJob: Task<GenericVariableHandle, any Error>? = nil
        var statisticsJob: Task<Void, Never>? = nil
        guard let firstHour = downloads.first?.hour, let lastHour = downloads.last?.hour else { return (handles, nil) }
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        let statistics = domain.ensembleMeanDomain.map { _ in ArrayMeanStdDevSampler() }
        // [y, x, time]: each location's complete time series is contiguous.
        var data = Array2DFastTime(nLocations: domain.grid.count, nTime: 0)
        var deaverager = GribDeaverager()
        var loopActiveTime = 0.0
        var downloadStart = DispatchTime.now()

        // Keep one ordered stream alive so downloads can cross member boundaries.
        let decoded = downloads.mapStream(nConcurrent: downloadConcurrent, nBuffered: 2 * downloadConcurrent, body: { download -> DecodedEnsembleField in
            let range = "\(download.range.lowerBound)-\(download.range.upperBound - 1)"
            let buffer = try await curl.downloadInMemoryAsync(url: download.url, range: range, minSize: download.range.count, cacheDirectory: nil, quiet: true)
            await progress.add(buffer.readableBytes)
            // Decode while the compressed buffer is alive; only owned arrays leave this job.
            return try buffer.withUnsafeReadableBytes { bytes in
                guard let message = try GribAsyncStreamHelper.decodeMessages(memory: bytes).first else {
                    throw GribAsyncStreamError.didNotFindGibHeader
                }
                guard let shortName = message.get(attribute: "shortName"),
                      let level = message.get(attribute: "level").flatMap(Int.init),
                      let stepType = message.get(attribute: "stepType"),
                      let stepRange = message.get(attribute: "stepRange") else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                guard variable.matches(shortName: shortName, level: level) else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                guard (message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0) == download.member else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                var grib = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib.load(message: message)
                grib.array.flipLatitude()
                return DecodedEnsembleField(hour: download.hour, member: download.member, shortName: shortName, stepType: stepType, stepRange: stepRange, grib: grib)
            }
        })
        for try await decodedField in decoded {
            let member = decodedField.member
            if decodedField.hour == firstHour {
                data = Array2DFastTime(nLocations: domain.grid.count, nTime: time.count)
                deaverager = GribDeaverager()
                loopActiveTime = 0
            }
            let loopStart = DispatchTime.now()
            var field = decodedField
            // Deaccumulate before converting units; retain the previous field in its original units.
            let stepRange = field.stepType == "accum" && !field.stepRange.contains("-") ? "0-\(field.stepRange)" : field.stepRange
            let previousStep = await deaverager.lastStep(variable, field.member)
            if await deaverager.deaccumulateIfRequired(variable: variable, member: field.member, stepType: field.stepType, stepRange: stepRange, array2d: &field.grib.array) {
                // Respect both cumulative fields and fields that reset their accumulation interval.
                let start = stepRange.splitTo2Integer()?.0 ?? field.hour
                let dtSeconds = max(1, field.hour - max(start, previousStep ?? start)) * 3600
                if field.shortName == "z" { await field.grib.array.data.multiplyAddConcurrent(multiply: 1 / 9.80665, add: 0) }
                if let fma = variable.multiplyAdd(dtSeconds: dtSeconds) {
                    await field.grib.array.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                }
                await data.setConcurrent(location: 0..<domain.grid.count, time: field.hour * 3600 / domain.dtSeconds, values: field.grib.array.data)
            }
            loopActiveTime += loopStart.timeElapsedSeconds()
            guard decodedField.hour == lastHour else { continue }

            let downloadTime = downloadStart.timeElapsedPretty()
            let interpolationStart = DispatchTime.now()
            await data.interpolateInplace(type: variable.interpolation, time: time, grid: domain.grid, locationRange: 0..<domain.grid.count, nConcurrent: concurrent)
            let interpolationTime = interpolationStart.timeElapsedPretty()
            let convertLoopTime = loopActiveTime.asSecondsPrettyPrint
            // Match spatial chunk boundaries used by the rolling converter, keeping
            // the full time axis contiguous in each chunk.
            let writer = OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx, time.count], chunks: [1, chunkLocations, time.count])
            let waitStart = DispatchTime.now()
            if let writeJob {
                handles.append(try await writeJob.value)
            }
            let writeJobWait = waitStart.timeElapsedPretty()
            let statisticsWaitStart = DispatchTime.now()
            await statisticsJob?.value
            let statisticsWait = statisticsWaitStart.timeElapsedPretty()
            if let statistics {
                statisticsJob = Task { [values = data.data] in
                    let statisticsStart = DispatchTime.now()
                    await statistics.ingest(values, nConcurrent: concurrent)
                    curl.logger.info("\(variable.rawValue) member \(member): stats=\(statisticsStart.timeElapsedPretty()), wait=\(statisticsWait)")
                }
            }
            // Statistics and compression run alongside the next member's download.
            writeJob = Task { [values = data.data] in
                let writeStart = DispatchTime.now()
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: values)
                let handle = try await GenericVariableHandle(variable: variable, time: run, member: member, fn: fn, domain: domain)
                curl.logger.info("\(variable.rawValue) member \(member): write=\(writeStart.timeElapsedPretty()), interpolation=\(interpolationTime), wait=\(writeJobWait), download=\(downloadTime), fma+deaccum=\(convertLoopTime)")
                return handle
            }
            downloadStart = DispatchTime.now()
        }
        await progress.finish()
        let waitStart = DispatchTime.now()
        if let writeJob {
            handles.append(try await writeJob.value)
        }
        curl.logger.info("\(variable.rawValue) final write wait=\(waitStart.timeElapsedPretty())")
        let statisticsWaitStart = DispatchTime.now()
        await statisticsJob?.value
        let statisticsWait = statisticsWaitStart.timeElapsedPretty()
        curl.logger.info("\(variable.rawValue) final statistics wait=\(statisticsWait)")
        return (handles, statistics)
    }
}
