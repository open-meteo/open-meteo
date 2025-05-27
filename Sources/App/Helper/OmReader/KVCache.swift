import Foundation

/**
 Coordinate concurrent requests for the same cache key
 */
final actor KVCacheCoordinator<Cache: KVCache> {
    let cache: Cache
    private var inFlight: [UInt64: [CheckedContinuation<Data, any Error>]] = [:]
    
    init(cache: Cache) {
        self.cache = cache
    }
    
    func get(key: UInt64, fn: @Sendable () async throws -> Data) async throws -> Data {
        if let value = await cache.get(key: key) {
            return value
        }
        guard inFlight[key] == nil else {
            return try await withCheckedThrowingContinuation { continuation in
                print("Enqueuing request for key \(key)")
                inFlight[key, default: []].append(continuation)
            }
        }
        inFlight[key] = []
        do {
            print("Getting data for key \(key)")
            let data = try await fn()
            await cache.set(key: key, value: data)
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .success(data))
            })
            return data
        } catch {
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}

/**
 A KV cache should provide those functions
 */
protocol KVCache: Sendable {
    func set(key: UInt64, value: Data) async
    func get(key: UInt64) async -> Data?
}

/**
 Simple KV cache using a dicttinaty
 */
final actor SimpleKVCache: KVCache, Sendable {
    var cache: [UInt64: Data] = [:]
    
    func set(key: UInt64, value: Data) {
        print("Storing \(value.count) bytes in cache for key \(key)")
        cache[key] = value
    }
    
    func get(key: UInt64) -> Data? {
        if let value = cache[key] {
            print("Cache HIT for key \(key)")
            return value
        }
        print("Cache MISS for key \(key)")
        return nil
    }
}
