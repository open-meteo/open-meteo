import Foundation
import Vapor
import OmFileFormat
import OmFileIO

/// Repair the historical RUC precipitation split using the original grid temperature.
struct RepairIconD2RucSnowCommand: AsyncCommand {
    // Resume cached work for the same range; refresh from remote when the range changes.
    var help: String { "Repair ICON-D2 RUC snow in remote historical chunks and individual runs." }

    struct Signature: CommandSignature {
        @Argument(name: "start-date", help: "First date to correct (YYYY-MM-DD).")
        var startDate: String
        @Argument(name: "end-date", help: "Last date to correct, inclusive (YYYY-MM-DD).")
        var endDate: String
        @Option(name: "upload-s3-bucket", help: "Optional comma-separated S3 upload destinations. If omitted, corrected files remain local.")
        var uploadS3Bucket: String?
        @Flag(name: "install-local", help: "Install corrected files into live data directories before uploading. Stop ICON jobs and drain uploads first.")
        var installLocal: Bool
        @Option(name: "storage", help: "data, data_run, or both (default). Dates select forecast valid times.")
        var storage: String?
        @Option(name: "directory", help: "Local working directory. Defaults to DATA_DIRECTORY/repair-icon-d2-ruc.")
        var directory: String?
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = try IsoDate(fromIsoString: signature.startDate).toTimestamp().timeIntervalSince1970
        let end = try IsoDate(fromIsoString: signature.endDate).toTimestamp().timeIntervalSince1970 + 86400
        guard start < end else { throw Abort(.badRequest, reason: "Invalid date range") }
        let storage = signature.storage ?? "both"
        guard ["data", "data_run", "both"].contains(storage) else {
            throw Abort(.badRequest, reason: "Unknown storage \(storage)")
        }
        if signature.installLocal && storage != "data" && OpenMeteo.dataRunDirectory == nil {
            throw Abort(.badRequest, reason: "DATA_RUN_DIRECTORY is required to install run files")
        }
        let logger = context.application.logger
        if signature.installLocal {
            logger.warning("Installing into live storage. ICON jobs and queued uploads must remain stopped until this command finishes.")
        }
        let directory = signature.directory ?? OpenMeteo.dataDirectory + "repair-icon-d2-ruc"
        let snowDomain = IconNativeDomains.iconD2RucNative15min
        let temperatureDomain = IconNativeDomains.iconD2RucNative
        let snowPath = "data/\(snowDomain.domainRegistry.rawValue)"
        let temperaturePath = "data/\(temperatureDomain.domainRegistry.rawValue)/temperature_2m"
        let source = "\(directory)/original"
        let destination = "\(directory)/corrected"
        let endpoints = signature.uploadS3Bucket.map(S3BucketEndpoint.parseList) ?? []
        if endpoints.isEmpty {
            logger.warning("No --upload-s3-bucket configured. Corrected files will remain local at \(destination).")
        }
        guard let remote = OmFileSystemManager.instance.remoteFileSystem else {
            throw Abort(.badRequest, reason: "REMOTE_DATA_DIRECTORY is required")
        }
        let root = try await remote.getRoot()
        try Self.prepareWorkspace(directory, selection: start..<end, refresh: signature.installLocal)
        var outputs = [String]()
        if storage != "data_run" {
            guard let snowDirectory = try await root.getDirectory(fullPath: snowPath + "/snowfall_water_equivalent/"),
                  let temperatureDirectory = try await root.getDirectory(fullPath: temperaturePath + "/") else {
                throw Abort(.notFound, reason: "Remote RUC snow or temperature directory missing")
            }
            var directories = Set<String>()
            var snowFiles = [String: (lastModified: Timestamp, size: Int64)]()
            var temperatureFiles = [String: (lastModified: Timestamp, size: Int64)]()
            await snowDirectory.directory.exportDirectories(directories: &directories, files: &snowFiles)
            await temperatureDirectory.directory.exportDirectories(directories: &directories, files: &temperatureFiles)
            let targets = snowFiles.keys.sorted().filter {
                Self.fileTime($0, domain: snowDomain)?.overlaps(start..<end) == true
            }
            guard !targets.isEmpty else { throw Abort(.notFound, reason: "No remote snow chunks in the selected dates") }
            let targetTimes = targets.map { Self.fileTime($0, domain: snowDomain)! }
            for name in targets {
                for variable in ["snowfall_water_equivalent", "precipitation", "rain", "hail"] {
                    let path = "\(snowPath)/\(variable)/\(name)"
                    let local = try signature.installLocal ? Self.livePath(path) : nil
                    let file = try await root.getFile(fullPath: path)
                    if variable == "hail", file == nil, local.map({ FileManager.default.fileExists(atPath: $0) }) != true { continue }
                    logger.info("Downloading or snapshotting \(path)")
                    try await Self.download(file, to: "\(source)/\(path)", local: local)
                }
            }
            for name in temperatureFiles.keys.sorted() {
                guard let time = Self.fileTime(name, domain: temperatureDomain), targetTimes.contains(where: { $0.overlaps(time) }),
                      let file = await temperatureDirectory.getFile(name: name) else { continue }
                logger.info("Downloading or reusing \(temperaturePath)/\(name)")
                try await Self.download(file, to: "\(source)/\(temperaturePath)/\(name)", local: signature.installLocal ? Self.livePath("\(temperaturePath)/\(name)") : nil)
            }
            let fm = FileManager.default
            let localTemperatureFiles = temperatureFiles.keys.sorted()
            for name in targets {
                let time = Self.fileTime(name, domain: snowDomain)!
                var inputs = [String: OmFileReaderArray<MmapFile, Float>]()
                for variable in ["snowfall_water_equivalent", "precipitation", "rain", "hail"] {
                    let path = "\(source)/\(snowPath)/\(variable)/\(name)"
                    if variable == "hail", !fm.fileExists(atPath: path) { continue }
                    inputs[variable] = try await OmFileReader(mmapFile: path).expectArray(of: Float.self)
                }
                var temperatures = [(time: [Int], reader: OmFileReaderArray<MmapFile, Float>)]()
                for temperatureName in localTemperatureFiles {
                    guard let temperatureTime = Self.fileTime(temperatureName, domain: temperatureDomain), temperatureTime.overlaps(time) else { continue }
                    let reader = try await OmFileReader(mmapFile: "\(source)/\(temperaturePath)/\(temperatureName)").expectArray(of: Float.self)
                    temperatures.append((Array(stride(from: temperatureTime.lowerBound, to: temperatureTime.upperBound, by: 3600)), reader))
                }
                guard !temperatures.isEmpty else { throw Abort(.notFound, reason: "No temperature files for \(name)") }
                let output = "\(destination)/\(snowPath)/snowfall_water_equivalent/\(name)"
                let changed = try await Self.repair(inputs: inputs, temperatures: temperatures, time: Array(stride(from: time.lowerBound, to: time.upperBound, by: 900)), selection: start..<end, output: output)
                outputs.append("\(snowPath)/snowfall_water_equivalent/\(name)")
                logger.info(changed.map { "\(name): corrected \($0) values" } ?? "Skipping completed \(name)")
            }

        }
        if storage != "data" {
            outputs += try await repairRuns(root: root, source: source, destination: destination, selection: start..<end, logger: logger, installLocal: signature.installLocal)
        }

