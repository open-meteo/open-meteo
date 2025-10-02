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
final class RemoteFileManager: Sendable {
    public static let instance = RemoteFileManager()
    
    /// Isolate requests to files
    private let cache = RemoteFileManagerCache()
    
    /// Execute a closure with a reader. If the remote file was modified during execution, restart the execution
    func with<R, Key: RemoteFileManageable>(file: Key, client: HTTPClient, logger: Logger, fn: (_ value: Key.Value) async throws -> R) async throws -> R? {
        guard let value = try await get(file: file, client: client, logger: logger, forceNew: false) else {
            return nil
        }
        do {
            return try await fn(value)
        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
            guard let value = try await get(file: file, client: client, logger: logger, forceNew: true) else {
                return nil
            }
            return try await fn(value)
        }
    }
    
    /// Check if the file is available locally or remotely.
    /// `with<R>()` is recommended to automatically reload files if they are modified during execution
    /// Note: If the file is remote, the reader may throw `CurlError.fileModifiedSinceLastDownload` if the file was modified on the remote end
    func get<Key: RemoteFileManageable>(file: Key, client: HTTPClient, logger: Logger, forceNew: Bool = false) async throws -> Key.Value? {
        guard let backend = try await cache.get(key: file, client: client, logger: logger, forceNew: forceNew) else {
            return nil
        }
        switch backend {
        case .local(let value):
            guard let value = value as? (any LocalFileRepresentable<Key.Value>) else {
                fatalError("Not cast-able to LocalFileRepresentable")
            }
            return value.cast()
        case .remote(let value):
            guard let value = value as? (any RemoteFileRepresentable<Key.Value>) else {
                fatalError("Not cast-able to RemoteFileRepresentable")
            }
            return value.cast()
        }
    }
    
    /// Called every 10 seconds from a life cycle handler on an available thread
    func backgroundTask(application: Application) async throws {
        try await cache.revalidate(client: application.http.client.shared, logger: application.logger)
    }
}

fileprivate enum LocalOrRemote {
    case local(any LocalFileRepresentable)
    case remote(any RemoteFileRepresentable)
}


fileprivate extension OmHttpReaderBackend {
    /// Create a new remote reader and store in meta cache if the file is available
    static func makeRemoteReaderAndCacheMeta(client: HTTPClient, logger: Logger, url: String) async throws -> OmReaderBlockCache<OmHttpReaderBackend, MmapFile>? {
        guard let reader = try await OmHttpReaderBackend(client: client, logger: logger, url: url) else {
            try HttpMetaCache.set(url: url, state: .missing(lastValidated: .now()))
            return nil
        }
        try HttpMetaCache.set(url: url, state: .available(lastValidated: .now(), contentLength: reader.count, lastModified: reader.lastModifiedTimestamp, eTag: reader.eTag))
        return OmReaderBlockCache(backend: reader, cache: OpenMeteo.dataBlockCache, cacheKey: reader.cacheKey)
    }
}


/**
 KV cache, but a resource is resolved not in parallel
 */
