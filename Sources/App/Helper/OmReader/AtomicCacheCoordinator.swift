import Foundation

/**
 Coordinate concurrent requests for the same cache key. Make sure cache can be accessed in parallel
 */
struct AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    let cache: AtomicBlockCache<Backend>
    let queue: AtomicCacheCoordinatorQueue
    
    init(cache: AtomicBlockCache<Backend>) {
        self.cache = cache
        self.queue = .init()
    }
    
    func with<R: Sendable, T: ContiguousBytes & Sendable>(key: UInt64, backendFetch: @Sendable () async throws -> T, callback: @Sendable (UnsafeRawBufferPointer) throws -> (R)) async throws -> R {
        if let result = cache.get(key: key) {
            return try callback(result)
        }
        return try await queue.with(key: key, backendFetch: {
            let result = try await backendFetch()
            cache.set(key: key, value: result)
            return result
        }, callback: callback)
    }
    
    func prefetchData(key: UInt64) {
        cache.prefetch(key: key)
    }
}


/**
 Isolate missed cache requests. This prevents parallel requests of the same key to the backend
 */
final actor AtomicCacheCoordinatorQueue {
    private var inFlight: [UInt64: [CheckedContinuation<UnsafeRawBufferPointer, any Error>]] = [:]
    
    func with<R: Sendable, T: ContiguousBytes & Sendable>(key: UInt64, backendFetch: () async throws -> T, callback: @Sendable (UnsafeRawBufferPointer) throws -> (R)) async throws -> R {
        guard inFlight[key] == nil else {
            let ptr = try await withCheckedThrowingContinuation { continuation in
                //print("Enqueuing request for key \(key)")
                inFlight[key, default: []].append(continuation)
            }
            return try callback(ptr)
        }
        inFlight[key] = []
        do {
            //print("Getting data for key \(key)")
            let data = try await backendFetch()
            return try data.withUnsafeBytes({ ptr in
                inFlight.removeValue(forKey: key)?.forEach({
                    $0.resume(with: .success(ptr))
                })
                return try callback(ptr)
            })
        } catch {
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}