        // Replace the downloader's inputs before publishing the same corrected files remotely.
        if signature.installLocal {
            for path in outputs {
                let live = try Self.livePath(path)
                logger.info("Installing \(live)")
                try Self.install(from: "\(destination)/\(path)", to: live)
            }
        }

        // Publish only after all local corrections have completed.
        guard !endpoints.isEmpty else { return }
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 4)
        for path in outputs {
            logger.info("Uploading \(path)")
            for endpoint in endpoints {
                let upload = try await S3Uploader.uploadMultipart(client: context.application.http1Client, file: "\(destination)/\(path)",
                    url: endpoint.uploadURL(remotePath: path), lastModified: .now(), executor: executor)
                try await upload.commit(client: context.application.http1Client)
            }
        }
    }

    private func repairRuns(root: OmFileSystemS3.DirectoryWithContext, source: String, destination: String,
                            selection: Range<Int>, logger: Logger, installLocal: Bool) async throws -> [String] {
        var outputs = [String]()
        // RUC runs hourly and forecasts up to 27 hours ahead. Include earlier runs
        // whose valid times overlap the requested dates.
        for run in stride(from: selection.lowerBound - IconDownloadDomains.iconD2Ruc.quarterHourlyForecastHorizon!, to: selection.upperBound, by: 3600) {
            let date = Timestamp(run).format_directoriesYYYYMMddhhmm
            let path = "data_run/\(IconNativeDomains.iconD2RucNative15min.domainRegistry.rawValue)/\(date)"
            guard let snow = try await root.getFile(fullPath: path + "/snowfall_water_equivalent.om") else { continue }
            logger.info("Downloading or reusing run \(date)")
            try await Self.download(snow, to: "\(source)/\(path)/snowfall_water_equivalent.om", local: installLocal ? Self.livePath("\(path)/snowfall_water_equivalent.om") : nil)
            for variable in ["precipitation", "rain", "hail"] {
                let local = try installLocal ? Self.livePath("\(path)/\(variable).om") : nil
                let file = try await root.getFile(fullPath: "\(path)/\(variable).om")
                if variable == "hail", file == nil, local.map({ FileManager.default.fileExists(atPath: $0) }) != true { continue }
                try await Self.download(file, to: "\(source)/\(path)/\(variable).om", local: local)
            }
            let temperaturePath = "data_run/\(IconNativeDomains.iconD2RucNative.domainRegistry.rawValue)/\(date)/temperature_2m.om"
            guard let temperature = try await root.getFile(fullPath: temperaturePath) else {
                throw Abort(.notFound, reason: "Missing run temperature \(temperaturePath)")
            }
            try await Self.download(temperature, to: "\(source)/\(temperaturePath)", local: installLocal ? Self.livePath(temperaturePath) : nil)
            let localSnow = try await OmFileReader(mmapFile: "\(source)/\(path)/snowfall_water_equivalent.om")
            let times = try await Self.runTimes(localSnow, run: run)
            guard times.contains(where: selection.contains) else { continue }
            var inputs = [String: OmFileReaderArray<MmapFile, Float>]()
            for variable in ["snowfall_water_equivalent", "precipitation", "rain", "hail"] {
                let localPath = "\(source)/\(path)/\(variable).om"
                if variable == "hail", !FileManager.default.fileExists(atPath: localPath) { continue }
                let file = try await OmFileReader(mmapFile: localPath)
                guard try await Self.runTimes(file, run: run) == times else {
                    throw Abort(.badRequest, reason: "Mismatched run timestamps in \(localPath)")
                }
                inputs[variable] = try file.expectArray(of: Float.self)
            }
            let localTemperature = try await OmFileReader(mmapFile: "\(source)/\(temperaturePath)")
            let temperatureTimes = try await Self.runTimes(localTemperature, run: run)
            let outputPath = "\(path)/snowfall_water_equivalent.om"
            let changed = try await Self.repair(inputs: inputs,
                temperatures: [(temperatureTimes, try localTemperature.expectArray(of: Float.self))],
                time: times, selection: selection, output: "\(destination)/\(outputPath)", metadata: localSnow)
            logger.info(changed.map { "Run \(date): corrected \($0) values" } ?? "Skipping completed run \(date)")
            outputs.append(outputPath)
        }
        if outputs.isEmpty { logger.warning("No matching RUC files found in data_run") }
        return outputs
    }

    static func runTimes(_ file: OmFileReader<MmapFile>, run: Int) async throws -> [Int] {
        let reference: Int? = try await file.getChild(name: "forecast_reference_time")?.readScalar()
        guard reference == run, let time = try await file.getChild(name: "time")?.asArray(of: Int.self) else {
            throw Abort(.badRequest, reason: "Missing or mismatched run metadata")
        }
        let times = try await time.read()
        guard !times.isEmpty, zip(times, times.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw Abort(.badRequest, reason: "Invalid run timestamps")
        }
        return times
    }

    static func livePath(_ object: String, dataDirectory: String = OpenMeteo.dataDirectory,
                         dataRunDirectory: String? = OpenMeteo.dataRunDirectory) throws -> String {
        if object.hasPrefix("data/") {
            return URL(fileURLWithPath: dataDirectory).appendingPathComponent(String(object.dropFirst(5))).path
        }
        if object.hasPrefix("data_run/"), let dataRunDirectory {
            return URL(fileURLWithPath: dataRunDirectory).appendingPathComponent(String(object.dropFirst(9))).path
        }
        throw Abort(.badRequest, reason: "No local storage configured for \(object)")
    }

    /// Copy to a sibling temporary file, then replace the live inode atomically.
    static func install(from source: String, to destination: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: URL(fileURLWithPath: destination).deletingLastPathComponent().path, withIntermediateDirectories: true)
        let temporary = destination + ".repair.partial"
        try fm.removeItemIfExists(at: temporary)
        try fm.copyItem(atPath: source, toPath: temporary)
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: temporary))
        defer { try? handle.close() }
        try handle.synchronize()
        try handle.close()
        try fm.moveFileOverwrite(from: temporary, to: destination)
    }

    static func prepareWorkspace(_ directory: String, selection: Range<Int>, refresh: Bool = false) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let marker = URL(fileURLWithPath: "\(directory)/selection")
        let range = "\(selection.lowerBound)-\(selection.upperBound)"
        if !refresh, fm.fileExists(atPath: marker.path), try String(contentsOf: marker, encoding: .utf8) == range {
            return
        }
        // Invalidate the marker first so an interrupted reset cannot resume stale files.
        try fm.removeItemIfExists(at: marker.path)
        try fm.removeItemIfExists(at: "\(directory)/original")
        try fm.removeItemIfExists(at: "\(directory)/corrected")
        try range.write(to: marker, atomically: true, encoding: .utf8)
    }

    static func fileTime(_ name: String, domain: IconNativeDomains) -> Range<Int>? {
        if name.hasPrefix("chunk_"), name.hasSuffix(".om"), let chunk = Int(name.dropFirst(6).dropLast(3)) {
            let duration = domain.omFileLength * domain.dtSeconds
            return chunk * duration ..< (chunk + 1) * duration
        }
        return nil
    }

    private static func download(_ file: OmFileSystemS3.FileWithContext?, to path: String, local: String? = nil) async throws {
        if let local, FileManager.default.fileExists(atPath: local) {
            try install(from: local, to: path)
            _ = try await OmFileReader(mmapFile: path).expectArray(of: Float.self)
            return
        }
        if FileManager.default.fileExists(atPath: path) {
            _ = try await OmFileReader(mmapFile: path).expectArray(of: Float.self)
            return
        }
        try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path, withIntermediateDirectories: true)
        guard let file else { throw Abort(.notFound, reason: "Missing input for \(path)") }
        let backend = await file.file.makeCachedClient(context: file.context)
        let temporary = path + ".partial"
        let handle = try FileHandle.createNewFile(file: temporary, overwrite: true)
        defer { try? handle.close() }
        for offset in stride(from: 0, to: backend.count, by: 8 * 1024 * 1024) {
            let buffer = try await backend.getData(offset: offset, count: min(8 * 1024 * 1024, backend.count - offset))
            try handle.write(contentsOf: Data(buffer.readableBytesView))
        }
        try handle.synchronize()
        try handle.close()
        _ = try await OmFileReader(mmapFile: temporary).expectArray(of: Float.self)
        try FileManager.default.moveFileOverwrite(from: temporary, to: path)
    }

    static func correctedSnow(snow: Float, precipitation: Float, rain: Float, hail: Float, temperature: Float) -> Float {
        guard snow.isFinite, precipitation.isFinite, rain.isFinite, hail.isFinite,
              temperature.isFinite, temperature <= IconDomains.tMelt else { return snow }
        return snow + max(0, precipitation - rain - hail - snow)
    }

    static func repair(inputs: [String: OmFileReaderArray<MmapFile, Float>],
                       temperatures: [(time: [Int], reader: OmFileReaderArray<MmapFile, Float>)],
                       time: [Int], selection: Range<Int>, output: String, metadata: OmFileReader<MmapFile>? = nil) async throws -> Int? {
        guard let snow = inputs["snowfall_water_equivalent"], inputs["precipitation"] != nil, inputs["rain"] != nil else {
            throw Abort(.badRequest, reason: "Missing precipitation inputs")
        }
        let dimensions = Array(snow.getDimensions())
        guard dimensions.count == 3, dimensions[0] == 1, dimensions[2] == time.count,
              inputs.values.allSatisfy({ Array($0.getDimensions()) == dimensions }),
              temperatures.allSatisfy({ Array($0.reader.getDimensions()) == [1, dimensions[1], UInt64($0.time.count)] }) else {
            throw Abort(.badRequest, reason: "Unexpected RUC file dimensions")
        }
        if FileManager.default.fileExists(atPath: output) {
            try await validate(output, dimensions: dimensions)
            return nil
        }
        try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: output).deletingLastPathComponent().path, withIntermediateDirectories: true)
        let temporary = output + ".partial"
        let handle = try FileHandle.createNewFile(file: temporary, overwrite: true)
        defer { try? handle.close() }
        let file = OmFileWriter(fn: handle, initialCapacity: 1024 * 1024)
        let writer = try file.prepareArray(type: Float.self, dimensions: dimensions, chunkDimensions: Array(snow.getChunkDimensions()),
                                          compression: snow.compression, scale_factor: snow.scaleFactor, add_offset: snow.addOffset)
        let temperatureIndices = temperatures.map { source in
            let indices = Dictionary(uniqueKeysWithValues: source.time.enumerated().map { ($0.element, $0.offset) })
            return time.map { indices[$0 / 3600 * 3600] }
        }
        var changed = 0
        // Process one spatial chunk at a time.
        let spatialChunk = snow.getChunkDimensions()[1]
        for x in stride(from: UInt64(0), to: dimensions[1], by: Int(spatialChunk)) {
            let locations = x..<min(x + spatialChunk, dimensions[1])
            let range: InlineArray<3, Range<UInt64>> = [0..<1, locations, 0..<dimensions[2]]
            var values = try await snow.read(range: range)
            let precipitation = try await inputs["precipitation"]!.read(range: range)
            let rain = try await inputs["rain"]!.read(range: range)
            let hail = try await inputs["hail"]?.read(range: range)
            let nt = Int(dimensions[2])
            var temperature = [Float](repeating: .nan, count: values.count)
            for (source, indices) in zip(temperatures, temperatureIndices) {
                let data = try await source.reader.read(range: [0..<1, locations, 0..<UInt64(source.time.count)])
                for t in time.indices {
                    guard let hour = indices[t] else { continue }
                    for location in 0..<locations.count {
                        temperature[location * nt + t] = data[location * source.time.count + hour]
                    }
                }
            }
            for i in values.indices where selection.contains(time[i % nt]) {
                let updated = correctedSnow(snow: values[i], precipitation: precipitation[i], rain: rain[i], hail: hail?[i] ?? 0, temperature: temperature[i])
                if updated.isFinite && updated != values[i] { changed += 1 }
                values[i] = updated
            }
            try writer.writeData(array: values, arrayDimensions: [1, UInt64(locations.count), dimensions[2]], arrayOffset: nil, arrayCount: nil)
        }
        let array = try writer.finalise()
        var children = [OmOffsetSize]()
        if let metadata {
            for index in 0..<metadata.numberOfChildren {
                guard let child = try await metadata.getChild(index) else { continue }
                let name = child.withName { String($0) }
                if let value: String = child.readScalar() {
                    children.append(try file.write(value: value, name: name, children: []))
                } else if let value: Int = child.readScalar() {
                    children.append(try file.write(value: value, name: name, children: []))
                } else if let values = child.asArray(of: Int.self) {
                    let copied = try file.writeArray(data: try await values.read(), dimensions: Array(values.getDimensions()),
                        chunkDimensions: Array(values.getChunkDimensions()), compression: values.compression,
                        scale_factor: values.scaleFactor, add_offset: values.addOffset)
                    children.append(try file.write(array: copied, name: name, children: []))
                } else {
                    throw Abort(.badRequest, reason: "Unsupported run metadata \(name)")
                }
            }
        }
        let root = try file.write(array: array, name: "", children: children)
        try file.writeTrailer(rootVariable: root)
        try handle.synchronize()
        try handle.close()
        try await validate(temporary, dimensions: dimensions)
        try FileManager.default.moveFileOverwrite(from: temporary, to: output)
        return changed
    }

    private static func validate(_ path: String, dimensions: [UInt64]) async throws {
        let reader = try await OmFileReader(mmapFile: path).expectArray(of: Float.self)
        guard Array(reader.getDimensions()) == dimensions else {
            throw Abort(.badRequest, reason: "Unexpected output dimensions in \(path)")
        }
    }
}
