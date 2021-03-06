import Foundation

extension FileHandle {
    /// Create new file and convert it into a `FileHandle`. For some reason this does not exist in stock swift....
    /// Error on existing file
    public static func createNewFile(file: String) throws -> FileHandle {
        // 0644 permissions
        // O_TRUNC for overwrite
        let fn = open(file, O_WRONLY | O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH)
        guard fn > 0 else {
            let error = String(cString: strerror(errno))
            throw SwiftPFor2DError.cannotOpenFile(filename: file, errno: errno, error: error)
        }
        let handle = FileHandle(fileDescriptor: fn, closeOnDealloc: true)
        try handle.seek(toOffset: 0)
        return handle
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
