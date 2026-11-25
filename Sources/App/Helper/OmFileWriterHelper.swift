import Foundation
import OmFileFormat
import SwiftNetCDF
import Vapor
import OmFileIO

/// Small helper class to generate compressed files
public final class OmFileWriterHelper: Sendable {
    public let dimensions: [Int]
    public let chunks: [Int]

    public init(dimensions: [Int], chunks: [Int]) {
        self.dimensions = dimensions
        self.chunks = chunks
    }

    /// Write all data at once without any streaming
    /// If `overwrite` is set, overwrite existing files atomically
    @discardableResult
    public func write(file: String, compressionType: OmCompressionType, scalefactor: Float, all: [Float], overwrite: Bool = false) throws -> FileHandle {
        if !overwrite && FileManager.default.fileExists(atPath: file) {
            throw OmFileFormatSwiftError.fileExistsAlready(filename: file)
        }
        let fn = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
        try all.writeOmFile(fn: fn, dimensions: dimensions, chunks: chunks, compression: compressionType, scalefactor: scalefactor)
        try fn.linkTemporary(file: file)
        return fn
    }
    
    /*func write(domain: GenericDomain, run: Timestamp, time: Timestamp, member: Int, variable: GenericVariable, data: [Float], storeOnDisk: Bool, compressionType: CompressionType = .pfor_delta2d_int16, overwrite: Bool = false) throws -> GenericVariableHandle {
        let fn: FileHandle
        if storeOnDisk {
            let path = "\(domain.domainRegistry.directorySpatial)\(run.format_directoriesYYYYMMddhhmm)/\(time.iso8601_YYYYMMddTHHmm)/"
            let file = "\(path)\(variable.omFileName.file).om"
            if !overwrite && FileManager.default.fileExists(atPath: file) {
                throw OmFileFormatSwiftError.fileExistsAlready(filename: file)
            }
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            let fileTemp = "\(file)~"
            try FileManager.default.removeItemIfExists(at: fileTemp)
            fn = try FileHandle.createNewFile(file: fileTemp)
            try data.writeOmFile(fn: fn, dimensions: dimensions, chunks: chunks, compression: compressionType, scalefactor: variable.scalefactor)
            try FileManager.default.moveFileOverwrite(from: fileTemp, to: file)
        } else {
            let file = "\(OpenMeteo.tempDirectory)/\(Int.random(in: 0..<Int.max)).om"
            try FileManager.default.removeItemIfExists(at: file)
            fn = try FileHandle.createNewFile(file: file)
            try FileManager.default.removeItem(atPath: file)
            try data.writeOmFile(fn: fn, dimensions: dimensions, chunks: chunks, compression: compressionType, scalefactor: variable.scalefactor)
        }
        return GenericVariableHandle(variable: variable, time: time, member: member, fn: fn)
    }*/

    /// Transpose and interpolate bounded row blocks in parallel, then append them
    /// in chunk order. Only the original timesteps and a few row blocks stay in memory.
    /// Transpose/interpolation timings sum worker time; write measures compression and IO.
    func writeTemporaryTimeSeries(compressionType: OmCompressionType, scalefactor: Float, timesteps: [(time: Int, data: [Float])], time: TimerangeDt, grid: any Gridable, interpolation: ReaderInterpolation, nConcurrent: Int) async throws -> (handle: FileHandle, transpose: Double, interpolation: Double, write: Double) {
        precondition(nConcurrent > 0 && time.count > 0)
        precondition(dimensions == [grid.ny, grid.nx, time.count] && chunks.count == 3 && chunks.allSatisfy { $0 > 0 })
        precondition(chunks[2] == time.count)
        precondition(timesteps.allSatisfy { $0.time >= 0 && $0.time < time.count && $0.data.count == grid.count })
        precondition(Set(timesteps.map(\.time)).count == timesteps.count)
        let writeStart = DispatchTime.now()
        let path = "\(OpenMeteo.tempDirectory)/\(UUID().uuidString).om"
        let fn = try FileHandle.createNewFile(file: path, overwrite: true, temporary: true)
        let file = OmFileWriter(fn: fn, initialCapacity: 4 * 1024)
        let array = try file.prepareArray(type: Float.self, dimensions: dimensions.map(UInt64.init), chunkDimensions: chunks.map(UInt64.init), compression: compressionType, scale_factor: scalefactor, add_offset: 0)
        var writeTime = writeStart.timeElapsedSeconds()
        var transposeTime = 0.0
        var interpolationTime = 0.0
        // Aim for 8 MiB per worker, rounded down to complete spatial chunk rows.
        let rows = max(1, 8 * 1024 * 1024 / (grid.nx * time.count * MemoryLayout<Float>.size * chunks[0])) * chunks[0]
        let blocks = stride(from: 0, to: grid.ny, by: rows).map { $0..<min($0 + rows, grid.ny) }
        let prepared = blocks.mapStream(nConcurrent: nConcurrent) { y in
            try Task.checkCancellation()
            let transposeStart = DispatchTime.now()
            let locations = y.lowerBound * grid.nx..<y.upperBound * grid.nx
            var data = Array2DFastTime(nLocations: locations.count, nTime: time.count)
            for start in stride(from: 0, to: locations.count, by: 64) {
                let end = min(start + 64, locations.count)
                for timestep in timesteps {
                    for location in start..<end {
                        data.data[location * time.count + timestep.time] = timestep.data[locations.lowerBound + location]
                    }
                }
            }
            let transpose = transposeStart.timeElapsedSeconds()
            let interpolationStart = DispatchTime.now()
            data.interpolateInplace(type: interpolation, time: time, grid: grid, locationRange: locations)
            return (rows: y.count, data: data.data, transpose: transpose, interpolation: interpolationStart.timeElapsedSeconds())
        }
        for try await block in prepared {
            transposeTime += block.transpose
            interpolationTime += block.interpolation
            let writeStart = DispatchTime.now()
            try await array.writeDataConcurrent(array: block.data, arrayDimensions: [UInt64(block.rows), UInt64(grid.nx), UInt64(time.count)], nConcurrent: nConcurrent)
            writeTime += writeStart.timeElapsedSeconds()
        }
        let finaliseStart = DispatchTime.now()
        let finalised = try array.finalise()
        let createdAt = try file.write(value: Timestamp.now().timeIntervalSince1970, name: "created_at", children: [])
        let root = try file.write(array: finalised, name: "", children: [createdAt])
        try file.writeTrailer(rootVariable: root)
        writeTime += finaliseStart.timeElapsedSeconds()
        return (fn, transposeTime, interpolationTime, writeTime)
    }

