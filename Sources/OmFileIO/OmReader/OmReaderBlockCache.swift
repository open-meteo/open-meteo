import OmFileFormat
import Foundation
import NIOCore

/// Adapts file byte-range reads to a shared `AtomicCacheCoordinator` and its atomic block cache.
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
/// Prefetching and inventory preloading return after scheduling background work. Fully cached linear
/// ranges receive page advice directly; mixed ranges go to the coordinator. WILLNEED advice covers
/// only pages intersecting the requested bytes, while backend misses fetch whole blocks. Preloading
/// clips ranges from an older file revision to the current size. Active-block tracking can scale
/// recently accessed ranges for a replacement file, and deletion removes sufficiently old entries.
public final class OmReaderBlockCache<Backend: OmFileReaderBackend, Cache: AtomicBlockCacheStorable>: OmFileReaderBackend, Sendable {
    public let backend: Backend
    private let coordinator: AtomicCacheCoordinator<Cache>
    let cacheKey: UInt64
    
    public typealias DataType = Data
    
    /// Wrap a backend with a shared coordinator. `cacheKey` identifies the file's contents;
    /// use a new identity when replacing the file's contents.
    public init(backend: Backend, cache: AtomicCacheCoordinator<Cache>, cacheKey: UInt64) {
        self.backend = backend
        self.coordinator = cache
        self.cacheKey = cacheKey
    }
    
    /// Derive this file's block key, preserving the existing wrapping hash and absolute block index. O(1).
    func calculateCacheKey(block: Int) -> UInt64 {
        coordinator.calculateCacheKey(fileKey: cacheKey, block: block)
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
            coordinator.cache.advise(key: calculateCacheKey(block: block),
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
            let key = calculateCacheKey(block: blocks.lowerBound)

            if let cached = coordinator.cache.get(key: key, count: UInt64(blocks.count)) {
                let offset = coordinator.cache.data.withMutableUnsafeBytes { UnsafeRawPointer($0.baseAddress!).distance(to: cached.baseAddress!) }
                coordinator.cache.data.prefetchData(offset: offset + localBytes.lowerBound, count: localBytes.count)
                continue
            }
            try await coordinator.prefetch(key: key, count: blocks.count, byteRange: localBytes, deadline: deadline,
                                     superBlockKey: calculateCacheKey(block: superBlockStart), provider: { [self] fetchKey, count in
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
    /// An owned result must be deallocated; borrowed cache storage remains unpinned. Range preparation
    /// is O(1), cache lookup examines the requested blocks, and misses incur coordinator scheduling.
    func fetch(offset: Int, count: Int, allowedWait: Duration = .zero) async throws -> DataOwnership {
        precondition(offset >= 0 && count >= 0 && allowedWait >= .zero)
        try Task.checkCancellation()
        guard count > 0 else { return .borrowed(UnsafeRawBufferPointer(start: nil, count: 0)) }
        let blockSize = coordinator.cache.blockSize
        let blockRange = (offset..<(offset + count)).divideRoundedUp(divisor: blockSize)
        let start = offset - blockRange.lowerBound * blockSize
        let localBytes = start..<(start + count)
        if blockRange.lowerBound / coordinator.superBlockLength == (blockRange.upperBound - 1) / coordinator.superBlockLength,
           let cached = coordinator.cache.get(key: calculateCacheKey(block: blockRange.lowerBound), count: UInt64(blockRange.count)) {
            return .borrowed(UnsafeRawBufferPointer(rebasing: cached[localBytes]))
        }
        let fileSize = backend.count
        return try await coordinator.get(fileKey: cacheKey, blockRange: blockRange, byteRange: localBytes,
                                   deadline: .now.advanced(by: allowedWait),
                                   provider: { [backend] block, count in
            let start = Int(block) * blockSize
            return try await backend.getData(offset: start, count: min((Int(block) + count) * blockSize, fileSize) - start)
        })
    }

    /// Read a valid file byte range and invoke `fn` synchronously with its bytes.
    /// The pointer must not escape `fn`: owned storage is released on return or throw, and borrowed
    /// cache storage remains unpinned. Propagates both read errors and errors thrown by `fn`.
    /// Adds no copy beyond those required by the coordinator.
    public func withData<T: Sendable>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        switch try await fetch(offset: offset, count: count) {
        case .borrowed(let data):
            return try fn(data)
        case .owned(let data):
            defer { data.deallocate() }
            return try fn(data)
        }
    }
    
    /// Read a valid file byte range into an independent NIO buffer, propagating read errors.
    /// Copies O(count) bytes and releases any temporary owned read storage.
    public func getByteBuffer(offset: Int, count: Int) async throws -> ByteBuffer {
        switch try await fetch(offset: offset, count: count) {
        case .borrowed(let data):
            return ByteBufferAllocator().buffer(bytes: data)
        case .owned(let data):
            let bb = ByteBufferAllocator().buffer(bytes: data)
            data.deallocate()
            return bb
        }
    }
    
    /// Read a valid file byte range into `Data` whose lifetime is independent of the cache.
    /// Copies borrowed bytes in O(count); transfers owned storage to `Data` without another copy.
    /// Propagates scheduling, backend, and cancellation errors.
    public func getData(offset: Int, count: Int) async throws -> Data {
        switch try await fetch(offset: offset, count: count) {
        case .borrowed(let data):
            // Copy data
            return Data(data)
        case .owned(let data):
            // Reuse existing buffer
            let ptr = UnsafeMutableRawPointer(mutating: data.baseAddress!)
            return Data(bytesNoCopy: ptr, count: count, deallocator: .free)
        }
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
        for block in blocks where coordinator.cache.get(key: calculateCacheKey(block: block), maxAccessedAgeInSeconds: maxAgeSeconds) != nil {
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
            deletedCount += coordinator.cache.delete(key: calculateCacheKey(block: blocks.lowerBound), count: UInt64(blocks.count), olderThanSeconds: olderThanSeconds)
        }
        return deletedCount
    }
    
    /// Preload absolute block-index ranges after rotating files, with a 30-second scheduling allowance.
    /// Clamp old ranges to the current file size, skip empty ranges, and clip the final block at EOF.
    /// Cached blocks receive WILLNEED advice for their requested bytes; missing blocks fetch in the
    /// background. The reader splits super blocks; the coordinator shares overlapping work.
    /// Returns after scheduling, not backend completion. Cancellation or queue exhaustion may throw
    /// after earlier ranges have been registered; backend failures are not returned. Work is proportional
    /// to the examined blocks plus coordinator scheduling, without an output-buffer allocation.
    public func preloadBlocks(blocks: [Range<Int>]) async throws {
        let blockSize = coordinator.cache.blockSize
        let totalCount = self.backend.count
        let totalBlockCount = totalCount.divideRoundedUp(divisor: blockSize)
        for range in blocks {
            let range = range.clamped(to: 0..<totalBlockCount)
            guard !range.isEmpty else {
                /// The list of blocks is from an older file revision.
                /// The new file could be smaller and contain fewer blocks.
                continue
            }
            try await prefetch(byteRange: (range.lowerBound * blockSize)..<min(range.upperBound * blockSize, totalCount),
                               allowedWait: .seconds(30))
        }
    }
}
