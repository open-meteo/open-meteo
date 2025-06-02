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
    func with<R>(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, fn: (any OmFileReaderAsyncProtocol) async throws -> R) async throws -> R? {
        guard let reader = try await get(file: file, client: client, logger: logger, forceNew: false) else {
            return nil
        }
        do {
            return try await fn(reader)
        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
            guard let reader = try await get(file: file, client: client, logger: logger, forceNew: true) else {
                return nil
            }
            return try await fn(reader)
        }
    }
    
    /// Check if the file is available locally or remotely. `with<R>()` is recommended
    /// Note: If the file is remote, the reader may throw `CurlError.fileModifiedSinceLastDownload` if the file was modified on the remote end
    func get(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, forceNew: Bool = false) async throws -> (any OmFileReaderAsyncProtocol)? {
        guard let backend = try await cache.get(key: file, forceNew: forceNew, provider: {
            return try await file.asOmFileLocalOrRemote(client: client, logger: logger)
        }) else {
            return nil
        }
        return try await backend.toReader()
    }
    
    /// Called every 10 seconds from a life cycle handler on an available thread
    func backgroundTask(application: Application) async throws {
        try await cache.revalidate(client: application.http.client.shared, logger: application.logger)
    }
}

enum OmFileLocalOrRemote {
    case local(MmapFile)
    case remote(OmHttpReaderBackend)
    
    func toReader() async throws -> any OmFileReaderAsyncProtocol {
        switch self {
        case .local(let local):
            return try await OmFileReaderAsync(fn: local)
        case .remote(let remote):
            let cacheFn = OmReaderBlockCache(backend: remote, cache: OpenMeteo.dataBlockCache, cacheKey: remote.cacheKey)
            return try await OmFileReaderAsync(fn: cacheFn)
        }
    }
}

extension OmFileManagerReadable {
    func asOmFileLocalOrRemote(client: HTTPClient, logger: Logger) async throws -> OmFileLocalOrRemote? {
        let file = self.getRelativeFilePath()
        let localFile = "\(OpenMeteo.dataDirectory)\(file)"
        
        if FileManager.default.fileExists(atPath: localFile) {
            return .local(try MmapFile(fn: try FileHandle.openFileReading(file: localFile), mode: .readOnly))
        }
        if let remoteDirectory = OpenMeteo.remoteDataDirectory {
            let remoteFile = "\(remoteDirectory)\(file)"
            if let remote = try await OmHttpReaderBackend(client: client, logger: logger, url: remoteFile) {
                return .remote(remote)
            }
        }
        return nil
    }
}

extension OmFileReaderAsyncProtocol {
    func asArray<OmType: OmFileArrayDataTypeProtocol>(of: OmType.Type) -> (any OmFileReaderAsyncArrayProtocol<OmType>)? {
        return asArray(of: of, io_size_max: 65536, io_size_merge: 512)
    }
}

/**
 KV cache, but a resource is resolved not in parallel
 */
final actor RemoteOmFileManagerCache {
    typealias Key = OmFileManagerReadable
    typealias Value = OmFileLocalOrRemote?
    
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
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get(key: Key, forceNew: Bool, provider: () async throws -> Value) async throws -> Value {
        guard let state = cache[key], !(forceNew == true && state.isCached) else {
            // Value not cached or needs to be refreshed
            cache[key] = .running([])
            do {
                let data = try await provider()
                guard case .running(let queued) = cache.updateValue(.cached(.init(value: data)), forKey: key) else {
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
     Revalidate entries older than 3 minutes
     */
    func revalidate(client: HTTPClient, logger: Logger) async throws {
        print("## In om remote file revalidation")
        let removeLastAccessedThan: Timestamp = .now().subtract(minutes: 15)
        let revalidateAfter: Timestamp = .now().subtract(minutes: 3)
        for (key, state) in cache {
            guard case .cached(let entry) = state else {
                continue
            }
            // Evict unused entries after 15 minutes
            if entry.lastAccessed < removeLastAccessedThan {
                cache.removeValue(forKey: key)
                continue
            }
            
            // Always check if local files got deleted or overwritten
            if case .local(let local) = entry.value, local.file.wasDeleted() {
                cache.removeValue(forKey: key)
                continue
            }
            
            // Always check if a local file is now available
            if entry.value == nil, FileManager.default.fileExists(atPath: key.getFilePath()) {
                cache.removeValue(forKey: key)
                continue
            }
            
            // Revalidate remote files every 3 minutes
            // File may got added, modified or removed
            if let remoteDirectory = OpenMeteo.remoteDataDirectory, entry.lastValidated < revalidateAfter {
                entry.lastValidated = .now()
                let remoteFile = "\(remoteDirectory)\(key.getRelativeFilePath())"
                if let new = try await OmHttpReaderBackend(client: client, logger: logger, url: remoteFile) {
                    if case .remote(let old) = entry.value {
                        guard old.cacheKey != new.cacheKey else {
                            continue // do not update if the existing entry is the same
                        }
                        entry.value = .remote(new)
                    } else {
                        entry.value = .remote(new)
                    }
                } else {
                    entry.value = nil
                }
            }
        }
    }
}
