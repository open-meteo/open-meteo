
import Foundation
@_implementationOnly import CTurboPFor

/// Simple floating point array compresion to disk using `TurboFloat XOR`. Compress speed is around 1 GB/s with decompress speed of 8 GB/s.
public struct FloatArrayCompressor {
    /// Write Float array to disk with simple `fpgenc32` compression. No meta data at all.
    public static func write(file: String, data: [Float]) throws {
        if FileManager.default.fileExists(atPath: file) {
            throw SwiftPFor2DError.fileExistsAlready(filename: file)
        }
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: (data.count * MemoryLayout<Float>.stride).P4NENC256_BOUND())
        defer { buffer.deallocate() }
        let compressedSize = data.withUnsafeBytes { ptr -> Int in
            let mut = UnsafeMutablePointer(mutating: ptr.bindMemory(to: UInt32.self).baseAddress)
            return fpxenc32(mut, data.count, buffer, 0)
        }
        let fn = try FileHandle.createNewFile(file: file)
        // add some padding at the end, otherwise fpxdec32 crashes
        try fn.write(contentsOf: UnsafeRawBufferPointer(start: buffer, count: compressedSize.P4NENC256_BOUND()))
        try fn.synchronize()
    }
    
    /// Read data from disk and uncompress
    public static func read(file: String, nElements: Int) throws -> [Float] {
        let fn = try FileHandle.openFileReading(file: file)
        let mmap = try MmapFile(fn: fn)
        
        return [Float](unsafeUninitializedCapacity: nElements, initializingWith: { (ptr, count) in
            let ptr32 = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self, capacity: nElements).baseAddress
            let _ = fpxdec32(UnsafeMutablePointer(mutating: mmap.data.baseAddress), nElements, ptr32, 0)
            count += nElements
        })
    }
}
