import OmFileFormat
import Vapor
import Synchronization


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
    func with<R, Key: RemoteFileManageable>(file: Key, client: HTTPClient?, logger: Logger, fn: (_ value: Key.Value) async throws -> R) async throws -> R? {
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
    func get<Key: RemoteFileManageable>(file: Key, client: HTTPClient?, logger: Logger, forceNew: Bool = false) async throws -> Key.Value? {
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
    
    /// On cache miss this function is called to create a new reader
    /// If `forceNew` is set, do not use cached meta data
    static fileprivate func open<Key: RemoteFileManageable>(key: Key, client: HTTPClient?, logger: Logger, forceNew: Bool) async throws -> (value: LocalOrRemote?, lastValidated: Timestamp) {
        let localFile = key.getFilePath()
        if FileManager.default.fileExists(atPath: localFile) {
            do {
                let file = try MmapFile(fn: try FileHandle.openFileReading(file: localFile))
                let reader = try await key.makeLocalReader(file: file)
                return (.local(reader), .now())
            } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
                print("[ ERROR ] Not an OpenMeteo file \(localFile)")
                return (nil, .now())
            } catch {
                print("[ ERROR ] Error while opening file \(localFile): \(error.localizedDescription)")
                throw error
            }
        }
        
        guard let client, let remoteFile = key.getRemoteUrl() else {
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
     Check local and remote files for modifications
     Called every second.
     Removes entries that have not been accessed for more than 15 minutes.
     Revalidates local files every minutes.
     Revalidates remote files on demand.
     Does not block the cache manager actor. Gets list of entries to check and validates them outside actor isolation.
     */
    func revalidate(client: HTTPClient, logger: Logger) async throws {
        let startRevalidation = DispatchTime.now()
        let now = Timestamp.now()
        
        // Remove unused entries
        await cache.removeLastAccessed(olderThan: now.subtract(minutes: 15))
        
        // Every minute: Check if local files got added or deleted
        // Local File IO is blocking, therefore we get a list of keys and check it outside actor isolation
        for (key, entry) in await cache.entriesLastValidatedLocal(olderThan: now.subtract(minutes: 1)) {
            if case .local(let local) = entry.value {
                // Local file open. Check if it was deleted
                if local.fn.file.wasDeleted() {
                    OmStatistics.localModified.add(1, ordering: .relaxed)
                    await cache.removeEntry(forKey: key)
                    continue
                }
            } else {
                // Local file is missing, or a remote file is open
                // Check if a file is now available locally
                if FileManager.default.fileExists(atPath: key.key.getFilePath()) {
                    OmStatistics.localModified.add(1, ordering: .relaxed)
                    await cache.removeEntry(forKey: key)
                    continue
                }
            }
            await cache.setEntry(forKey: key, value: entry.with(lastValidatedLocal: now))
        }
        
        /// Update `HttpMetaCache` with latest `lastValidated` timestamps if required
        /// `HttpMetaCache.set` could be blocking, therefore we perform this action outside actor isolation
        for (remoteFile, state) in await cache.activeRemoteFilesToUpdateHttpMeta() {
            /// Update meta cache to also reflect updates in `lastBackendFetchTimestamp`
            try HttpMetaCache.set(url: remoteFile, state: state)
        }
        
        /// Validate open remote files
        for (key, entry) in await cache.activeRemoteFilesToValidate() {
            // Remote file is open
            guard let remoteFile = key.key.getRemoteUrl(), case .remote(let old) = entry.value  else {
                continue
            }
            OmStatistics.remoteRevalidated.add(1, ordering: .relaxed)
            if let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile) {
                guard old.fn.cacheKey != new.cacheKey else {
                    await cache.setEntry(forKey: key, value: entry.with(lastValidated: now))
                    old.fn.backend.lastValidated = now
                    continue // do not update if the existing entry is the same
                }
                OmStatistics.remoteModified.add(1, ordering: .relaxed)
                guard let reader = try await key.key.makeRemoteCaptureNotOmFile(file: new) else {
                    await cache.setEntry(forKey: key, value: entry.with(value: nil, lastValidated: now))
                    continue
                }
                let activeBlocks = old.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
                logger.error("OmFileManager: Remote file modified \(key). \(activeBlocks.count) blocks active in the last 15 minutes")
                if activeBlocks.count > 0 {
                    // TODO: Consider: While we are preloading, another call could fail and we fetch data twice. Solution could be some kind of preload manager
                    let startPreload = DispatchTime.now()
                    try await new.preloadBlocks(blocks: activeBlocks)
                    logger.error("OmFileManager: Preload completed in \(startPreload.timeElapsedPretty())")
                }
                await cache.setEntry(forKey: key, value: entry.with(value: .remote(reader), lastValidated: now))
            } else {
                // File was deleted on remote server
                logger.error("OmFileManager: Remote file deleted \(key).")
                OmStatistics.remoteDeleted.add(1, ordering: .relaxed)
                await cache.setEntry(forKey: key, value: entry.with(value: nil, lastValidated: now))
            }
            // Remove data from local cache
            // Keep blocks that have been accessed less than 60 seconds ago, because they still could be used
            // If they are deleted, the cache might immediately write new data into the cached slot
            let deletedBlocks = old.fn.deleteCachedBlocks(olderThanSeconds: 60)
            if deletedBlocks > 0 {
                logger.error("OmFileManager: \(deletedBlocks) blocks have been deleted")
            }
        }
        
        /// Validate missing remote files
        for (key, entry, remoteFile) in await cache.missingRemoteFilesToValidate() {
            OmStatistics.remoteCheckedExist.add(1, ordering: .relaxed)
            if let new = try await OmHttpReaderBackend.makeRemoteReaderAndCacheMeta(client: client, logger: logger, url: remoteFile),
                let reader = try await key.key.makeRemoteCaptureNotOmFile(file: new)  {
                OmStatistics.remoteModified.add(1, ordering: .relaxed)
                await cache.setEntry(forKey: key, value: entry.with(value: .remote(reader), lastValidated: now))
            } else {
                await cache.setEntry(forKey: key, value: entry.with(lastValidated: now))
            }
        }
        let total = await cache.count()
        if total > 0, OmStatistics.lastPrintUnitTimestampSeconds.load(ordering: .relaxed) < Timestamp.now().subtract(minutes: 1).timeIntervalSince1970 {
            logger.error("OmFileManager: \(total) open files. Revalidation took \(startRevalidation.timeElapsedPretty()). \(OmStatistics.toString())")
            if OpenMeteo.remoteDataDirectory != nil {
                logger.error("\(OpenMeteo.dataBlockCache.cache.statistics().prettyPrint)")
            }
            OmStatistics.reset()
        }
    }
    
    /// Called every second from a life cycle handler on an available thread
    func backgroundTask(application: Application) async throws {
        try await revalidate(client: application.http.client.shared, logger: application.logger)
    }
}


/// Runtime statistics print to the console regularly
/// Could be further improved
enum OmStatistics {
    static let inactivity = Atomic(0)
    static let localModified = Atomic(0)
    static let remoteModified = Atomic(0)
    static let remoteDeleted = Atomic(0)
    static let remoteRevalidated = Atomic(0)
    static let remoteCheckedExist = Atomic(0)
    static let currentlyOpeningFiles = Atomic(0)
    static let currentlyWaitingOnOpeningFiles = Atomic(0)
    static let lastPrintUnitTimestampSeconds = Atomic(0)
    
    static func reset() {
        inactivity.store(0, ordering: .relaxed)
        localModified.store(0, ordering: .relaxed)
        remoteModified.store(0, ordering: .relaxed)
        remoteDeleted.store(0, ordering: .relaxed)
        remoteRevalidated.store(0, ordering: .relaxed)
        remoteCheckedExist.store(0, ordering: .relaxed)
        lastPrintUnitTimestampSeconds.store(Timestamp.now().timeIntervalSince1970, ordering: .relaxed)
    }
    
    static func toString() -> String {
        return "inactivity=\(inactivity.load(ordering: .relaxed)) localModified=\(localModified.load(ordering: .relaxed)) remoteModified=\(remoteModified.load(ordering: .relaxed)) remoteDeleted=\(remoteDeleted.load(ordering: .relaxed)) remoteRevalidated=\(remoteRevalidated.load(ordering: .relaxed)) remoteCheckedExist=\(remoteCheckedExist.load(ordering: .relaxed)) currentlyOpeningFiles=\(currentlyOpeningFiles.load(ordering: .relaxed)) currentlyWaitingOnOpeningFiles=\(currentlyWaitingOnOpeningFiles.load(ordering: .relaxed))"
    }
}

fileprivate enum LocalOrRemote: Sendable {
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
    struct AnyRemoteFileManageable: Sendable, Hashable {
        let key: (any RemoteFileManageable)
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.key.hashValue == rhs.key.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }
    
    struct Entry {
        let value: LocalOrRemote?
        let lastValidated: Timestamp
        let lastValidatedLocal: Timestamp
        let lastAccessed: Timestamp
        
        init(value: LocalOrRemote?, lastValidated: Timestamp = .now(), lastValidatedLocal: Timestamp = .now(), lastAccessed: Timestamp = .now()) {
            self.value = value
            self.lastValidated = lastValidated
            self.lastValidatedLocal = lastValidatedLocal
            self.lastAccessed = lastAccessed
        }
        
        func with(value: LocalOrRemote? = nil, lastValidated: Timestamp? = nil, lastValidatedLocal: Timestamp? = nil, lastAccessed: Timestamp? = nil) -> Self {
            return .init(value: value ?? self.value, lastValidated: lastValidated ?? self.lastValidated, lastValidatedLocal: lastValidatedLocal ?? self.lastValidatedLocal, lastAccessed: lastAccessed ?? self.lastAccessed)
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
    
    private var cache = [AnyRemoteFileManageable: State]()
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get<Key: RemoteFileManageable>(key: Key, client: HTTPClient?, logger: Logger, forceNew: Bool) async throws -> LocalOrRemote? {
        let key = AnyRemoteFileManageable(key: key)
        guard let state = cache[key], !(forceNew == true && state.isCached) else {
            // Value not cached or needs to be refreshed
            cache[key] = .running([])
            do {
                OmStatistics.currentlyOpeningFiles.add(1, ordering: .relaxed)
                let (data, lastValidated) = try await RemoteFileManager.open(key: key.key, client: client, logger: logger, forceNew: forceNew)
                guard case .running(let queued) = cache.updateValue(.cached(.init(value: data, lastValidated: lastValidated)), forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach {
                    $0.resume(with: .success(data))
                }
                OmStatistics.currentlyOpeningFiles.subtract(1, ordering: .relaxed)
                return data
            } catch {
                guard case .running(let queued) = cache.removeValue(forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach({
                    $0.resume(with: .failure(error))
                })
                OmStatistics.currentlyOpeningFiles.subtract(1, ordering: .relaxed)
                throw error
            }
        }
        switch state {
        case .cached(let entry):
            cache[key] = .cached(Entry(value: entry.value, lastValidated: entry.lastValidated, lastValidatedLocal: entry.lastValidatedLocal, lastAccessed: .now()))
            return entry.value
        case .running(let running):
            OmStatistics.currentlyWaitingOnOpeningFiles.add(1, ordering: .relaxed)
            let value = try await withCheckedThrowingContinuation { continuation in
                cache[key] = .running(running + [continuation])
            }
            OmStatistics.currentlyWaitingOnOpeningFiles.subtract(1, ordering: .relaxed)
            return value
        }
    }
    
    /// If a file has not been used for 15 minutes, remove it from cache
    func removeLastAccessed(olderThan: Timestamp) {
        for (key, state) in cache {
            guard case .cached(let entry) = state else {
                continue
            }
            // Evict unused entries after 15 minutes
            if entry.lastAccessed < olderThan {
                OmStatistics.inactivity.add(1, ordering: .relaxed)
                cache.removeValue(forKey: key)
            }
        }
    }
    
    /// Get entries that have not been validated locally for a while
    func entriesLastValidatedLocal(olderThan: Timestamp) -> [(key: AnyRemoteFileManageable, value: Entry)] {
        return cache.compactMap({ (key, state) in
            guard case .cached(let entry) = state else {
                return nil
            }
            return entry.lastValidatedLocal < olderThan ? (key, entry) : nil
        })
    }
    
    /// Open files that need to be revalidated
    func activeRemoteFilesToValidate() -> [(key: AnyRemoteFileManageable, value: Entry)] {
        let now = Timestamp.now()
        return cache.compactMap({ (key, state) in
            guard case .cached(let entry) = state, case .remote(let old) = entry.value else {
                return nil
            }
            let revalidateSeconds = key.key.revalidateEverySeconds(modificationTime: old.fn.backend.lastModifiedTimestamp, now: now)
            let lastValidated = max(entry.lastValidated, old.fn.backend.lastValidated)
            return lastValidated < now.subtract(seconds: revalidateSeconds) ? (key, entry) : nil
        })
    }
    
    /// If the backend was able to fetch data in the meantime, update the local cache
    func activeRemoteFilesToUpdateHttpMeta() -> [(remoteFile: String, state: HttpMetaCache.State)] {
        return cache.compactMap({ (key, state) in
            guard case .cached(let entry) = state, case .remote(let old) = entry.value, let remoteFile = key.key.getRemoteUrl() else {
                return nil
            }
            return old.fn.backend.lastValidated > entry.lastValidated ? (remoteFile, .available(
                lastValidated: old.fn.backend.lastValidated,
                contentLength: old.fn.backend.count,
                lastModified: old.fn.backend.lastModifiedTimestamp,
                eTag: old.fn.backend.eTag
            )) : nil
        })
    }
    
    /// Files to check if they got added to the remote server
    func missingRemoteFilesToValidate() -> [(key: AnyRemoteFileManageable, value: Entry, remoteFile: String)] {
        let now = Timestamp.now()
        return cache.compactMap({ (key, state) in
            guard case .cached(let entry) = state, let remoteFile = key.key.getRemoteUrl(), entry.value == nil else {
                return nil
            }
            // Check if a remote file is now available on the remote server
            let revalidateSeconds = key.key.revalidateEverySeconds(modificationTime: nil, now: now)
            return entry.lastValidated < now.subtract(seconds: revalidateSeconds) ? (key, entry, remoteFile) : nil
        })
    }
    
    func setEntry(forKey key: AnyRemoteFileManageable, value: Entry) {
        return cache[key] = .cached(value)
    }
    
    func removeEntry(forKey key: AnyRemoteFileManageable) {
        cache.removeValue(forKey: key)
    }
    
    func count() -> Int {
        cache.count
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
