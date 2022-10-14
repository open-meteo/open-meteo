import Foundation
import SwiftPFor2D
import NIOConcurrencyHelpers
import Vapor
import NIO


/// cache file handles, background close checks
/// If a file path is missing, this information is cached and checked in the background
final class OmFileManager: LifecycleHandler {
    /// A file might exist and is open, or it is missing
    enum OmFileState {
        case exists(file: OmFileReader)
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
    public static func get(basePath: String, variable: String, timeChunk: Int) throws -> OmFileReader? {
        try instance.get(basePath: basePath, variable: variable, timeChunk: timeChunk)
    }

    /// Get cached file or return nil, if the files does not exist
    public func get(basePath: String, variable: String, timeChunk: Int) throws -> OmFileReader? {
        var hasher = Hasher()
        basePath.hash(into: &hasher)
        variable.hash(into: &hasher)
        timeChunk.hash(into: &hasher)
        let key = hasher.finalize()
        
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
            let path = basePath + variable + "_\(timeChunk).om"
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

extension OmFileReader {
    /// Keep one buffer per thread
    fileprivate static var buffers = [Thread: UnsafeMutableRawBufferPointer]()
    
    /// Thread safe access to buffers
    fileprivate static let lockBuffers = NIOLock()
    
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
    public func read(into: UnsafeMutablePointer<Float>, arrayRange: Range<Int>, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        let chunkBuffer = OmFileReader.getBuffer(minBytes: (chunk0 * chunk1 * compression.bytesPerElement).P4NENC256_BOUND()).baseAddress!
        try read(into: into, arrayRange: arrayRange, chunkBuffer: chunkBuffer, dim0Slow: dim0Read, dim1: dim1Read)
    }
    
    /// Read data. This version is a bit slower, because it is allocating the output buffer
    public func read(dim0Slow dim0Read: Range<Int>?, dim1 dim1Read: Range<Int>?) throws -> [Float] {
        let dim0Read = dim0Read ?? 0..<dim0
        let dim1Read = dim1Read ?? 0..<dim1
        let count = dim0Read.count * dim1Read.count
        return try [Float](unsafeUninitializedCapacity: count, initializingWith: {ptr, countRead in
            try read(into: ptr.baseAddress!, arrayRange: 0..<count, dim0Slow: dim0Read, dim1: dim1Read)
            countRead += count
        })
    }
    
    // prefect and read all
    public func readAll() throws -> [Float] {
        fn.prefetchData(offset: 0, count: fn.data.count)
        return try read(dim0Slow: 0..<dim0, dim1: 0..<dim1)
    }
}
