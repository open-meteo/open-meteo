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

        @Option(name: "file", help: "Only write this basename, e.g. year_2024.om; neighbours are still read")
        var file: String?
    }

    var help: String { "Repair SARAH scan-time averaging into separate _corrected directories; resume by rerunning" }

    struct ArchiveFile {
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
            grid: grid, mviri: mviri, seviri: seviri, logger: logger)
    }

    static func repairArchive(directory: String, variables: [String], selectedFile: String?, grid: any Gridable,
                              mviri: [Double], seviri: [Double], logger: Logger) async throws {
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
                for y in stride(from: 0, to: grid.ny, by: cy) {
                    for x in stride(from: 0, to: grid.nx, by: cx) {
                        let ys = y..<min(y + cy, grid.ny)
                        let xs = x..<min(x + cx, grid.nx)
                        var data = [Float](repeating: .nan, count: ys.count * xs.count * inputTime.count)
                        for (file, reader) in readers {
                            let lo = max(inputTime.lowerBound, file.time.lowerBound)
                            let hi = min(inputTime.upperBound, file.time.upperBound)
                            let tr = UInt64(lo - file.time.lowerBound)..<UInt64(hi - file.time.lowerBound)
                            try await reader.read(into: &data, range: [ys.toUInt64(), xs.toUInt64(), tr],
                                intoCubeOffset: [0, 0, UInt64(lo - start)],
                                intoCubeDimension: [UInt64(ys.count), UInt64(xs.count), UInt64(inputTime.count)])
                        }
                        var result = [Float](repeating: .nan, count: ys.count * xs.count * target.time.count)
                        for (row, yy) in ys.enumerated() {
                            let locations = yy * grid.nx + xs.lowerBound ..< yy * grid.nx + xs.upperBound
                            for day in stride(from: start, to: inputTime.upperBound, by: 48) {
                                let count = min(48, inputTime.upperBound - day)
                                let time = TimerangeDt(start: Timestamp(day * 1800), nTime: count, dtSeconds: 1800)
                                let scan = day * 1800 < Timestamp(2006, 1, 1).timeIntervalSince1970 ? mviri : seviri
                                let offsets = Array(scan[locations])
                                var daily = [Float](repeating: .nan, count: xs.count * count)
                                for col in 0..<xs.count {
                                    let base = (row * xs.count + col) * inputTime.count + day - start
                                    daily.replaceSubrange(col * count ..< (col + 1) * count, with: data[base..<base + count])
                                }
                                Self.correct(data: &daily, grid: grid, locations: locations, time: time, offsets: offsets)
                                for col in 0..<xs.count {
                                    for t in 0..<count {
                                        let out = day + t + 1 - target.time.lowerBound
                                        if out >= 0 && out < target.time.count {
                                            result[(row * xs.count + col) * target.time.count + out] = daily[col * count + t]
                                        }
                                    }
                                }
                            }
                        }
                        try writer.writeData(array: result, arrayDimensions: [UInt64(ys.count), UInt64(xs.count), UInt64(target.time.count)])
                        await progress.add(result.count * 4)
                    }
                }
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

    static func correct(data: inout [Float], grid: any Gridable, locations: Range<Int>, time: TimerangeDt, offsets: [Double]) {
        let missing = data.map { $0.isNaN }
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &data, grid: grid, locationRange: locations,
            timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets, undoAveraging: true)
        let unrecoverable = data.map { $0.isNaN }
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &data, grid: grid, locationRange: locations,
            timerange: TimerangeDt(start: time.range.lowerBound.add(1800), nTime: time.count, dtSeconds: 1800),
            sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets.map { $0 - 0.5 })
        // Do not turn archive gaps (including absent neighbours) into synthetic observations.
        for i in data.indices where missing[i] || unrecoverable[i] || !offsets[i / time.count].isFinite { data[i] = .nan }
    }
}
