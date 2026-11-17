import Foundation
import Vapor
import OmFileFormat
import OmFileIO

/// Repair the historical RUC precipitation split using the original grid temperature.
struct RepairIconD2RucSnowCommand: AsyncCommand {
    var help: String { "Repair ICON-D2 RUC snow in remote historical chunks and individual runs." }

    struct Signature: CommandSignature {
        @Argument(name: "start-date", help: "First date to correct (YYYY-MM-DD).")
        var startDate: String
        @Argument(name: "end-date", help: "Last date to correct, inclusive (YYYY-MM-DD).")
        var endDate: String
        @Option(name: "upload-s3-bucket", help: "Optional comma-separated S3 upload destinations. If omitted, corrected files remain local.")
        var uploadS3Bucket: String?
        @Flag(name: "install-local", help: "Install corrected chunks into DATA_DIRECTORY before uploading. Requires the working directory on the same filesystem. Stop ICON jobs and drain uploads first.")
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
        let logger = context.application.logger
        if signature.installLocal && storage != "data_run" {
            logger.warning("Installing chunks into live storage. ICON jobs and queued uploads must remain stopped until this command finishes.")
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
        func input(_ path: String, optional: Bool = false) async throws -> OmFileReader<MmapFile>? {
            if signature.installLocal, let local = Self.localChunkPath(path) {
                if FileManager.default.fileExists(atPath: local) {
                    return try await OmFileReader(mmapFile: local)
                }
            }
            guard let file = try await root.getFile(fullPath: path) else {
                if optional { return nil }
                throw Abort(.notFound, reason: "Missing input \(path)")
            }
            logger.info("Downloading \(path)")
            let backend = await file.file.makeCachedClient(context: file.context)
            let server = try await backend.server.getServerFor(hash: backend.object.fnv1aHash64)
            let local = "\(source)/\(path)"
            try await backend.server.client.downloadWholeFile(url: server.uploadURL(remotePath: backend.object), localFile: local, logger: logger)
            return try await OmFileReader(mmapFile: local)
        }

        var outputs = [String]()
        if storage != "data_run" {
            for chunk in Self.chunks(for: start..<end, domain: snowDomain) {
                let name = "chunk_\(chunk).om"
                let path = "\(snowPath)/snowfall_water_equivalent/\(name)"
                guard let snow = try await input(path, optional: true) else { continue }
                var inputs = ["snowfall_water_equivalent": try snow.expectArray(of: Float.self)]
                for variable in ["precipitation", "rain", "hail"] {
                    inputs[variable] = try await input("\(snowPath)/\(variable)/\(name)", optional: variable == "hail")?.expectArray(of: Float.self)
                }
                let duration = snowDomain.omFileLength * snowDomain.dtSeconds
                let time = chunk * duration ..< (chunk + 1) * duration
                let selected = max(start, time.lowerBound)..<min(end, time.upperBound)
                var temperatures = [(time: [Int], reader: OmFileReaderArray<MmapFile, Float>)]()
                // Calculate required temperature chunks; remote listings may lag local data.
                for temperatureChunk in Self.chunks(for: selected, domain: temperatureDomain) {
                    let file = try await input("\(temperaturePath)/chunk_\(temperatureChunk).om")!
                    let first = temperatureChunk * temperatureDomain.omFileLength * 3600
                    let times = (0..<temperatureDomain.omFileLength).map { first + $0 * 3600 }
                    temperatures.append((times, try file.expectArray(of: Float.self)))
                }
                let changed = try await Self.repair(inputs: inputs, temperatures: temperatures,
                    time: Array(stride(from: time.lowerBound, to: time.upperBound, by: 900)),
                    selection: start..<end, output: "\(destination)/\(path)")
                logger.info("\(name): corrected \(changed) values")
                outputs.append(path)
            }
            if signature.installLocal {
                for path in outputs {
                    guard let live = Self.localChunkPath(path) else { continue }
                    logger.info("Installing \(live)")
                    try Self.install(from: "\(destination)/\(path)", to: live)
                }
            }
        }
        if storage != "data" {
            // Include earlier runs whose forecasts overlap the requested valid dates.
            let horizon = IconDownloadDomains.iconD2Ruc.quarterHourlyForecastHorizon!
            for run in stride(from: start - horizon, to: end, by: 3600) {
                let date = Timestamp(run).format_directoriesYYYYMMddhhmm
                let path = "data_run/\(snowDomain.domainRegistry.rawValue)/\(date)"
                let outputPath = "\(path)/snowfall_water_equivalent.om"
                guard let snow = try await input(outputPath, optional: true) else { continue }
                let times = try await Self.runTimes(snow, run: run)
                guard times.contains(where: { (start..<end).contains($0) }) else { continue }
                var inputs = ["snowfall_water_equivalent": try snow.expectArray(of: Float.self)]
                for variable in ["precipitation", "rain", "hail"] {
                    guard let file = try await input("\(path)/\(variable).om", optional: variable == "hail") else { continue }
                    guard try await Self.runTimes(file, run: run) == times else {
                        throw Abort(.badRequest, reason: "Mismatched run timestamps in \(path)/\(variable).om")
                    }
                    inputs[variable] = try file.expectArray(of: Float.self)
                }
                let temperature = try await input("data_run/\(temperatureDomain.domainRegistry.rawValue)/\(date)/temperature_2m.om")!
                let temperatureTimes = try await Self.runTimes(temperature, run: run)
                let changed = try await Self.repair(inputs: inputs,
                    temperatures: [(temperatureTimes, try temperature.expectArray(of: Float.self))],
                    time: times, selection: start..<end, output: "\(destination)/\(outputPath)", metadata: snow)
                logger.info("Run \(date): corrected \(changed) values")
                outputs.append(outputPath)
            }
        }
        guard !outputs.isEmpty else { throw Abort(.notFound, reason: "No RUC files in the selected dates") }

        guard !endpoints.isEmpty else { return }
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 4)
        for path in outputs {
            logger.info("Uploading \(path)")
            let local = (signature.installLocal ? Self.localChunkPath(path) : nil) ?? "\(destination)/\(path)"
            for endpoint in endpoints {
                let upload = try await S3Uploader.uploadMultipart(client: context.application.http1Client, file: local,
                    url: endpoint.uploadURL(remotePath: path), lastModified: .now(), executor: executor)
                try await upload.commit(client: context.application.http1Client)
            }
        }
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