fileprivate final actor RemoteFileManagerCache {
        /// Wrap `any RemoteFileManageable` into a hashable key
    struct AnyRemoteFileManageable: Hashable {
        let key: (any RemoteFileManageable)
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.key.hashValue == rhs.key.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }
    
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
        var value: LocalOrRemote?
        var lastValidated: Timestamp
        var lastAccessed: Timestamp
        
        init(value: LocalOrRemote?, lastValidated: Timestamp = .now(), lastAccessed: Timestamp = .now()) {
            self.value = value
            self.lastValidated = lastValidated
            self.lastAccessed = lastAccessed
        }
    }
    
    enum State {
        /// Value and last accessed timestamp
        case cached(Entry)
        case running([CheckedContinuation<LocalOrRemote?, any Error>])
        
        var isCached: Bool {
            switch self {
            case .cached:
                return true
            case .running:
                return false
            }
        }
    }
    
    var cache = [AnyRemoteFileManageable: State]()
    var statistics: Statistics = .init()
    
    /// On cache miss, create a new reader
    /// If `forceNew` is set, do not use cached meta data
    nonisolated private func open<Key: RemoteFileManageable>(key: Key, client: HTTPClient, logger: Logger, forceNew: Bool) async throws -> (value: LocalOrRemote?, lastValidated: Timestamp) {
        let localFile = key.getFilePath()
        if FileManager.default.fileExists(atPath: localFile) {
            let file = try MmapFile(fn: try FileHandle.openFileReading(file: localFile))
            do {
                let reader = try await key.makeLocalReader(file: file)
                return (.local(reader), .now())
            } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
                print("[ ERROR ] Not an OpenMeteo file \(localFile)")
                return (nil, .now())
            }
        }
        
        guard let remoteFile = key.getRemoteUrl() else {
            return (nil, .now())
        }
        let now = Timestamp.now()
        let cachedFileMeta = forceNew ? HttpMetaCache.State.missing(lastValidated: Timestamp(0)) : HttpMetaCache.get(url: remoteFile)
        switch cachedFileMeta {
        case .missing(let lastValidated):
            let revalidateSeconds = key.revalidateEverySeconds(modificationTime: nil, now: now)
            if lastValidated >= now.subtract(seconds: revalidateSeconds) {
                // safe to assume the file is still missing
                return (nil, lastValidated)
            }
            // need to revalidate
            guard let file = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile), let reader = try await key.makeRemoteCaptureNotOmFile(file: file) else {
                // file is still missing
                return (nil, .now())
            }
            return (.remote(reader), lastValidated)
            
        case .available(let lastValidated, let count, let lastModified, let eTag):
            let reader = OmHttpReaderBackend(client: client, logger: logger, url: remoteFile, count: count, lastModified: lastModified, eTag: eTag, lastValidated: lastValidated)
            let cached = OmReaderBlockCache(backend: reader, cache: OpenMeteo.dataBlockCache, cacheKey: reader.cacheKey)
            let revalidateSeconds = key.revalidateEverySeconds(modificationTime: lastModified, now: now)
            if lastValidated >= now.subtract(seconds: revalidateSeconds) {
                /// Reuse cached meta attributes
                guard let reader = try await key.makeRemoteCaptureNotOmFile(file: cached) else {
                    return (nil, lastValidated)
                }
                return (.remote(reader), lastValidated)
            }
            // need to revalidate
            guard let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile) else {
                return (nil, .now())
            }
            if new.cacheKey != cached.cacheKey {
                let deletedBlocks = cached.deleteCachedBlocks(olderThanSeconds: 60)
                logger.warning("OmFileManager: Opened stale file. New file version available. \(deletedBlocks) previously cached blocks have been deleted")
            }
            guard let reader = try await key.makeRemoteCaptureNotOmFile(file: new) else {
                return (nil, .now())
            }
            return (.remote(reader), .now())
        }
    }
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get<Key: RemoteFileManageable>(key: Key, client: HTTPClient, logger: Logger, forceNew: Bool) async throws -> LocalOrRemote? {
        let key = AnyRemoteFileManageable(key: key)
        guard let state = cache[key], !(forceNew == true && state.isCached) else {
            // Value not cached or needs to be refreshed
            cache[key] = .running([])
            do {
                let (data, lastValidated) = try await open(key: key.key, client: client, logger: logger, forceNew: forceNew)
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
            let key2 = key.key
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
            if case .local(let local) = entry.value, local.fn.file.wasDeleted() {
                statistics.localModified += 1
                cache.removeValue(forKey: key)
                continue
            }
            
            // Always check if a local file is now available
            if entry.value == nil, FileManager.default.fileExists(atPath: key2.getFilePath()) {
                statistics.localModified += 1
                cache.removeValue(forKey: key)
                continue
            }
            
            if let remoteFile = key2.getRemoteUrl() {
                // Remote file is open
                if case .remote(let old) = entry.value {
                    let revalidateSeconds = key2.revalidateEverySeconds(modificationTime: old.fn.backend.lastModifiedTimestamp, now: now)
                    if old.fn.backend.lastValidated > entry.lastValidated {
                        /// Update meta cache to also reflect updates in `lastBackendFetchTimestamp`
                        try HttpMetaCache.set(url: remoteFile, state: .available(lastValidated: old.fn.backend.lastValidated, contentLength: old.fn.backend.count, lastModified: old.fn.backend.lastModifiedTimestamp, eTag: old.fn.backend.eTag))
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
                            let activeBlocks = old.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
                            logger.warning("OmFileManager: Remote file modified \(key). \(activeBlocks.count) blocks active in the last 15 minutes")
                            if activeBlocks.count > 0 {
                                let startPreload = DispatchTime.now()
                                try await new.preloadBlocks(blocks: activeBlocks)
                                logger.warning("OmFileManager: Preload completed in \(startPreload.timeElapsedPretty())")
                            }
                            guard let reader = try await key2.makeRemoteCaptureNotOmFile(file: new) else {
                                entry.value = nil
                                continue
                            }
                            entry.value = .remote(reader)
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
                }
                if entry.value == nil {
                    // Check if a remote file is now available on the remote server
                    let revalidateSeconds = key2.revalidateEverySeconds(modificationTime: nil, now: now)
                    if entry.lastValidated < now.subtract(seconds: revalidateSeconds) {
                        entry.lastValidated = .now()
                        statistics.remoteCheckedExist += 1
                        if let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile), let reader = try await key2.makeRemoteCaptureNotOmFile(file: new)  {
                            statistics.remoteModified += 1
                            entry.value = .remote(reader)
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

fileprivate extension RemoteFileManageable {
    func makeRemoteCaptureNotOmFile(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> (any RemoteFileRepresentable<Value>)? {
        do {
            return try await self.makeRemoteReader(file: file)
        } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
            print("[ ERROR ] Not an OpenMeteo file \(file.backend.url)")
            return nil
        }
    }
}
