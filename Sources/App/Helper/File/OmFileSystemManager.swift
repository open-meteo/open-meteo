import OmFileFormat
import Dispatch
import AsyncHTTPClient
import Logging
import OmFileIO
import Synchronization

/**
 Keep a file system tree in user-space memory. File and directory handles are kept open. Payloads can be associated which are also kept in memory.
 
 Additionally files from a remote S3 server can be cached. The S3 directory tree is periodically updated.
 */
final class OmFileSystemManager: Sendable {
    private static let initialized = Atomic(false)
    public static let instance: OmFileSystemManager = {
        let manager = OmFileSystemManager()
        initialized.store(true, ordering: .releasing)
        return manager
    }()

    /// Background refresh must not initialize storage for commands that do not use it.
    static var isInitialized: Bool {
        initialized.load(ordering: .acquiring)
    }
    
    let localFileSystem: OmFileSystemLocal.Directory
    
    let remoteFileSystem: OmFileSystemS3?
    
    private init() {
        /// Make om root directory with data, data_run and data_spatial
        var directories = [String: OmFileSystemLocal.Directory]()
        directories["data"] = try! OmFileSystemLocal.Directory(path: OpenMeteo.dataDirectory)
        if let dataRunDirectory = OpenMeteo.dataRunDirectory {
            directories["data_run"] = try! OmFileSystemLocal.Directory(path: dataRunDirectory)
        }
        if let dataSpatialDirectory = OpenMeteo.dataSpatialDirectory {
            directories["data_spatial"] = try! OmFileSystemLocal.Directory(path: dataSpatialDirectory)
        }
        
        self.localFileSystem = OmFileSystemLocal.Directory(directories: directories)
        self.remoteFileSystem = OpenMeteo.remoteDataDirectory.map { OmFileSystemS3(server: S3ServerHealth(logger: .init(label: ""), servers: $0)) }
    }
    
    enum FileType {
        case local(OmFileSystemLocal.File)
        case remote(OmReaderBlockCache<OmHttpReaderBackend, MmapFile>)
        