    static func localChunkPath(_ object: String, dataDirectory: String = OpenMeteo.dataDirectory) -> String? {
        guard object.hasPrefix("data/") else { return nil }
        return URL(fileURLWithPath: dataDirectory).appendingPathComponent(String(object.dropFirst(5))).path
    }

    static func install(from source: String, to destination: String) throws {
        try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: destination).deletingLastPathComponent().path, withIntermediateDirectories: true)
        try FileManager.default.moveFileOverwrite(from: source, to: destination)
    }

    static func chunks(for time: Range<Int>, domain: IconNativeDomains) -> Range<Int> {
        let duration = domain.omFileLength * domain.dtSeconds
        return time.lowerBound / duration ..< (time.upperBound - 1) / duration + 1
    }

    static func correctedSnow(snow: Float, precipitation: Float, rain: Float, hail: Float, temperature: Float) -> Float {
        guard snow.isFinite, precipitation.isFinite, rain.isFinite, hail.isFinite,
              temperature.isFinite, temperature <= IconDomains.tMelt else { return snow }
        return snow + max(0, precipitation - rain - hail - snow)
    }

    static func repair(inputs: [String: OmFileReaderArray<MmapFile, Float>],
                       temperatures: [(time: [Int], reader: OmFileReaderArray<MmapFile, Float>)],
                       time: [Int], selection: Range<Int>, output: String, metadata: OmFileReader<MmapFile>? = nil) async throws -> Int {
        guard let snow = inputs["snowfall_water_equivalent"], inputs["precipitation"] != nil, inputs["rain"] != nil else {
            throw Abort(.badRequest, reason: "Missing precipitation inputs")
        }
        let dimensions = Array(snow.getDimensions())
        guard dimensions.count == 3, dimensions[0] == 1, dimensions[2] == time.count,
              inputs.values.allSatisfy({ Array($0.getDimensions()) == dimensions }),
              temperatures.allSatisfy({ Array($0.reader.getDimensions()) == [1, dimensions[1], UInt64($0.time.count)] }) else {
            throw Abort(.badRequest, reason: "Unexpected RUC file dimensions")
        }
        try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: output).deletingLastPathComponent().path, withIntermediateDirectories: true)
        let handle = try FileHandle.createNewFile(file: output, overwrite: true, temporary: true)
        defer { try? handle.close() }
        let file = OmFileWriter(fn: handle, initialCapacity: 1024 * 1024)
        let writer = try file.prepareArray(type: Float.self, dimensions: dimensions, chunkDimensions: Array(snow.getChunkDimensions()),
                                          compression: snow.compression, scale_factor: snow.scaleFactor, add_offset: snow.addOffset)
        let temperatureIndices = temperatures.map { source in
            let indices = Dictionary(uniqueKeysWithValues: source.time.enumerated().map { ($0.element, $0.offset) })
            return time.map { indices[$0 / 3600 * 3600] }
        }
        var changed = 0
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
        try handle.linkTemporary(file: output)
        return changed
    }

}