    public func writeTemporary(compressionType: OmCompressionType, scalefactor: Float, all: [Float]) throws -> FileHandle {
        let file = "\(OpenMeteo.tempDirectory)/\(Int.random(in: 0..<Int.max)).om"
        try FileManager.default.removeItemIfExists(at: file)
        let fn = try FileHandle.createNewFile(file: file)
        try FileManager.default.removeItem(atPath: file)
        try all.writeOmFile(fn: fn, dimensions: dimensions, chunks: chunks, compression: compressionType, scalefactor: scalefactor)
        return fn
    }
}

extension Array where Element == Float {
    /// Write a given array as a 2D om file
    @discardableResult
    func writeOmFile(file: String, dimensions: [Int], chunks: [Int], compression: OmCompressionType = .pfor_delta2d_int16, scalefactor: Float = 1, createNetCdf: Bool = false) throws -> FileHandle {
        guard !FileManager.default.fileExists(atPath: file) else {
            fatalError("File exists already \(file)")
        }
        let writeFn = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
        try writeOmFile(fn: writeFn, dimensions: dimensions, chunks: chunks, compression: compression, scalefactor: scalefactor)
        try writeFn.linkTemporary(file: file)

        if createNetCdf {
            let ncPath = file.replacingOccurrences(of: ".om", with: ".nc")
            let ncFile = try NetCDF.create(path: ncPath, overwriteExisting: true)
            let ncDimensions = try dimensions.enumerated().map {
                try ncFile.createDimension(name: "DIM\($0.offset)", length: $0.element)
            }
            var variable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: ncDimensions)
            try variable.write(self)
        }
        return writeFn
    }

    /// Write the current array as an om file to an open file handle
    func writeOmFile(fn: FileHandle, dimensions: [Int], chunks: [Int], compression: OmCompressionType, scalefactor: Float, run: Timestamp? = nil, time: Timestamp? = nil) throws {
        guard dimensions.reduce(1, *) == self.count else {
            fatalError(#function + ": Array size \(self.count) does not match dimensions \(dimensions)")
        }
        let writeFile = OmFileWriter(fn: fn, initialCapacity: 4 * 1024)
        let writer = try writeFile.prepareArray(
            type: Float.self,
            dimensions: dimensions.map(UInt64.init),
            chunkDimensions: chunks.map(UInt64.init),
            compression: compression,
            scale_factor: scalefactor,
            add_offset: 0
        )
        try writer.writeData(array: self)
        let writerFinalised = try writer.finalise()
        let runTime: OmOffsetSize? = try run.map { try writeFile.write(value: $0.timeIntervalSince1970, name: "forecast_reference_time", children: []) }
        let validTime: OmOffsetSize? = try time.map { try writeFile.write(value: $0.timeIntervalSince1970, name: "time", children: []) }
        let coordinates = dimensions.count == 2 ? try writeFile.write(value: "lat lon", name: "coordinates", children: []) : nil
        let createdAt = try writeFile.write(value: Timestamp.now().timeIntervalSince1970, name: "created_at", children: [])
        let root = try writeFile.write(array: writerFinalised, name: "", children: [runTime, validTime, coordinates, createdAt].compactMap({$0}))
        try writeFile.writeTrailer(rootVariable: root)
    }

    /// Writes a new static file and queues its upload, if configured. Callers skip existing files.
    /// Retains caller isolation through the write so elevation-generating actors cannot interleave writes.
    nonisolated(nonsending) func writeStaticOmFile(file: OmFileType, grid: any Gridable, application: Application, uploadQueues: [S3UploadQueue], createNetCdf: Bool = false) async throws {
        try writeOmFile2D(file: file.getFilePath(), grid: grid, createNetCdf: createNetCdf)
        guard !uploadQueues.isEmpty else { return }
        let handle = try FileHandle.openFileReading(file: file.getFilePath())
        for queue in uploadQueues {
            let uploads = queue.startMultiPartUploads()
            await uploads.uploadMultipart(data: handle, objectName: file.getRelativeFilePathWithData(), lastModified: .now())
            await queue.finishMultiPartUploads(uploads)
        }
    }

    /// Write a spatial om file using grid dimensions and 20x20 chunks. Mostly used to write elevation files
    func writeOmFile2D(file: String, grid: any Gridable, chunk0: Int = 20, chunk1: Int = 20, compression: OmCompressionType = .pfor_delta2d_int16, scalefactor: Float = 1, createNetCdf: Bool = false) throws {
        let chunk0 = Swift.min(grid.ny, 20)
        try writeOmFile(file: file, dimensions: [grid.ny, grid.nx], chunks: [chunk0, 400 / chunk0], compression: compression, scalefactor: scalefactor, createNetCdf: createNetCdf)
    }
}
