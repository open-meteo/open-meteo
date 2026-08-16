import OmFileFormat
import Vapor
import Synchronization

/**
 Keep a file system tree in user-space memory. File and directory handles are kept open. Payloads can be associated which are also kept in memory.
 
 Additionally files from a remote S3 server can be cached. The S3 directory tree is periodically updated.
 */
final class OmFileSystemManager: Sendable {
    public static let instance = OmFileSystemManager()
    
    private let localFileSystem: OmFileSystemLocal.Directory
    
    private let remoteFileSystem: OmFileSystemS3?
    
    private init() {
        self.localFileSystem = try! .makeOmRoot()
        self.remoteFileSystem = OpenMeteo.remoteDataDirectory.map { OmFileSystemS3(server: $0) }
    }
    
    enum FileType {
        case local(OmFileSystemLocal.File)
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
        
        if let local = await localFileSystem.getDirectory(fullPath: path) {
            await local.exportDirectories(directories: &directories, files: &files)
        }
        
        if let remoteFileSystem, let remoteDir = try await remoteFileSystem.getRoot(client: client, logger: logger).getDirectory(fullPath: path) {
            await remoteDir.directory.exportDirectories(directories: &directories, files: &files)
        }
        
        return (directories, files)
    }
    
    /// Option to traverse directory by directory for local and remote
    /// E.g can get /data/dwd_icon/ directory and check if a variable is present at all
    /// Or get all chunks from a directory
    func getDirectory(path: String, client: HTTPClient, logger: Logger) async throws -> LocalAndRemoteDirectory? {
        let local = await localFileSystem.getDirectory(fullPath: path)
        guard let remoteFileSystem else {
            return LocalAndRemoteDirectory(local: local, remote: nil)
        }
        let remote = try await remoteFileSystem.getRoot(client: client, logger: logger).getDirectory(fullPath: path)
        return LocalAndRemoteDirectory(local: local, remote: remote)
    }
    
    func getFile(path: String, client: HTTPClient, logger: Logger) async throws -> FileType? {
        if let file = await localFileSystem.getFile(fullPath: path) {
            return .local(file)
        }
        if let remoteFileSystem, let file = try await remoteFileSystem.getRoot(client: client, logger: logger).getFile(fullPath: path) {
            let client = await file.file.makeCachedClient(context: file.context)
            return .remote(client)
        }
        return nil
    }
    
    func with<R, Key: OmFileManagable>(file: Key, client: HTTPClient?, logger: Logger, fn: (_ value: Key.Payload) async throws -> R) async throws -> R? {
        let path = file.getRelativeFilePathWithData()
        assert(path.hasPrefix("/") == false)
        if let object = await localFileSystem.getFile(fullPath: path) {
            let payload = try await object.getPayload(ofType: Key.Payload.self)
            return try await fn(payload)
        }
        guard let remoteFileSystem else {
            return nil
        }
        /// Check for remote file
        guard let client, let object = try await remoteFileSystem.getRoot(client: client, logger: logger).getFile(fullPath: path) else {
            return nil
        }
        return try await object.with(fn: fn)
    }
    
    /// Check if the file is available locally or remotely.
    /// `with<R>()` is recommended to automatically reload files if they are modified during execution
    /// Note: If the file is remote, the reader may throw `CurlError.fileModifiedSinceLastDownload` if the file was modified on the remote end
    func get<Key: OmFileManagable>(file: Key, client: HTTPClient?, logger: Logger, forceNew: Bool = false) async throws -> Key.Payload? {
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

extension OmFileSystemManager {
    struct LocalAndRemoteDirectory {
        let local: OmFileSystemLocal.Directory?
        let remote: OmFileSystemS3.DirectoryWithContext?
        
        /// Get a sub directory in this directory
        func getDirectory(name: String) async throws -> LocalAndRemoteDirectory {
            let local = await local?.getDirectory(name: name)
            guard let remote else {
                return LocalAndRemoteDirectory(local: local, remote: nil)
            }
            let remoteContents = try await remote.getDirectory(name: name)
            return LocalAndRemoteDirectory(local: local, remote: remoteContents)
        }
        
        /// Get a file in this directory
        func getFile(name: String) async -> LocalOrRemoteFile? {
            if let file = await local?.getFile(name: name) {
                return .local(file)
            }
            if let remote, let file = await remote.getFile(name: name) {
                return .remote(file)
            }
            return nil
        }
    }

    enum LocalOrRemoteFile {
        case local(OmFileSystemLocal.File)
        case remote(OmFileSystemS3.FileWithContext)
        
        func with<R, Key: OmFileManagable>(payloadType: Key.Type, client: HTTPClient, logger: Logger, fn: (_ value: Key.Payload) async throws -> R) async throws -> R? {
            switch self {
            case .local(let file):
                return try await fn(file.getPayload(ofType: Key.Payload.self))
            case .remote(let file):
                return try await file.with(fn: fn)
            }
        }
    }

}
