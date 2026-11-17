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

    /// Fetch every inventory once, then overlap each variable download with the previous conversion.
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
            let entries = try await curl.downloadInMemoryAsync(url: request.indexURL, minSize: nil).readEcmwfIndexEntries()
            return EnsembleInventory(hour: file.hour, url: request.url, entries: entries)
        }) {
            inventories.append(inventory)
        }

        var end: Timestamp?
        var conversionJob: Task<Void, any Error>? = nil
        for variable in variables {
            let downloads = try Self.ensembleDownloads(inventories: inventories, variable: variable, memberCount: domain.countEnsembleMember)
            guard !downloads.isEmpty else { continue }
            logger.info("Downloading \(variable.rawValue): \(downloads.count) fields")
            let handles = try await downloadEnsembleVariable(application: application, domain: domain, run: run, variable: variable, downloads: downloads, curl: curl, nConcurrent: downloadConcurrent)
            // Finish the previous conversion before starting another; its work overlaps
            // the download above.
            try await conversionJob?.value
            conversionJob = Task { [createNetcdf = signature.createNetcdf, generateTimeSeries = !signature.skipTimeseries] in
                try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: false, generateTimeSeries: generateTimeSeries)
            }
            if let latest = handles.map({ $0.time.range.lowerBound.add(domain.dtSeconds) }).max() {
                end = max(end ?? latest, latest)
            }
        }
        try await conversionJob?.value
        guard let end else { throw CurlError.didNotFindAllVariablesInGribIndex }
        // Publish the run only after all available variables have been converted.
        if !signature.skipTimeseries && signature.timeinterval == nil && domain.generateTimeSeries {
            let data = try ModelUpdateMetaJson.update(domain: domain, run: run, end: end, now: .now())
            for queue in uploadQueues {
                await queue.upload(data: data, objectName: "data/\(domain.domainRegistry.rawValue)/static/meta.json", contentType: "application/json", lastModified: .now())
            }
        }
        await curl.printStatistics()
    }

    private func downloadEnsembleVariable<V: EcmwfEnsembleVariable>(application: Application, domain: EcmwfDomain, run: Timestamp, variable: V, downloads: [EnsembleDownload], curl: Curl, nConcurrent: Int) async throws -> [GenericVariableHandle] {
        // Match the converter's member count, including control-only selections.
        let nMembers = downloads.contains { $0.member > 0 } ? domain.countEnsembleMember : 1
        let chunks = OmFileSplitter(domain, nMembers: nMembers).spatialReadChunkDimensions
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: application.logger, chunkDimensions: [chunks.y, chunks.x])
        var deaverager = GribDeaverager()
        var previousMember: Int?
        // mapStream preserves input order even when requests finish out of order.
        for try await (download, buffer) in downloads.mapStream(nConcurrent: nConcurrent, nBuffered: 2 * nConcurrent, body: { download in
            let range = "\(download.range.lowerBound)-\(download.range.upperBound - 1)"
            let buffer = try await curl.downloadInMemoryAsync(url: download.url, range: range, minSize: download.range.count, cacheDirectory: nil)
            return (download, buffer)
        }) {
            // ecCodes messages may reference the compressed buffer during processing.
            defer { withExtendedLifetime(buffer) {} }
            let messages = try buffer.withUnsafeReadableBytes { try GribAsyncStreamHelper.decodeMessages(memory: $0) }
            guard !messages.isEmpty else { throw GribAsyncStreamError.didNotFindGibHeader }
            for message in messages {
                guard let shortName = message.get(attribute: "shortName"),
                      let level = message.get(attribute: "level").flatMap(Int.init),
                      let stepType = message.get(attribute: "stepType"),
                      let stepRange = message.get(attribute: "stepRange") else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                // Inventories can group soil layers under one parameter/range.
                guard variable.matches(shortName: shortName, level: level) else { continue }
                guard (message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0) == download.member else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                let time = run.add(hours: download.hour)
                if previousMember != download.member {
                    deaverager = GribDeaverager()
                    previousMember = download.member
                }
                var grib = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib.load(message: message)
                grib.array.flipLatitude()
                guard await Self.prepareEnsembleField(variable: variable, member: download.member, hour: download.hour, stepType: stepType, stepRange: stepRange, shortName: shortName, deaverager: deaverager, data: &grib.array) else { continue }
                try await writer.write(time: time, member: download.member, variable: variable, data: grib.array.data)
            }
        }
        return try await writer.finalise()
    }

    /// Deaccumulate before converting units; keep the previous field in its original units.
    static func prepareEnsembleField<V: EcmwfEnsembleVariable>(variable: V, member: Int, hour: Int, stepType: String, stepRange: String, shortName: String, deaverager: GribDeaverager, data: inout Array2D) async -> Bool {
        let stepRange = stepType == "accum" && !stepRange.contains("-") ? "0-\(stepRange)" : stepRange
        let previousStep = await deaverager.lastStep(variable, member)
        guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, array2d: &data) else { return false }
        // Respect both cumulative fields and fields that reset their accumulation interval.
        let start = stepRange.splitTo2Integer()?.0 ?? hour
        let dtSeconds = max(1, hour - max(start, previousStep ?? start)) * 3600
        if shortName == "z" { data.data.multiplyAdd(multiply: 1 / 9.80665, add: 0) }
        if let fma = variable.multiplyAdd(dtSeconds: dtSeconds) {
            data.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        return true
    }

}
