import Foundation

/// Result storage: callers must release owned buffers and must never release borrowed cache memory.
enum DataOwnership: Sendable {
    /// Only usable for a short time. Must not be freed.
    case borrowed(UnsafeRawBufferPointer)

    /// The caller owns this allocation and must call `deallocate()` exactly once after use.
    case owned(UnsafeRawBufferPointer)
}

/// Coordinates backend concurrency, shared block fetches, and result assembly for an atomic cache.
/// `OmReaderBlockCache` handles file byte ranges, contiguous cache hits, and cached-page advice.
/// This actor receives explicit ranges, deadlines, and providers; it does not depend on a reader
/// instance. It owns the super-block size and cache-key calculation used by both paths.
///
/// Each missing block is reserved before work starts, so overlapping reads share the same fetch.
/// `get` registers all ranges in one actor call before waiting, allowing independent gaps and super
/// blocks to fetch concurrently with one request and continuation. Its provider uses absolute file
/// block indices; internal jobs and the single-super-block `prefetch` entry point use cache keys.
/// Providers fetch whole blocks and clip the final block at EOF.
///
/// Up to 4 jobs run concurrently by default; another 16,384 may queue. Readers compute an absolute
/// deadline as request time plus `allowedWait`. Free slots start immediately; queued jobs run by
/// earliest deadline, without a timeout or guaranteed start time. Joining readers can advance a
/// deadline, and equal deadlines have no guaranteed ordering. Workers reuse their task and slot
/// while draining the queue. Limits count jobs, regardless of block counts or subscriber counts.
///
/// Queued ranges can expand or merge within the same super block, retaining all subscribers and
/// the earliest deadline. Requesting block 3 can join queued ranges 1–2 and 4–5 into one fetch of
/// 1–5. Providers must accept expansion in either direction. Cached blocks separate fetches, and
/// running jobs cannot expand. A full queue rejects new entries with `pendingQueueFull`, while
/// sharing or extending existing jobs remains possible.
///
/// A read within one super block borrows cache storage when its delivered bytes are contiguous,
/// including after a miss; otherwise it copies into owned storage. Reads crossing super blocks
/// allocate once up front. Owned results are 32-byte aligned and must be deallocated by the caller.
/// Borrowed slices may have arbitrary alignment and must never be freed. Prefetches allocate no
/// result buffer and return after scheduling; mixed ranges advise only the requested cached pages.
///
/// The first read error disables late writes, frees owned storage, and resumes the caller. Shared
/// work continues for other subscribers. Cancellation also leaves shared work running and is checked
/// before returning a completed result. Background backend failures reach only joined readers.
///
/// Cache storage is deliberately unpinned: eviction can change borrowed bytes, including during a
/// copy. Owned results are independent after copying. The production cache is large enough that
/// reuse during a read is not expected under normal load; small caches or heavy eviction can expose
/// this accepted performance tradeoff.
public final actor AtomicCacheCoordinator<Backend: AtomicBlockCacheStorable> {
    typealias Key = UInt64

    public nonisolated let cache: AtomicBlockCache<Backend>
    private let maxConcurrentFetches: Int
    private let maxPendingFetches: Int
    private var activeFetches = 0
    
    /// Fetch consecutive cache keys, returning full blocks except for a possible short final block at EOF.
    /// `get` receives a provider using absolute file block indices; scheduler closures translate cache keys.
    /// A queued job may expand in either direction within its super block, beyond the original request.
    typealias FetchProvider = @Sendable (_ key: Key, _ count: Int) async throws -> any ContiguousBytes & Sendable

    /// Assembles one read on the actor. Single ranges borrow until a noncontiguous block arrives;
    /// reads across super blocks start with an allocation. Waiters identify byte positions, not cache keys.
    private final class ReadRequest {
        let byteRange: Range<Int>
        let continuation: CheckedContinuation<DataOwnership, Error>
        // The extra completion keeps cached deliveries from finishing during registration.
        var pendingCompletions = 1
        private enum ReadStorage {
            // Borrowed spans may begin after the start of the result until earlier blocks arrive.
            case borrowed(UnsafeRawBufferPointer, offset: Int)
            // Keep capacity in the buffer and the delivered extent separately for partial final blocks.
            case owned(UnsafeMutableRawBufferPointer, receivedEnd: Int)
        }
        private var storage: ReadStorage?

        /// Create a request for bytes relative to the first requested block. `allocate` reserves the
        /// final output immediately; otherwise the request borrows until noncontiguous data arrives.
        /// The initial completion sentinel must be released after all blocks have been registered.
        init(byteRange: Range<Int>, allocate: Bool, continuation: CheckedContinuation<DataOwnership, Error>) {
            self.byteRange = byteRange
            self.continuation = continuation
            if allocate {
                storage = .owned(.allocate(byteCount: byteRange.count, alignment: 32), receivedEnd: 0) // 32-byte alignment for 256-bit SIMD.
            }
        }

        /// Deliver one registered block at its byte offset in the untrimmed result, in any order.
        /// Clip to `byteRange`, retain linear cache storage or copy into owned storage, then account
        /// for the delivery. Failed or completed requests ignore late results without accessing memory.
        /// Borrowing is O(1); copying is proportional to the bytes copied, including a retained span
        /// when switching from borrowed to owned storage.
        func receive(offset: Int, with result: Result<UnsafeRawBufferPointer, Error>) {
            guard pendingCompletions > 0 else { return }
            switch result {
            case .success(let bytes):
                let requested = byteRange.clamped(to: offset..<(offset + bytes.count))
                if !requested.isEmpty {
                    let source = UnsafeRawBufferPointer(rebasing: bytes[(requested.lowerBound - offset)..<(requested.upperBound - offset)])
                    let destinationOffset = requested.lowerBound - byteRange.lowerBound
                    switch storage {
                    case .borrowed(let previous, let borrowedOffset)?:
                        // Completion order may differ from block order. Compare actual addresses,
                        // extending the borrowed span in either direction when they are linear.
                        // Gaps are still pending; later deliveries fill them before completion.
                        if previous.baseAddress!.distance(to: source.baseAddress!) == destinationOffset - borrowedOffset {
                            let start = min(borrowedOffset, destinationOffset)
                            let end = max(borrowedOffset + previous.count, destinationOffset + source.count)
                            storage = .borrowed(UnsafeRawBufferPointer(start: start == borrowedOffset ? previous.baseAddress! : source.baseAddress!, count: end - start), offset: start)
                        } else {
                            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: byteRange.count, alignment: 32) // 32-byte alignment for 256-bit SIMD.
                            previous.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: buffer[borrowedOffset..<(borrowedOffset + previous.count)]))
                            storage = .owned(buffer, receivedEnd: borrowedOffset + previous.count)
                        }
                    case nil:
                        storage = .borrowed(source, offset: destinationOffset)
                    case .owned?:
                        break
                    }
                    if case .owned(let output, let receivedEnd)? = storage {
                        source.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: output[destinationOffset..<(destinationOffset + source.count)]))
                        storage = .owned(output, receivedEnd: max(receivedEnd, destinationOffset + source.count))
                    }
                }
                completeOne()
            case .failure(let error):
                fail(error)
            }
        }

        /// Resume with the first error and release owned storage. Subsequent deliveries are ignored;
        /// shared fetches and other readers are unaffected. O(1), excluding allocator work.
        func fail(_ error: Error) {
            guard pendingCompletions > 0 else { return }
            // Disable late deliveries before freeing storage or resuming the caller.
            pendingCompletions = -1
            if case .owned(let buffer, _)? = storage { buffer.deallocate() }
            storage = nil
            continuation.resume(throwing: error)
        }

        /// Account for a delivery or release the registration sentinel. The last completion transfers
        /// ownership to the caller; a failed request cannot resume again. O(1).
        func completeOne() {
            guard pendingCompletions > 0 else { return }
            pendingCompletions -= 1
            guard pendingCompletions == 0 else { return }
            let result: DataOwnership
            switch storage {
            case .owned(let buffer, let receivedEnd)?:
                result = .owned(UnsafeRawBufferPointer(start: buffer.baseAddress, count: receivedEnd))
            case .borrowed(let buffer, _)?:
                result = .borrowed(buffer)
            case nil:
                result = .borrowed(UnsafeRawBufferPointer(start: nil, count: 0))
            }
            storage = nil // Transfer ownership to the caller.
            continuation.resume(returning: result)
        }
    }

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
        // Store the byte position in the assembled result, independent of cache keys.
        private var firstWaiter: (request: ReadRequest, offset: Int)?
        private var additionalWaiters: [(request: ReadRequest, offset: Int)] = []

        /// Reserve a block with an optional first subscriber, avoiding an array allocation for one reader.
        init(status: Status, firstWaiter: (request: ReadRequest, offset: Int)? = nil) {
            self.status = status
            self.firstWaiter = firstWaiter
        }

        /// Number of registered subscribers, including requests that failed on another block. O(1).
        var waiterCount: Int {
            (firstWaiter == nil ? 0 : 1) + additionalWaiters.count
        }

        /// Append a subscriber at its byte offset in the request's untrimmed result. Amortized O(1);
        /// the first subscriber is inline, while additional subscribers share an array allocation.
        // Mutate through the dictionary subscript without looking up the block again.
        mutating func addWaiter(_ request: ReadRequest, offset: Int) {
            if firstWaiter == nil {
                firstWaiter = (request, offset)
            } else {
                additionalWaiters.append((request, offset))
            }
        }

        /// Deliver the block result to all subscribers after removing its reservation. O(W) deliveries
        /// for W subscribers, plus any bytes they copy; failed requests ignore the result.
        func complete(with result: Result<UnsafeRawBufferPointer, Error>) {
            if let firstWaiter {
                firstWaiter.request.receive(offset: firstWaiter.offset, with: result)
            }
            for waiter in additionalWaiters {
                waiter.request.receive(offset: waiter.offset, with: result)
            }
        }
    }

    /// One entry per queued or running block. Completion removes the entry and resumes its readers.
    private var blockStates: [Key: BlockFetchState] = [:]
    private var queuedFetches = KeyedPriorityQueue<Key, ContinuousClock.Instant, FetchJob>()

    /// Number of waiting backend jobs, excluding running jobs and individual block subscribers. O(1).
    var queuedFetchCount: Int { queuedFetches.count }

    public enum CacheCoordinatorError: Error {
        /// A new job cannot be queued; previously scheduled work is retained.
        case pendingQueueFull
    }

    // Jobs own backend metadata; per-block waiters live exclusively in blockStates.
    private final class FetchJob {
        // Heap identity stays fixed when prepending blocks changes startKey.
        let queueKey: Key
        let superBlockKey: Key
        var startKey: Key
        var blockCount: Int
        let provider: FetchProvider

        /// Create a queued range whose stable queue identity initially equals its first cache key.
        /// `superBlockKey` limits merging; `provider` must support expansion within that group. O(1).
        init(queueKey: Key, superBlockKey: Key, blockCount: Int, provider: @escaping FetchProvider) {
            self.queueKey = queueKey
            self.superBlockKey = superBlockKey
            self.startKey = queueKey
            self.blockCount = blockCount
            self.provider = provider
        }
    }

    /// Return the subscriber count for a derived cache block key, or zero without a reservation.
    /// Includes failed requests until their shared backend work finishes. Expected O(1).
    func waiterCount(for key: Key) -> Int {
        blockStates[key]?.waiterCount ?? 0
    }

    /// Coordinate reads against an existing cache. Both limits must be positive and count backend
    /// jobs, not blocks: running jobs use concurrency slots, and waiting jobs use queue capacity.
    /// Defaults are 4 concurrent and 16,384 queued jobs. Construction does not start background work.
    public init(
        cache: AtomicBlockCache<Backend>,
        maxConcurrentFetches: Int = 4,
        maxPendingFetches: Int = 16_384
    ) {
        precondition(maxConcurrentFetches > 0)
        precondition(maxPendingFetches > 0)
        self.cache = cache
        self.maxConcurrentFetches = maxConcurrentFetches
        self.maxPendingFetches = maxPendingFetches
    }

    /// Expand a queued job to cover an adjacent or overlapping range in the same super block.
    /// Optionally remove an absorbed job, preserving its earliest deadline and all block subscribers.
    /// The caller supplies a range covering the absorbed job. Cache-key arithmetic may wrap.
    /// Expected O(R + log Q) for R reassigned block reservations and Q queued jobs; without absorption,
    /// only the O(R) reservation updates are needed. Unchanged reservations are not rewritten.
    private func merge(into fetch: FetchJob, key: Key, count: Int, absorbing other: FetchJob? = nil) {
        // Keys wrap at UInt64.max. Compare nearby offsets as signed distances.
        let start = Int64(bitPattern: fetch.startKey &- key) < 0 ? fetch.startKey : key
        let previousEndOffset = Int(Int64(bitPattern: fetch.startKey &+ UInt64(fetch.blockCount) &- key))
        let end = key &+ UInt64(max(count, previousEndOffset))
        if let other {
            let deadline = queuedFetches.priority(for: other.queueKey)!
            queuedFetches.remove(key: other.queueKey)
            // Keep the earliest deadline across the combined requests.
            queuedFetches.decreasePriority(for: fetch.queueKey, to: deadline)
        }
        // Only update added/absorbed blocks. Changing their job key leaves waiter buffers in place.
        for block in 0..<Int(fetch.startKey &- start) {
            blockStates[start &+ UInt64(block), default: .init(status: .queued(fetch.queueKey))].status = .queued(fetch.queueKey)
        }
        let previousEnd = fetch.startKey &+ UInt64(fetch.blockCount)
        for block in 0..<Int(end &- previousEnd) {
            blockStates[previousEnd &+ UInt64(block), default: .init(status: .queued(fetch.queueKey))].status = .queued(fetch.queueKey)
        }
        fetch.startKey = start
        fetch.blockCount = Int(end &- start)
    }

    /// Use one occupied concurrency slot to fetch, cache, and deliver a range, then drain queued jobs
    /// in deadline order using the same task. All input blocks must already be reserved as running.
    /// Backend failures complete that range's subscribers but do not stop the worker from draining.
    /// Each job costs O(B + W + log Q) bookkeeping for B blocks, W deliveries, and Q queued jobs,
    /// plus backend I/O, cache access, and byte copying. The slot is released when the queue is empty.
    private func run(key: Key, count: Int, provider: @escaping FetchProvider) async {
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
                        let value = UnsafeRawBufferPointer(rebasing: bytes[range])
                        let cached = cache.set(key: key, value: value)
                        // Deliver cache storage so a single-block reader can retain a borrowed pointer.
                        let delivered = UnsafeRawBufferPointer(rebasing: cached[..<value.count])
                        blockStates.removeValue(forKey: key)?.complete(with: .success(delivered))
                    }
                }
            } catch {
                for block in 0..<blockCount {
                    let key = start &+ UInt64(block)
                    blockStates.removeValue(forKey: key)?.complete(with: .failure(error))
                }
            }
            guard let next = queuedFetches.popMin() else { break }
            start = next.startKey
            blockCount = next.blockCount
            fetch = next.provider
            // Starting a job changes only its blocks' status; their waiters stay in place.
            for block in 0..<blockCount {
                let key = start &+ UInt64(block)
                blockStates[key]!.status = .running
            }
        }
    }

    /// Register background work for one super block without waiting for backend completion.
    /// Keys and the provider use cache-block coordinates; `byteRange` is relative to `key` and
    /// restricts advice to the requested pages. Scheduling errors leave earlier work registered.
    /// Uses `schedule`'s bookkeeping costs and allocates no read request or output buffer.
    func prefetch(
        key: Key, count: Int, byteRange: Range<Int>, deadline: ContinuousClock.Instant,
        superBlockKey: Key, provider: @escaping FetchProvider
    ) throws {
        try schedule(key: key, count: count, deadline: deadline, superBlockKey: superBlockKey,
                     provider: provider, request: nil, outputOffset: 0, prefetchByteRange: byteRange)
    }

    /// Number of cache blocks in an 8 MB super block, shared by scheduling and reader fast paths.
    nonisolated var superBlockLength: Int { 8 * 1024 * 1024 / cache.blockSize }

    /// Derive a cache block key from a file-content identity and absolute block index. O(1).
    /// Keys remain consecutive within a super block, with wrapping arithmetic preserving placement.
    nonisolated func calculateCacheKey(fileKey: Key, block: Int) -> Key {
        fileKey.addFnv1aHash(UInt64(block / superBlockLength)) &+ UInt64(block)
    }

    /// Register a nonempty file read before suspending, sharing one request and continuation.
    /// A single super block starts without an allocation and borrows when its cache storage is linear;
    /// reads crossing super-block boundaries allocate the output once before registration.
    /// `fileKey` identifies the file contents; `blockRange` contains absolute file block indices.
    /// The coordinator's `superBlockLength` defines merge boundaries. `provider` accepts absolute file
    /// block indices and counts, and must clip its backend read at EOF. Deliveries retain file order.
    /// `byteRange` is relative to `blockRange.lowerBound`; `deadline` is shared by every scheduled range.
    /// The registration sentinel prevents early completion. Failure disables late writes and releases
    /// owned storage; cancellation after completion also releases any owned result before throwing.
    /// Cost is the sum of scheduling each super block, any required copies, and backend work.
    func get(
        fileKey: Key, blockRange: Range<Int>, byteRange: Range<Int>,
        deadline: ContinuousClock.Instant, provider: @escaping FetchProvider
    ) async throws -> DataOwnership {
        try Task.checkCancellation()
        let result = try await withCheckedThrowingContinuation { continuation in
            let spansSuperBlocks = blockRange.lowerBound / superBlockLength != (blockRange.upperBound - 1) / superBlockLength
            let request = ReadRequest(byteRange: byteRange, allocate: spansSuperBlocks, continuation: continuation)
            do {
                var lowerBound = blockRange.lowerBound
                while lowerBound < blockRange.upperBound {
                    let firstBlock = lowerBound
                    let superBlockStart = firstBlock / superBlockLength * superBlockLength
                    let end = min(blockRange.upperBound, superBlockStart + superBlockLength)
                    let key = calculateCacheKey(fileKey: fileKey, block: firstBlock)
                    try schedule(key: key, count: end - firstBlock, deadline: deadline,
                                 superBlockKey: calculateCacheKey(fileKey: fileKey, block: superBlockStart),
                                 provider: { fetchKey, count in
                        try await provider(UInt64(firstBlock) &+ (fetchKey &- key), count)
                    }, request: request, outputOffset: (firstBlock - blockRange.lowerBound) * cache.blockSize,
                                 prefetchByteRange: 0..<((end - firstBlock) * cache.blockSize))
                    lowerBound = end
                }
            } catch {
                request.fail(error)
            }
            request.completeOne()
        }
        do {
            try Task.checkCancellation()
            return result
        } catch {
            if case .owned(let buffer) = result { buffer.deallocate() }
            throw error
        }
    }

    /// Reserve and schedule missing ranges without suspension. Backend tasks cannot complete any
    /// registrations until this method returns to the actor. Nil requests are background prefetches.
    /// `keyStart` and `superBlockKey` are derived cache keys; `provider` also accepts cache keys.
    /// `count` is nonnegative and the range must stay within one super block. `deadline` orders work.
    /// `outputOffset` locates this range in the request's untrimmed result. For background requests,
    /// `prefetchByteRange` selects advised bytes relative to `keyStart`, clipped to each cached block.
    /// It does not restrict whole-block backend fetches.
    /// Throws on observed cancellation or queue exhaustion; earlier registrations remain intact.
    /// Demand callers must fail their shared request if registration throws.
    /// Expected bookkeeping is O(S + R + H log Q): S scan steps, R reservation/subscriber updates,
    /// H heap mutations, and Q queued jobs. Cached deliveries may also copy bytes. Scanning skips
    /// whole queued ranges, but registration still visits each requested block.
    private func schedule(
        key keyStart: Key,
        count: Int,
        deadline: ContinuousClock.Instant,
        superBlockKey: Key,
        provider: @escaping FetchProvider,
        request: ReadRequest?,
        outputOffset: Int,
        prefetchByteRange: Range<Int>
    ) throws {
        precondition(count >= 0)
        var offset = 0
        while offset < count {
            try Task.checkCancellation()
            let key = keyStart &+ UInt64(offset)
            // Another fetch may have filled this block while this caller awaited the actor or data.
            if let value = cache.get(key: key, count: 1) {
                if let request {
                    request.pendingCompletions += 1
                    request.receive(offset: outputOffset + offset * cache.blockSize, with: .success(value))
                } else {
                    // Advise only the requested bytes within this cached block.
                    let blockStart = offset * cache.blockSize
                    let adviceRange = prefetchByteRange.clamped(to: blockStart..<(blockStart + cache.blockSize))
                    cache.advise(key: key, byteRange: (adviceRange.lowerBound - blockStart)..<(adviceRange.upperBound - blockStart), advice: .willneed)
                }
                offset += 1
                continue
            }
            // Include queued ranges in this scan so overlapping requests also extend their tail.
            var rangeBlockCount = 0
            var candidate: FetchJob?
            // An adjacent queued fetch on the left can absorb this request's missing blocks.
            // Running fetches have fixed ranges; only queued fetches in this super block can grow.
            if case .queued(let leftKey)? = blockStates[key &- 1]?.status, let left = queuedFetches.value(for: leftKey), left.superBlockKey == superBlockKey {
                candidate = left
            }
            scan: while offset + rangeBlockCount < count {
                let nextKey = key &+ UInt64(rangeBlockCount)
                // Stop at cached data rather than fetching it again to bridge a gap.
                guard cache.get(key: nextKey, count: 1) == nil else { break }
                switch blockStates[nextKey]?.status {
                case .running?:
                    // Running work has a fixed range and cannot be absorbed.
                    break scan
                case .queued(let queuedKey)?:
                    let job = queuedFetches.value(for: queuedKey)!
                    guard job.superBlockKey == superBlockKey else { break scan }
                    // Merge as we scan. Multiple block keys may point to the same fetch,
                    // so the identity check prevents merging a fetch into itself.
                    if let selected = candidate {
                        if selected !== job {
                            merge(into: selected, key: job.startKey, count: job.blockCount, absorbing: job)
                        }
                    } else {
                        candidate = job
                    }
                    // All remaining blocks in this queued range are already reserved and missing.
                    // Jump to its end (or the request's end), including when keys wrap at UInt64.max.
                    let remainingBlocks = job.blockCount - Int(nextKey &- job.startKey)
                    rangeBlockCount += min(remainingBlocks, count - offset - rangeBlockCount)
                case nil:
                    rangeBlockCount += 1
                }
            }
            var newStatus: BlockFetchState.Status?
            if rangeBlockCount > 0 {
                // The next queued range can bridge this request to a second job.
                if queuedFetches.count > 0, case .queued(let rightKey)? = blockStates[key &+ UInt64(rangeBlockCount)]?.status, let job = queuedFetches.value(for: rightKey), job.superBlockKey == superBlockKey {
                    if let selected = candidate {
                        if selected !== job {
                            merge(into: selected, key: job.startKey, count: job.blockCount, absorbing: job)
                        }
                    } else {
                        candidate = job
                    }
                }
                if let candidate {
                    merge(into: candidate, key: key, count: rangeBlockCount)
                } else {
                    if activeFetches < maxConcurrentFetches {
                        // Start directly from the range; only queued work needs a FetchJob allocation.
                        newStatus = .running
                        activeFetches += 1
                        Task { [rangeBlockCount] in await run(key: key, count: rangeBlockCount, provider: provider) }
                    } else {
                        // Existing shared/merged jobs bypass this limit because they need no new entry.
                        guard queuedFetches.count < maxPendingFetches else {
                            throw CacheCoordinatorError.pendingQueueFull
                        }
                        let work = FetchJob(queueKey: key, superBlockKey: superBlockKey, blockCount: rangeBlockCount, provider: provider)
                        newStatus = .queued(work.queueKey)
                        queuedFetches.insert(key: work.queueKey, priority: deadline, value: work)
                    }
                }
            }
            // Register every block before suspending, then continue scanning after this range.
            // A running block stops the scan at zero, but still needs this request as a reader.
            if newStatus == nil, queuedFetches.count > 0, case .queued(let queuedKey)? = blockStates[key]?.status {
                queuedFetches.decreasePriority(for: queuedKey, to: deadline)
            }
            let registeredCount = max(rangeBlockCount, 1)
            request?.pendingCompletions += registeredCount
            if let newStatus {
                // Reserve new blocks with their first reader in one dictionary write. This scan
                // never suspends, so the worker cannot start before all reservations are installed.
                for block in 0..<registeredCount {
                    blockStates[key &+ UInt64(block)] = .init(status: newStatus, firstWaiter: request.map { ($0, outputOffset + (offset + block) * cache.blockSize) })
                }
            } else if let request {
                for block in 0..<registeredCount {
                    blockStates[key &+ UInt64(block)]!.addWaiter(request, offset: outputOffset + (offset + block) * cache.blockSize)
                }
            }
            offset += registeredCount
        }
    }
}
