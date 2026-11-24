import Foundation
import Vapor
import OmFileIO
import OmFileFormat

/// Repair already timestamp-corrected SARAH-3 archives. Run with ingestion stopped.
/// Run repair-eumetsat-sarah-sunset --execute to write all yearly and chunk files
/// to shortwave_radiation_corrected and direct_radiation_corrected for API review, leaving the originals untouched.
/// Omit --execute to count repairs without writing. Use --file year_2020.om to test one file.
struct EumetsatSarahRepairSunsetCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "file", help: "Only process this filename for both SARAH radiation variables, e.g. year_2020.om or chunk_12345.om")
        var file: String?

        @Option(name: "concurrent", short: "c", help: "Number of radiation file pairs to process in parallel (default: 1)")
        var concurrent: Int?

        @Flag(name: "execute", help: "Write both radiation variables to _corrected files; otherwise only count repairs")
        var execute: Bool
    }

    var help: String { "Repair sunset NaNs and excessive radiation in timestamp-corrected SARAH-3 files" }

    func run(using context: CommandContext, signature: Signature) async throws {
        let concurrent = signature.concurrent ?? 1
        guard concurrent > 0 else {
            throw Abort(.badRequest, reason: "--concurrent must be greater than zero")
        }
        let logger = context.application.logger
        let execute = signature.execute
        let domain = EumetsatSarahDomain.sarah3_30min
        let variables = ["shortwave_radiation", "direct_radiation"]
        var names = Set<String>()
        for variable in variables {
            let directory = domain.domainRegistry.directory + variable
            guard FileManager.default.fileExists(atPath: directory) else { continue }
            names.formUnion(try FileManager.default.contentsOfDirectory(atPath: directory).filter {
                $0.hasSuffix(".om") && ($0.hasPrefix("year_") || $0.hasPrefix("chunk_"))
            })
        }
        if let file = signature.file {
            guard names.contains(file) else {
                throw Abort(.badRequest, reason: "SARAH file not found: \(file). Pass a year_YYYY.om or chunk_INDEX.om filename")
            }
            names = [file]
        }
        try await names.sorted(by: >).foreachConcurrent(nConcurrent: concurrent) { name in
            let files = variables.map { domain.domainRegistry.directory + $0 + "/" + name }
                .filter { FileManager.default.fileExists(atPath: $0) }
            try await repairFiles(files: files, domain: domain, execute: execute, logger: logger)
        }
        context.application.logger.info("Processed \(names.count) SARAH radiation file groups")
    }

    private struct FileState {
        let file: String
        let reader: OmFileReaderArray<MmapFile, Float>
        let dimensions: [UInt64]
        let chunks: [UInt64]
        let handle: FileHandle?
        let fileWriter: OmFileWriter<FileHandle>?
        let writer: OmFileWriterArray<Float, FileHandle>?
        let output: String
        let temporary: String
        var repaired = 0
        var limited = 0
    }

    func repairFiles(files: [String], domain: EumetsatSarahDomain, execute: Bool, logger: Logger) async throws {
        guard let first = files.first else { return }
        let grid = domain.grid
        let name = URL(fileURLWithPath: first).deletingPathExtension().lastPathComponent
        let start: Timestamp
        let expectedCount: Int
        if name.hasPrefix("year_"), let year = Int(name.dropFirst(5)), (1983...2100).contains(year) {
            start = Timestamp(year, 1, 1)
            expectedCount = TimerangeDt(start: start, to: Timestamp(year + 1, 1, 1), dtSeconds: domain.dtSeconds).count
        } else if name.hasPrefix("chunk_"), let index = Int(name.dropFirst(6)), index >= 0 {
            start = Timestamp(index * domain.omFileLength * domain.dtSeconds)
            expectedCount = domain.omFileLength
        } else {
            throw Abort(.badRequest, reason: "Expected year_YYYY.om or chunk_INDEX.om")
        }
        var states = [FileState]()
        var handles = [(FileHandle, String)]()
        defer {
            for (handle, temporary) in handles {
                try? handle.close()
                try? FileManager.default.removeItem(atPath: temporary)
            }
        }
        for file in files {
            let reader = try await OmFileReader(mmapFile: file).expectArray(of: Float.self)
            let dimensions = Array(reader.getDimensions())
            guard dimensions == [UInt64(grid.count), UInt64(expectedCount)] || dimensions == [UInt64(grid.ny), UInt64(grid.nx), UInt64(expectedCount)] else {
                throw Abort(.badRequest, reason: "Unexpected SARAH-3 file dimensions: \(dimensions)")
            }
            let chunks = Array(reader.getChunkDimensions())
            logger.info("Processing \(file), chunks=\(chunks)")
            let output = Self.correctedFilePath(file)
            if execute {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: output).deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            let temporary = output + ".sunset-repair~"
            let handle = execute ? try FileHandle.createNewFile(file: temporary) : nil
            if let handle { handles.append((handle, temporary)) }
            let fileWriter = handle.map { OmFileWriter(fn: $0, initialCapacity: 1024 * 1024 * 10) }
            let writer = try fileWriter?.prepareArray(type: Float.self,
                dimensions: dimensions, chunkDimensions: chunks, compression: reader.compression,
                scale_factor: reader.scaleFactor, add_offset: reader.addOffset)
            states.append(FileState(file: file, reader: reader, dimensions: dimensions, chunks: chunks,
                handle: handle, fileWriter: fileWriter, writer: writer, output: output, temporary: temporary))
        }
        // Both variables use the same spatial chunks. Compute solar radiation once per
        // native spatial chunk for the entire time interval and reuse it for both fields.
        let spatialDimensions = Array(states[0].dimensions.dropLast()).map(Int.init)
        let spatialChunks = Array(states[0].chunks.dropLast()).map(Int.init)
        let blocks = Self.spatialBlocks(dimensions: spatialDimensions, chunks: spatialChunks)
        let solarTime = TimerangeDt(start: start, nTime: expectedCount + 1, dtSeconds: domain.dtSeconds)
        for (blockIndex, spatialRange) in blocks.enumerated() {
            try Task.checkCancellation()
            let locations = spatialRange.count == 1 ? Array(spatialRange[0]) : spatialRange[0].flatMap { y in spatialRange[1].map { y * grid.nx + $0 } }
            let solar = Zensun.calculateRadiationBackwardsAveraged(grid: grid,
                locationRange: locations, timerange: solarTime)
            for stateIndex in states.indices {
                let state = states[stateIndex]
                let chunks = state.chunks
                let reader = state.reader
                let writer = state.writer
                for t in stride(from: 0, to: expectedCount, by: Int(chunks.last!)) {
                    let end = min(t + Int(chunks.last!), expectedCount)
                    // Read neighbouring samples from the same file across internal time chunks.
                    let lower = max(t - 1, 0)
                    let upper = min(end + 1, expectedCount)
                    let readCount = upper - lower
                    let ranges = spatialRange.map { $0.toUInt64() } + [UInt64(lower)..<UInt64(upper)]
                    let source: [Float]
                    if ranges.count == 2 {
                        source = try await reader.read(range: [ranges[0], ranges[1]])
                    } else {
                        source = try await reader.read(range: [ranges[0], ranges[1], ranges[2]])
                    }
                    var output = [Float]()
                    output.reserveCapacity(locations.count * (end - t))
                    for i in locations.indices {
                        for step in t..<end {
                            let index = i * readCount + step - lower
                            var value = source[index]
                            // At the file start there is no previous KT; use zero if the next interval is dark.
                            if step == 0, value.isNaN, solar[i, step + 1] == 0 {
                                value = 0
                                states[stateIndex].repaired += 1
                            } else if step > 0, value.isNaN, let replacement = Self.reconstruct(previous: source[index - 1],
                                solarPrevious: solar[i, step - 1], solarCurrent: solar[i, step], solarNext: solar[i, step + 1]) {
                                value = replacement
                                states[stateIndex].repaired += 1
                            }
                            let next = step + 1 < expectedCount ? source[index + 1] : .nan
                            let limited = Self.limitRadiation(value, solarFactor: solar[i, step],
                                next: next, solarNext: solar[i, step + 1])
                            if limited < value { states[stateIndex].limited += 1 }
                            output.append(limited)
                        }
                    }
                    try writer?.writeData(array: output,
                        arrayDimensions: spatialRange.map { UInt64($0.count) } + [UInt64(end - t)],
                        arrayOffset: nil, arrayCount: nil)
                }
            }
            if blockIndex % 1000 == 0 { logger.info("SARAH sunset repair: block \(blockIndex)/\(blocks.count)") }
        }
        for state in states {
            if let writer = state.writer, let fileWriter = state.fileWriter, let handle = state.handle {
                let root = try fileWriter.write(array: try writer.finalise(), name: "", children: [])
                try fileWriter.writeTrailer(rootVariable: root)
                try handle.close()
                try FileManager.default.moveFileOverwrite(from: state.temporary, to: state.output)
            }
            logger.info("\(execute ? "Wrote" : "Would write") \(state.output), repairing \(state.repaired) sunset NaNs and limiting \(state.limited) radiation peaks from \(state.file)")
        }
    }

    /// Replace radiation above 90% of extraterrestrial radiation using the next observed KT.
    /// Missing, dark or excessive next samples fall back to KT = 0.8.
    static func limitRadiation(_ value: Float, solarFactor: Float, next: Float = .nan, solarNext: Float = .nan) -> Float {
        guard solarFactor.isFinite, solarFactor >= 0 else { return value }
        let extraterrestrial = solarFactor * Zensun.solarConstant
        guard value > 0.9 * extraterrestrial else { return value }
        if next.isFinite, next >= 0, solarNext.isFinite, solarNext > 0 {
            let kt = next / (solarNext * Zensun.solarConstant)
            if kt.isFinite, kt <= 0.9 {
                return kt * extraterrestrial
            }
        }
        return 0.8 * extraterrestrial
    }

    static func correctedFilePath(_ file: String) -> String {
        let source = URL(fileURLWithPath: file)
        return source.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(source.deletingLastPathComponent().lastPathComponent + "_corrected")
            .appendingPathComponent(source.lastPathComponent).path
    }

    /// Iterate in the same order as the file's chunk index, preserving its spatial layout.
    static func spatialBlocks(dimensions: [Int], chunks: [Int]) -> [[Range<Int>]] {
        if dimensions.count == 1 {
            return stride(from: 0, to: dimensions[0], by: chunks[0]).map {
                [$0..<min($0 + chunks[0], dimensions[0])]
            }
        }
        return stride(from: 0, to: dimensions[0], by: chunks[0]).flatMap { y in
            stride(from: 0, to: dimensions[1], by: chunks[1]).map { x in
                [y..<min(y + chunks[0], dimensions[0]), x..<min(x + chunks[1], dimensions[1])]
            }
        }
    }

    /// Fill the final sunlit interval or a fully dark interval followed by darkness.
    /// KT uses the immediately preceding observed interval, never a repair.
    static func reconstruct(previous: Float, solarPrevious: Float, solarCurrent: Float, solarNext: Float) -> Float? {
        guard previous.isFinite, previous >= 0,
              solarPrevious.isFinite, solarCurrent.isFinite, solarNext.isFinite,
              solarNext <= 0 else { return nil }
        // A missing interval just after sunset needs no KT: its solar integral is zero.
        if solarCurrent == 0 { return 0 }
        guard solarPrevious > 0, solarCurrent > 0, solarCurrent < solarPrevious else { return nil }
        let kt = previous / (solarPrevious * Zensun.solarConstant)
        let result = kt * solarCurrent * Zensun.solarConstant
        return result.isFinite ? result : nil
    }
}
