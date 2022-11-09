import Foundation

extension FileHandle {
    /// Create new file and convert it into a `FileHandle`. For some reason this does not exist in stock swift....
    /// Error on existing file
    public static func createNewFile(file: String, size: Int? = nil) throws -> FileHandle {
        // 0644 permissions
        // O_TRUNC for overwrite
        let fn = open(file, O_WRONLY | O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)
        guard fn > 0 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(filename: file, errno: errno, error: error)
        }
        
        let handle = FileHandle(fileDescriptor: fn, closeOnDealloc: true)
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
    
    /// Check if the file was deleted on the file system. Linux keep the file alive, as long as some processes have it open.
    public func wasDeleted() -> Bool {
        var stats = stat()
        guard fstat(fileDescriptor, &stats) != -1 else {
            let error = String(cString: strerror(errno))
            fatalError("fstat failed on open file descriptor. Error \(errno) \(error)")
        }
        // This field contains the number of hard links to the file.
        return stats.st_nlink == 0
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
}
