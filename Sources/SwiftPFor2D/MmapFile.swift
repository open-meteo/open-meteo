import Foundation

/// `Mmap` all pages for a file
public final class MmapFile {
    public let data: UnsafeBufferPointer<UInt8>
    public let file: FileHandle
    
    public enum Mode {
        case readOnly
        case readWrite
        
        /// mmap `prot` attribute
        fileprivate var prot: Int32 {
            switch self {
            case .readOnly:
                return PROT_READ
            case .readWrite:
                return PROT_READ | PROT_WRITE
            }
        }
    }

    /// Mmap the entire filehandle
    public init(fn: FileHandle, mode: Mode = .readOnly) throws {
        let len = try Int(fn.seekToEnd())
        guard let mem = mmap(nil, len, mode.prot, MAP_SHARED, fn.fileDescriptor, 0), mem != UnsafeMutableRawPointer(bitPattern: -1) else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(errno: errno, error: error)
        }
        //madvise(mem, len, MADV_SEQUENTIAL)
        let start = mem.assumingMemoryBound(to: UInt8.self)
        self.data = UnsafeBufferPointer(start: start, count: len)
        self.file = fn
    }
    
    /// Check if the file was deleted on the file system. Linux keep the file alive, as long as some processes have it open.
    public func wasDeleted() -> Bool {
        file.wasDeleted()
    }
    
    /// Tell the OS to prefault the required memory pages. Subsequent calls to read data should be faster
    public func prefetchData(offset: Int, count: Int) {
        let pageStart = offset.floor(to: 4096)
        let pageEnd = (offset + count).ceil(to: 4096)
        let length = pageEnd - pageStart
        let ret = madvise(UnsafeMutableRawPointer(mutating: data.baseAddress!.advanced(by: pageStart)), length, MADV_WILLNEED)
        guard ret == 0 else {
            let error = String(cString: strerror(errno))
            fatalError("madvice failed! ret=\(ret), errno=\(errno), \(error)")
        }
    }

    deinit {
        let len = data.count * MemoryLayout<UInt8>.size
        guard munmap(UnsafeMutableRawPointer(mutating: data.baseAddress!), len) == 0 else {
            fatalError("munmap failed")
        }
    }
}
