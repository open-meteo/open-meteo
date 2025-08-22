import OmFileFormat
import Vapor


/**
 Keep track of local and remote OM files. If a OM file is locally available, use it, otherwise check a remote http endpoint.
 
 Local files use mmap to read data. This should only be used for fast storage. Access to mmap data is synchronous, but uses madvice for better prefetching
 
 Remote files use HTTP Range requests to get data in chunks of 64kb. Requests to the same 64kb data block are serialised and queued.
 Data blocks are cached in a local cache file. The cache file uses mmap and should reside on a fast local disk.
 The mmap cache uses fixed blocks of 64kb and stores meta data using atomic double word operations. Cache can be reused after restart.
 
 Files are checked for deletion, modification or addition periodically in the background:
 - Local files are checked every 10 seconds
 - Remote files are checked every 3 minutes
 - All files are evicted from cache after 15 minutes of inactivity
 
 TODO:
 - Support multiple cache files. Could be useful if multiple NVMe drive are available for caching
 - Support cache tiering for HDD + NVME cache
 */
final class RemoteOmFileManager: Sendable {
    public static let instance = RemoteOmFileManager()
    
    /// Isolate requests to files
    let cache = RemoteOmFileManagerCache()
    
    /// Execute a closure with a reader. If the remote file was modified during execution, restart the execution
    func with<R>(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, fn: (_ reader: any OmFileReaderArrayProtocol<Float>, _ timestamps: [Timestamp]?) async throws -> R) async throws -> R? {
        guard let reader = try await get(file: file, client: client, logger: logger, forceNew: false) else {
            return nil
        }
        do {
            return try await fn(reader.reader, reader.timestamps)
        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
            guard let reader = try await get(file: file, client: client, logger: logger, forceNew: true) else {
                return nil
            }
            return try await fn(reader.reader, reader.timestamps)
        }
    }
    
    /// Check if the file is available locally or remotely. `with<R>()` is recommended
    /// Note: If the file is remote, the reader may throw `CurlError.fileModifiedSinceLastDownload` if the file was modified on the remote end
    func get(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, forceNew: Bool = false) async throws -> (reader: any OmFileReaderArrayProtocol<Float>, timestamps: [Timestamp]?)? {
        guard let backend = try await cache.get(key: file, forceNew: forceNew, provider: {
            return try await file.newReader(client: client, logger: logger)
        }) else {
            return nil
        }
        return backend.toReader()
    }
    
    /// Called every 10 seconds from a life cycle handler on an available thread
    func backgroundTask(application: Application) async throws {
        try await cache.revalidate(client: application.http.client.shared, logger: application.logger)
    }
}

enum OmFileLocalOrRemote {
    case local(OmFileReaderArray<MmapFile, Float>, timestamps: [Timestamp]?)
    case remote(OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float>, timestamps: [Timestamp]?)
    
    func toReader() -> (reader: any OmFileReaderArrayProtocol<Float>, timestamps: [Timestamp]?) {
        switch self {
        case .local(let local, let timestamps):
            return (local, timestamps)
        case .remote(let remote, let timestamps):
            return (remote, timestamps)
        }
    }
}

extension OmFileManagerReadable {
    func newReader(client: HTTPClient, logger: Logger) async throws -> (value: OmFileLocalOrRemote?, lastValidated: Timestamp) {
        let localFile = getFilePath()
        if FileManager.default.fileExists(atPath: localFile) {
            do {
                let reader = try await OmFileReader(fn: try MmapFile(fn: try FileHandle.openFileReading(file: localFile), mode: .readOnly))
                guard let arrayReader = reader.asArray(of: Float.self) else {
                    return (nil, .now())
                }
                if let times = try await reader.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init) {
                    return (.local(arrayReader, timestamps: times), .now())
                }
                return (.local(arrayReader, timestamps: nil), .now())
            } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
                print("[ ERROR ] Not an OpenMeteo file \(localFile)")
                return (nil, .now())
            }
        }
        let (reader, lastValidated) = try await self.makeOrCachedRemoteReader(client: client, logger: logger)
        return (try await reader?.asRemoteReader(), lastValidated)
    }
}

extension OmHttpReaderBackend {
    /// Create a new remote reader and store in meta cache if the file is available
    static func makeRemoteReaderAndCacheMeta(client: HTTPClient, logger: Logger, url: String) async throws -> OmHttpReaderBackend? {
        guard let reader = try await OmHttpReaderBackend(client: client, logger: logger, url: url) else {
            try OmHttpMetaCache.set(url: url, state: .missing(lastValidated: .now()))
            return nil
        }
        try OmHttpMetaCache.set(url: url, state: .available(lastValidated: .now(), contentLength: reader.count, lastModified: reader.lastModifiedTimestamp, eTag: reader.eTag))
        return reader
    }
}

