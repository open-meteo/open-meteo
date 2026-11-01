import Foundation
import Vapor
import OmFileIO
import OmFileFormat
import SwiftNetCDF

/// Offline repair of the legacy SARAH archive. Inputs must be frozen while this runs.
struct EumetsatSarahCorrect: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "directory", help: "Path to eumetsat_sarah3_30min")
        var directory: String

        @Option(name: "variables", help: "Comma-separated shortwave_radiation,direct_radiation (default: both)")
        var variables: String?

        @Option(name: "concurrent", short: "c", help: "Parallel spatial tiles (default: up to 8 CPU cores; buffers capped at 512 MiB)")
        var concurrent: Int?

        @Option(name: "file", help: "Only write this basename, e.g. year_2024.om; neighbours are still read")
        var file: String?
    }

    var help: String { "Repair SARAH scan-time averaging into separate _corrected directories; resume by rerunning" }

    struct ArchiveFile: Sendable {
        let name: String
        let time: Range<Int> // half-hour indices since Unix epoch
    }

    enum RepairError: Error {
        case invalid(String)
    }

    static func file(_ name: String) -> ArchiveFile? {
        let dt = 1800
        if name.hasPrefix("year_"), name.hasSuffix(".om"), let year = Int(name.dropFirst(5).dropLast(3)), (1900...2100).contains(year) {
            return ArchiveFile(name: name, time: Timestamp(year, 1, 1).timeIntervalSince1970 / dt ..< Timestamp(year + 1, 1, 1).timeIntervalSince1970 / dt)
        }
        if name.hasPrefix("chunk_"), name.hasSuffix(".om"), let chunk = Int(name.dropFirst(6).dropLast(3)), (0..<100000).contains(chunk) {
            let length = EumetsatSarahDomain.sarah3_30min.omFileLength
            return ArchiveFile(name: name, time: chunk * length ..< (chunk + 1) * length)
        }
        return nil
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = EumetsatSarahDomain.sarah3_30min
        let grid = domain.grid
        let variables = signature.variables?.split(separator: ",").map(String.init) ?? ["shortwave_radiation", "direct_radiation"]
        guard !variables.isEmpty, variables.allSatisfy({ ["shortwave_radiation", "direct_radiation"].contains($0) }) else {
            throw RepairError.invalid("Only shortwave_radiation and direct_radiation are supported")
        }
        let metaDataFile = "\(domain.downloadDirectory)/AuxilaryData_SARAH-3.nc"
        guard let nc = try NetCDF.open(path: metaDataFile, allowUpdate: false) else {
            throw RepairError.invalid("Cannot open auxiliary NetCDF at \(metaDataFile)")
        }
        func offsets(_ name: String) throws -> [Double] {
            guard let values = try nc.getVariable(name: name)?.asType(Double.self)?.read(), values.count == grid.count else {
                throw RepairError.invalid("Missing or wrong-sized \(name)")
            }
            return values.map { $0 <= -999 ? .nan : $0 }
        }
        let mviri = try offsets("time_difference_MVIRI")
        let seviri = try offsets("time_difference_SEVIRI")
        try await Self.repairArchive(directory: signature.directory, variables: variables, selectedFile: signature.file,
            grid: grid, mviri: mviri, seviri: seviri, logger: logger,
            concurrent: signature.concurrent ?? min(8, ProcessInfo.processInfo.activeProcessorCount))
    }

    static func repairArchive(directory: String, variables: [String], selectedFile: String?, grid: any Gridable,
                              mviri: [Double], seviri: [Double], logger: Logger, concurrent: Int = 1) async throws {
        guard concurrent > 0 else { throw RepairError.invalid("--concurrent must be positive") }
        let fm = FileManager.default
        for variable in variables {
            let source = "\(directory)/\(variable)"
            let destination = "\(directory)/\(variable)_corrected"
            try fm.createDirectory(atPath: destination, withIntermediateDirectories: true)
            let files = try fm.contentsOfDirectory(atPath: source).compactMap(Self.file).sorted { $0.time.lowerBound < $1.time.lowerBound }
            guard let last = files.max(by: { $0.time.upperBound < $1.time.upperBound }) else {
                throw RepairError.invalid("No archive files in \(source)")
            }
            var targets = files
            // Preserve the final sample too, even if there is no following archive file yet.
            let length = EumetsatSarahDomain.sarah3_30min.omFileLength
            let tail = Self.file("chunk_\(last.time.upperBound / length).om")!
            if !files.contains(where: { $0.time.contains(last.time.upperBound) }) {
                if !targets.contains(where: { $0.name == tail.name }) { targets.append(tail) }
            }
            if let selected = selectedFile, !targets.contains(where: { $0.name == selected }) {
                throw RepairError.invalid("Unknown file \(selected)")
            }
            for target in targets where selectedFile == nil || selectedFile == target.name {
                let output = "\(destination)/\(target.name)"
                if fm.fileExists(atPath: output) {
                    let existing = try await OmFileReader(mmapFile: output).expectArray(of: Float.self)
                    guard existing.getDimensions() == [UInt64(grid.ny), UInt64(grid.nx), UInt64(target.time.count)] else {
                        throw RepairError.invalid("Unexpected completed output \(output)")
                    }
                    logger.info("Skipping completed \(output)")
                    continue
                }
                logger.info("Correcting \(variable)/\(target.name)")
                // Start at source midnight to reproduce the downloader's daily backfill resets.
                let start = ((target.time.lowerBound - 1) / 48) * 48
                let inputTime = start ..< target.time.upperBound - 1
                let candidates = files.filter { $0.time.overlaps(inputTime) }
                // Years override overlapping chunks, and the target's own source wins last.
                let ordered = candidates.sorted {
                    func priority(_ file: ArchiveFile) -> Int { file.name == target.name ? 2 : file.name.hasPrefix("year_") ? 1 : 0 }
                    return priority($0) < priority($1)
                }
                let readers = try await ordered.asyncMap { file in
                    (file, try await OmFileReader(mmapFile: "\(source)/\(file.name)").expectArray(of: Float.self))
                }
                guard let reference = readers.last?.1 else { throw RepairError.invalid("No source for \(target.name)") }
                for (file, reader) in readers {
                    let dims = reader.getDimensions()
                    guard dims == [UInt64(grid.ny), UInt64(grid.nx), UInt64(file.time.count)] else {
                        throw RepairError.invalid("Unexpected dimensions in \(file.name): \(dims)")
                    }
                }
                let nativeChunks = reference.getChunkDimensions()
                // Keep source spatial chunks aligned; full time series avoids repeated decompression
                // of shifted time chunks.
                let cy = Int(nativeChunks[0])
                let cx = min(grid.nx, Int(nativeChunks[1]))
                guard cy * cx * inputTime.count <= 32 * 1024 * 1024 else {
                    throw RepairError.invalid("Spatial chunk requires over 128 MiB per buffer; rechunk source first")
                }
                let dimensions: [UInt64] = [UInt64(grid.ny), UInt64(grid.nx), UInt64(target.time.count)]
                let temporary = output + ".partial"
                let handle = try FileHandle.createNewFile(file: temporary, overwrite: true)
                defer { try? handle.close() }
                let fileWriter = OmFileWriter(fn: handle, initialCapacity: 1024 * 1024)
                let writer = try fileWriter.prepareArray(type: Float.self, dimensions: dimensions,
                    chunkDimensions: [UInt64(cy), UInt64(cx), min(nativeChunks[2], UInt64(target.time.count))],
                    compression: reference.compression, scale_factor: reference.scaleFactor, add_offset: reference.addOffset)
                let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * target.time.count * 4, name: "Correct")
                let days = stride(from: start, to: inputTime.upperBound, by: 48).map { day in
                    CorrectionDay(start: day, count: min(48, inputTime.upperBound - day))
                }
                let nxTiles = (grid.nx + cx - 1) / cx
                let nTiles = ((grid.ny + cy - 1) / cy) * nxTiles
                // Includes input/output and daily scratch buffers; lookup tables and mappings are extra.
                let bytesPerTile = cy * cx * (inputTime.count + target.time.count + 4 * 48) * MemoryLayout<Float>.stride
                let workers = min(concurrent, nTiles, max(1, 512 * 1024 * 1024 / bytesPerTile))
                logger.info("Using \(workers) spatial workers, approximately \(workers * bytesPerTile / 1024 / 1024) MiB of tile buffers")
                let tileRanges: @Sendable (Int) -> (Range<Int>, Range<Int>) = { index in
                    let y = (index / nxTiles) * cy
                    let x = (index % nxTiles) * cx
                    return (y..<min(y + cy, grid.ny), x..<min(x + cx, grid.nx))
                }
                let conversionStart = DispatchTime.now()
                var workerReadSeconds = 0.0
                var workerSolarSeconds = 0.0
                var writeSeconds = 0.0
                try await processOrdered(count: nTiles, concurrent: workers, process: { index in
                    let (ys, xs) = tileRanges(index)
                    return try await correctTile(ys: ys, xs: xs, readers: readers, grid: grid,
                        inputTime: inputTime, target: target, days: days, mviri: mviri, seviri: seviri)
                }, consume: { index, result in
                    let (ys, xs) = tileRanges(index)
                    let writeStart = DispatchTime.now()
                    try writer.writeData(array: result.data, arrayDimensions: [UInt64(ys.count), UInt64(xs.count), UInt64(target.time.count)])
                    writeSeconds += elapsedSeconds(since: writeStart)
                    workerReadSeconds += result.readSeconds
                    workerSolarSeconds += result.solarSeconds
                    await progress.add(result.data.count * 4)
                })
                logger.info("Tile processing elapsed \(elapsedSeconds(since: conversionStart))s; summed worker read/decode \(workerReadSeconds)s, solar \(workerSolarSeconds)s; serial compression/write \(writeSeconds)s")
                let root = try fileWriter.write(array: try writer.finalise(), name: "", children: [])
                try fileWriter.writeTrailer(rootVariable: root)
                try handle.synchronize()
                try handle.close()
                let check = try await OmFileReader(mmapFile: temporary).expectArray(of: Float.self)
                guard check.getDimensions() == dimensions else { throw RepairError.invalid("Output validation failed") }
                try fm.moveFileOverwrite(from: temporary, to: output)
                await progress.finish()
            }
        }
    }

    struct CorrectionDay: Sendable {
        let start: Int
        let time: TimerangeDt
        let isMviri: Bool
        let geometry: Zensun.SolarAveragingGeometry
        let shiftedGeometry: Zensun.SolarAveragingGeometry

        init(start: Int, count: Int) {
            self.start = start
            self.time = TimerangeDt(start: Timestamp(start * 1800), nTime: count, dtSeconds: 1800)
            self.isMviri = start * 1800 < Timestamp(2006, 1, 1).timeIntervalSince1970
            self.geometry = Zensun.SolarAveragingGeometry(time: time)
            self.shiftedGeometry = Zensun.SolarAveragingGeometry(time:
                TimerangeDt(start: time.range.lowerBound.add(1800), nTime: count, dtSeconds: 1800))
        }
    }

    /// Parallel reads and solar conversion, with a bounded reorder buffer and a single ordered writer.
    /// Only refill slots after consuming results, so a slow early tile cannot accumulate unbounded data.
    static func processOrdered<Result: Sendable>(count: Int, concurrent: Int,
                               process: @escaping @Sendable (Int) async throws -> Result,
                               consume: (Int, Result) async throws -> Void) async throws {
        precondition(concurrent > 0)
        try await withThrowingTaskGroup(of: (Int, Result).self) { group in
            var submitted = 0
            var next = 0
            var pending = [Int: Result]()
            for index in 0..<min(count, concurrent) {
                group.addTask { (index, try await process(index)) }
                submitted += 1
            }
            while let (index, data) = try await group.next() {
                pending[index] = data
                while let result = pending.removeValue(forKey: next) {
                    try Task.checkCancellation()
                    try await consume(next, result)
                    next += 1
                    if submitted < count {
                        let index = submitted
                        group.addTask { (index, try await process(index)) }
                        submitted += 1
                    }
                }
            }
        }
    }

    struct TileResult: Sendable {
        let data: [Float]
        let readSeconds: Double
        let solarSeconds: Double
    }

    static func elapsedSeconds(since start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }

    static func correctTile(ys: Range<Int>, xs: Range<Int>,
                            readers: [(ArchiveFile, OmFileReaderArray<MmapFile, Float>)], grid: any Gridable,
                            inputTime: Range<Int>, target: ArchiveFile, days: [CorrectionDay],
                            mviri: [Double], seviri: [Double]) async throws -> TileResult {
        try Task.checkCancellation()
        let start = inputTime.lowerBound
        // Outside the satellite footprint both sensors have invalid offsets; output is always NaN.
        let outsideFootprint = ys.allSatisfy { y in
            xs.allSatisfy { x in
                let location = y * grid.nx + x
                return !mviri[location].isFinite && !seviri[location].isFinite
            }
        }
        if outsideFootprint {
            return TileResult(data: [Float](repeating: .nan, count: ys.count * xs.count * target.time.count), readSeconds: 0, solarSeconds: 0)
        }
        let readStart = DispatchTime.now()
        var data = [Float](repeating: .nan, count: ys.count * xs.count * inputTime.count)
        for (file, reader) in readers {
            let lo = max(inputTime.lowerBound, file.time.lowerBound)
            let hi = min(inputTime.upperBound, file.time.upperBound)
            let tr = UInt64(lo - file.time.lowerBound)..<UInt64(hi - file.time.lowerBound)
            try await reader.read(into: &data, range: [ys.toUInt64(), xs.toUInt64(), tr],
                intoCubeOffset: [0, 0, UInt64(lo - start)],
                intoCubeDimension: [UInt64(ys.count), UInt64(xs.count), UInt64(inputTime.count)])
        }
        let readSeconds = elapsedSeconds(since: readStart)
        let solarStart = DispatchTime.now()
        if data.allSatisfy({ $0.isNaN }) {
            return TileResult(data: [Float](repeating: .nan, count: ys.count * xs.count * target.time.count),
                readSeconds: readSeconds, solarSeconds: elapsedSeconds(since: solarStart))
        }
        var result = [Float](repeating: .nan, count: ys.count * xs.count * target.time.count)
        for (row, yy) in ys.enumerated() {
            let locations = yy * grid.nx + xs.lowerBound ..< yy * grid.nx + xs.upperBound
            let mviriOffsets = Array(mviri[locations])
            let seviriOffsets = Array(seviri[locations])
            let mviriShifted = mviriOffsets.map { $0 - 0.5 }
            let seviriShifted = seviriOffsets.map { $0 - 0.5 }
            var daily = [Float](repeating: .nan, count: xs.count * 48)
            for day in days {
                try Task.checkCancellation()
                let count = day.time.count
                let offsets = day.isMviri ? mviriOffsets : seviriOffsets
                let shiftedOffsets = day.isMviri ? mviriShifted : seviriShifted
                if daily.count != xs.count * count {
                    daily = [Float](repeating: .nan, count: xs.count * count)
                }
                for col in 0..<xs.count {
                    let base = (row * xs.count + col) * inputTime.count + day.start - start
                    daily.replaceSubrange(col * count ..< (col + 1) * count, with: data[base..<base + count])
                }
                Self.correct(data: &daily, grid: grid, locations: locations, time: day.time, offsets: offsets, geometry: day.geometry,
                    shiftedGeometry: day.shiftedGeometry, shiftedOffsets: shiftedOffsets)
                for col in 0..<xs.count {
                    for t in 0..<count {
                        let out = day.start + t + 1 - target.time.lowerBound
                        if out >= 0 && out < target.time.count {
                            result[(row * xs.count + col) * target.time.count + out] = daily[col * count + t]
                        }
                    }
                }
            }
        }
        return TileResult(data: result, readSeconds: readSeconds, solarSeconds: elapsedSeconds(since: solarStart))
    }

    static func correct(data: inout [Float], grid: any Gridable, locations: Range<Int>, time: TimerangeDt, offsets: [Double],
                        geometry: Zensun.SolarAveragingGeometry? = nil,
                        shiftedGeometry: Zensun.SolarAveragingGeometry? = nil, shiftedOffsets: [Double]? = nil) {
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &data, grid: grid, locationRange: locations,
            timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets, undoAveraging: true, geometry: geometry)
        let unrecoverable = data.map { $0.isNaN }
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &data, grid: grid, locationRange: locations,
            timerange: TimerangeDt(start: time.range.lowerBound.add(1800), nTime: time.count, dtSeconds: 1800),
            sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: shiftedOffsets ?? offsets.map { $0 - 0.5 }, geometry: shiftedGeometry)
        // Do not turn archive gaps (including absent neighbours) into synthetic observations.
        for i in data.indices where unrecoverable[i] || !offsets[i / time.count].isFinite { data[i] = .nan }
    }
}
