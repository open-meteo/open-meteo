import Foundation
import OmFileFormat
import SwiftNetCDF


/// Small helper class to generate compressed files
public final class OmFileWriterHelper {
    public let dimensions: [Int]
    public let chunks: [Int]
    
    public init(dimensions: [Int], chunks: [Int]) {
        self.dimensions = dimensions
        self.chunks = chunks
    }
    
    /// Write all data at once without any streaming
    /// If `overwrite` is set, overwrite existing files atomically
    @discardableResult
    public func write(file: String, compressionType: CompressionType, scalefactor: Float, all: [Float], overwrite: Bool = false) throws -> FileHandle {
        if !overwrite && FileManager.default.fileExists(atPath: file) {
            throw OmFileFormatSwiftError.fileExistsAlready(filename: file)
        }
        let fileTemp = "\(file)~"
        try FileManager.default.removeItemIfExists(at: fileTemp)
        let fn = try FileHandle.createNewFile(file: fileTemp)
        try all.writeOmFile(fn: fn, dimensions: dimensions, chunks: chunks, compression: compressionType, scalefactor: scalefactor)
        try FileManager.default.moveFileOverwrite(from: fileTemp, to: file)
        return fn
    }
    
    public func writeTemporary(compressionType: CompressionType, scalefactor: Float, all: [Float]) throws -> FileHandle {
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
    func writeOmFile(file: String, dimensions: [Int], chunks: [Int], compression: CompressionType = .pfor_delta2d_int16, scalefactor: Float = 1, createNetCdf: Bool = false) throws -> FileHandle {
        guard !FileManager.default.fileExists(atPath: file) else {
            fatalError("File exists already \(file)")
        }
        let tempFile = file + "~"
        // Another process might be updating this file right now. E.g. Second flush of GFS ensemble
        FileManager.default.waitIfFileWasRecentlyModified(at: tempFile)
        try FileManager.default.removeItemIfExists(at: tempFile)
        let writeFn = try FileHandle.createNewFile(file: tempFile)
        try writeOmFile(fn: writeFn, dimensions: dimensions, chunks: chunks, compression: compression, scalefactor: scalefactor)
        
        // Overwrite existing file, with newly created
        try FileManager.default.moveFileOverwrite(from: tempFile, to: file)
        
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
    func writeOmFile(fn: FileHandle, dimensions: [Int], chunks: [Int], compression: CompressionType, scalefactor: Float) throws {
        guard dimensions.reduce(1, *) == self.count else {
            fatalError(#function + ": Array size \(self.count) does not match dimensions \(dimensions)")
        }
        let writeFile = OmFileWriter(fn: fn, initialCapacity: 4*1024)
        let writer = try writeFile.prepareArray(
            type: Float.self,
            dimensions: dimensions.map(UInt64.init),
            chunkDimensions: chunks.map(UInt64.init),
            compression: compression,
            scale_factor: scalefactor,
            add_offset: 0
        )
        try writer.writeData(array: self)
        let root = try writeFile.write(array: writer.finalise(), name: "", children: [])
        try writeFile.writeTrailer(rootVariable: root)
    }
    
    /// Write a spatial om file using grid dimensions and 20x20 chunks. Mostly used to write elevation files
    func writeOmFile2D(file: String, grid: Gridable, chunk0: Int = 20, chunk1: Int = 20, compression: CompressionType = .pfor_delta2d_int16, scalefactor: Float = 1, createNetCdf: Bool = false) throws {
        let chunk0 = Swift.min(grid.ny, 20)
        try writeOmFile(file: file, dimensions: [grid.ny, grid.nx], chunks: [chunk0, 400/chunk0], compression: compression, scalefactor: scalefactor, createNetCdf: createNetCdf)
    }
}
