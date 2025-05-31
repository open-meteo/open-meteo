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
    
    func with<T: ContiguousBytes & Sendable>(key: UInt64, backendFetch: @Sendable () async throws -> T, callback: (UnsafeRawBufferPointer) -> ()) async throws {
        if cache.with(key: key, fn: callback) {
            return
        }
        guard inFlight[key] == nil else {
            let ptr = try await withCheckedThrowingContinuation { continuation in
                print("Enqueuing request for key \(key)")
                inFlight[key, default: []].append(continuation)
            }
            callback(ptr)
            return
        }
        inFlight[key] = []
        do {
            print("Getting data for key \(key)")
            let data = try await backendFetch()
            cache.set(key: key, value: data)
            data.withUnsafeBytes({ ptr in
                inFlight.removeValue(forKey: key)?.forEach({
                    $0.resume(with: .success(ptr))
                })
                callback(ptr)
            })
            return
        } catch {
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}
