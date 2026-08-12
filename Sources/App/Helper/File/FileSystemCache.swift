//import OmFileFormat
import SystemPackage
import Foundation
import AsyncHTTPClient
import Logging
//import NIOFileSystem
import OmFileFormat

#if os(Linux)
import Glibc
#else
import Darwin
#endif


/**
 Caches a file system tree and keeps files and directories open.
 Provides functions to traverse the file tree to get individual files.
 
 Directories and its files are revalidated every couple of seconds to check for modifications.
 Directories are opened on-demand recursively. Only the parts that are used at least once, are loaded into memory.
 
 Files may have an associated payload that is initialised lazily but then kept in memory.
 E.g. om or JSON files are decoded only once.
 
 File metadata like last modification time and size is kept in user to be able to list files
 
 Skips all files starting with a dot or ending in tilde
 
 Consider:
 - Currently OM files can be hash-mapped to open. String traversing is expensive. Any options?
 - Store last accessed attribute and release file handles if not used for a whiles
 - Background checks to revalidate eagerly -> make sure to release deleted files even if not read recently
 
 TODO:
 - Should use `getdents64` to speed up directory listing
 - Use `inotify` on linux to watch for modifications using events
 */
enum FileSystemCache {
    actor DirectoryEntry: Sendable {
        let fd: FileHandle?
        let inode: UInt64
        var lastRefreshTimestamp: UInt64
        private var files: [String: FileEntry]
        private var directories: [String: DirectoryEntry]
        
        /// Make om root directory with data, data_run and data_spatial
        static func makeOmRoot() throws -> DirectoryEntry {
            var directories = [String: DirectoryEntry]()
            directories["data"] = try DirectoryEntry(path: OpenMeteo.dataDirectory)
            if let dataRunDirectory = OpenMeteo.dataRunDirectory {
                directories["data_run"] = try DirectoryEntry(path: dataRunDirectory)
            }
            if let dataSpatialDirectory = OpenMeteo.dataSpatialDirectory {
                directories["data_spatial"] = try DirectoryEntry(path: dataSpatialDirectory)
            }
            return DirectoryEntry(directories: directories)
        }
        
        init(fd: FileHandle, inode: UInt64) {
            self.fd = fd
            self.inode = inode
            self.files = [:]
            self.directories = [:]
            lastRefreshTimestamp = 0
        }
        
        init(directories: [String: DirectoryEntry]) {
            self.fd = nil
            self.inode = 0
            self.lastRefreshTimestamp = 0
            self.directories = directories
            self.files = [:]
        }
        
        init(path: String) throws {
            self.fd = try FileHandle.openFor(path: path, mode: .pathReadOnly)
            self.inode = 0
            self.files = [:]
            self.directories = [:]
            lastRefreshTimestamp = 0
        }
        
        func updateIfRequired() {
            if lastRefreshTimestamp < UInt64(Date().timeIntervalSince1970) - 10 {
                do {
                    try forceUpdate()
                } catch {
                    print("Directory refresh failed: \(error)")
                }
            }
        }
        
        /// Updates files and directories by listing all files. Existing files are checked if the same inode is used.
        func forceUpdate() throws {
            guard let fd = fd.map({FileHandle(fileDescriptor: dup($0.fileDescriptor))}) else {
                return
            }
            guard let dir = fdopendir(fd.fileDescriptor) else {
                let error = String(cString: strerror(errno))
                throw FileSystemCacheError.cannotOpenFile(name: "", errno: errno, error: error)
            }
            defer { closedir(dir) }

            // dup() shares the same open file description (and directory offset),
            // so a previous scan may leave this stream at EOF. Always rewind.
            rewinddir(dir)

            var seenFiles = Set<String>()
            var seenDirectories = Set<String>()

            while let entry = readdir(dir) {
                if entry.pointee.d_name.0 == 46 {
                    continue // Skip all files/directories starting with dot
                }
                let name = withUnsafeBytes(of: entry.pointee.d_name) {
                    String(cString: $0.assumingMemoryBound(to: CChar.self).baseAddress!)
                }
                if name.hasSuffix("~") {
                    continue
                }
                
                var isDirectory = false
                if entry.pointee.d_type == DT_DIR {
                    isDirectory = true
                } else if entry.pointee.d_type == DT_UNKNOWN {
                    // We need to do an additional stat on this to see if it's really a directory or not.
                    // This path should be uncommon.
                    var statBuf = stat()
                    if fstatat(fd.fileDescriptor, &entry.pointee.d_name.0, &statBuf, 0) == 0 {
                        if (mode_t(statBuf.st_mode) & S_IFMT) == S_IFDIR {
                            isDirectory = true
                        }
                    }
                }
                if isDirectory {
                    seenDirectories.insert(name)
                    if let existing = directories[name], existing.inode == inode {
                        continue // directory name exists and is the same inode
                    }
                    let fileFd = try fd.openRelative(path: name, mode: .pathReadOnly)
                    directories[name] = DirectoryEntry(
                        fd: fileFd,
                        inode: inode
                    )
                } else {
                    seenFiles.insert(name)
                    if let existing = files[name], existing.inode == inode {
                        continue // file name exists and is the same inode
                    }
                    let fd = try fd.openRelative(path: &entry.pointee.d_name.0, mode: .fileReadOnly)
                    let stat = fd.fileStats()
                    files[name] = FileEntry(
                        fd: fd,
                        inode: inode,
                        size: Int64(stat.st_size),
                        modificationTimestamp: stat.modificationTime
                    )
                }
            }
            for name in files.keys where !seenFiles.contains(name) {
                files.removeValue(forKey: name)
            }
            for name in directories.keys where !seenDirectories.contains(name) {
                directories.removeValue(forKey: name)
            }
            lastRefreshTimestamp = UInt64(Date().timeIntervalSince1970)
        }
        
        func getDirectoriesAndFiles() -> (directories: [String: DirectoryEntry], files: [String: FileEntry]) {
            updateIfRequired()
            return (self.directories, self.files)
        }
        
        func exportDirectories(directories: inout Set<String>, files: inout [String: (Date, Int64)]) async {
            updateIfRequired()
            for name in self.directories.keys {
                directories.insert(name)
            }
            for (name, attr) in self.files {
                guard files[name] == nil else {
                    continue
                }
                files[name] = (attr.modificationTimestamp, attr.size)
            }
        }
        
        private func getDirectory(name: String) -> DirectoryEntry? {
            updateIfRequired()
            return directories[name]
        }
        
        private func getFile(name: String) -> FileEntry? {
            updateIfRequired()
            return files[name]
        }
        
        /// Find a directory for a path. Valid paths are ``, `data/`
        nonisolated func getDirectory(path: String) async -> DirectoryEntry? {
            assert(path.hasPrefix("/") == false)
            assert(path == "" || path.hasSuffix("/") == true)
            let trimmedPath = path.dropLast()
            var directory = self
            var componentStart = trimmedPath.startIndex
            while componentStart < trimmedPath.endIndex {
                let nextSlash = trimmedPath[componentStart..<trimmedPath.endIndex].firstIndex(of: "/") ?? trimmedPath.endIndex
                let component = trimmedPath[componentStart..<nextSlash]
                guard let next = await directory.getDirectory(name: String(component)) else {
                    return nil
                }
                directory = next
                guard nextSlash < trimmedPath.endIndex else {
                    break
                }
                componentStart = trimmedPath.index(after: nextSlash)
            }
            return directory
        }
        
        /// Find an object for a path
        nonisolated func getObject(path: String) async -> FileEntry? {
            assert(path.hasPrefix("/") == false)
            assert(path.hasSuffix("/") == false)
            let objectStart = path.lastIndex(of: "/").map { path.index(after: $0) } ?? path.startIndex
            let object = path[objectStart..<path.endIndex]

            var directory = self
            var componentStart = path.startIndex
            while componentStart < objectStart {
                let nextSlash = path[componentStart..<objectStart].firstIndex(of: "/") ?? objectStart
                let component = path[componentStart..<nextSlash]
                guard let next = await directory.getDirectory(name: String(component)) else {
                    return nil
                }
                directory = next
                componentStart = path.index(after: nextSlash)
            }
            return await directory.getFile(name: String(object))
        }
    }
    
