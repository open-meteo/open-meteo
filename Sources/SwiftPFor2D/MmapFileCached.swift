import Foundation

/// Mmap a all pages for a file
public final class MmapFileCached {
    public let backend: MmapFile
    public let frontend: MmapMutableFile?
    public let cacheFile: String?

    public init(backend: FileHandle, frontend: FileHandle?, cacheFile: String?) throws {
        self.backend = try MmapFile(fn: backend)
        self.frontend = try frontend.map { try MmapMutableFile(fn: $0) }
        self.cacheFile = cacheFile
    }
    
    /// Check if the file was deleted on the file system
    public func wasDeleted() -> Bool {
        if frontend?.wasDeleted() == true {
            return true
        }
        if backend.wasDeleted() {
            if let cacheFile {
                try? FileManager.default.removeItemIfExists(at: cacheFile)
            }
            return true
        }
        return false
    }
    
    /// Check if data is in cache, otherwise load data from backend into cache
    public func prefetchData(offset: Int, count: Int) {
        if let frontend {
            // Check for sparse hole and promote data from backend
            let blockSize = 128*1024
            let blockStart = offset.floor(to: blockSize)
            let blockEnd = (offset + count).ceil(to: blockSize)
            for block in stride(from: blockStart, to: blockEnd, by: blockSize) {
                let range = block..<min(block+blockSize, backend.data.count)
                if frontend.data.allZero(range) {
                    let backendData = UnsafeMutableBufferPointer(mutating: backend.data)
                    frontend.data[range] = backendData[range]
                }
            }
        } else {
            backend.prefetchData(offset: offset, count: count)
        }
    }
}

extension MmapFileCached: OmFileReaderBackend {
    public var count: Int {
        return backend.count
    }
    
    public var needsPrefetch: Bool {
        return true
    }
    
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        if let frontend {
            try frontend.data.withUnsafeBytes(body)
        } else {
            try backend.withUnsafeBytes(body)
        }
    }
}


/// Similar to MmapFile, but mutable
public final class MmapMutableFile {
    public let data: UnsafeMutableBufferPointer<UInt8>
    public let file: FileHandle

    /// Mmap the entire filehandle
    public init(fn: FileHandle) throws {
        let len = try Int(fn.seekToEnd())
        guard let mem = mmap(nil, len, PROT_READ | PROT_WRITE, MAP_SHARED, fn.fileDescriptor, 0), mem != UnsafeMutableRawPointer(bitPattern: -1) else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(errno: errno, error: error)
        }
        //madvise(mem, len, MADV_SEQUENTIAL)
        let start = mem.assumingMemoryBound(to: UInt8.self)
        data = UnsafeMutableBufferPointer(start: start, count: len)
        self.file = fn
    }
    
    /// Check if the file was deleted on the file system. Linux keep the file alive, as long as some processes have it open.
    public func wasDeleted() -> Bool {
        file.wasDeleted()
    }

    deinit {
        let len = data.count * MemoryLayout<UInt8>.size
        guard munmap(UnsafeMutableRawPointer(mutating: data.baseAddress!), len) == 0 else {
            fatalError("munmap failed")
        }
    }
}


extension UnsafeMutableBufferPointer where Element == UInt8 {
    /// Check if a range contains all zero bytes
    func allZero(_ range: Range<Int>) -> Bool {
        for i in (range).clamped(to: indices) {
            if self[i] != 0 {
                return false
            }
        }
        return true
    }
}
