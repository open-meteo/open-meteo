import Foundation
import SwiftPFor2D
import NIOConcurrencyHelpers
import Vapor
import NIO

/// Represents an om file that can be cached for file accesses.
protocol OmFileManagerReadable: Hashable {
    /// Will only be called if the file path needs to be assembled
    func getFilePath() -> String
}

/// Simple base path, variable name and timechunk
struct OmFilePathWithTime: OmFileManagerReadable {
    let basePath: String
    let variable: String
    let timeChunk: Int
    
    func getFilePath() -> String {
        return basePath + variable + "_\(timeChunk).om"
    }
}

/// Assemble a file path if required. Includes data directory as a prefix.
/// All input paths can be passed by reference and do not require to allocate new strings unless required
struct OmFilePathWithSuffix: OmFileManagerReadable {
    let domain: String
    let directory: String
    let variable: String
    let suffix: String
    
    func getFilePath() -> String {
        return "\(OpenMeteo.dataDictionary)\(directory)-\(domain)/\(variable)_\(suffix).om"
    }
    func createDirectory() throws {
        try FileManager.default.createDirectory(atPath: "\(OpenMeteo.dataDictionary)\(directory)-\(domain)", withIntermediateDirectories: true)
    }
}

/// cache file handles, background close checks
/// If a file path is missing, this information is cached and checked in the background
final class OmFileManager: LifecycleHandler {
    /// A file might exist and is open, or it is missing
    enum OmFileState {
        case exists(file: OmFileReader<MmapFile>)
        case missing(path: String)
    }
    
    /// Non existing files are set to nil
    private var cached = [Int: OmFileState]()
    
    private let lock = NIOLock()
    
    private var backgroundWatcher: RepeatedTask?
    
    public static var instance = OmFileManager()
    
    private init() {}
    
    func didBoot(_ application: Application) throws {
        let logger = application.logger
        logger.debug("Starting OmFileManager")
        backgroundWatcher = application.eventLoopGroup.next().scheduleRepeatedTask(initialDelay: .seconds(2), delay: .seconds(2), {
            task in
            
            // Could be later used to expose some metrics
            var countExisting = 0
            var countMissing = 0
            var countEjected = 0
            
            let copy = self.lock.withLock {
                return self.cached
            }
            
            for e in copy {
                switch e.value {
                case .exists(file: let file):
                    // Remove file from cache, if it was deleted
                    if file.wasDeleted() {
                        self.lock.withLock {
                            let _ = self.cached.removeValue(forKey: e.key)
                            countEjected += 1
                        }
                    }
                    countExisting += 1
                case .missing(path: let path):
                    // Remove file from cache, if it is now available, so the next open, will make it available
                    if FileManager.default.fileExists(atPath: path) {
                        self.lock.withLock {
                            let _ = self.cached.removeValue(forKey: e.key)
                            countEjected += 1
                        }
                    }
                    countMissing += 1
                }
            }
            
            //logger.info("OmFileManager tracking \(countExisting) open files, \(countMissing) missing files. \(countEjected) were ejected in this update.")
        })
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher?.cancel()
    }
    
    /// Get cached file or return nil, if the files does not exist
    public static func get<File: OmFileManagerReadable>(_ file: File) throws -> OmFileReader<MmapFile>? {
        try instance.get(file)
    }

    /// Get cached file or return nil, if the files does not exist
    public func get<File: OmFileManagerReadable>(_ file: File) throws -> OmFileReader<MmapFile>? {
        let key = file.hashValue
        
        return try lock.withLock {
            if let file = cached[key] {
                switch file {
                case .exists(file: let file):
                    return file
                case .missing(path: _):
                    return nil
                }
            }
            // The actual path name string is interpolated as last as possible. So a cached request, does not have to assemble a path string
            // This might be a bit over-optimised to just safe string allocations...
            let path = file.getFilePath()
            guard FileManager.default.fileExists(atPath: path) else {
                cached[key] = .missing(path: path)
                return nil
            }
            let file = try OmFileReader(file: path)
            cached[key] = .exists(file: file)
            return file
        }
    }
}

/// Keep one buffer per thread
fileprivate var buffers = [Thread: UnsafeMutableRawBufferPointer]()

/// Thread safe access to buffers
fileprivate let lockBuffers = NIOLock()

