import Foundation

extension FileHandle {
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

public enum FileHandleError: Error {
    case cannotMoveFile(from: String, to: String, errno: Int32, error: String)
}

extension FileManager {
    /// Rename file and replace if `to` already exists. https://www.gnu.org/software/libc/manual/html_node/Renaming-Files.html
    public func moveFileOverwrite(from: String, to: String) throws {
        guard rename(from, to) != -1 else {
            let error = String(cString: strerror(errno))
            throw FileHandleError.cannotMoveFile(from: from, to: to, errno: errno, error: error)
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
    public func waitIfFileWasRecentlyModified(at: String, waitTimeMinutes: Int = 15) {
        // Wait up to 15 minutes
        for _ in 0 ..< (waitTimeMinutes * 6) {
            guard let mTime = FileManager.default.fileStats(at: at)?.modificationTime,
                    mTime > Date().addingTimeInterval(-60) else {
                break
            }
            print("Another process is writing to \(at). Check in 10s. Waiting up to \(waitTimeMinutes) minutes.")
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
