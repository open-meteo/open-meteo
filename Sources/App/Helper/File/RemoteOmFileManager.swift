import OmFileFormat
import Vapor
import Synchronization

/**
 Keep a file system tree in user-space memory. File and directory handles are kept open. Payloads can be associated which are also kept in memory.
 
 Additionally files from a remote S3 server can be cached. The S3 directory tree is periodically updated.
 */
final class RemoteFileManager: Sendable {
    public static let instance = RemoteFileManager()
    
    private let localFileSystem: FileSystemCache.DirectoryEntry
    
    private let remoteFileSystem: S3Inventory?
    
    private init() {
        self.localFileSystem = try! .makeOmRoot()
        self.remoteFileSystem = OpenMeteo.remoteDataDirectory.map { S3Inventory(server: $0) }
    }
    
    enum FileType {
        case local(FileSystemCache.FileEntry)
        case remote(OmReaderBlockCache<OmHttpReaderBackend, MmapFile>)
        
        var modificationTimestamp: Timestamp {
            switch self {
            case .local(let fileEntry):
                return fileEntry.modificationTimestamp
            case .remote(let s3File):
                return s3File.backend.lastModifiedTimestamp
            }
        }
        
        var size: Int64 {
            switch self {
            case .local(let fileEntry):
                return fileEntry.size
            case .remote(let s3File):
                return Int64(s3File.backend.count)
            }
        }
    }
    
    func getDirectoryContents(path: String, client: HTTPClient, logger: Logger) async throws -> (directories: Set<String>, files: [String: (lastModified: Date, size: Int64, eTag: String?)])? {
        var directories = Set<String>()
        var files = [String: (lastModified: Date, size: Int64, eTag: String?)]()
        
        if let local = await localFileSystem.getDirectory(path: path) {
            await local.exportDirectories(directories: &directories, files: &files)
        }
        
        if let remoteFileSystem, let remoteDir = try await remoteFileSystem.getDirectory(path: path, client: client, logger: logger) {
            try await remoteDir.exportDirectories(directories: &directories, files: &files, server: remoteFileSystem.server, client: client, logger: logger)
        }
        
        return (directories, files)
    }
    
    /// Option to traverse directory by directory for local and remote
    /// E.g can get /data/dwd_icon/ directory and check if a variable is present at all
    /// Or get all chunks from a directory
    func getDirectory(path: String, client: HTTPClient, logger: Logger) async throws -> LocalAndRemoteDirectory? {
        let local = await localFileSystem.getDirectory(path: path)?.getContents()
        guard let remoteFileSystem else {
            return LocalAndRemoteDirectory(local: local, remote: nil)
        }
        let remote = try await remoteFileSystem.getDirectory(path: path, client: client, logger: logger)?
            .getContents(server: remoteFileSystem.server, client: client, logger: logger)
        return LocalAndRemoteDirectory(local: local, remote: remote)
    }
    
    func getFile(path: String, client: HTTPClient, logger: Logger) async throws -> FileType? {
        if let file = await localFileSystem.getObject(path: path) {
            return .local(file)
        }
        if let remoteFileSystem, let file = try await remoteFileSystem.getObject(path: path, client: client, logger: logger) {
            let client = await file.makeCachedClient(client: client, logger: logger, server: remoteFileSystem.server)
            return .remote(client)
        }
        return nil
    }
    
    func with<R, Key: RemoteFileManageable>(file: Key, client: HTTPClient?, logger: Logger, fn: (_ value: Key.Payload) async throws -> R) async throws -> R? {
        let path = file.getRelativeFilePathWithData()
        assert(path.hasPrefix("/") == false)
        if let object = await localFileSystem.getObject(path: path) {
            let payload = try await object.getPayload(ofType: Key.Payload.self)
            return try await fn(payload)
        }
        guard let remoteFileSystem else {
            return nil
        }
        /// Check for remote file
        guard let client, let object = try await remoteFileSystem.getObject(path: path, client: client, logger: logger) else {
            return nil
        }
        return try await object.with(client: client, logger: logger, server: remoteFileSystem.server, fn: fn)
    }
    
    /// Check if the file is available locally or remotely.
    /// `with<R>()` is recommended to automatically reload files if they are modified during execution
    /// Note: If the file is remote, the reader may throw `CurlError.fileModifiedSinceLastDownload` if the file was modified on the remote end
    func get<Key: RemoteFileManageable>(file: Key, client: HTTPClient?, logger: Logger, forceNew: Bool = false) async throws -> Key.Payload? {
        return try await self.with(file: file, client: client, logger: logger) {
            return $0
        }
    }
    
    /// Called every second from a life cycle handler on an available thread
    func backgroundTaskRemote(application: Application) async throws {
        await remoteFileSystem?.updateRecursivelyIfRequired(client: application.dedicatedHttpClient, logger: application.logger)
    }
    
    /// Called every second from a life cycle handler on an available thread
    func backgroundTaskLocal(application: Application) async throws {
        do {
            try await localFileSystem.updateRecursivelyIfRequired(now: .now())
        } catch {
            application.logger.error("Local file system update failed: \(error)")
        }
    }
}

protocol RemoteFileManagablePayload: RemotePayload, LocalPayload {
    
}

struct LocalAndRemoteDirectory {
    let local: FileSystemCache.DirectoryContents?
    let remote: S3Directory.DirectoryContents?
    
    /// Get a sub directory in this directory
    func getDirectory(name: String) async throws -> LocalAndRemoteDirectory {
        let local = await local?.directories[name]?.getContents()
        guard let remote else {
            return LocalAndRemoteDirectory(local: local, remote: nil)
        }
        let remoteContents = try await remote.directories[name]?.getContents(server: remote.server, client: remote.client, logger: remote.logger)
        return LocalAndRemoteDirectory(local: local, remote: remoteContents)
    }
    
    /// Get a file in this directory
    func getFile(name: String) async throws -> LocalOrRemoteFile? {
        if let file = local?.files[name] {
            return .local(file)
        }
        if let remote, let file = remote.files[name] {
            return .remote(file, client: remote.client, logger: remote.logger, server: remote.server)
        }
        return nil
    }
}

enum LocalOrRemoteFile {
    case local(FileSystemCache.FileEntry)
    case remote(S3File, client: HTTPClient, logger: Logger, server: String)
    
    func with<R, Key: RemoteFileManageable>(payloadType: Key.Type, client: HTTPClient, logger: Logger, fn: (_ value: Key.Payload) async throws -> R) async throws -> R? {
        switch self {
        case .local(let file):
            return try await fn(file.getPayload(ofType: Key.Payload.self))
        case .remote(let file, client: let client, logger: let logger, server: let server):
            return try await file.with(client: client, logger: logger, server: server, fn: fn)
        }
    }
}
