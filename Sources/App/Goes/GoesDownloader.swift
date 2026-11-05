import Vapor
import SwiftNetCDF
import OmFileIO

/// Anonymous NOAA Open Data Dissemination bucket. DSRF is radiation; DSIF is stability indices.
struct GoesDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain") var domain: String
        @Option(name: "timeinterval", short: "t", help: "Backfill inclusive dates, e.g. 20261101-20261103") var timeinterval: String?
        @Option(name: "lookback-days", help: "Recheck this many days for late/replaced scans (default 2)") var lookbackDays: Int?
        @Option(name: "concurrent", short: "c", help: "Download and conversion concurrency (default 1)") var concurrent: Int?
        @Flag(name: "create-netcdf") var createNetcdf: Bool
        @Flag(name: "force", help: "Reprocess available scans even if already completed") var force: Bool
        @Option(name: "upload-s3-bucket") var uploadS3Bucket: String?
    }
    var help: String { "Download GOES-19 10-minute surface shortwave radiation" }
    static let server = "https://noaa-goes19.s3.amazonaws.com/"

    struct Scan: Equatable, Sendable {
        let key: String
        let start: Timestamp
        let identity: String
        let fileSize: Int
        var time: Timestamp { Timestamp(start.timeIntervalSince1970 / 600 * 600 + 600) }

        init?(key: String, eTag: String, fileSize: Int = 0) {
            guard key.hasPrefix("ABI-L2-DSRF/"), key.hasSuffix(".nc"),
                  key.contains("OR_ABI-L2-DSRF-M6_G19_s"),
                  let token = key.components(separatedBy: "_s").last?.components(separatedBy: "_").first,
                  token.count == 14, token.allSatisfy(\.isNumber),
                  let year = Int(token[0..<4]), (2024...2100).contains(year),
                  let day = Int(token[4..<7]), (1...366).contains(day),
                  let hour = Int(token[7..<9]), hour < 24,
                  let minute = Int(token[9..<11]), minute < 60,
                  let second = Int(token[11..<13]), second < 60 else { return nil }
            self.key = key
            self.fileSize = fileSize
            self.start = Timestamp(year, 1, 1).add((day - 1) * 86400 + hour * 3600 + minute * 60 + second)
            // Preserve checkpoint identities written by the original XML listing parser.
            self.identity = key + ":" + eTag.replacingOccurrences(of: "\"", with: "&quot;")
        }
    }

    /// Convert each OM time chunk at most once per invocation. Use the stored
    /// interval-end timestamp, including its shift from the nominal scan time,
    /// and the same epoch-based indexing as OmFileSplitter.
    static func batches(scans: [Scan], completed: Set<String>, domain: GoesDomain = .goes19) -> [[Scan]] {
        var result = [[Scan]]()
        for (_, chunkScans) in scans.groupedPreservedOrder(by: {
            // Shift acquisition time to the stored interval end before choosing the chunk.
            ($0.start.timeIntervalSince1970 + domain.dtSeconds) / domain.dtSeconds / domain.omFileLength
        }) {
            guard let first = chunkScans.firstIndex(where: { !completed.contains($0.identity) }),
                  let last = chunkScans.lastIndex(where: { !completed.contains($0.identity) }) else {
                continue
            }
            // Include all observations between pending scans, plus their neighbors
            // within this chunk. This preserves actual observations during gap
            // interpolation without rewriting an adjacent OM file for an anchor.
            let start = max(0, first - 1)
            let end = min(chunkScans.count, last + 2)
            result.append(Array(chunkScans[start..<end]))
        }
        return result
    }

    static func recentCompleted(_ completed: Set<String>, lookbackDays: Int, now: Timestamp = .now()) -> Set<String> {
        let cutoff = now.add(days: -lookbackDays)
        return completed.filter { identity in
            guard let scan = Scan(key: String(identity.prefix { $0 != ":" }), eTag: "") else { return false }
            return scan.start >= cutoff
        }
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try GoesDomain.load(rawValue: signature.domain)
        let loopbackDays = signature.lookbackDays ?? 2
        let concurrent = signature.concurrent ?? 1
        guard loopbackDays > 0, concurrent > 0 else { throw Abort(.badRequest, reason: "lookback-days and concurrent must be positive") }
        let logger = context.application.logger
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient)
        let queues = await context.application.s3SyncManager.getQueues(bucketsOpt: signature.uploadS3Bucket)
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let stateFile = domain.downloadDirectory + "completed.json"
        // A corrupt checkpoint must fail loudly, rather than silently losing retry history.
        var completed = FileManager.default.fileExists(atPath: stateFile)
            ? Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: stateFile)))) : Set<String>()
        let range: TimerangeDt
        if let interval = signature.timeinterval {
            range = try Timestamp.parseRange(yyyymmdd: interval).toRange(dt: 86400)
        } else {
            let today = Timestamp.now().with(hour: 0)
            let lastSuccess = completed.compactMap { identity in
                Scan(key: String(identity.prefix { $0 != ":" }), eTag: "")?.start
            }.max()
            // Resume an interrupted downloader even when the outage exceeds the normal lookback.
            let firstDay = min(today.add(days: 1 - loopbackDays), lastSuccess?.with(hour: 0) ?? today)
            range = TimerangeDt(start: firstDay, to: today.add(days: 1), dtSeconds: 86400)
        }
        var scansByTime = [Timestamp: Scan]()
        for day in range {
            let year = day.toComponents().year
            let ordinal = (day.timeIntervalSince1970 - Timestamp(year, 1, 1).timeIntervalSince1970) / 86400 + 1
            let prefix = "ABI-L2-DSRF/\(year)/\(ordinal.zeroPadded(len: 3))/"
            let listing = try await S3List.s3list(server: Self.server, client: context.application.dedicatedHttpClient,
                logger: logger, prefix: prefix, apikey: nil, deadLineHours: 0.1, delimiter: "")
            for file in listing.files {
                guard let scan = Scan(key: file.name, eTag: file.eTag, fileSize: file.fileSize) else { continue }
                // Creation timestamp at the end of the key sorts reprocessed versions.
                if let old = scansByTime[scan.time], old.key > scan.key { continue }
                scansByTime[scan.time] = scan
            }
        }
        let scans = scansByTime.values.sorted { $0.time < $1.time }
        let batches = Self.batches(scans: scans, completed: signature.force ? [] : completed, domain: domain)
        // Prune even when no new scans need conversion. Plan first so existing
        // checkpoints still suppress completed historical work in this invocation.
        completed = Self.recentCompleted(completed, lookbackDays: loopbackDays)
        try JSONEncoder().encode(completed.sorted()).write(to: URL(fileURLWithPath: stateFile), options: .atomic)
        logger.info("GOES: \(scans.count) available scans, \(batches.count) conversion batches")
        guard !batches.isEmpty else { return }
        // Count the actual download plan, including observations needed for interpolation.
        let totalBytes = batches.reduce(0) { total, batch in total + batch.reduce(0) { $0 + $1.fileSize } }
        let fileCount = batches.reduce(0) { $0 + $1.count }
        logger.info("GOES: Downloading \(fileCount) files (\(totalBytes.bytesHumanReadable))")
        let progress = TransferAmountTracker(logger: logger, totalSize: totalBytes, name: "GOES overall download")
        for batch in batches {
            let downloads: [(scan: Scan, handle: GenericVariableHandle)?] = try await batch.mapConcurrent(nConcurrent: concurrent) { scan in
                logger.info("GOES: \(scan.key)")
                // Backfills can run for days. Start a fresh retry deadline per file
                // instead of inheriting Curl's deadline from command startup.
                let buffer = try await curl.downloadInMemoryAsync(url: Self.server + scan.key, minSize: nil, deadLineHours: 1)
                await progress.add(buffer.readableBytes)
                let data: [Float]
                do {
                    data = try buffer.withUnsafeBytes { bytes in
                        guard let nc = try NetCDF.open(memory: bytes) else { throw Abort(.badGateway, reason: "Cannot open GOES NetCDF") }
                        return try Self.decode(nc: nc, scan: scan)
                    }
                } catch let error as InvalidScanTimes {
                    logger.warning("GOES: Skipping \(scan.key): \(error). Leaving scan pending for retry.")
                    return nil
                }
                // Conversion reads full-width strips only a few rows high. Keep
                // chunks within one row to avoid repeatedly decoding 32-row tiles.
                let writer = OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx], chunks: [1, min(domain.grid.nx, 1024)])
                let handle = try await GenericVariableHandle(variable: GoesVariable.shortwave_radiation, time: scan.time, member: 0,
                    fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: data), domain: domain)
                return (scan, handle)
            }
            let successful = downloads.compactMap { $0 }
            guard !successful.isEmpty else { continue }
            let handles = successful.map(\.handle)
            try await GenericVariableHandle.convert(application: context.application, domain: domain, createNetcdf: signature.createNetcdf,
                run: nil, handles: handles, concurrent: concurrent, writeUpdateJson: true, uploadQueues: queues)
            // Commit only after conversion succeeds. Failed/interrupted batches are retried.
            completed.formUnion(successful.map { $0.scan.identity })
            completed = Self.recentCompleted(completed, lookbackDays: loopbackDays)
            try JSONEncoder().encode(completed.sorted()).write(to: URL(fileURLWithPath: stateFile), options: .atomic)
        }
        await progress.finish()
    }

    struct InvalidScanTimes: Error, CustomStringConvertible {
        let bounds: [Double]
        var description: String { "Invalid GOES mode-6 time_bounds: \(bounds)" }
    }

    static func validatedScanTimes(bounds: [Double], scan: Scan) throws -> (start: Double, end: Double) {
        guard bounds.count == 2 else { throw InvalidScanTimes(bounds: bounds) }
        let epoch = Double(Timestamp(2000, 1, 1, 12).timeIntervalSince1970)
        let start = epoch + bounds[0], end = epoch + bounds[1]
        guard start.isFinite, end.isFinite, abs(start - Double(scan.start.timeIntervalSince1970)) < 2,
              (560...590).contains(end - start) else {
            throw InvalidScanTimes(bounds: bounds)
        }
        return (start, end)
    }

    static func decode(nc: Group, scan: Scan) throws -> [Float] {
        let bounds = try nc.getVariable(name: "time_bounds")?.asType(Double.self)?.read() ?? []
        let (start, end) = try validatedScanTimes(bounds: bounds, scan: scan)
        let grid = GoesDomain.fixedGrid
        guard let variable = nc.getVariable(name: "DSR"), variable.dimensions.map(\.length) == [grid.ny, grid.nx],
              let raw = try variable.asType(UInt16.self)?.read(),
              let quality = try nc.getVariable(name: "DQF")?.asType(UInt8.self)?.read(), quality.count == raw.count,
              let scale = try variable.getAttribute("scale_factor")?.readFloat(),
              let offset = try variable.getAttribute("add_offset")?.readFloat(),
              let fill: UInt16 = try variable.getAttribute("_FillValue")?.read(),
              let x = try nc.getVariable(name: "x")?.readAndScale(),
              let y = try nc.getVariable(name: "y")?.readAndScale(), x.count == grid.nx, y.count == grid.ny,
              let projection = nc.getVariable(name: "goes_imager_projection"),
              let longitude: Double = try projection.getAttribute("longitude_of_projection_origin")?.read(), abs(longitude + 75) < 0.001,
              abs(x[0] + 0.151844) < 0.000001, abs(x.last! - 0.151844) < 0.000001,
              abs(y[0] - 0.151844) < 0.000001, abs(y.last! + 0.151844) < 0.000001 else {
            throw Abort(.badGateway, reason: "Unexpected GOES-19 DSR grid, variables or projection")
        }
        var data = [Float](repeating: .nan, count: raw.count)
        // Work one row at a time, avoiding a full-disk array of double scan offsets.
        for row in 0..<grid.ny {
            let sourceRow = grid.ny - 1 - row
            var values = [Float](repeating: .nan, count: grid.nx)
            var offsets = [Double](repeating: .nan, count: grid.nx)
            for col in 0..<grid.nx {
                let i = sourceRow * grid.nx + col
                let coordinates = grid.getCoordinates(gridpoint: row * grid.nx + col)
                guard coordinates.latitude.isFinite else { continue }
                values[col] = radiation(raw: raw[i], quality: quality[i], fill: fill, scale: scale, offset: offset)
                offsets[col] = (scanSeconds(sourceRow: sourceRow, column: col, start: start, end: end) - Double(scan.time.timeIntervalSince1970)) / 3600
            }
            Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &values, grid: grid,
                locationRange: row * grid.nx..<(row + 1) * grid.nx,
                timerange: TimerangeDt(start: scan.time, nTime: 1, dtSeconds: 600), sunDeclinationCutOffDegrees: 1,
                scanTimeDifferenceHours: offsets)
            data.replaceSubrange(row * grid.nx..<(row + 1) * grid.nx, with: values)
        }
        return data
    }

    static func radiation(raw: UInt16, quality: UInt8, fill: UInt16, scale: Float, offset: Float) -> Float {
        // DQF=1 includes low-sun retrievals (solar zenith >70 degrees), as well
        // as other degraded/invalid retrievals. Retain finite, in-range values
        // so sunrise/sunset radiation is available; still reject fill values.
        guard quality <= 1, raw != fill else { return .nan }
        let value = Float(raw) * scale + offset
        return (0...1500).contains(value) ? value : .nan
    }

    /// Approximate per-pixel acquisition times from the NOAA GOES-East mode 6A
    /// timeline (22 north-to-south swaths, each scanned west-to-east). Unlike a
    /// linear row ramp this retains the pauses for CONUS/mesoscale observations.
    /// DSR does not distribute pixel timestamps. Swath boundaries and along-scan
    /// positions are approximations; anchor the timeline to each file's time_bounds.
    /// https://www.goes-r.gov/users/abiScanModeInfo.html
    static let swaths: [(Double, Double)] = [
        (19.5, 26.5), (33.4, 42.3), (42.7, 53.0), (64.3, 75.7),
        (93.0, 105.2), (122.8, 135.3), (152.5, 165.5), (182.2, 195.8),
        (212.1, 226.0), (242.0, 256.0), (272.0, 286.2), (302.0, 316.2),
        (332.0, 346.0), (362.1, 376.0), (392.2, 405.8), (422.4, 435.5),
        (452.8, 465.3), (483.0, 495.0), (513.2, 524.5), (544.0, 554.2),
        (574.7, 583.3), (583.7, 590.7)
    ]

    static func scanSeconds(sourceRow: Int, column: Int, start: Double, end: Double) -> Double {
        let swath = min(21, sourceRow * 22 / 5424)
        let y = (Double(swath) + 0.5) / 22 * 2 - 1
        let halfWidth = sqrt(1 - y * y)
        let x = (Double(column) + 0.5) / 5424 * 2 - 1
        let fraction = max(0, min(1, (x / halfWidth + 1) / 2))
        let (left, right) = swaths[swath]
        let relative = (left + (right - left) * fraction - swaths[0].0) / (swaths[21].1 - swaths[0].0)
        return start + relative * (end - start)
    }
}
