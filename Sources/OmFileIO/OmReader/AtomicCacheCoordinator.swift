import Foundation

/**
 Coordinate concurrent requests for the same cache key. The atomic block cache is accessed in parallel.
 Requests are only isolated if they need to be fetched from the backend
 */
public final actor AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    typealias Key = UInt64
    public nonisolated let cache: AtomicBlockCache<Backend>

    private final class Fetch {
        let key: Key
        let count: Int
        let download: RemotePayloadDownload?
        var speculative = false
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<Data, Error>] = [:]
        var result: Result<Data, Error>?
        init(key: Key, count: Int, download: RemotePayloadDownload?) {
            self.key = key
            self.count = count
            self.download = download
        }
    }
    private var pending: [Key: Fetch] = [:]
    private var speculativeDownloads = 0
    // Speculation may be skipped under pressure; demand is never limited here.
    private let speculativeCapacity: Int

    public init(cache: AtomicBlockCache<Backend>, speculativeCapacity: Int = 4 * 1024) {
        precondition(speculativeCapacity > 0)
        self.speculativeCapacity = speculativeCapacity
        self.cache = cache
    }

    /**
     Fetch a range of keys. If consecutive keys are missing, fetch them in one call from the backend
     E.g. Two 64kb HTTP requests can be combined into a single 128kb request
     */
    nonisolated func get<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        prefetch: Bool = false,
        enqueueOnly: Bool = false,
        provider: @escaping @Sendable (_ key: Key, _ count: Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        /// Check if blocks are already cached
        for i in 0..<count {
            try Task.checkCancellation()
            let key = keyStart &+ UInt64(i)
            guard let value = cache.get(key: key, count: 1) else {
                /// Use actor isolation to ensure data is only fetched once for a given key
                try await getIsolated(key: key, count: count - i, prefetch: prefetch, enqueueOnly: enqueueOnly, provider: provider, dataCallback: dataCallback)
                return
            }
            dataCallback(key, value)
        }
    }

    private func getIsolated<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        prefetch: Bool = false,
        enqueueOnly: Bool = false,
        provider: @escaping @Sendable (Key, Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        /// Loop over keys, check:
        /// 1. if they are cached
        /// 2. if they are being fetched by another thread already
        /// 3. need to be fetched from backend
        var i = 0
        while i < count {
            try RemotePreloadSession.current?.checkActive()
            try Task.checkCancellation()
            let key = keyStart &+ UInt64(i)
            if let value = cache.get(key: key, count: 1) {
                dataCallback(key, value)
                i += 1
                continue
            }
            let fetch: Fetch
            if let existing = pending[key] {
                fetch = existing
            } else {
                if enqueueOnly && speculativeDownloads >= speculativeCapacity { return }
                var length = 1
                while i + length < count {
                    let next = key &+ UInt64(length)
                    if pending[next] != nil || cache.get(key: next, count: 1) != nil { break }
                    length += 1
                }
                let download = prefetch ? RemotePreloadSession.current.flatMap { owner in
                    owner.admission == nil ? nil : RemotePayloadDownload(owner: owner)
                } : nil
                fetch = Fetch(key: key, count: length, download: download)
                fetch.speculative = enqueueOnly
                if enqueueOnly { speculativeDownloads += 1 }
                for offset in 0..<length { pending[key &+ UInt64(offset)] = fetch }
                // The download belongs to all waiters, not to the task that first missed the cache.
                fetch.task = Task { [length] in
                    let result: Result<Data, Error>
                    do {
                        let bytes = try await RemotePreloadSession.$current.withValue(nil) {
                            try await RemotePayloadDownload.$current.withValue(fetch.download) {
                                try await provider(key, length)
                            }
                        }
                        let data = bytes.withUnsafeBytes { Data($0) }
                        guard data.count > (length - 1) * self.cache.blockSize, data.count <= length * self.cache.blockSize else {
                            throw CurlErrorNonRetry.chunkSizeMismatch
                        }
                        result = .success(data)
                    } catch {
                        result = .failure(error)
                    }
                    finish(fetch, result: result)
                }
            }
            if enqueueOnly {
                i += min(fetch.count - Int(key &- fetch.key), count - i)
                continue
            }
            let waiter = UUID()
            let data: Data
            do {
                data = try await withTaskCancellationHandler {
                    try await wait(for: fetch, waiter: waiter, key: key, demand: !prefetch)
                } onCancel: {
                    Task { await self.cancel(waiter: waiter, key: key) }
                }
            } catch is CancellationError where !prefetch && !Task.isCancelled && fetch.download != nil {
                // Demand can arrive while a stopped speculative attempt is completing.
                continue
            }
            try Task.checkCancellation()
            let offset = Int(key &- fetch.key)
            let available = min(fetch.count - offset, count - i)
            data.withUnsafeBytes { bytes in
                for block in 0..<available {
                    let start = (offset + block) * cache.blockSize
                    let end = min(start + cache.blockSize, bytes.count)
                    dataCallback(key &+ UInt64(block), UnsafeRawBufferPointer(rebasing: bytes[start..<end]))
                }
            }
            i += available
        }
    }

    /// Keep registration actor-isolated on Swift 6.3 as well as newer toolchains.
    private func wait(for fetch: Fetch, waiter: UUID, key: Key, demand: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            if let result = fetch.result {
                continuation.resume(with: result)
            } else {
                fetch.waiters[waiter] = continuation
                // Register interest before crossing actors, so another caller's cancellation
                // cannot abandon this fetch while demand promotion is in flight.
                if demand, let download = fetch.download, download.markDemand() {
                    Task { await download.owner.admission?.promote(download) }
                }
                // Cancellation can arrive before this actor-isolated method is entered.
                if Task.isCancelled { cancel(waiter: waiter, key: key) }
            }
        }
    }

    private func finish(_ fetch: Fetch, result: Result<Data, Error>) {
        if fetch.speculative { speculativeDownloads -= 1 }
        // An abandoned download may finish after a replacement was registered for these keys.
        for offset in 0..<fetch.count {
            let key = fetch.key &+ UInt64(offset)
            if pending[key] === fetch { pending.removeValue(forKey: key) }
        }
        if case .success(let data) = result {
            data.withUnsafeBytes { bytes in
                for block in 0..<fetch.count {
                    let start = block * cache.blockSize
                    let end = min(start + cache.blockSize, bytes.count)
                    guard start < end else { continue }
                    _ = cache.set(key: fetch.key &+ UInt64(block), value: UnsafeRawBufferPointer(rebasing: bytes[start..<end]))
                }
            }
        }
        fetch.result = result
        fetch.task = nil
        let waiters = fetch.waiters
        fetch.waiters.removeAll()
        for waiter in waiters.values { waiter.resume(with: result) }
    }

    private func cancel(waiter: UUID, key: Key) {
        guard let fetch = pending[key], let continuation = fetch.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(throwing: CancellationError())
        if fetch.waiters.isEmpty && !fetch.speculative && (fetch.download?.abandonBeforeStart() ?? true) {
            fetch.task?.cancel()
            for offset in 0..<fetch.count {
                let key = fetch.key &+ UInt64(offset)
                if pending[key] === fetch { pending.removeValue(forKey: key) }
            }
        }
    }
}
