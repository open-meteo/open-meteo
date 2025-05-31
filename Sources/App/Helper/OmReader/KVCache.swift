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
    
    func with<R, T: ContiguousBytes & Sendable>(key: UInt64, backendFetch: () async throws -> T, callback: @Sendable (UnsafeRawBufferPointer) throws -> (R)) async throws -> R {
        if let ret = try cache.with(key: key, fn: callback) {
            print("Cached data for key \(key)")
            return ret
        }
        guard inFlight[key] == nil else {
            let ptr = try await withCheckedThrowingContinuation { continuation in
                print("Enqueuing request for key \(key)")
                inFlight[key, default: []].append(continuation)
            }
            return try callback(ptr)
        }
        inFlight[key] = []
        do {
            print("Getting data for key \(key)")
            let data = try await backendFetch()
            cache.set(key: key, value: data)
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
