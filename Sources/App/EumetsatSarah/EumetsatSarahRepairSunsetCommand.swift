import Foundation
import Vapor
import OmFileIO
import OmFileFormat

/// Repair already timestamp-corrected SARAH-3 archives. Run with ingestion stopped.
/// Run repair-eumetsat-sarah-sunset --execute to write all yearly and chunk files
/// to shortwave_radiation_corrected for API review, leaving the originals untouched.
/// Omit --execute to count repairs without writing. Use --file year_2020.om to test one file.
struct EumetsatSarahRepairSunsetCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "file", help: "Only process this filename in the SARAH shortwave_radiation directory, e.g. year_2020.om or chunk_12345.om")
        var file: String?

        @Flag(name: "execute", help: "Write shortwave_radiation_corrected files; otherwise only count repairs")
        var execute: Bool
    }

    var help: String { "Fill sunset NaNs in all timestamp-corrected SARAH-3 shortwave radiation files" }

    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = EumetsatSarahDomain.sarah3_30min
        let directory = domain.domainRegistry.directory + "shortwave_radiation/"
        var files = try FileManager.default.contentsOfDirectory(atPath: directory).filter {
            $0.hasSuffix(".om") && ($0.hasPrefix("year_") || $0.hasPrefix("chunk_"))
        }.sorted(by: >)
        if let file = signature.file {
            guard files.contains(file) else {
                throw Abort(.badRequest, reason: "SARAH shortwave file not found: \(file). Pass a filename from \(directory)")
            }
            files = [file]
        }
        for file in files {
            try await repairFile(file: directory + file, domain: domain,
                execute: signature.execute, logger: context.application.logger)
        }
        context.application.logger.info("Processed \(files.count) SARAH shortwave radiation files")
    }

    func repairFile(file: String, domain: EumetsatSarahDomain, execute: Bool, logger: Logger) async throws {
        let grid = domain.grid
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
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
        defer {
            try? handle?.close()
            if execute { try? FileManager.default.removeItem(atPath: temporary) }
        }
        let fileWriter = handle.map { OmFileWriter(fn: $0, initialCapacity: 1024 * 1024 * 10) }
        let writer = try fileWriter?.prepareArray(type: Float.self,
            dimensions: dimensions,
            chunkDimensions: chunks, compression: reader.compression,
            scale_factor: reader.scaleFactor, add_offset: reader.addOffset)
        var repaired = 0
        // Flattened legacy files have one spatial dimension; current files have Y and X.
        let spatialDimensions = Array(dimensions.dropLast()).map(Int.init)
        let spatialChunks = Array(chunks.dropLast()).map(Int.init)
        let blocks = Self.spatialBlocks(dimensions: spatialDimensions, chunks: spatialChunks)
        let solarTime = TimerangeDt(start: start, nTime: expectedCount + 1, dtSeconds: domain.dtSeconds)
        for (blockIndex, spatialRange) in blocks.enumerated() {
            let locations: [Int]
            if spatialRange.count == 1 {
                locations = Array(spatialRange[0])
            } else {
                locations = spatialRange[0].flatMap { y in spatialRange[1].map { y * grid.nx + $0 } }
            }
            // Precompute the complete time interval (plus the following solar interval) for every grid
            // point in this spatial block. A whole 2600x2600 yearly field would use ~474 GB,
            // so retain only one spatial block at a time. No solar calculations in the gap loop.
            let solar = Zensun.calculateRadiationBackwardsAveraged(grid: grid,
                locationRange: locations, timerange: solarTime)
            for t in stride(from: 0, to: expectedCount, by: Int(chunks.last!)) {
                let end = min(t + Int(chunks.last!), expectedCount)
                // Include i-1 from this same file when a hole starts a time chunk.
                let lower = max(t - 1, 0)
                let readCount = end - lower
                let ranges = spatialRange.map { $0.toUInt64() } + [UInt64(lower)..<UInt64(end)]
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
                        let value = source[index]
                        // At the file start there is no previous KT; use zero if the next interval is dark.
                        if step == 0, value.isNaN, solar[i, step + 1] == 0 {
                            output.append(0)
                            repaired += 1
                        } else if step > 0, value.isNaN, let replacement = Self.reconstruct(previous: source[index - 1],
                            solarPrevious: solar[i, step - 1], solarCurrent: solar[i, step], solarNext: solar[i, step + 1]) {
                            output.append(replacement)
                            repaired += 1
                        } else {
                            output.append(value)
                        }
                    }
                }
                try writer?.writeData(array: output,
                    arrayDimensions: spatialRange.map { UInt64($0.count) } + [UInt64(end - t)],
                    arrayOffset: nil, arrayCount: nil)
            }
            if blockIndex % 1000 == 0 { logger.info("SARAH sunset repair: block \(blockIndex)/\(blocks.count), \(repaired) values") }
        }
        if let writer, let fileWriter, let handle {
            let root = try fileWriter.write(array: try writer.finalise(), name: "", children: [])
            try fileWriter.writeTrailer(rootVariable: root)
            try handle.close()
            try FileManager.default.moveFileOverwrite(from: temporary, to: output)
        }
        logger.info("\(execute ? "Wrote" : "Would write") \(output), repairing \(repaired) sunset NaNs from \(file)")
    }

    static func correctedFilePath(_ file: String) -> String {
        let source = URL(fileURLWithPath: file)
        return source.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shortwave_radiation_corrected")
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

    /// Use the last sunlit backwards interval, followed by a fully dark interval, to
    /// identify sunset. KT uses the immediately preceding observed interval, never a repair.
    static func reconstruct(previous: Float, solarPrevious: Float, solarCurrent: Float, solarNext: Float) -> Float? {
        guard previous.isFinite, previous >= 0,
              solarPrevious.isFinite, solarCurrent.isFinite, solarNext.isFinite,
              solarPrevious * Zensun.solarConstant > 5,
              solarCurrent > 0, solarCurrent < solarPrevious, solarNext <= 0 else { return nil }
        let kt = previous / (solarPrevious * Zensun.solarConstant)
        let result = kt * solarCurrent * Zensun.solarConstant
        return result.isFinite ? result : nil
    }
}