extension OmFileManagerReadable {
    /// Create a new remote reader, getting meta attributes from cache
    func makeOrCachedRemoteReader(client: HTTPClient, logger: Logger) async throws -> (OmHttpReaderBackend?, Timestamp) {
        guard let remoteFile = self.getRemoteUrl() else {
            return (nil, .now())
        }
        let now = Timestamp.now()
                
        switch OmHttpMetaCache.get(url: remoteFile) {
        case .missing(let lastValidated):
            let revalidateSeconds = self.revalidateEverySeconds(modificationTime: nil, now: now)
            if lastValidated < now.subtract(seconds: revalidateSeconds) {
                // need to revalidate
                return (try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile), .now())
            }
            // safe to assume the file is still missing
            return (nil, lastValidated)
            
        case .available(let lastValidated, let count, let lastModified, let eTag):
            let revalidateSeconds = self.revalidateEverySeconds(modificationTime: lastModified, now: now)
            if lastValidated < now.subtract(seconds: revalidateSeconds) {
                // need to revalidate
                return (try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile), .now())
            }
            /// Reuse cached meta attributes
            return (OmHttpReaderBackend(client: client, logger: logger, url: remoteFile, count: count, lastModified: lastModified, eTag: eTag, lastValidated: lastValidated), lastValidated)
            
        case .none:
            return (try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile), .now())
        }
    }
}

extension OmFileReaderProtocol {
    func asArray<OmType: OmFileArrayDataTypeProtocol>(of: OmType.Type) -> (any OmFileReaderArrayProtocol<OmType>)? {
        return asArray(of: of, io_size_max: 65536, io_size_merge: 512)
    }
}

/**
 KV cache, but a resource is resolved not in parallel
 */