    /// File needs to be in sync with size and modification timestamp.
    actor FileEntry {
        let fd: FileHandle
        let inode: UInt64 // required to check while looping directories
        let size: Int64
        let modificationTimestamp: Date
        
        /// Reference to the open-meteo file or json file
        private var payload: PayloadState
        
        private enum PayloadState {
            case none
            case initialising([CheckedContinuation<FileSystemPayload, any Error>])
            case ready(FileSystemPayload)
            case error(Error)
        }
        
        init(fd: FileHandle, inode: UInt64, size: Int64, modificationTimestamp: Date) {
            self.fd = fd
            self.inode = inode
            self.size = size
            self.modificationTimestamp = modificationTimestamp
            payload = .none
        }
        
        func getPayload<T: FileSystemPayload>(ofType: T.Type) async throws -> T {
            switch payload {
            case .none:
                self.payload = .initialising([])
                do {
                    let payload = try await T(fd: fd, size: size)
                    guard case .initialising(let queued) = self.payload else {
                        fatalError("State was not .initialising()")
                    }
                    self.payload = .ready(payload)
                    queued.forEach {
                        $0.resume(with: .success(payload))
                    }
                    return payload
                } catch {
                    guard case .initialising(let queued) = self.payload else {
                        fatalError("State was not .initialising()")
                    }
                    // Do not cache the cancellation as terminal error.
                    if error is CancellationError {
                        self.payload = .none
                    } else {
                        self.payload = .error(error)
                    }
                    queued.forEach({
                        $0.resume(throwing: error)
                    })
                    throw error
                }
            case .initialising(let queue):
                let payload = try await withCheckedThrowingContinuation { continuation in
                    self.payload = .initialising(queue + [continuation])
                }
                guard let payload = payload as? T else {
                    fatalError("Payload was not of correct type \(T.self)")
                }
                return payload
            case .ready(let payload):
                guard let payload = payload as? T else {
                    fatalError("Payload was not of correct type \(T.self)")
                }
                return payload
            case .error(let error):
                throw error
            }
        }
    }
}