extension OmFileReader {
    /// Thread safe buffer provider that automatically reallocates buffers
    fileprivate static func getBuffer(minBytes: Int) -> UnsafeMutableRawBufferPointer {
        return lockBuffers.withLock {
            if let buffer = buffers[Thread.current] {
                if buffer.count < minBytes {
                    let buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, minBytes), count: minBytes)
                    buffers[Thread.current] = buffer
                    return buffer
                }
                return buffer
            }
            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: minBytes, alignment: 4)
            buffers[Thread.current] = buffer
            return buffer
        }
    }
    /// Read data into existing output float buffer
    public func read(into: UnsafeMutablePointer<Float>, arrayDim1Range: Range<Int>, arrayDim1Length: Int, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        assert(arrayDim1Range.count == dim1Read.count)
        let chunkBuffer = OmFileReader.getBuffer(minBytes: P4NDEC256_BOUND(n: chunk0*chunk1, bytesPerElement: compression.bytesPerElement)).baseAddress!
        try read(into: into, arrayDim1Range: arrayDim1Range, arrayDim1Length: arrayDim1Length, chunkBuffer: chunkBuffer, dim0Slow: dim0Read, dim1: dim1Read)
    }
    
    /// Read data into existing output float buffer
    public func read(into: inout [Float], arrayRange: Range<Int>, arrayDim1Length: Int, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        try into.withUnsafeMutableBufferPointer {
            let chunkBuffer = OmFileReader.getBuffer(minBytes: P4NDEC256_BOUND(n: chunk0*chunk1, bytesPerElement: compression.bytesPerElement)).baseAddress!
            try read(into: $0.baseAddress!, arrayDim1Range: arrayRange, arrayDim1Length: arrayDim1Length, chunkBuffer: chunkBuffer, dim0Slow: dim0Read, dim1: dim1Read)
        }
    }
    
    /// Read data. This version is a bit slower, because it is allocating the output buffer
    public func read(dim0Slow dim0Read: Range<Int>?, dim1 dim1Read: Range<Int>?) throws -> [Float] {
        let dim0Read = dim0Read ?? 0..<dim0
        let dim1Read = dim1Read ?? 0..<dim1
        let count = dim0Read.count * dim1Read.count
        return try [Float](unsafeUninitializedCapacity: count, initializingWith: {ptr, countRead in
            try read(into: ptr.baseAddress!, arrayDim1Range: 0..<dim1Read.count, arrayDim1Length: dim1Read.count, dim0Slow: dim0Read, dim1: dim1Read)
            countRead += count
        })
    }
    
    /// Read interpolated between 4 points
    public func readInterpolated(dim0X: Int, dim0XFraction: Float, dim0Y: Int, dim0YFraction: Float, dim0Nx: Int, dim1 dim1Read: Range<Int>) throws -> [Float] {
        
        // bound x and y
        var dim0X = dim0X
        var dim0XFraction = dim0XFraction
        if dim0X > dim0Nx-2 {
            dim0X = dim0Nx-2
            dim0XFraction = 1
        }
        var dim0Y = dim0Y
        var dim0YFraction = dim0YFraction
        let dim0Ny = dim0 / dim0Nx
        if dim0Y > dim0Ny-2 {
            dim0Y = dim0Ny-2
            dim0YFraction = 1
        }
        
        // reads 4 points. As 2 points are next to each other, we can read a small row of 2 elements at once
        let top = try read(dim0Slow: dim0Y * dim0Nx + dim0X ..< dim0Y * dim0Nx + dim0X + 2, dim1: dim1Read)
        let bottom = try read(dim0Slow: (dim0Y + 1) * dim0Nx + dim0X ..< (dim0Y + 1) * dim0Nx + dim0X + 2, dim1: dim1Read)
        
        // interpolate linearly between
        let nt = dim1Read.count
        return zip(zip(top[0..<nt], top[nt..<2*nt]), zip(bottom[0..<nt], bottom[nt..<2*nt])).map {
            let ((a,b),(c,d)) = $0
            return  a * (1-dim0XFraction) * (1-dim0YFraction) +
                    b * (dim0XFraction) * (1-dim0YFraction) +
                    c * (1-dim0XFraction) * (dim0YFraction) +
                    d * (dim0XFraction) * (dim0YFraction)
        }
    }
    
    /// Read interpolated between 4 points. If one point is NaN, ignore it.
    /*public func readInterpolatedIgnoreNaN(dim0X: Int, dim0XFraction: Float, dim0Y: Int, dim0YFraction: Float, dim0Nx: Int, dim1 dim1Read: Range<Int>) throws -> [Float] {
        
        // reads 4 points. As 2 points are next to each other, we can read a small row of 2 elements at once
        let top = try read(dim0Slow: dim0Y * dim0Nx + dim0X ..< dim0Y * dim0Nx + dim0X + 2, dim1: dim1Read)
        let bottom = try read(dim0Slow: (dim0Y + 1) * dim0Nx + dim0X ..< (dim0Y + 1) * dim0Nx + dim0X + 2, dim1: dim1Read)
        
        // interpolate linearly between
        let nt = dim1Read.count
        return zip(zip(top[0..<nt], top[nt..<2*nt]), zip(bottom[0..<nt], bottom[nt..<2*nt])).map {
            let ((a,b),(c,d)) = $0
            var value: Float = 0
            var weight: Float = 0
            if !a.isNaN {
                value += a * (1-dim0XFraction) * (1-dim0YFraction)
                weight += (1-dim0XFraction) * (1-dim0YFraction)
            }
            if !b.isNaN {
                value += b * (1-dim0XFraction) * (dim0YFraction)
                weight += (1-dim0XFraction) * (dim0YFraction)
            }
            if !c.isNaN {
                value += c * (dim0XFraction) * (1-dim0YFraction)
                weight += (dim0XFraction) * (1-dim0YFraction)
            }
            if !d.isNaN {
                value += d * (dim0XFraction) * (dim0YFraction)
                weight += (dim0XFraction) * (dim0YFraction)
            }
            return weight > 0.001 ? value / weight : .nan
        }
    }*/
    
    // prefect and read all
    public func readAll() throws -> [Float] {
        fn.prefetchData(offset: 0, count: fn.count)
        return try read(dim0Slow: 0..<dim0, dim1: 0..<dim1)
    }
    
    // prefect and read all
    public func readAll2D() throws -> Array2DFastTime {
        return Array2DFastTime(data: try readAll(), nLocations: dim0, nTime: dim1)
    }
}