final actor RemoteOmFileManagerCache {
    typealias Key = OmFileManagerReadable
    typealias Value = OmFileLocalOrRemote?
    
    struct Statistics {
        var ticks = 0
        var inactivity = 0
        var localModified = 0
        var remoteModified = 0
        var remoteDeleted = 0
        var remoteRevalidated = 0
        var remoteCheckedExist = 0
        
        mutating func reset() {
            inactivity = 0
            localModified = 0
            remoteModified = 0
            remoteDeleted = 0
            remoteRevalidated = 0
            remoteCheckedExist = 0
        }
    }
    
    
    final class Entry {
        var value: Value
        var lastValidated: Timestamp
        var lastAccessed: Timestamp
        
        init(value: Value, lastValidated: Timestamp = .now(), lastAccessed: Timestamp = .now()) {
            self.value = value
            self.lastValidated = lastValidated
            self.lastAccessed = lastAccessed
        }
    }
    
    enum State {
        /// Value and last accessed timestamp
        case cached(Entry)
        case running([CheckedContinuation<Value, any Error>])
        
        var isCached: Bool {
            switch self {
            case .cached:
                return true
            case .running:
                return false
            }
        }
    }
    
    var cache = [Key: State]()
    var statistics: Statistics = .init()
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get(key: Key, forceNew: Bool, provider: () async throws -> (value: Value, lastValidated: Timestamp)) async throws -> Value {
        guard let state = cache[key], !(forceNew == true && state.isCached) else {
            // Value not cached or needs to be refreshed
            cache[key] = .running([])
            do {
                let (data, lastValidated) = try await provider()
                guard case .running(let queued) = cache.updateValue(.cached(.init(value: data, lastValidated: lastValidated)), forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach {
                    $0.resume(with: .success(data))
                }
                return data
            } catch {
                guard case .running(let queued) = cache.removeValue(forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach({
                    $0.resume(with: .failure(error))
                })
                throw error
            }
        }
        switch state {
        case .cached(let entry):
            entry.lastAccessed = .now()
            return entry.value
        case .running(let running):
            let value = try await withCheckedThrowingContinuation { continuation in
                cache[key] = .running(running + [continuation])
            }
            return value
        }
    }
    
    /**
     Remove entries that have not been accessed for more than 15 minutes
     Revalidate entries older than 3 minutes.
     Called every 10 seconds
     */
    func revalidate(client: HTTPClient, logger: Logger) async throws {
        var running = 0
        var total = 0
        statistics.ticks += 1
        let startRevalidation = DispatchTime.now()
        
        let now = Timestamp.now()
        let removeLastAccessedThan = now.subtract(minutes: 15)
        for (key, state) in cache {
            total += 1
            guard case .cached(let entry) = state else {
                running += 1
                continue
            }
            // Evict unused entries after 15 minutes
            if entry.lastAccessed < removeLastAccessedThan {
                statistics.inactivity += 1
                cache.removeValue(forKey: key)
                continue
            }
            
            // Always check if local files got deleted or overwritten
            if case .local(let local, _) = entry.value, local.fn.file.wasDeleted() {
                statistics.localModified += 1
                cache.removeValue(forKey: key)
                continue
            }
            
            // Always check if a local file is now available
            if entry.value == nil, FileManager.default.fileExists(atPath: key.getFilePath()) {
                statistics.localModified += 1
                cache.removeValue(forKey: key)
                continue
            }
            
            if let remoteFile = key.getRemoteUrl() {
                // Remote file is open
                if case .remote(let old, _) = entry.value {
                    let revalidateSeconds = key.revalidateEverySeconds(modificationTime: old.fn.backend.lastModifiedTimestamp, now: now)
                    if old.fn.backend.lastValidated > entry.lastValidated {
                        /// Update meta cache to also reflect updates in `lastBackendFetchTimestamp`
                        try OmHttpMetaCache.set(url: remoteFile, state: .available(lastValidated: old.fn.backend.lastValidated, contentLength: old.fn.backend.count, lastModified: old.fn.backend.lastModifiedTimestamp, eTag: old.fn.backend.eTag))
                    }
                    let lastValidated = max(entry.lastValidated, old.fn.backend.lastValidated)
                    if lastValidated < now.subtract(seconds: revalidateSeconds) {
                        entry.lastValidated = .now()
                        statistics.remoteRevalidated += 1
                        if let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile) {
                            guard old.fn.cacheKey != new.cacheKey else {
                                continue // do not update if the existing entry is the same
                            }
                            statistics.remoteModified += 1
                            let blockCached = new.asBlockCached()
                            let activeBlocks = old.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
                            logger.warning("OmFileManager: Remote file modified \(key). \(activeBlocks.count) blocks active in the last 15 minutes")
                            if activeBlocks.count > 0 {
                                let startPreload = DispatchTime.now()
                                try await blockCached.preloadBlocks(blocks: activeBlocks)
                                logger.warning("OmFileManager: Preload completed in \(startPreload.timeElapsedPretty())")
                            }
                            guard let reader = try await blockCached.asCachedReader()?.asRemoteReader() else {
                                entry.value = nil
                                continue
                            }
                            entry.value = reader
                        } else {
                            // File was deleted on remote server
                            logger.warning("OmFileManager: Remote file deleted \(key).")
                            statistics.remoteDeleted += 1
                            entry.value = nil
                        }
                        // Remove data from local cache
                        // Keep blocks that have been accessed less than 60 seconds ago, because they still could be used
                        // If they are deleted, the cache might immediately write new data into the cached slot
                        let deletedBlocks = old.fn.deleteCachedBlocks(olderThanSeconds: 60)
                        if deletedBlocks > 0 {
                            logger.warning("OmFileManager: \(deletedBlocks) blocks have been deleted")
                        }
                    }
                } else {
                    // Check if a remote file is now available on the remote server
                    let revalidateSeconds = key.revalidateEverySeconds(modificationTime: nil, now: now)
                    if entry.lastValidated < now.subtract(seconds: revalidateSeconds) {
                        entry.lastValidated = .now()
                        statistics.remoteCheckedExist += 1
                        if let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile) {
                            statistics.remoteModified += 1
                            guard let reader = try await new.asRemoteReader() else {
                                entry.value = nil
                                continue
                            }
                            entry.value = reader
                        }
                    }
                }
            }
        }
        if statistics.ticks.isMultiple(of: 10), total > 0 {
            logger.warning("OmFileManager: \(total) open files, \(running) running. Revalidation took \(startRevalidation.timeElapsedPretty()). \(statistics)")
            if OpenMeteo.remoteDataDirectory != nil {
                logger.warning("\(OpenMeteo.dataBlockCache.cache.statistics().prettyPrint)")
            }
            statistics.reset()
        }
    }
}

extension OmHttpReaderBackend {
    func asBlockCached() -> OmReaderBlockCache<OmHttpReaderBackend, MmapFile> {
        return OmReaderBlockCache(backend: self, cache: OpenMeteo.dataBlockCache, cacheKey: self.cacheKey)
    }
    func asRemoteReader() async throws -> OmFileLocalOrRemote? {
        return try await asBlockCached().asCachedReader()?.asRemoteReader()
    }
}

extension OmReaderBlockCache<OmHttpReaderBackend, MmapFile> {
    func asCachedReader() async throws -> OmFileReader<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>>? {
        do {
            return try await OmFileReader(fn: self)
        } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
            print("[ ERROR ] Not an OpenMeteo file \(self.backend.url)")
            return nil
        }
    }
}

extension OmFileReader<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>> {
    func asRemoteReader() async throws -> OmFileLocalOrRemote? {
        guard let arrayReader = self.asArray(of: Float.self) else {
            return nil
        }
        if let times = try await self.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init) {
            return .remote(arrayReader, timestamps: times)
        }
        return .remote(arrayReader, timestamps: nil)
    }
}


extension OmFileReader {
    func getChild(name: String) async throws -> Self? {
        for i in 0..<numberOfChildren {
            if let child = try await getChild(i), child.getName() == name {
                return child
            }
        }
        return nil
    }
}
