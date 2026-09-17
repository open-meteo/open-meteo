import Foundation

/**
 Coordinate concurrent requests for the same cache key. The atomic block cache is accessed in parallel.
 Requests are only isolated if they need to be fetched from the backend
 */
public final actor AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    typealias Key = UInt64
    public nonisolated let cache: AtomicBlockCache<Backend>
    private let upstreamFetchExecutor: LimitedConcurrencyExecutor
    private var queue: [Key: [CheckedContinuation<FetchedBlock, any Error>]] = [:]
    
    /// Retain upstream storage only when the grace period prevented insertion.
    private enum FetchedBlock {
        case cached(UnsafeRawBufferPointer)
        case uncached(any ContiguousBytes & Sendable, Range<Int>)

        func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void) {
            switch self {
            case .cached(let bytes):
                body(bytes)
            case .uncached(let storage, let range):
                storage.withUnsafeBytes { body(UnsafeRawBufferPointer(rebasing: $0[range])) }
            }
        }
    }

    public init(cache: AtomicBlockCache<Backend>, maxConcurrentUpstreamFetches: Int = 60) {
        self.cache = cache
        self.upstreamFetchExecutor = LimitedConcurrencyExecutor(maxConcurrency: maxConcurrentUpstreamFetches)
        self.queue = .init()
    }    

    /// Unique fetch operations holding a permit (including retries), or waiting for one.
    /// Callers waiting for the same cache keys are not counted again.
    public func upstreamFetchStatistics() async -> (active: Int, queued: Int) {
        await upstreamFetchExecutor.statistics()
    }
    
    /**
     Fetch a range of keys. If consecutive keys are missing, fetch them in one call from the backend
     E.g. Two 64kb HTTP requests can be combined into a single 128kb request
     */
    nonisolated func get<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        provider: @Sendable (_ key: Key, _ count: Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        /// Check if blocks are already cached
        for i in 0..<count {
            let key = keyStart &+ UInt64(i)
            guard let value = cache.get(key: key, count: 1) else {
                /// Use actor isolation to ensure data is only fetched once for a given key
                try await getIsolated(key: key, count: count - i, provider: provider, dataCallback: dataCallback)
                return
            }
            dataCallback(key, value)
        }
    }
    
    private func getIsolated<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        provider: @Sendable (_ key: Key, _ count: Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        
        /// The start position if a range of keys is fetched from the backend
        var keyFetchStart: Int? = nil
        
        let blockSize = cache.blockSize

        /// Loop over keys, check:
        /// 1. if they are cached
        /// 2. if they are being fetched by another thread already
        /// 3. need to be fetched from backend
        for i in 0..<count {
            let key = (keyStart &+ UInt64(i))
            let cachedValue = cache.get(key: key, count: 1)
            let cached = cachedValue != nil
            let queued = queue[key] != nil
            var queuedValue: FetchedBlock? = nil
            let isLast = i == count-1
            let cachedOrQueued = cached || queued
            
            /// If this is the first missing key, mark this position
            if !cachedOrQueued && keyFetchStart == nil {
                keyFetchStart = i
            }
            
            /// Enqueue all further calls to his key
            if !cachedOrQueued {
                queue[key] = []
            }
            
            /// Someone else requested this data. Wait for it to arrive. This is leaving the current concurrency isolation and all data in `queue` might be different afterwards
            /// The queued call can fail and we need to fail all previously blocked keys
            if queued {
                do {
                    let value = try await withCheckedThrowingContinuation(isolation: self) { continuation in
                        queue[key, default: []].append(continuation)
                    }
                    queuedValue = value
                } catch {
                    // If the queued fetch fails, fail all previously blocked keys
                    if let offset = keyFetchStart {
                        let count = i - offset
                        let fetchStart = keyStart &+ UInt64(offset)
                        for block in 0..<count {
                            let key = fetchStart &+ UInt64(block)
                            queue.removeValue(forKey: key)?.forEach({
                                $0.resume(with: .failure(error))
                            })
                        }
                    }
                    throw error
                }
            }
            
            /// Get data from backend for all prior keys (or if is the last key). Also leaves concurrency isolation.
            if let offset = keyFetchStart, cachedOrQueued || isLast {
                let includeEnd = isLast && !cachedOrQueued
                let count = i - offset + (includeEnd ? 1 : 0)
                let fetchStart = keyStart &+ UInt64(offset)
                do {
                    /// Contains data for all keys in `toFetch`. Needs to be chunked
                    // Keys are already reserved, so duplicates share this fetch even
                    // while it waits for capacity. Hold the permit through all retries
                    // and body collection performed by the provider.
                    let fetched = try await upstreamFetchExecutor.execute {
                        try Task.checkCancellation()
                        return try await provider(fetchStart, count)
                    }
                    fetched.withUnsafeBytes({bytes in
                        let nBlocks = bytes.count.divideRoundedUp(divisor: blockSize)
                        assert(count == nBlocks)
                        for block in 0..<count {
                            let key = fetchStart &+ UInt64(block)
                            let blockRange = block * blockSize ..< min((block + 1) * blockSize, bytes.count)
                            let blockData = UnsafeRawBufferPointer(rebasing: bytes[blockRange])
                            let cachedBlock = cache.set(key: key, value: blockData)
                            queue.removeValue(forKey: key)?.forEach {
                                $0.resume(returning: cachedBlock.map { .cached($0) } ?? .uncached(fetched, blockRange))
                            }
                            dataCallback(key, cachedBlock ?? blockData)
                        }
                    })
                } catch {
                    for block in 0..<count {
                        let key = fetchStart &+ UInt64(block)
                        queue.removeValue(forKey: key)?.forEach({
                            $0.resume(with: .failure(error))
                        })
                    }
                    throw error
                }
                keyFetchStart = nil
            }
            
            if let cachedValue {
                dataCallback(key, cachedValue)
            }

            if let queuedValue {
                queuedValue.withUnsafeBytes { dataCallback(key, $0) }
            }
        }
    }
}
