import OmFileFormat
import Foundation
import NIOCore
import Synchronization

public enum OmReaderCacheError: Error {
    case cacheMiss
}

/// Adapts file byte-range reads to a shared `AtomicCacheCoordinator` and its atomic block cache.
/// See `docs/remote-data.md` at the repository root for remote access, caching, and prefetch configuration.
/// `cacheKey` identifies this file's contents and must change when those contents are replaced.
/// Read and prefetch offsets and counts must describe valid ranges within the backend file.
///
/// The reader converts bytes to blocks, preserves partial-block boundaries, and clips backend reads
/// at EOF. It uses the coordinator's super-block size and key calculation so reads, prefetches,
/// active-block tracking, and deletion agree on cache placement. Contiguous cache hits within one
/// super block return directly without an actor hop. Other reads enter the coordinator once, which
/// registers every range before waiting and handles sharing, merging, deadlines, and concurrency.
///
/// `withData` exposes bytes only for the duration of its closure. Linear results may borrow unpinned
/// cache storage; noncontiguous results and reads crossing super blocks use owned storage.
/// `getData` copies borrowed bytes or transfers an owned allocation, while `getByteBuffer` copies
/// into independent storage. Temporary owned buffers are released after use. Borrowed slices have
/// no SIMD alignment guarantee and retain the eviction tradeoff documented by the coordinator.
///
/// Prefetching returns after scheduling; inventory preloading waits for backend deliveries.
/// Prefetch advises cached pages intersecting the requested bytes; preload skips
/// cached blocks without page advice. Backend misses fetch whole blocks. Preloading
/// clips ranges from an older file revision to the current size. Active-block tracking can scale
/// recently accessed ranges for a replacement file. Retired readers delete their cached entries
/// only when their final reference is released.
public final class OmReaderBlockCache<Backend: OmFileReaderBackend, Cache: AtomicBlockCacheStorable>: OmFileReaderBackend, Sendable {
    public let backend: Backend
    private let coordinator: AtomicCacheCoordinator<Cache>
    let cacheKey: UInt64
    private let deleteOnDeinit = Atomic(false)
    
    public typealias DataType = Data
    
    /// Wrap a backend with a shared coordinator. `cacheKey` identifies the file's contents;
    /// use a new identity when replacing the file's contents.
    public init(backend: Backend, cache: AtomicCacheCoordinator<Cache>, cacheKey: UInt64) {
        self.backend = backend
        self.coordinator = cache
        self.cacheKey = cacheKey
    }

    /// Adapt cached reads to the OM reader backend interface without changing this reader's mode.
    public func cachedOnly() -> CachedOnly {
        CachedOnly(reader: self)
    }

    public struct CachedOnly: OmFileReaderBackend {
        // Retain the reader so retirement cannot delete its blocks while this view is in use.
        let reader: OmReaderBlockCache

        public var count: Int { reader.count }

        public func prefetchData(offset: Int, count: Int) async throws {}

        public func getData(offset: Int, count: Int) throws -> Data {
            try reader.fetchCachedOnly(offset: offset, count: count).intoData()
        }

