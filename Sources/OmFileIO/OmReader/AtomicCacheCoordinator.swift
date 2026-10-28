import Foundation

/// Cache hits stay lock-free. Misses share a download and its priority across overlapping ranges.
public final actor AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    typealias Key = UInt64
    public nonisolated let cache: AtomicBlockCache<Backend>

    private final class Fetch {
        let key: Key
        let count: Int
        let job: RemoteDownloadJob
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<Data, Error>] = [:]
        var result: Result<Data, Error>?
        init(key: Key, count: Int, priority: RemoteReadPriority) {
            self.key = key
            self.count = count
            self.job = RemoteDownloadJob(priority: priority)
        }
    }
    private var pending: [Key: Fetch] = [:]

    public init(cache: AtomicBlockCache<Backend>) {
        self.cache = cache
    }

    nonisolated func get<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        priority: RemoteReadPriority = .foreground,
        provider: @escaping @Sendable (_ key: Key, _ count: Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> Void
    ) async throws {
        for i in 0..<count {
            try Task.checkCancellation()
            let key = keyStart &+ UInt64(i)
            guard let value = cache.get(key: key, count: 1) else {
                try await getIsolated(key: key, count: count - i, priority: priority, provider: provider, dataCallback: dataCallback)
                return
            }
            dataCallback(key, value)
        }
    }

    private func getIsolated<T: ContiguousBytes & Sendable>(
        key keyStart: Key,
        count: Int,
        priority: RemoteReadPriority,
        provider: @escaping @Sendable (Key, Int) async throws -> T,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> Void
    ) async throws {
        var i = 0
        while i < count {
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
                var length = 1
                while i + length < count {
                    let next = key &+ UInt64(length)
                    if pending[next] != nil || cache.get(key: next, count: 1) != nil { break }
                    length += 1
                }
                fetch = Fetch(key: key, count: length, priority: priority)
                for offset in 0..<length { pending[key &+ UInt64(offset)] = fetch }
                // The download belongs to all waiters, not to the task that first missed the cache.
                fetch.task = Task {
                    let result: Result<Data, Error>
                    do {
                        let bytes = try await RemoteDownloadJob.$current.withValue(fetch.job) {
                            try await provider(key, length)
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
            let waiter = UUID()
            let data = try await withTaskCancellationHandler {
                // Swift 6.3 does not infer this actor through the cancellation-handler closure.
                // Keep waiter registration isolated with finish and cancel.
                return try await withCheckedThrowingContinuation(isolation: self) { continuation in
                    if let result = fetch.result {
                        continuation.resume(with: result)
                    } else {
                        fetch.waiters[waiter] = continuation
                        if priority == .foreground {
                            let job = fetch.job
                            Task { await job.promote() }
                        }
                    }
                }
            } onCancel: {
                Task { await self.cancel(waiter: waiter, key: key) }
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

    private func finish(_ fetch: Fetch, result: Result<Data, Error>) {
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
        if fetch.waiters.isEmpty {
            fetch.task?.cancel()
            for offset in 0..<fetch.count {
                let key = fetch.key &+ UInt64(offset)
                if pending[key] === fetch { pending.removeValue(forKey: key) }
            }
        }
    }
}
