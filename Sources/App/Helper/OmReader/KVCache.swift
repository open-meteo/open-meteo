import Foundation

/**
 Coordinate concurrent requests for the same cache key
 */
final actor KVCacheCoordinator<Backend: BlockCacheStorable> {
    let cache: MmapBlockCache<Backend>
    private var inFlight: [UInt64: [CheckedContinuation<UnsafeRawBufferPointer, any Error>]] = [:]
    
    init(cache: MmapBlockCache<Backend>) {
        self.cache = cache
    }
    
    func get<T: ContiguousBytes & Sendable>(key: UInt64, fn: @Sendable () async throws -> T) async throws -> UnsafeRawBufferPointer {
        if let value = cache.get(key: key) {
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
            cache.set(key: key, value: data)
            let result = cache.get(key: key)!
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .success(result))
            })
            return result
        } catch {
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}
