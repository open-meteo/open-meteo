import Foundation

/// Shares reads for an atomic block cache, merging queued ranges and limiting backend concurrency.
/// Cache hits bypass the actor. Missing blocks are reserved before a backend read starts or queues,
/// so readers requesting the same block share its result instead of issuing duplicate reads.
///
/// Up to 16 backend fetches run concurrently by default. When a slot is available, work starts
/// immediately; otherwise it queues by an absolute deadline: request time plus `allowedWait`.
/// A worker picks the earliest deadline when its current fetch finishes. The deadline is an ordering
/// preference, not a timeout, guaranteed start time, or minimum delay. Zero-wait requests usually
/// precede background work, but an older background request takes precedence once its deadline is
/// earlier. A reader joining queued work can advance its deadline, never postpone it. Equal deadlines
/// have no guaranteed ordering. Workers reuse their task and slot while draining queued work.
///
/// Queued ranges can expand in either direction and absorb other queued ranges, provided they share
/// a `superBlockKey`. For example, requesting block 3 joins queued ranges 1–2 and 4–5 into one backend
/// read of 1–5. Overlapping requests can extend a queued range as well. The combined job keeps the
/// earliest deadline and all existing waiters, using one of the original providers for the expanded
/// range. Providers must therefore accept expansion in either direction within their super block.
/// Cached blocks and running ranges stop the scan; running reads cannot grow or be merged.
/// Callers split requests at super-block boundaries before passing them to this coordinator.
///
/// Up to 16,384 fetches may queue by default. A request needing a new job when the queue is full
/// throws `CacheCoordinatorError.pendingQueueFull`; sharing or extending an existing job is still
/// allowed, and merging jobs frees queue entries. Limits count jobs, not blocks or waiting readers.
///
/// Fetched blocks are cached before their waiting readers resume. Each reader receives only its
/// requested blocks, and backend errors propagate to all readers waiting on the failed fetch.
/// Cancelling a reader does not cancel shared work; cancellation is checked when the reader resumes.
///
/// Readers borrow cache memory without pinning or copying it. Eviction can overwrite a block
/// before a resumed reader runs its callback, or while the callback reads it. This risk is accepted
/// for performance: the production cache is sized generously enough that such reuse is not expected
/// under normal real-world load. Small caches or heavy eviction pressure can expose this behavior.
public final actor AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    typealias Key = UInt64

    public nonisolated let cache: AtomicBlockCache<Backend>
    private let maxConcurrentFetches: Int
    private let maxPendingFetches: Int
    private var activeFetches = 0
    
    /// Keeps a block's readers in one place throughout queueing, merging, and execution.
    private struct BlockFetchState {
        enum Status {
            /// Stable heap key of the queued job covering this block.
            case queued(Key)
            /// The backend read has started and its range can no longer grow.
            case running
        }

        var status: Status
        // An entry with no waiters still reserves the block against duplicate reads.
        // Keep the common single-reader case inline; allocate an array only for shared reads.
        private var firstWaiter: CheckedContinuation<UnsafeRawBufferPointer, Error>?
        private var additionalWaiters: [CheckedContinuation<UnsafeRawBufferPointer, Error>] = []

        var waiterCount: Int {
            (firstWaiter == nil ? 0 : 1) + additionalWaiters.count
        }

        // Mutate through the dictionary subscript without looking up the block again.
        mutating func addWaiter(_ continuation: CheckedContinuation<UnsafeRawBufferPointer, Error>) {
            if firstWaiter == nil {
                firstWaiter = continuation
            } else {
                additionalWaiters.append(continuation)
            }
        }

        // Called after removing the block reservation, so each waiter completes exactly once.
        func resume(with result: Result<UnsafeRawBufferPointer, Error>) {
            firstWaiter?.resume(with: result)
            additionalWaiters.forEach { $0.resume(with: result) }
        }
    }

    /// One entry per queued or running block. Completion removes the entry and resumes its readers.
    private var fetches: [Key: BlockFetchState] = [:]
    private var pendingFetches = KeyedPriorityQueue<Key, ContinuousClock.Instant, FetchJob>()

    var queuedFetchCount: Int { pendingFetches.count }

    public enum CacheCoordinatorError: Error {
        case pendingQueueFull
    }

    typealias Provider = @Sendable (_ key: Key, _ count: Int) async throws -> any ContiguousBytes & Sendable

    // Jobs own backend metadata; per-block waiters live exclusively in fetches.
    private final class FetchJob: @unchecked Sendable {
        // Heap identity stays fixed when prepending blocks changes start.
        let key: Key
        let superBlockKey: Key
        var start: Key
        var count: Int
        let provider: Provider

        init(key: Key, superBlockKey: Key, count: Int, provider: @escaping Provider) {
            self.key = key
            self.superBlockKey = superBlockKey
            self.start = key
            self.count = count
            self.provider = provider
        }
    }

    func waiterCount(for key: Key) -> Int {
        fetches[key]?.waiterCount ?? 0
    }

    public init(
        cache: AtomicBlockCache<Backend>,
        maxConcurrentFetches: Int = 16,
        maxPendingFetches: Int = 16_384
    ) {
        precondition(maxConcurrentFetches > 0)
        precondition(maxPendingFetches > 0)
        self.cache = cache
        self.maxConcurrentFetches = maxConcurrentFetches
        self.maxPendingFetches = maxPendingFetches
    }

    private func merge(into fetch: FetchJob, key: Key, count: Int, absorbing other: FetchJob? = nil) {
        // Keys wrap at UInt64.max. Compare nearby offsets as signed distances.
        let start = Int64(bitPattern: fetch.start &- key) < 0 ? fetch.start : key
        let previousEndOffset = Int(Int64(bitPattern: fetch.start &+ UInt64(fetch.count) &- key))
        let end = key &+ UInt64(max(count, previousEndOffset))
        if let other {
            let deadline = pendingFetches.priority(for: other.key)!
            pendingFetches.remove(key: other.key)
            // Keep the earliest deadline across the combined requests.
            pendingFetches.decreasePriority(for: fetch.key, to: deadline)
        }
        // Only update added/absorbed blocks. Changing their job key leaves waiter buffers in place.
        for block in 0..<Int(fetch.start &- start) {
            fetches[start &+ UInt64(block), default: .init(status: .queued(fetch.key))].status = .queued(fetch.key)
        }
        let previousEnd = fetch.start &+ UInt64(fetch.count)
        for block in 0..<Int(end &- previousEnd) {
            fetches[previousEnd &+ UInt64(block), default: .init(status: .queued(fetch.key))].status = .queued(fetch.key)
        }
        fetch.start = start
        fetch.count = Int(end &- start)
    }

    private func run(key: Key, count: Int, provider: @escaping Provider) async {
        defer { activeFetches -= 1 }
        var start = key
        var blockCount = count
        var fetch = provider
        // Reuse this task and its backend slot until the queue is empty.
        while true {
            do {
                let fetched = try await fetch(start, blockCount)
                fetched.withUnsafeBytes { bytes in
                    assert(blockCount == bytes.count.divideRoundedUp(divisor: cache.blockSize))
                    for block in 0..<blockCount {
                        let key = start &+ UInt64(block)
                        let range = block * cache.blockSize ..< min((block + 1) * cache.blockSize, bytes.count)
                        let value = cache.set(key: key, value: UnsafeRawBufferPointer(rebasing: bytes[range]))
                        fetches.removeValue(forKey: key)?.resume(with: .success(value))
                    }
                }
            } catch {
                for block in 0..<blockCount {
                    let key = start &+ UInt64(block)
                    fetches.removeValue(forKey: key)?.resume(with: .failure(error))
                }
            }
            guard let next = pendingFetches.popMin() else { break }
            start = next.start
            blockCount = next.count
            fetch = next.provider
            // Starting a job changes only its blocks' status; their waiters stay in place.
            for block in 0..<blockCount {
                let key = start &+ UInt64(block)
                fetches[key]!.status = .running
            }
        }
    }

    /// Cache hits bypass actor isolation and the backend concurrency limit.
    /// `allowedWait` determines queue order, not a timeout or a delay when capacity is available.
    /// Adjacent queued requests with the same `superBlockKey` share a provider call. Providers must
    /// accept expanded ranges in either direction; callbacks still receive only requested blocks.
    /// Queued work continues if a caller is cancelled; that caller throws when it resumes.
    nonisolated func get(
        key keyStart: Key,
        count: Int,
        allowedWait: Duration,
        superBlockKey: Key,
        provider: @escaping Provider,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        precondition(allowedWait >= .zero)
        let deadline = ContinuousClock.now.advanced(by: allowedWait)
        for i in 0..<count {
            let key = keyStart &+ UInt64(i)
            guard let value = cache.get(key: key, count: 1) else {
                try await getIsolated(key: key, count: count - i, deadline: deadline, superBlockKey: superBlockKey, provider: provider, dataCallback: dataCallback)
                return
            }
            dataCallback(key, value)
        }
    }

    private func getIsolated(
        key keyStart: Key,
        count: Int,
        deadline: ContinuousClock.Instant,
        superBlockKey: Key,
        provider: @escaping Provider,
        dataCallback: @Sendable (Key, UnsafeRawBufferPointer) -> ()
    ) async throws {
        var offset = 0
        while offset < count {
            try Task.checkCancellation()
            let key = keyStart &+ UInt64(offset)
            // Another fetch may have filled this block while this caller awaited the actor or data.
            if let value = cache.get(key: key, count: 1) {
                dataCallback(key, value)
                offset += 1
                continue
            }
            // Include queued ranges in this scan so overlapping requests also extend their tail.
            var fetchCount = 0
            var candidate: FetchJob?
                // An adjacent queued fetch on the left can absorb this request's missing blocks.
                // Running fetches have fixed ranges; only queued fetches in this super block can grow.
                if case .queued(let leftKey)? = fetches[key &- 1]?.status, let left = pendingFetches.value(for: leftKey), left.superBlockKey == superBlockKey {
                    candidate = left
                }
                scan: while offset + fetchCount < count {
                    let nextKey = key &+ UInt64(fetchCount)
                    // Stop at cached data rather than fetching it again to bridge a gap.
                    guard cache.get(key: nextKey, count: 1) == nil else { break }
                    switch fetches[nextKey]?.status {
                    case .running?:
                        // Running work has a fixed range and cannot be absorbed.
                        break scan
                    case .queued(let queuedKey)?:
                        let job = pendingFetches.value(for: queuedKey)!
                        guard job.superBlockKey == superBlockKey else { break scan }
                        // Merge as we scan. Multiple block keys may point to the same fetch,
                        // so the identity check prevents merging a fetch into itself.
                        if let selected = candidate {
                            if selected !== job {
                                merge(into: selected, key: job.start, count: job.count, absorbing: job)
                            }
                        } else {
                            candidate = job
                        }
                        // All remaining blocks in this queued range are already reserved and missing.
                        // Jump to its end (or the request's end), including when keys wrap at UInt64.max.
                        let remainingBlocks = job.count - Int(nextKey &- job.start)
                        fetchCount += min(remainingBlocks, count - offset - fetchCount)
                    case nil:
                        fetchCount += 1
                }
            }
            if fetchCount > 0 {
                // The next queued range can bridge this request to a second job.
                if pendingFetches.count > 0, case .queued(let rightKey)? = fetches[key &+ UInt64(fetchCount)]?.status, let job = pendingFetches.value(for: rightKey), job.superBlockKey == superBlockKey {
                    if let selected = candidate {
                        if selected !== job {
                            merge(into: selected, key: job.start, count: job.count, absorbing: job)
                        }
                    } else {
                        candidate = job
                    }
                }
                if let candidate {
                    merge(into: candidate, key: key, count: fetchCount)
                } else {
                    if activeFetches < maxConcurrentFetches {
                        // Start directly from the range; only queued work needs a FetchJob allocation.
                        for block in 0..<fetchCount {
                            fetches[key &+ UInt64(block)] = .init(status: .running)
                        }
                        activeFetches += 1
                        Task { [fetchCount] in await run(key: key, count: fetchCount, provider: provider) }
                    } else {
                        // Existing shared/merged jobs bypass this limit because they need no new entry.
                        guard pendingFetches.count < maxPendingFetches else {
                            throw CacheCoordinatorError.pendingQueueFull
                        }
                        let work = FetchJob(key: key, superBlockKey: superBlockKey, count: fetchCount, provider: provider)
                        for block in 0..<fetchCount { fetches[key &+ UInt64(block)] = .init(status: .queued(work.key)) }
                        pendingFetches.insert(key: work.key, priority: deadline, value: work)
                    }
                }
            }
            // A more urgent reader can bring a queued fetch forward, never delay it.
            if pendingFetches.count > 0, case .queued(let queuedKey)? = fetches[key]?.status {
                pendingFetches.decreasePriority(for: queuedKey, to: deadline)
            }
            // Register before suspending: the actor cannot run the new worker in between.
            // Every caller waits for its current block, regardless of which caller created the fetch.
            let value = try await withCheckedThrowingContinuation { continuation in
                fetches[key]!.addWaiter(continuation)
            }
            // Cancellation affects this reader only; the shared fetch completes for other readers.
            try Task.checkCancellation()
            dataCallback(key, value)
            // The rest of a combined fetch is now cached and is handled by subsequent iterations.
            offset += 1
        }
    }
}
