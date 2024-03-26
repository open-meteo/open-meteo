import Foundation

extension FileHandle {
    /// Create new file and convert it into a `FileHandle`. For some reason this does not exist in stock swift....
    /// Error on existing file
    public static func createNewFile(file: String, size: Int? = nil, sparseSize: Int? = nil) throws -> FileHandle {
        // 0644 permissions
        // O_TRUNC for overwrite
        let fn = open(file, O_RDWR | O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)
        guard fn > 0 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(filename: file, errno: errno, error: error)
        }
        
        let handle = FileHandle(fileDescriptor: fn, closeOnDealloc: true)
        if let sparseSize {
            guard ftruncate(fn, off_t(sparseSize)) == 0 else {
                let error = String(cString: strerror(errno))
                throw SwiftPFor2DError.cannotTruncateFile(filename: file, errno: errno, error: error)
            }
        }
        if let size {
            try handle.preAllocate(size: size)
        }
        try handle.seek(toOffset: 0)
        return handle
    }
    
    /// Allocate the required diskspace for a given file
    func preAllocate(size: Int) throws {
        #if os(Linux)
        let error = posix_fallocate(fileDescriptor, 0, size)
        guard error == 0 else {
            throw SwiftPFor2DError.posixFallocateFailed(error: error)
        }
        #else
        /// Try to allocate continous space first
        var store = fstore(fst_flags: UInt32(F_ALLOCATECONTIG), fst_posmode: F_PEOFPOSMODE, fst_offset: 0, fst_length: off_t(size), fst_bytesalloc: 0)
        var error = fcntl(fileDescriptor, F_PREALLOCATE, &store)
        if error == -1 {
            // Try non-continous
            store.fst_flags = UInt32(F_PREALLOCATE)
            error = fcntl(fileDescriptor, F_PREALLOCATE, &store)
        }
        guard error >= 0 else {
            throw SwiftPFor2DError.posixFallocateFailed(error: error)
        }
        let error2 = ftruncate(fileDescriptor, off_t(size))
        guard error2 >= 0 else {
            throw SwiftPFor2DError.ftruncateFailed(error: error2)
        }
        #endif
    }
    
    /// Open file for reading
    public static func openFileReading(file: String) throws -> FileHandle {
        // 0644 permissions
        // O_TRUNC for overwrite
        let fn = open(file, O_RDONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)
        guard fn > 0 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(filename: file, errno: errno, error: error)
        }
        let handle = FileHandle(fileDescriptor: fn, closeOnDealloc: true)
        return handle
    }
    
    /// Open file for read/write
    public static func openFileReadWrite(file: String) throws -> FileHandle {
        // 0644 permissions
        // O_TRUNC for overwrite
        let fn = open(file, O_RDWR, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)
        guard fn > 0 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(filename: file, errno: errno, error: error)
        }
        let handle = FileHandle(fileDescriptor: fn, closeOnDealloc: true)
        return handle
    }
    
    /// Check if the file was deleted on the file system. Linux keep the file alive, as long as some processes have it open.
    public func wasDeleted() -> Bool {
        // This field contains the number of hard links to the file.
        return fileStats().st_nlink == 0
    }
    
    public func fileSize() -> Int {
        return Int(fileStats().st_size)
    }
    
    public func fileSizeAndModificationTime() -> (size: Int, modificationTime: Date, creationTime: Date) {
        let stats = fileStats()
        return (Int(stats.st_size), stats.modificationTime, stats.creationTime)
    }
    
    /// Return file `stat` structure
    public func fileStats() -> stat {
        var stats = stat()
        guard fstat(fileDescriptor, &stats) != -1 else {
            let error = String(cString: strerror(errno))
            fatalError("fstat failed on open file descriptor. Error \(errno) \(error)")
        }
        return stats
    }
}

extension FileManager {
    /// Rename file and replace if `to` already exists. https://www.gnu.org/software/libc/manual/html_node/Renaming-Files.html
    public func moveFileOverwrite(from: String, to: String) throws {
        guard rename(from, to) != -1 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotMoveFile(from: from, to: to, errno: errno, error: error)
        }
    }
    
    public func removeItemIfExists(at: String) throws {
        if fileExists(atPath: at) {
            try removeItem(atPath: at)
        }
    }
    
    /// Return file `stat` structure
    public func fileStats(at: String) -> stat? {
        var stats = stat()
        let ret = stat(at, &stats)
        guard ret != -1 else {
            if errno == 2 {
                // No such file or directory
                return nil
            }
            let error = String(cString: strerror(errno))
            fatalError("fstat failed on open file descriptor. Error \(errno) \(error), ret=\(ret)")
        }
        return stats
    }
    
    /// Get modification and creation time
    public func fileSizeAndModificationTime(at: String) -> (size: Int, modificationTime: Date, creationTime: Date)? {
        guard let stats = fileStats(at: at) else {
            return nil
        }
        return (Int(stats.st_size), stats.modificationTime, stats.creationTime)
    }
    
    /// Wait until the file was not updated for at least 60 seconds. If the file does not exist, do nothing
    public func waitIfFileWasRecentlyModified(at: String) {
        // Wait up to 15 minutes
        for _ in 0..<90 {
            guard let mTime = FileManager.default.fileStats(at: at)?.modificationTime,
                    mTime > Date().addingTimeInterval(-60) else {
                break
            }
            print("Another process is writing to \(at). Waiting up to 15 minutes.")
            sleep(10)
        }
    }
}

extension stat {
    /// Last modification time of the file
    public var modificationTime: Date {
        #if os(Linux)
            let seconds = Double(st_mtim.tv_sec)
            let nanosends = Double(st_mtim.tv_nsec)
        #else
            let seconds = Double(st_mtimespec.tv_sec)
            let nanosends = Double(st_mtimespec.tv_nsec)
        #endif
        return Date(timeIntervalSince1970: seconds + nanosends / 1_000_000)
    }
    
    /// Creation time of the file / inode
    public var creationTime: Date {
        #if os(Linux)
            let seconds = Double(st_ctim.tv_sec)
            let nanosends = Double(st_ctim.tv_nsec)
        #else
            let seconds = Double(st_ctimespec.tv_sec)
            let nanosends = Double(st_ctimespec.tv_nsec)
        #endif
        return Date(timeIntervalSince1970: seconds + nanosends / 1_000_000)
    }
}
