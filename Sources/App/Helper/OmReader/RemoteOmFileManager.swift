import OmFileFormat
import Vapor

/*protocol OmFileReaderAsyncProvider {
    func asArray<OmType: OmFileArrayDataTypeProtocol>(of: OmType.Type, io_size_max: UInt64, io_size_merge: UInt64) -> any OmFileReaderAsyncArrayProvider
}

protocol OmFileReaderAsyncArrayProvider {
    associatedtype OmType: OmFileArrayDataTypeProtocol
    
    func willNeed(range: [Range<UInt64>]?) async throws
    func read(into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]?, intoCubeDimension: [UInt64]?) async throws
}

extension OmFileReaderAsync: OmFileReaderAsyncProvider {
    func asArray<OmType>(of: OmType.Type, io_size_max: UInt64, io_size_merge: UInt64) -> any OmFileReaderAsyncArrayProvider where OmType : OmFileFormat.OmFileArrayDataTypeProtocol {
        return self.asArray(of: of, io_size_max: io_size_max, io_size_merge: io_size_merge)
    }
}
extension OmFileReaderAsyncArray: OmFileReaderAsyncArrayProvider {
    func read(into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]?, intoCubeDimension: [UInt64]?) async throws {
        return try await self.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
    }
}*/

/**
 Keep track of remote files.
 Store 404 state
 Keep files open
 Reload files on read/willNeed if remote file was modified, retry with new file
 Background check if remote file was modified (every x seconds)
 
 Old file validation:
 - background task every 10 seconds + replace existing -> never ending flood of requests. Last accessed timestamp + evict after 10 minutes?
 - after x seconds do refresh on request -> random latency + needs isolation
 */
final class RemoteOmFileManager: Sendable {
    public static let instance = RemoteOmFileManager()
    
    /// Isolate requests to files
    let cache = RemoteOmFileManagerCache()
    
    func get(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, forceNew: Bool = false) async throws -> OmFileReaderAsync<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>>? {
        guard let backend = try await cache.get(key: file, forceNew: forceNew, provider: {
            try await OmHttpReaderBackend(client: client, logger: logger, url: file.getFilePath())
        }) else {
            return nil
        }
        let cacheFn = OmReaderBlockCache(backend: backend, cache: OpenMeteo.dataBlockCache!, cacheKey: backend.cacheKey)
        return try await OmFileReaderAsync(fn: cacheFn)
    }
    
    public func willNeed(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, range: [Range<UInt64>]? = nil) async throws {
        do {
            let read = try await get(file: file, client: client, logger: logger)!.asArray(of: Float.self)!
            try await read.willNeed(range: range)
        } catch CurlError.fileModifiedSinceLastDownload {
            let read = try await get(file: file, client: client, logger: logger, forceNew: true)!.asArray(of: Float.self)!
            try await read.willNeed(range: range)
        }
    }
    
    public func read(file: OmFileManagerReadable, client: HTTPClient, logger: Logger, into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]? = nil, intoCubeDimension: [UInt64]? = nil) async throws {
        do {
            let read = try await get(file: file, client: client, logger: logger)!.asArray(of: Float.self)!
            try await read.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
        } catch CurlError.fileModifiedSinceLastDownload {
            // File was modified on the remote server
            let read = try await get(file: file, client: client, logger: logger, forceNew: true)!.asArray(of: Float.self)!
            try await read.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
        }
    }
    
    /// Called every 10 seconds from a life cycle handler on an available thread
    @Sendable func backgroundTask(application: Application) async throws {
        try await cache.revalidate(client: application.http.client.shared, logger: application.logger)
    }
}

/**
 KV cache, but a resource is resolved not in parallel
 */
final actor RemoteOmFileManagerCache {
    typealias Key = OmFileManagerReadable
    typealias Value = OmHttpReaderBackend?
    
    final class Entry {
        var value: Value
        var created: Timestamp
        var lastAccessed: Timestamp
        
        init(value: OmHttpReaderBackend?, created: Timestamp = .now(), lastAccessed: Timestamp = .now()) {
            self.value = value
            self.created = created
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
            if entry.lastAccessed < removeLastAccessedThan {
                /// Evict unused entries
                cache.removeValue(forKey: key)
                continue
            }
            if entry.created < revalidateAfter {
                let new = try await OmHttpReaderBackend(client: client, logger: logger, url: key.getFilePath())
                if new != entry.value {
                    entry.value = new
                }
            }
        }
    }
}