        var modificationTimestamp: Timestamp {
            switch self {
            case .local(let fileEntry):
                return fileEntry.modificationTimestamp
            case .remote(let s3File):
                return s3File.backend.lastModified
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
    
    /// Called after a file has been uploaded using the integrated S3 server
    func updateLocalDirectory(path: String) async {
        await localFileSystem.getDirectory(fullPath: path)?.updateIfRequired(force: true)
    }
    
    func getDirectoryContents(path: String, client: HTTPClient, logger: Logger, localOnly: Bool) async throws -> (directories: Set<String>, files: [String: (lastModified: Timestamp, size: Int64)])? {
        var directories = Set<String>()
        var files = [String: (lastModified: Timestamp, size: Int64)]()
        
        if let local = await localFileSystem.getDirectory(fullPath: path) {
            await local.exportDirectories(directories: &directories, files: &files)
        }
        
        if localOnly == false, let remoteFileSystem, let remoteDir = try await remoteFileSystem.getRoot(client: client, logger: logger).getDirectory(fullPath: path) {
            await remoteDir.directory.exportDirectories(directories: &directories, files: &files)
        }
        
        return (directories, files)
    }
    
    func getFile(path: String, client: HTTPClient, logger: Logger, localOnly: Bool) async throws -> FileType? {
        if let file = await localFileSystem.getFile(fullPath: path) {
            return .local(file)
        }
        if localOnly == false, (!OpenMeteo.remotePressureLevelsOnly || path.contains("hPa")), let remoteFileSystem, let file = try await remoteFileSystem.getRoot(client: client, logger: logger).getFile(fullPath: path) {
            let client = await file.file.makeCachedClient(context: file.context)
            let file = OmReaderBlockCache(backend: client, cache: OpenMeteo.dataBlockCache, cacheKey: client.cacheKey)
            return .remote(file)
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
        guard !OpenMeteo.remotePressureLevelsOnly || path.contains("hPa"), let remoteFileSystem else {
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
    func backgroundTaskRemote() async {
        let logger = Logger(label: "OmFileSystemManager backgroundTaskRemote")
        let start = DispatchTime.now()
        await remoteFileSystem?.updateRecursivelyIfRequired(client: .shared, logger: logger)
        let duration = start.timeElapsedSeconds()
        if duration > 5 {
            logger.warning("Remote S3 file system background update took \(duration.asSecondsPrettyPrint)")
        }
    }
    
    /// Called every second from a life cycle handler on an available thread
    func backgroundTaskLocal() async {
        let logger = Logger(label: "OmFileSystemManager backgroundTaskLocal")
        let start = DispatchTime.now()
        await localFileSystem.updateRecursivelyIfRequired(now: .now())
        let duration = start.timeElapsedSeconds()
        if duration > 5 {
            logger.warning("Local file system background update took \(duration.asSecondsPrettyPrint)")
        }
    }
}

extension OmFileSystemManager {
    /// Resolve the variable directory once and retain its copy-on-write file indexes.
    /// Returns nil when neither an accessible local nor remote directory exists.
    func getSeriesDirectory(domain: DomainRegistry, variable: String, ensembleMember: Int, previousDay: Int, client: HTTPClient?, logger: Logger) async throws -> SeriesDirectory? {
        // The common case reuses the variable string without allocating a path.
        var name = variable
        if previousDay > 0 {
            name += "_previous_day"
            name += String(previousDay)
        }
        if ensembleMember > 0 {
            name += "_member"
            name += ensembleMember.zeroPadded(len: 2)
        }
        let local = await localFileSystem
            .getDirectory(name: "data")?
            .getDirectory(name: domain.rawValue)?
            .getDirectory(name: name)?
            .getSeriesIndex()
        var remote: OmFileSystemS3.DirectoryWithContext?
        if let client, !OpenMeteo.remotePressureLevelsOnly || variable.contains("hPa") || domain.rawValue.contains("hPa"), let remoteFileSystem {
            remote = try await remoteFileSystem.getRoot(client: client, logger: logger)
                .getDirectory(name: "data")?
                .getDirectory(name: domain.rawValue)?
                .getDirectory(name: name)
        }
        guard local != nil || remote != nil else {
            return nil
        }
        return SeriesDirectory(local: local, remote: await remote?.directory.getSeriesIndex(), context: remote)
    }

    struct SeriesDirectory {
        let local: OmFileSeriesIndex<OmFileSystemLocal.File>?
        let remote: OmFileSeriesIndex<OmFileSystemS3.File>?
        let context: OmFileSystemS3.DirectoryWithContext?

        private func union(_ lhs: Range<Int>?, _ rhs: Range<Int>?) -> Range<Int> {
            guard let lhs, !lhs.isEmpty else { return rhs ?? 0..<0 }
            guard let rhs, !rhs.isEmpty else { return lhs }
            return min(lhs.lowerBound, rhs.lowerBound)..<max(lhs.upperBound, rhs.upperBound)
        }

        var chunkRange: Range<Int> { union(local?.chunkRange, remote?.chunkRange) }
        var yearRange: Range<Int> { union(local?.yearRange, remote?.yearRange) }

        func getFile(type: OmFileSeriesType, index: Int = 0) -> LocalOrRemoteFile? {
            let localFile: OmFileSystemLocal.File?
            let remoteFile: OmFileSystemS3.File?
            switch type {
            case .chunk:
                localFile = local?.chunks[index]
                remoteFile = remote?.chunks[index]
            case .year:
                localFile = local?.years[index]
                remoteFile = remote?.years[index]
            case .master:
                localFile = local?.master
                remoteFile = remote?.master
            case .rolling:
                localFile = local?.rolling
                remoteFile = remote?.rolling
            case .linear_bias_seasonal:
                return nil
            }
            if let localFile { return .local(localFile) }
            if let remoteFile, let context { return .remote(context.withContext(file: remoteFile)) }
            return nil
        }
    }

    enum LocalOrRemoteFile {
        case local(OmFileSystemLocal.File)
        case remote(OmFileSystemS3.FileWithContext)
        
        func with<R, Key: OmFileManagable>(payloadType: Key.Type, fn: (_ value: Key.Payload) async throws -> R) async throws -> R? {
            switch self {
            case .local(let file):
                return try await fn(file.getPayload(ofType: Key.Payload.self))
            case .remote(let file):
                return try await file.with(fn: fn)
            }
        }
    }

}
