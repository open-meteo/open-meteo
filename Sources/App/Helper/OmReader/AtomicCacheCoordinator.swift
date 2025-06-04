import Foundation

/**
 Coordinate concurrent requests for the same cache key. Make sure cache can be accessed in parallel
 */
struct AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    let cache: AtomicBlockCache<Backend>
    let queue: IsolatedSerialisationQueue<UInt64, UnsafeRawBufferPointer>
    
    init(cache: AtomicBlockCache<Backend>) {
        self.cache = cache
        self.queue = .init()
    }
    
    func get<T: ContiguousBytes & Sendable>(key: UInt64, backendFetch: @Sendable () async throws -> T) async throws -> UnsafeRawBufferPointer {
        if let result = cache.get(key: key) {
            return result
        }
        // Note: Not 100% sure if there could be a race condition between cache check and calling the actor
        return try await queue.get(key: key) {
            let result = try await backendFetch()
            return cache.set(key: key, value: result)
        }
    }
    
    func prefetchData(key: UInt64) {
        cache.prefetch(key: key)
    }
}