protocol FileSystemPayload: Sendable {
    /// Payload can retain a reference to FileHandle to ensure the file stays open
    init(fd: FileHandle, size: Int64) async throws
    
    /// Initialise from remote source
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Self
    func remoteDeleted() async throws
}

#if os(Linux)
// Linux-specific O_PATH definition
let O_PATH: Int32 = 0x00200000
#endif

fileprivate extension FileHandle {
    enum OFlags {
        case fileReadOnly
        case pathReadOnly
        
        var flags: Int32 {
            switch self {
            case .fileReadOnly:
                return O_RDONLY
            case .pathReadOnly:
                #if os(Linux)
                return O_PATH | O_DIRECTORY
                #else
                return O_RDONLY | O_DIRECTORY
                #endif
            }
        }
    }
    
    /// Open file for reading
    static func openFor(path: UnsafePointer<CChar>, mode: OFlags) throws -> FileHandle {
        var fd: Int32 = -1
        repeat {
            fd = open(path, mode.flags)
        } while fd == -1 && errno == EINTR
        guard fd > 0 else {
            let error = String(cString: strerror(errno))
            throw FileSystemCacheError.cannotOpenFile(name: String(cString: path), errno: errno, error: error)
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        return handle
    }
    
    /// Open file relative to current directory
    func openRelative(path: UnsafePointer<CChar>, mode: OFlags) throws -> FileHandle {
        var fd: Int32 = -1
        repeat {
            fd = openat(fileDescriptor, path, mode.flags)
        } while fd == -1 && errno == EINTR
        guard fd > 0 else {
            let error = String(cString: strerror(errno))
            throw FileSystemCacheError.cannotOpenFile(name: String(cString: path), errno: errno, error: error)
        }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
}

enum FileSystemCacheError: Error {
    case cannotOpenFile(name: String, errno: Int32, error: String)
}

/*
import SystemPackage
import Foundation

// MARK: - Native Layout Abstraction Layer
#if os(Linux)
import Glibc
// Re-maps layout properties to standard Linux 64-bit kernel interfaces
public typealias PlatformDirent = linux_dirent64
#elseif os(macOS) || os(iOS)
import Darwin
// Re-maps layout properties to standard Apple Darwin definitions
public typealias PlatformDirent = dirent
#endif

/// A portable Swift model representing a discovered filesystem object
public struct DirectoryEntry {
    public let inode: UInt64
    public let name: String
    public let type: UInt8
}

// MARK: - Safe Directory Iterator
public struct FileDescriptorDirectoryIterator: IteratorProtocol {
    public typealias Element = DirectoryEntry
    
    private let fileDescriptor: FileDescriptor
    private var buffer: [UInt8]
    private var bufferBytesRead: Int = 0
    private var bufferPosition: Int = 0
    private var isEndOfDirectory: Bool = false
    
    // Tracks the opaque directory base cookie required exclusively by macOS getdirentries
    #if os(macOS) || os(iOS)
    private var basep: Int = 0
    #endif

    public init(fileDescriptor: FileDescriptor, bufferSize: Int = 32768) {
        self.fileDescriptor = fileDescriptor
        self.buffer = Array(repeating: 0, count: bufferSize)
    }

    public mutating func next() -> DirectoryEntry? {
        while true {
            // 1. If user-space memory buffer runs completely dry, pull next batch from OS kernel
            if bufferPosition >= bufferBytesRead {
                if isEndOfDirectory { return nil }
                fetchNextChunk()
                if bufferBytesRead <= 0 { return nil }
            }
            
            // 2. Fetch memory boundaries of the active variable-length record
            let currentOffset = bufferPosition
            
            // Re-bind raw contiguous memory addresses safely to read C field lengths
            let recordLength: Int = buffer.withUnsafeBufferPointer { ptr in
                let baseAddress = ptr.baseAddress!.advanced(by: currentOffset)
                #if os(Linux)
                // Offset matching 'unsigned short d_reclen' on Linux systems
                let lengthOffset = MemoryLayout<UInt64>.size + MemoryLayout<Int64>.size
                return Int(baseAddress.advanced(by: lengthOffset).assumingMemoryBound(to: UInt16.self).pointee)
                #elseif os(macOS) || os(iOS)
                // Offset matching 'uint16_t d_reclen' on Darwin systems
                let lengthOffset = MemoryLayout<UInt64>.size + MemoryLayout<UInt64>.size
                return Int(baseAddress.advanced(by: lengthOffset).assumingMemoryBound(to: UInt16.self).pointee)
                #endif
            }
            
            // Advance cursor forward to point to the immediate next layout boundary
            bufferPosition += recordLength
            
            // Guard clause checking for corrupted filesystems or invalid record returns
            if recordLength == 0 {
                isEndOfDirectory = true
                return nil
            }
            
            // 3. Extract exact entry values directly out of our raw staging frame
            let parsedEntry = buffer.withUnsafeBufferPointer { ptr -> DirectoryEntry? in
                let baseAddress = ptr.baseAddress!.advanced(by: currentOffset)
                
                #if os(Linux)
                let inode = baseAddress.assumingMemoryBound(to: UInt64.self).pointee
                let typeOffset = MemoryLayout<UInt64>.size + MemoryLayout<Int64>.size + MemoryLayout<UInt16>.size
                let fileType = baseAddress.advanced(by: typeOffset).assumingMemoryBound(to: UInt8.self).pointee
                let nameOffset = typeOffset + MemoryLayout<UInt8>.size
                let nameString = String(cString: baseAddress.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self))
                #elseif os(macOS) || os(iOS)
                let inode = baseAddress.assumingMemoryBound(to: UInt64.self).pointee
                let typeOffset = MemoryLayout<UInt64>.size + MemoryLayout<UInt64>.size + MemoryLayout<UInt16>.size + MemoryLayout<UInt8>.size
                let fileType = baseAddress.advanced(by: typeOffset).assumingMemoryBound(to: UInt8.self).pointee
                let nameOffset = typeOffset + MemoryLayout<UInt8>.size
                let nameString = String(cString: baseAddress.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self))
                #endif
                
                // Skip the explicit shell self (.) and parent (..) layout targets
                if nameString == "." || nameString == ".." { return nil }
                
                return DirectoryEntry(inode: inode, name: nameString, type: fileType)
            }
            
            // If the element wasn't skipped (i.e., not "." or ".."), return it to the loop
            if let entry = parsedEntry {
                return entry
            }
        }
    }
    
    private mutating func fetchNextChunk() {
        bufferPosition = 0
        
        buffer.withUnsafeMutableBufferPointer { ptr in
            let rawBufferPointer = UnsafeMutableRawPointer(ptr.baseAddress!)
            
            #if os(Linux)
            // Executes raw 64-bit Linux getdents system trap call (sys_getdents64 = 217)
            let result = syscall(SYS_getdents64, fileDescriptor.rawValue, rawBufferPointer, ptr.count)
            bufferBytesRead = Int(result)
            #elseif os(macOS) || os(iOS)
            // Executes matching historical Darwin system stream read calls
            let result = getdirentries(fileDescriptor.rawValue, rawBufferPointer.assumingMemoryBound(to: CChar.self), ptr.count, &basep)
            bufferBytesRead = Int(result)
            #endif
        }
        
        if bufferBytesRead <= 0 {
            isEndOfDirectory = true
        }
    }
}

// MARK: - Concrete Custom Sequence Wrapper
public struct FileDescriptorDirectorySequence: Sequence {
    private let fileDescriptor: FileDescriptor
    private let bufferSize: Int

    public init(fileDescriptor: FileDescriptor, bufferSize: Int = 32768) {
        self.fileDescriptor = fileDescriptor
        self.bufferSize = bufferSize
    }

    public func makeIterator() -> FileDescriptorDirectoryIterator {
        return FileDescriptorDirectoryIterator(fileDescriptor: fileDescriptor, bufferSize: bufferSize)
    }
}
*/