        public func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) throws -> T {
            let result = try reader.fetchCachedOnly(offset: offset, count: count)
            return try result.withUnsafeBytes(fn)
        }
    }

    deinit {
        if deleteOnDeinit.load(ordering: .relaxed) {
            _ = deleteCachedBlocks(olderThanSeconds: 0)
        }
    }

    /// Apply memory advice only to cached pages intersecting the requested file byte range.
    /// Missing blocks, empty ranges, and invalid ranges are ignored; no backend work is scheduled.
    /// Visits each intersecting block and uses the mmap backend's page alignment.
    public func adviseData(offset: Int, count: Int, advice: MmapFile.MAdvice) {
        guard offset >= 0, count > 0, offset <= self.count, count <= self.count - offset else { return }
        let blockSize = coordinator.cache.blockSize
        let dataRange = offset..<(offset + count)
        let blocks = dataRange.divideRoundedUp(divisor: blockSize)
        for block in blocks {
            let blockStart = block * blockSize
            let requested = dataRange.clamped(to: blockStart..<(blockStart + blockSize))
            coordinator.cache.advise(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: block),
                               byteRange: (requested.lowerBound - blockStart)..<(requested.upperBound - blockStart), advice: advice)
        }
    }

    /// Advise cached pages and schedule missing whole blocks for a valid file byte range.
    /// Uses a one-second scheduling allowance, preserving the exact advised bytes across super blocks.
    /// Returns after scheduling; backend failures are not returned. Cancellation or queue exhaustion
    /// may throw after earlier work has already been scheduled. Misses incur coordinator scheduling costs.
    public func prefetchData(offset: Int, count: Int) async throws {
        try await prefetch(byteRange: offset..<(offset + count), allowedWait: .seconds(1))
    }

    /// Prepare a valid absolute file byte range for background fetching. Fully cached linear ranges
    /// receive one page-advice call without an actor hop; mixed ranges are scanned by the coordinator.
    /// `allowedWait` sets queue order, not a timeout. Throws scheduling errors without cancelling work
    /// already registered; backend failures occur in the background. No output buffer is allocated.
    func prefetch(byteRange: Range<Int>, allowedWait: Duration) async throws {
        precondition(byteRange.lowerBound >= 0 && allowedWait >= .zero)
        try Task.checkCancellation()
        guard !byteRange.isEmpty else { return }
        let blockSize = coordinator.cache.blockSize
        let blockRange = byteRange.divideRoundedUp(divisor: blockSize)
        let deadline = ContinuousClock.now.advanced(by: allowedWait)
        let fileSize = backend.count
        for superBlock in blockRange.divideRoundedUp(divisor: coordinator.superBlockLength) {
            try Task.checkCancellation()
            let superBlockStart = superBlock * coordinator.superBlockLength
            let blocks = (superBlockStart..<(superBlockStart + coordinator.superBlockLength)).clamped(to: blockRange)
            let blockStart = blocks.lowerBound * blockSize
            let requested = byteRange.clamped(to: blockStart..<(blocks.upperBound * blockSize))
            let localBytes = (requested.lowerBound - blockStart)..<(requested.upperBound - blockStart)
            let key = coordinator.calculateCacheKey(fileKey: cacheKey, block: blocks.lowerBound)

            if let cached = coordinator.cache.get(key: key, count: UInt64(blocks.count)) {
                let offset = coordinator.cache.data.withMutableUnsafeBytes { UnsafeRawPointer($0.baseAddress!).distance(to: cached.baseAddress!) }
                coordinator.cache.data.prefetchData(offset: offset + localBytes.lowerBound, count: localBytes.count)
                continue
            }
            try await coordinator.prefetch(key: key, count: blocks.count, byteRange: localBytes, deadline: deadline,
                                     superBlockKey: coordinator.calculateCacheKey(fileKey: cacheKey, block: superBlockStart), provider: { [self] fetchKey, count in
                let block = Int(UInt64(blocks.lowerBound) &+ (fetchKey &- key))
                let start = block * blockSize
                return try await backend.getData(offset: start, count: min((block + count) * blockSize, fileSize) - start)
            })
        }
    }

    /// Backend file size in bytes.
    public var count: Int {
        return backend.count
    }
    
    /// Prepare a valid file byte range and borrow contiguous cache hits without an actor hop.
    /// Misses use one actor call to register all ranges and await shared completion. `allowedWait`
    /// controls queue ordering; scheduling, backend, and cancellation errors propagate to the caller.
    /// An owned result is released automatically; borrowed cache storage remains unpinned. Range preparation
    /// is O(1), cache lookup examines the requested blocks, and misses incur coordinator scheduling.
    func fetch(offset: Int, count: Int, allowedWait: Duration = .zero) async throws -> OwnedOrBorrowedBuffer {
        precondition(offset >= 0 && count >= 0 && allowedWait >= .zero)
        try Task.checkCancellation()
        guard count > 0 else { return .borrowed(UnsafeRawBufferPointer(start: nil, count: 0)) }
        let blockSize = coordinator.cache.blockSize
        let blockRange = (offset..<(offset + count)).divideRoundedUp(divisor: blockSize)
        let start = offset - blockRange.lowerBound * blockSize
        let localBytes = start..<(start + count)
        if blockRange.lowerBound / coordinator.superBlockLength == (blockRange.upperBound - 1) / coordinator.superBlockLength,
           let cached = coordinator.cache.get(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: blockRange.lowerBound), count: UInt64(blockRange.count)) {
            return .borrowed(UnsafeRawBufferPointer(rebasing: cached[localBytes]))
        }
        let fileSize = backend.count
        // Backend work retains this reader so retirement cleanup cannot run before its final cache write.
        return try await coordinator.get(fileKey: cacheKey, blockRange: blockRange, byteRange: localBytes,
                                   deadline: .now.advanced(by: allowedWait),
                                   provider: { [self] block, count in
            let start = Int(block) * blockSize
            return try await backend.getData(offset: start, count: min((Int(block) + count) * blockSize, fileSize) - start)
        })
    }

    /// Read cached blocks without scheduling or waiting for backend work. Throws cacheMiss on a miss.
    func fetchCachedOnly(offset: Int, count: Int) throws -> OwnedOrBorrowedBuffer {
        precondition(offset >= 0 && count >= 0)
        try Task.checkCancellation()
        guard count > 0 else { return .borrowed(UnsafeRawBufferPointer(start: nil, count: 0)) }
        let blockSize = coordinator.cache.blockSize
        let blockRange = (offset..<(offset + count)).divideRoundedUp(divisor: blockSize)
        let start = offset - blockRange.lowerBound * blockSize
        if blockRange.lowerBound / coordinator.superBlockLength == (blockRange.upperBound - 1) / coordinator.superBlockLength,
           let cached = coordinator.cache.get(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: blockRange.lowerBound), count: UInt64(blockRange.count)) {
            return .borrowed(UnsafeRawBufferPointer(rebasing: cached[start..<(start + count)]))
        }
        // Copy one block at a time, including noncontiguous cache hits and super-block boundaries.
        // A miss never enters the scheduler or waits for an in-flight fetch.
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 8)
        let owned = OwnedRawBuffer(UnsafeRawBufferPointer(buffer))
        for block in blockRange {
            guard let cached = coordinator.cache.get(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: block), count: 1) else {
                throw OmReaderCacheError.cacheMiss
            }
            let lower = max(offset, block * blockSize)
            let upper = min(offset + count, (block + 1) * blockSize)
            let destination = UnsafeMutableRawBufferPointer(rebasing: buffer[(lower - offset)..<(upper - offset)])
            let source = UnsafeRawBufferPointer(rebasing: cached[(lower - block * blockSize)..<(upper - block * blockSize)])
            destination.copyMemory(from: source)
        }
        return .owned(owned)
    }

    /// Read a valid file byte range and invoke `fn` synchronously with its bytes.
    /// The pointer must not escape `fn`: owned storage is released on return or throw, and borrowed
    /// cache storage remains unpinned. Propagates both read errors and errors thrown by `fn`.
    /// Adds no copy beyond those required by the coordinator.
    public func withData<T: Sendable>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let result = try await fetch(offset: offset, count: count)
        return try result.withUnsafeBytes(fn)
    }

    /// Read into independent NIO storage, copying bytes and automatically releasing temporary allocations.
    public func getByteBuffer(offset: Int, count: Int) async throws -> ByteBuffer {
        let result = try await fetch(offset: offset, count: count)
        return result.withUnsafeBytes { ByteBufferAllocator().buffer(bytes: $0) }
    }

    /// Copy borrowed bytes or transfer an owned allocation into independent Foundation storage.
    public func getData(offset: Int, count: Int) async throws -> Data {
        let result = try await fetch(offset: offset, count: count)
        return result.intoData()
    }
    
    /// Return sorted, coalesced ranges of cached blocks accessed within `maxAgeSeconds`.
    /// Successful lookups refresh their access timestamps. Optionally scale block positions to
    /// `scaledToFileSize` bytes, rounding outward and coalescing overlaps, for preloading a replacement.
    /// Scans every file block; output storage is proportional to the number of active ranges.
    public func listOfActiveBlocks(maxAgeSeconds: UInt, scaledToFileSize: Int? = nil) -> [Range<Int>] {
        let totalCount = self.backend.count
        let blockSize = coordinator.cache.blockSize
        let blocks = 0..<totalCount.divideRoundedUp(divisor: blockSize)
        var activeRanges = [Range<Int>]()
        for block in blocks where coordinator.cache.get(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: block), maxAccessedAgeInSeconds: maxAgeSeconds) != nil {
            if activeRanges.last?.upperBound == block {
                activeRanges[activeRanges.count - 1] = activeRanges.last!.lowerBound..<(block + 1)
            } else {
                activeRanges.append(block..<(block + 1))
            }
        }
        guard let newSize = scaledToFileSize, newSize != totalCount else {
            return activeRanges
        }
        guard totalCount > 0, newSize > 0 else {
            return []
        }
        let newBlockCount = newSize.divideRoundedUp(divisor: blockSize)
        /// Scale a block boundary by the new-to-old file-size ratio, clamped to the new block count.
        /// Full-width multiplication preserves exact rounding without overflowing. O(1).
        func scale(_ block: Int, roundUp: Bool) -> Int {
            let product = UInt(block).multipliedFullWidth(by: UInt(newSize))
            let (quotient, remainder) = UInt(totalCount).dividingFullWidth(product)
            let rounded = quotient + (roundUp && remainder != 0 ? 1 : 0)
            return Int(min(rounded, UInt(newBlockCount)))
        }
        var scaledRanges = [Range<Int>]()
        for range in activeRanges {
            let scaled = scale(range.lowerBound, roundUp: false)..<scale(range.upperBound, roundUp: true)
            guard !scaled.isEmpty else { continue }
            if let last = scaledRanges.last, last.upperBound >= scaled.lowerBound {
                scaledRanges[scaledRanges.count - 1] = last.lowerBound..<max(last.upperBound, scaled.upperBound)
            } else {
                scaledRanges.append(scaled)
            }
        }
        return scaledRanges
    }
    
    /// Count this file's cached blocks regardless of age, without refreshing access timestamps.
    /// Scans file blocks with bounded cache lookups and no allocations. Concurrent eviction or writes
    /// can change the count; this is a snapshot for logging, not a reservation of cache entries.
    public func countCachedBlocks() -> Int {
        var count = 0
        for block in 0..<backend.count.divideRoundedUp(divisor: coordinator.cache.blockSize) {
            if coordinator.cache.contains(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: block)) {
                count += 1
            }
        }
        return count
    }

    /// Remove this file's cached blocks last accessed more than `olderThanSeconds` ago.
    /// Return the number removed. Visits the file's block ranges without fetching data or cancelling
    /// in-flight work; a concurrent fetch may populate the cache again.
    public func deleteCachedBlocks(olderThanSeconds: UInt) -> Int {
        let blockSize = coordinator.cache.blockSize
        let dataRange = 0..<backend.count
        let blocks = dataRange.divideRoundedUp(divisor: blockSize)
        let superBlocks = dataRange.divideRoundedUp(divisor: blockSize * coordinator.superBlockLength)
        var deletedCount = 0
        for superBlock in superBlocks {
            let blocks = (superBlock * coordinator.superBlockLength ..< (superBlock + 1) * coordinator.superBlockLength).clamped(to: blocks)
            deletedCount += coordinator.cache.delete(key: coordinator.calculateCacheKey(fileKey: cacheKey, block: blocks.lowerBound), count: UInt64(blocks.count), olderThanSeconds: olderThanSeconds)
        }
        return deletedCount
    }
    
    /// Mark a replaced or deleted file for cache cleanup when its final reference is released. O(1).
    /// All blocks remain available to live readers and backend jobs until deinit. Ordinary reader
    /// eviction leaves cache contents intact; retirement itself does not delete any blocks.
    public func deleteCachedBlocksOnDeinit() {
        deleteOnDeinit.store(true, ordering: .relaxed)
    }

    /// Preload block ranges with a configurable scheduling allowance (default 10 minutes).
    /// Await all backend deliveries; the allowance controls queue ordering, not a timeout.
    /// Clip old ranges to this file's size and skip cached blocks without page advice. All ranges
    /// are registered before waiting, without allocating or copying an output buffer. Errors propagate
    /// and leave shared fetches running. Loaded blocks remain subject to normal cache eviction.
    /// Returns false without scheduling when the coordinator is too busy or lacks capacity.
    @discardableResult
    public func preloadBlocks(blocks: [Range<Int>], allowedWait: Duration = .seconds(600)) async throws -> Bool {
        let blockSize = coordinator.cache.blockSize
        let fileSize = backend.count
        return try await coordinator.preload(fileKey: cacheKey, blockRanges: blocks, fileSize: fileSize,
                                      deadline: .now.advanced(by: allowedWait), provider: { [self] block, count in
            let start = Int(block) * blockSize
            return try await backend.getData(offset: start, count: min((Int(block) + count) * blockSize, fileSize) - start)
        })
    }
}
