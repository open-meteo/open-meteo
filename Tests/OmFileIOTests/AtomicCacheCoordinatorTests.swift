import Foundation
import Synchronization
import OmFileFormat
@testable import OmFileIO
import Testing

// Adapt scheduler fixtures to the production reader entry points. Providers remain expressed in
// blocks so the tests can assert merge boundaries independently of byte-range preparation.
private struct ProviderReaderBackend: OmFileReaderBackend {
    let blockSize: Int
    let provider: @Sendable (UInt64, Int) async throws -> any ContiguousBytes & Sendable
    var count: Int { Int.max }

    func getData(offset: Int, count: Int) async throws -> Data {
        let bytes = try await provider(UInt64(offset / blockSize), count.divideRoundedUp(divisor: blockSize))
        return bytes.withUnsafeBytes { Data($0) }
    }

    func prefetchData(offset: Int, count: Int) async throws {}

    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let data = try await getData(offset: offset, count: count)
        return try data.withUnsafeBytes(fn)
    }
}

// Inspect returned ownership without retaining borrowed pointers beyond this read.
extension AtomicCacheCoordinator {
    nonisolated func get(fileKey: UInt64, byteRange: Range<Int>, allowedWait: Duration = .zero,
                         provider: @escaping FetchProvider) async throws -> OwnedOrBorrowedBuffer {
        let reader = OmReaderBlockCache(backend: ProviderReaderBackend(blockSize: cache.blockSize, provider: provider), cache: self, cacheKey: fileKey)
        return try await reader.fetch(offset: byteRange.lowerBound, count: byteRange.count, allowedWait: allowedWait)
    }

    nonisolated func prefetch(fileKey: UInt64, byteRange: Range<Int>, allowedWait: Duration,
                              provider: @escaping FetchProvider) async throws {
        let reader = OmReaderBlockCache(backend: ProviderReaderBackend(blockSize: cache.blockSize, provider: provider), cache: self, cacheKey: fileKey)
        try await reader.prefetch(byteRange: byteRange, allowedWait: allowedWait)
    }

    // Expected placement also checks compatibility with the original cache format.
    nonisolated func calculateCacheKey(fileKey: UInt64, block: Int) -> UInt64 {
        fileKey.addFnv1aHash(UInt64(block / superBlockLength)) &+ UInt64(block)
    }

    nonisolated func checkRead(
        key: UInt64, count: Int, allowedWait: Duration, fileKey: UInt64,
        provider: @escaping FetchProvider,
        check: @Sendable (UInt64, UnsafeRawBufferPointer) -> Void
    ) async throws {
        let result = try await get(fileKey: fileKey, byteRange: (Int(key) * cache.blockSize)..<((Int(key) + count) * cache.blockSize),
                                   allowedWait: allowedWait, provider: provider)
        result.withUnsafeBytes { bytes in
            for block in 0..<count {
                let range = block * cache.blockSize..<min((block + 1) * cache.blockSize, bytes.count)
                check(key &+ UInt64(block), UnsafeRawBufferPointer(rebasing: bytes[range]))
            }
        }
    }

    func testWaiterCount(forBlock block: UInt64, fileKey: UInt64 = 0) -> Int {
        waiterCount(for: calculateCacheKey(fileKey: fileKey, block: Int(block)))
    }

}

private typealias Coordinator = AtomicCacheCoordinator<MmapFile>

private final class PrefetchStorage: AtomicBlockCacheStorable, Sendable {
    let storage: MmapFile
    let advisedRanges = Mutex<[Range<Int>]>([])

    init(storage: MmapFile) { self.storage = storage }
    var count: Int { storage.count }

    func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withMutableUnsafeBytes(body)
    }

    func prefetchData(offset: Int, count: Int) {
        advisedRanges.withLock { $0.append(offset..<(offset + count)) }
        storage.prefetchData(offset: offset, count: count)
    }

    func adviseData(offset: Int, count: Int, advice: MmapFile.MAdvice) {
        switch advice {
        case .willneed: advisedRanges.withLock { $0.append(offset..<(offset + count)) }
        default: Issue.record("Prefetch must use WILLNEED advice")
        }
        storage.adviseData(offset: offset, count: count, advice: advice)
    }
}

private actor FetchProbe {
    enum Failure: Error { case backend }
    private(set) var started: [UInt64] = []
    private(set) var maximumActive = 0
    private(set) var startedCounts: [Int] = []
    private var completions: [UInt64: CheckedContinuation<Void, Error>] = [:]

    func fetch(key: UInt64, count: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            started.append(key)
            startedCounts.append(count)
            completions[key] = continuation
            maximumActive = max(maximumActive, completions.count)
        }
        return Data((0..<count * 64).map { byte in
            UInt8(truncatingIfNeeded: key &+ UInt64(byte / 64))
        })
    }

    func finish(_ key: UInt64, fail: Bool = false) {
        let continuation = completions.removeValue(forKey: key)
        if fail {
            continuation?.resume(throwing: Failure.backend)
        } else {
            continuation?.resume()
        }
    }
}

private struct GatedReaderBackend: OmFileReaderBackend {
    let count: Int
    let probe: FetchProbe

    func getData(offset: Int, count: Int) async throws -> Data {
        try await probe.fetch(key: UInt64(offset / 64), count: count / 64)
    }

    func prefetchData(offset: Int, count: Int) async throws {}

    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let data = try await getData(offset: offset, count: count)
        return try data.withUnsafeBytes(fn)
    }
}

struct AtomicCacheCoordinatorTests {
    @Test func cacheMetricsTrackQueueingBatchingAndPreloads() async throws {
        let cache = try coordinator(limit: 1, pendingLimit: 2)
        let probe = FetchProbe()
        let initialBytes = OmFileSystemMetrics.blockCacheFetchedBytesTotal.load(ordering: .relaxed)
        let initialMerged = OmFileSystemMetrics.blockCacheMergedBlocksTotal.load(ordering: .relaxed)
        let initialFull = OmFileSystemMetrics.blockCacheQueueFullTotal.load(ordering: .relaxed)
        let initialPreload = OmFileSystemMetrics.blockCachePreloadsBytesTotal.load(ordering: .relaxed)
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started == [100] }
        let left = request(cache, probe, key: 5, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let right = request(cache, probe, key: 7, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 2 }
        // Metrics aggregate all coordinators, including other concurrently running tests.
        #expect(OmFileSystemMetrics.blockCacheFetchesRunning.load(ordering: .relaxed) >= 1)
        #expect(OmFileSystemMetrics.blockCacheFetchesQueued.load(ordering: .relaxed) >= 2)
        let rejected = request(cache, probe, key: 20, allowedWait: .zero)
        await #expect(throws: Coordinator.CacheCoordinatorError.pendingQueueFull) { try await rejected.value }
        #expect(OmFileSystemMetrics.blockCacheQueueFullTotal.load(ordering: .relaxed) >= initialFull + 1)
        let bridge = request(cache, probe, key: 6, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 6) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        #expect(OmFileSystemMetrics.blockCacheFetchesQueued.load(ordering: .relaxed) >= 1)
        await probe.finish(100)
        try await waitUntil { await probe.started == [100, 5] }
        #expect(await probe.startedCounts == [1, 3])
        #expect(OmFileSystemMetrics.blockCacheMergedBlocksTotal.load(ordering: .relaxed) >= initialMerged + 2)
        await probe.finish(5)
        for task in [running, left, right, bridge] { try await task.value }
        #expect(OmFileSystemMetrics.blockCacheFetchedBytesTotal.load(ordering: .relaxed) >= initialBytes + 256)

        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: 100)), cache: cache, cacheKey: 789)
        cache.cache.set(key: cache.calculateCacheKey(fileKey: reader.cacheKey, block: 0), value: Data(repeating: 7, count: 64))
        try await reader.preloadBlocks(blocks: [-2..<4, 9..<10])
        // Preload volume includes the 64 cached bytes, but backend volume adds only the 36-byte tail.
        #expect(OmFileSystemMetrics.blockCachePreloadsBytesTotal.load(ordering: .relaxed) >= initialPreload + 100)
        #expect(OmFileSystemMetrics.blockCacheFetchedBytesTotal.load(ordering: .relaxed) >= initialBytes + 292)
    }

    @Test(arguments: [0, 64, 128])
    func ownedRawBufferTransfersDeliveredBytes(count: Int) throws {
        enum Failure: Error { case expected }
        let allocation = UnsafeMutableRawBufferPointer.allocate(byteCount: 128, alignment: 32)
        allocation.initializeMemory(as: UInt8.self, repeating: 42)
        let owner = OwnedRawBuffer(UnsafeRawBufferPointer(start: allocation.baseAddress, count: count))
        do {
            try owner.withUnsafeBytes { _ in throw Failure.expected }
            Issue.record("Expected the borrowing closure to throw")
        } catch Failure.expected {}
        // A failed borrow leaves the allocation available for ownership transfer.
        let data = owner.intoData()
        #expect(data == Data(repeating: 42, count: count))
        if count > 0 {
            data.withUnsafeBytes { #expect($0.baseAddress == UnsafeRawPointer(allocation.baseAddress)) }
        }
    }

    @Test(arguments: [false, true])
    func readerSchedulesSuperBlocksTogetherAndStopsWritesOnError(fail: Bool) async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let boundary = 8 * 1024 * 1024
        let reader = OmReaderBlockCache(backend: GatedReaderBackend(count: boundary + 64, probe: probe), cache: cache, cacheKey: 123)
        let returned = Mutex(false)
        let task = Task {
            defer { returned.withLock { $0 = true } }
            return try await reader.getData(offset: boundary - 31, count: 62)
        }
        let first = UInt64(boundary / 64 - 1)
        let last = first + 1
        try await waitUntil { await probe.started.count == 2 }
        #expect(Set(await probe.started) == [first, last])
        await probe.finish(last, fail: fail)
        try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: reader.cacheKey, block: Int(last))) == 0 }
        if fail {
            // The shared request disables late writes before freeing its output.
            await #expect(throws: FetchProbe.Failure.self) { try await task.value }
            #expect(returned.withLock { $0 })
            await probe.finish(first)
            try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: reader.cacheKey, block: Int(first))) == 0 }
        } else {
            #expect(!returned.withLock { $0 })
            await probe.finish(first)
            #expect(try await task.value == Data(repeating: 255, count: 31) + Data(repeating: 0, count: 31))
        }
    }

    @Test(arguments: [false, true])
    func fileReadsShareWorkAndCopyInFileOrder(trim: Bool) async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let boundary = cache.superBlockLength
        let blocks = (boundary - 2)..<(boundary + 2)
        let tasks = (0..<2).map { _ in Task {
            let result = try await cache.get(fileKey: 123, byteRange: (blocks.lowerBound * 64 + (trim ? 7 : 0))..<(blocks.upperBound * 64 - (trim ? 7 : 0)),
                                provider: { key, count in
                try await probe.fetch(key: key, count: count)
            })
            switch consume result {
            case .owned(let buffer): return buffer.intoData()
            case .borrowed(let buffer):
                Issue.record("Cross-super-block reads must own their storage")
                return Data(buffer)
            }
        } }
        let firstKey = cache.calculateCacheKey(fileKey: 123, block: blocks.lowerBound)
        let lastKey = cache.calculateCacheKey(fileKey: 123, block: boundary)
        try await waitUntil { await probe.started.count == 2 }
        try await waitUntil { await cache.waiterCount(for: firstKey) == 2 }
        #expect(await cache.waiterCount(for: lastKey) == 2)
        #expect(Set(await probe.started) == [UInt64(blocks.lowerBound), UInt64(boundary)])
        await probe.finish(UInt64(boundary))
        await probe.finish(UInt64(blocks.lowerBound))
        let expected = blocks.reduce(into: Data()) { $0.append(Data(repeating: UInt8(truncatingIfNeeded: $1), count: 64)) }
        for task in tasks {
            let result = try await task.value
            #expect(result == expected.subdata(in: trim ? 7..<249 : 0..<256))
        }
    }

    @Test func fileReadStopsWritingOnRegistrationFailure() async throws {
        // One cache block per super block exercises three boundaries with only three reservations.
        let cache = try coordinator(limit: 1, pendingLimit: 1, blockSize: 8 * 1024 * 1024, blockCount: 4)
        let probe = FetchProbe()
        let task = Task {
            let result = try await cache.get(fileKey: 123, byteRange: cache.cache.blockSize..<(4 * cache.cache.blockSize), provider: { key, count in
                try await probe.fetch(key: key, count: count)
            })
            return result.intoData()
        }
        await #expect(throws: Coordinator.CacheCoordinatorError.pendingQueueFull) { try await task.value }
        try await waitUntil { await probe.started == [1] }
        await probe.finish(1)
        try await waitUntil { await probe.started == [1, 2] }
        await probe.finish(2)
        try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: 123, block: 2)) == 0 }
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test func emptyReadCompletesWithoutFetching() async throws {
        let cache = try coordinator()
        let empty = try await cache.get(fileKey: 123, byteRange: 31..<31, provider: { _, _ in
            Issue.record("Empty ranges must not fetch")
            return Data()
        })
        guard case .borrowed(let bytes) = empty else { Issue.record("Empty file read should borrow"); return }
        #expect(bytes.isEmpty)
    }

    @Test(arguments: [false, true])
    func readCompletesOrFailsBeforeOutstandingWork(fail: Bool) async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        cache.cache.set(key: 2, value: Data(repeating: 2, count: 64))
        let returned = Mutex(false)
        let reader = Task {
            defer { returned.withLock { $0 = true } }
            let result = try await cache.get(fileKey: 0, byteRange: 64..<256, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            })
            switch consume result {
            case .borrowed(let buffer): return Data(buffer)
            case .owned(let buffer):
                Issue.record("Out-of-order linear cache blocks should still be borrowed")
                return buffer.intoData()
            }
        }
        try await waitUntil { await probe.started.count == 2 }
        await probe.finish(3, fail: fail)
        try await waitUntil { await cache.testWaiterCount(forBlock: 3) == 0 }
        if fail {
            // A second failure must not resume the request again.
            await #expect(throws: FetchProbe.Failure.self) { try await reader.value }
            #expect(returned.withLock { $0 })
            await probe.finish(1, fail: true)
            try await waitUntil { await cache.testWaiterCount(forBlock: 1) == 0 }
        } else {
            #expect(!returned.withLock { $0 })
            await probe.finish(1)
            let result = try await reader.value
            #expect(result == Data(repeating: 1, count: 64) + Data(repeating: 2, count: 64) + Data(repeating: 3, count: 64))
        }
    }

    @Test(arguments: [UInt64(10), UInt64(1023)])
    func singleRangeBorrowsLinearStorageAndCopiesAcrossCacheWrap(key: UInt64) async throws {
        let cache = try coordinator()
        let requested = 7..<185
        let expected = Data((0..<192).map { UInt8(truncatingIfNeeded: key + UInt64($0 / 64)) }).subdata(in: requested)
        // Check the miss and then the hit: both should make the same ownership decision.
        for cached in [false, true] {
            let result = try await cache.get(fileKey: 0, byteRange: (Int(key) * 64 + requested.lowerBound)..<(Int(key) * 64 + requested.upperBound), provider: { start, count in
                #expect(!cached)
                return Data((0..<count * 64).map { UInt8(truncatingIfNeeded: start + UInt64($0 / 64)) })
            })
            switch result {
            case .borrowed(let bytes):
                #expect(key == 10)
                let cached = try #require(cache.cache.get(key: key, count: 3))
                #expect(bytes.baseAddress == cached.baseAddress?.advanced(by: requested.lowerBound))
                #expect(Data(bytes) == expected)
            case .owned(let bytes):
                #expect(key == 1023)
                bytes.withUnsafeBytes { #expect(Data($0) == expected) }
            }
        }
    }

    @Test func readerBorrowsSingleBlockAfterAMissAndOnHits() async throws {
        let cache = try coordinator(limit: 1)
        let contents = Data((0..<135).map { UInt8($0 / 64) })
        let reader = OmReaderBlockCache(backend: DataAsClass(data: contents), cache: cache, cacheKey: 123)
        for _ in 0..<2 {
            // Includes a partial final block and a slice inside a complete block.
            for range in [71..<95, 130..<135] {
                try await reader.withData(offset: range.lowerBound, count: range.count) { bytes in
                    let block = range.lowerBound / 64
                    let cached = try #require(cache.cache.get(key: cache.calculateCacheKey(fileKey: reader.cacheKey, block: block), count: 1))
                    #expect(bytes.baseAddress == cached.baseAddress?.advanced(by: range.lowerBound % 64))
                    #expect(Data(bytes) == contents.subdata(in: range))
                }
            }
        }
        for _ in 0..<2 {
            let data = try await reader.getData(offset: 61, count: 74)
            #expect(data == contents.subdata(in: 61..<135))
        }
    }

    @Test func prefetchAndAdviceKeepRequestedByteRanges() async throws {
        let blockSize = 64 * 1024
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let backing = try AtomicBlockCache(file: path, blockSize: blockSize, blockCount: 8)
        let storage = PrefetchStorage(storage: backing.data)
        let cache = AtomicCacheCoordinator(cache: AtomicBlockCache(data: storage, blockSize: blockSize))
        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: blockSize)), cache: cache, cacheKey: 123)
        let cached = cache.cache.set(key: cache.calculateCacheKey(fileKey: reader.cacheKey, block: 0), value: Data(repeating: 7, count: blockSize))
        let physicalStart = storage.withMutableUnsafeBytes { UnsafeRawPointer($0.baseAddress!).distance(to: cached.baseAddress!) }
        let pageSize = Int(getpagesize())
        // Pick an actual mapped page boundary; cache metadata need not be page aligned.
        let boundary = ((physicalStart / pageSize + 1) * pageSize) - physicalStart
        for range in [(boundary + 1)..<(boundary + 18), (boundary - 1)..<(boundary + 1)] {
            storage.advisedRanges.withLock { $0.removeAll() }
            try await reader.prefetchData(offset: range.lowerBound, count: range.count)
            reader.adviseData(offset: range.lowerBound, count: range.count, advice: .willneed)
            let expected = (physicalStart + range.lowerBound)..<(physicalStart + range.upperBound)
            #expect(storage.advisedRanges.withLock { $0 } == [expected, expected])
            let pages = (expected.upperBound - 1) / pageSize - expected.lowerBound / pageSize + 1
            #expect(pages == (range.count == 2 ? 2 : 1))
        }
    }

    @Test func partialPrefetchPreservesEdgesAroundMissingBlock() async throws {
        let blockSize = 64 * 1024
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let backing = try AtomicBlockCache(file: path, blockSize: blockSize, blockCount: 8)
        let storage = PrefetchStorage(storage: backing.data)
        let cache = AtomicCacheCoordinator(cache: AtomicBlockCache(data: storage, blockSize: blockSize))
        for key: UInt64 in [5, 7] {
            cache.cache.set(key: key, value: Data(repeating: UInt8(key), count: blockSize))
        }
        let probe = FetchProbe()
        let range = (blockSize - 6)..<(2 * blockSize + 7)
        try await cache.prefetch(fileKey: 0, byteRange: (5 * blockSize + range.lowerBound)..<(5 * blockSize + range.upperBound), allowedWait: .zero, provider: { key, count in
            _ = try await probe.fetch(key: key, count: count)
            return Data(repeating: 6, count: count * blockSize)
        })
        #expect(storage.advisedRanges.withLock { $0.map(\.count) } == [6, 7])
        try await waitUntil { await probe.started == [6] }
        #expect(await probe.startedCounts == [1])
        await probe.finish(6)
        try await waitUntil { cache.cache.get(key: 6, count: 1) != nil }
        storage.advisedRanges.withLock { $0.removeAll() }
        try await cache.prefetch(fileKey: 0, byteRange: (5 * blockSize + range.lowerBound)..<(5 * blockSize + range.upperBound), allowedWait: .zero, provider: { _, _ in
            Issue.record("The entire range is cached")
            return Data()
        })
        #expect(storage.advisedRanges.withLock { $0.map(\.count) } == [range.count])
    }

    @Test(arguments: [false, true])
    func preloadWaitsForAllBackendDeliveries(failLast: Bool) async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let boundary = cache.superBlockLength
        let reader = OmReaderBlockCache(backend: GatedReaderBackend(count: (boundary + 1) * 64, probe: probe), cache: cache, cacheKey: 456)
        let completed = Mutex(false)
        let preload = Task {
            defer { completed.withLock { $0 = true } }
            try await reader.preloadBlocks(blocks: [1..<2, boundary..<(boundary + 1)])
        }
        // Register both ranges before either provider completes.
        try await waitUntil { await probe.started.count == 2 }
        let firstKey = cache.calculateCacheKey(fileKey: reader.cacheKey, block: 1)
        let lastKey = cache.calculateCacheKey(fileKey: reader.cacheKey, block: boundary)
        #expect(cache.cache.get(key: firstKey, count: 1) == nil)
        #expect(cache.cache.get(key: lastKey, count: 1) == nil)
        #expect(!completed.withLock { $0 })
        await probe.finish(1)
        try await waitUntil { await cache.waiterCount(for: firstKey) == 0 }
        #expect(!completed.withLock { $0 })
        await probe.finish(UInt64(boundary), fail: failLast)
        if failLast {
            await #expect(throws: FetchProbe.Failure.self) { try await preload.value }
        } else {
            try await preload.value
            #expect(cache.cache.get(key: lastKey, count: 1) != nil)
        }
        #expect(cache.cache.get(key: firstKey, count: 1) != nil)
        #expect(completed.withLock { $0 })
    }

    @Test func cachedBlockCountIncludesOldEntriesWithoutRefreshingThem() throws {
        let cache = try coordinator(blockCount: 16)
        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: 8 * 64)), cache: cache, cacheKey: 123)
        let keys = [1, 2, 4].map { cache.calculateCacheKey(fileKey: reader.cacheKey, block: $0) }
        for key in keys { cache.cache.set(key: key, value: Data(repeating: 7, count: 64)) }
        cache.cache.set(key: cache.calculateCacheKey(fileKey: 456, block: 1), value: Data(repeating: 8, count: 64))
        let before = cache.cache.data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            return (0..<cache.cache.blockCount).map { index in
                var entry = entries[index].load(ordering: .relaxed)
                if entry.first == keys[0] { entry.second = 1 } // Committed but very old.
                if entry.first == keys[2] { entry.second &= ~UInt(1) } // Not yet committed.
                entries[index].store(entry, ordering: .relaxed)
                return entry.second
            }
        }
        #expect(reader.countCachedBlocks() == 2)
        let after = cache.cache.data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            return (0..<cache.cache.blockCount).map { entries[$0].load(ordering: .relaxed).second }
        }
        #expect(after == before)
    }

    @Test(arguments: [false, true])
    func onlyRetiredReadersDeleteRecentBlocksOnDeinit(retire: Bool) async throws {
        let cache = try coordinator()
        let boundary = cache.superBlockLength
        let probe = FetchProbe()
        var reader: OmReaderBlockCache<GatedReaderBackend, MmapFile>? = OmReaderBlockCache(
            backend: GatedReaderBackend(count: (boundary + 1) * 64, probe: probe), cache: cache, cacheKey: 123)
        weak var released = reader
        let oldKeys = [1, boundary].map { cache.calculateCacheKey(fileKey: reader!.cacheKey, block: $0) }
        let replacementKey = cache.calculateCacheKey(fileKey: 456, block: boundary)
        for key in oldKeys + [replacementKey] {
            cache.cache.set(key: key, value: Data(repeating: 7, count: 64))
        }
        if retire {
            // Retirement only marks the reader; all entries survive until deinit.
            reader!.deleteCachedBlocksOnDeinit()
        }
        for key in oldKeys { #expect(cache.cache.get(key: key, count: 1) != nil) }
        reader = nil
        #expect(released == nil)
        for key in oldKeys { #expect((cache.cache.get(key: key, count: 1) == nil) == retire) }
        #expect(cache.cache.get(key: replacementKey, count: 1) != nil)
    }

    @Test func retiredReaderWaitsForBackgroundFetchBeforeDeinitCleanup() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        var reader: OmReaderBlockCache<GatedReaderBackend, MmapFile>? = OmReaderBlockCache(
            backend: GatedReaderBackend(count: 128, probe: probe), cache: cache, cacheKey: 123)
        weak var released = reader
        let key = cache.calculateCacheKey(fileKey: reader!.cacheKey, block: 1)
        try await reader!.prefetchData(offset: 64, count: 64)
        reader!.deleteCachedBlocksOnDeinit()
        reader = nil
        try await waitUntil { await probe.started == [1] }
        #expect(released != nil)
        await probe.finish(1)
        try await waitUntil { released == nil }
        #expect(cache.cache.get(key: key, count: 1) == nil)
    }

    @Test(arguments: [false, true])
    func preloadSkipsPageAdviceAndClipsOldRanges(fullyCached: Bool) async throws {
        let storage = PrefetchStorage(storage: try coordinator().cache.data)
        let cache = AtomicCacheCoordinator(cache: AtomicBlockCache(data: storage, blockSize: 64))
        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: 100)), cache: cache, cacheKey: 123)
        for block in 0..<(fullyCached ? 2 : 1) {
            cache.cache.set(key: cache.calculateCacheKey(fileKey: reader.cacheKey, block: block), value: Data(repeating: 7, count: 64))
        }
        try await reader.preloadBlocks(blocks: [-2..<4, 5..<9])
        #expect(storage.advisedRanges.withLock { $0.isEmpty })
        #expect(reader.listOfActiveBlocks(maxAgeSeconds: 60) == [0..<2])
    }

    @Test func prefetchAdvisesCachedPagesAndSharesBackgroundWork() async throws {
        let backing = try coordinator().cache.data
        let storage = PrefetchStorage(storage: backing)
        let cache = AtomicCacheCoordinator(cache: AtomicBlockCache(data: storage, blockSize: 64), maxConcurrentFetches: 1)
        for key: UInt64 in [5, 6] {
            Data(repeating: UInt8(key), count: 64).withUnsafeBytes { _ = cache.cache.set(key: key, value: $0) }
        }
        try await cache.prefetch(fileKey: 0, byteRange: (5 * 64)..<(7 * 64), allowedWait: .zero, provider: { _, _ in
            Issue.record("Cached prefetch must not fetch from the backend")
            return Data()
        })
        #expect(storage.advisedRanges.withLock { $0.map(\.count) } == [128])

        let probe = FetchProbe()
        // Includes cached pages plus a missing tail. Prefetch returns while that tail is still held.
        try await cache.prefetch(fileKey: 0, byteRange: (5 * 64)..<(9 * 64), allowedWait: .seconds(1), provider: { key, count in
            try await probe.fetch(key: key, count: count)
        })
        try await waitUntil { await probe.started.count == 1 }
        #expect(await probe.started == [7])
        #expect(await probe.startedCounts == [2])
        #expect(await cache.testWaiterCount(forBlock: 7) == 0)
        #expect(storage.advisedRanges.withLock { $0.map(\.count) } == [128, 64, 64])
        let demand = Task {
            try await cache.checkRead(key: 8, count: 1, allowedWait: .zero, fileKey: 0, provider: { _, _ in
                Issue.record("Demand must share the background fetch")
                return Data()
            }, check: { _, bytes in
                #expect(Data(bytes) == Data(repeating: 8, count: 64))
            })
        }
        try await waitUntil { await cache.testWaiterCount(forBlock: 8) == 1 }
        await probe.finish(7)
        try await demand.value
        #expect(await probe.started == [7])
    }

    @Test(arguments: [false, true])
    func backgroundPrefetchCompletesJoinedReads(fail: Bool) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        try await cache.prefetch(fileKey: 0, byteRange: (5 * 64)..<(7 * 64), allowedWait: .seconds(1), provider: { key, count in
            try await probe.fetch(key: key, count: count)
        })
        try await waitUntil { await probe.started.count == 1 }
        #expect(await cache.testWaiterCount(forBlock: 5) == 0)
        let reader = Task {
            try await cache.checkRead(key: 5, count: 2, allowedWait: .zero, fileKey: 0, provider: { _, _ in
                Issue.record("The read must join the background fetch")
                return Data()
            }, check: { key, bytes in
                #expect(Data(bytes) == Data(repeating: UInt8(key), count: 64))
            })
        }
        try await waitUntil { await cache.testWaiterCount(forBlock: 5) == 1 }
        #expect(await cache.testWaiterCount(forBlock: 6) == 1)
        await probe.finish(5, fail: fail)
        if fail {
            await #expect(throws: FetchProbe.Failure.self) { try await reader.value }
        } else {
            try await reader.value
        }
    }

    private func coordinator(limit: Int? = nil, pendingLimit: Int = 16_384, blockSize: Int = 64, blockCount: Int = 1024) throws -> Coordinator {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        // Use the production mmap storage: Data's mutable access is not safe for concurrent cache hits.
        let cache = try AtomicBlockCache(file: path, blockSize: blockSize, blockCount: blockCount)
        if let limit { return Coordinator(cache: cache, maxConcurrentFetches: limit, maxPendingFetches: pendingLimit) }
        return Coordinator(cache: cache, maxPendingFetches: pendingLimit)
    }

    private func request(_ cache: Coordinator, _ probe: FetchProbe, key: UInt64, allowedWait: Duration, mergeAdjacent: Bool = false) -> Task<Void, Error> {
        // Scheduling tests use separate files unless they explicitly exercise merging.
        Task {
            try await cache.checkRead(key: key, count: 1, allowedWait: allowedWait, fileKey: mergeAdjacent ? 0 : key, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { _, data in
                #expect(data.count == 64)
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
    }

    private func waitUntil(
        timeout: Duration = .seconds(60), sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () async -> Bool
    ) async throws {
        // The full suite can occupy the cooperative executor for seconds on small CI runners.
        // This is a deadlock watchdog, not a performance assertion.
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !(await condition()) {
            if ContinuousClock.now >= deadline {
                // An actor predicate may return false before this task gets CPU time again.
                // Check fresh state before reporting a timeout at the caller's source location.
                try #require(await condition(), "Timed out waiting for cache scheduling state", sourceLocation: sourceLocation)
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    @Test func waitUntilRechecksConditionAfterSuspension() async throws {
        var checks = 0
        try await waitUntil(timeout: .milliseconds(1)) {
            checks += 1
            if checks == 1 {
                // Simulate a stale false result arriving after the watchdog deadline.
                try? await Task.sleep(for: .milliseconds(10))
                return false
            }
            return true
        }
        #expect(checks == 2)
    }

    @Test func earliestDeadlineFirst() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let first = request(cache, probe, key: 1, allowedWait: .seconds(120))
        try await waitUntil { await probe.started.count == 1 }
        let waits: [Duration] = [.seconds(120), .seconds(60), .zero, .zero, .seconds(60), .seconds(120)]
        var tasks: [Task<Void, Error>] = []
        for (index, allowedWait) in waits.enumerated() {
            tasks.append(request(cache, probe, key: UInt64(index + 2), allowedWait: allowedWait))
            try await waitUntil {
                await cache.queuedFetchCount == index + 1
            }
        }
        let expected: [UInt64] = [1, 4, 5, 3, 6, 2, 7]
        for (index, key) in expected.enumerated() {
            try await waitUntil { await probe.started.count == index + 1 }
            #expect(await probe.started == Array(expected.prefix(index + 1)))
            await probe.finish(key)
        }
        try await first.value
        for task in tasks { try await task.value }
        #expect(await probe.maximumActive == 1)
    }

    @Test func defaultLimitAndCacheHitsBypassQueue() async throws {
        let limit = 4
        let cache = try coordinator()
        let probe = FetchProbe()
        Data(repeating: 231, count: 64).withUnsafeBytes {
            _ = cache.cache.set(key: cache.calculateCacheKey(fileKey: 999, block: 999), value: $0)
        }
        let tasks = (0..<(limit + 1)).map { request(cache, probe, key: UInt64($0), allowedWait: .zero) }
        try await waitUntil {
            await cache.queuedFetchCount == 1
        }
        try await waitUntil { await probe.started.count == limit }
        // This finishes even though all backend slots are occupied.
        try await request(cache, probe, key: 999, allowedWait: .seconds(120)).value
        #expect(await probe.started.count == limit)
        let firstBatch = await probe.started
        for key in firstBatch { await probe.finish(key) }
        try await waitUntil { await probe.started.count == limit + 1 }
        let last = try #require(await probe.started.last)
        await probe.finish(last)
        for task in tasks { try await task.value }
        #expect(await probe.maximumActive == limit)
    }

    @Test func cancellationAndFailureReleaseReservationsAndSlots() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .seconds(60))
        try await waitUntil { await probe.started.count == 1 }
        let cancelled = request(cache, probe, key: 2, allowedWait: .seconds(120))
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let shared = request(cache, probe, key: 2, allowedWait: .zero)
        try await waitUntil { await cache.testWaiterCount(forBlock: 2, fileKey: 2) == 2 }
        cancelled.cancel()
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(1, fail: true)
        await #expect(throws: FetchProbe.Failure.self) { try await running.value }
        try await waitUntil { await probe.started.count == 2 }
        await probe.finish(2, fail: true)
        await #expect(throws: FetchProbe.Failure.self) { try await cancelled.value }
        await #expect(throws: FetchProbe.Failure.self) { try await shared.value }
        #expect(await cache.queuedFetchCount == 0)
        let retry = request(cache, probe, key: 2, allowedWait: .seconds(60))
        try await waitUntil { await probe.started.count == 3 }
        await probe.finish(2)
        try await retry.value
        #expect(await probe.started == [1, 2, 2])
    }

    @Test(arguments: [false, true])
    func agedBackgroundFetchPrecedesNewDemandRead(promoteAgedFetch: Bool) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let background = request(cache, probe, key: 2, allowedWait: .milliseconds(10))
        try await waitUntil { await cache.queuedFetchCount == 1 }
        // Let the scheduling deadline pass while the only backend slot remains occupied.
        try await Task.sleep(for: .milliseconds(20))
        let demand = request(cache, probe, key: 3, allowedWait: .zero)
        try await waitUntil { await cache.queuedFetchCount == 2 }
        var tasks = [running, background, demand]
        if promoteAgedFetch {
            tasks.append(request(cache, probe, key: 2, allowedWait: .zero))
            try await waitUntil { await cache.testWaiterCount(forBlock: 2, fileKey: 2) == 2 }
        }
        // Promotion must retain the older deadline rather than reset it to the current time.
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [1, 2])
        await probe.finish(2)
        try await waitUntil { await probe.started.count == 3 }
        await probe.finish(3)
        for task in tasks { try await task.value }
        #expect(await probe.started == [1, 2, 3])
    }

    @Test func overlappingReaderPromotesCombinedRange() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .seconds(60))
        try await waitUntil { await probe.started.count == 1 }
        let range = Task {
            try await cache.checkRead(key: 10, count: 3, allowedWait: .seconds(120), fileKey: 0, provider: { key, count in
                #expect(key == 10)
                #expect(count == 3)
                return try await probe.fetch(key: key, count: count)
            }, check: { key, data in #expect(data[0] == UInt8(key)) })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let overlapping = Task {
            try await cache.checkRead(key: 11, count: 1, allowedWait: .zero, fileKey: 0, provider: { _, _ in
                Issue.record("An overlapping reader must share the combined fetch")
                return Data(repeating: 0, count: 64)
            }, check: { key, data in
                #expect(key == 11)
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.testWaiterCount(forBlock: 11) == 2 }
        let anotherBlock = Task {
            try await cache.checkRead(key: 12, count: 1, allowedWait: .zero, fileKey: 0, provider: { _, _ in
                Issue.record("All block reservations must share the promoted fetch")
                return Data(repeating: 0, count: 64)
            }, check: { key, data in
                #expect(key == 12)
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.testWaiterCount(forBlock: 12) == 2 }
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        await probe.finish(10)
        for task in [running, range, overlapping, anotherBlock] { try await task.value }
        #expect(await probe.started == [1, 10])
    }

    @Test func cancelledReaderDoesNotCancelQueuedWork() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let cancelled = request(cache, probe, key: 2, allowedWait: .zero)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let next = request(cache, probe, key: 3, allowedWait: .seconds(60))
        try await waitUntil { await cache.queuedFetchCount == 2 }
        cancelled.cancel()
        #expect(await cache.queuedFetchCount == 2)
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [1, 2])
        await probe.finish(2)
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [1, 2, 3])
        await probe.finish(3)
        try await running.value
        try await next.value

        let later = request(cache, probe, key: 4, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 4 }
        await probe.finish(4)
        try await later.value
        #expect(await probe.maximumActive == 1)
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test(arguments: [false, true])
    func repeatedPromotionsPreserveWaiters(cancelPromoted: Bool) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let original = request(cache, probe, key: 2, allowedWait: .seconds(2000))
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let later = request(cache, probe, key: 3, allowedWait: .seconds(1500))
        try await waitUntil { await cache.queuedFetchCount == 2 }
        let earlier = request(cache, probe, key: 4, allowedWait: .zero)
        try await waitUntil { await cache.queuedFetchCount == 3 }
        var readers: [Task<Void, Error>] = []
        for index in 0..<8 {
            readers.append(request(cache, probe, key: 2, allowedWait: .seconds(1000 - index)))
            try await waitUntil { await cache.testWaiterCount(forBlock: 2, fileKey: 2) == index + 2 }
        }
        #expect(await cache.queuedFetchCount == 3)
        if cancelPromoted { original.cancel() }
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        // Promotion passes the competing deadline but preserves the earlier demand read.
        #expect(await probe.started == [1, 4])
        await probe.finish(4)
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [1, 4, 2])
        await probe.finish(2)
        try await waitUntil { await probe.started.count == 4 }
        #expect(await probe.started == [1, 4, 2, 3])
        await probe.finish(3)
        for task in [running, earlier, later] + readers { try await task.value }
        if cancelPromoted {
            await #expect(throws: CancellationError.self) { try await original.value }
        } else {
            try await original.value
        }
        #expect(await cache.queuedFetchCount == 0)
        #expect(await probe.maximumActive == 1)
    }

    @Test(arguments: [UInt64(4), 8])
    func adjacentBlocksExtendQueuedRange(adjacent: UInt64) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let range = Task {
            try await cache.checkRead(key: 5, count: 3, allowedWait: .seconds(120), fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect((5...7).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let reader = request(cache, probe, key: adjacent, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: adjacent) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        let start = min(5, adjacent)
        #expect(await probe.started == [100, start])
        #expect(await probe.startedCounts == [1, 4])
        await probe.finish(start)
        for task in [running, range, reader] { try await task.value }
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test(arguments: [false, true])
    func bridgingQueuedRangesSharesCompletionAndFailure(fail: Bool) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let left = request(cache, probe, key: 5, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let right = Task {
            try await cache.checkRead(key: 7, count: 2, allowedWait: .zero, fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect((7...8).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 2 }
        let sharedRight = request(cache, probe, key: 7, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 7) == 2 }
        let middle = request(cache, probe, key: 6, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 6) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        let competitor = request(cache, probe, key: 20, allowedWait: .seconds(60))
        try await waitUntil { await cache.queuedFetchCount == 2 }
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        // The merged fetch inherits the right-hand request's earlier deadline.
        #expect(await probe.started == [100, 5])
        #expect(await probe.startedCounts == [1, 4])
        await probe.finish(5, fail: fail)
        for task in [left, right, sharedRight, middle] {
            if fail {
                await #expect(throws: FetchProbe.Failure.self) { try await task.value }
            } else {
                try await task.value
            }
        }
        try await waitUntil { await probe.started.count == 3 }
        await probe.finish(20)
        try await competitor.value
        try await running.value
        #expect(await probe.maximumActive == 1)
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test(arguments: ["read", "preload", "prefetch"], [5, 8 * 1024 * 1024 / 64 + 1])
    func blockReaderSupportsPrependedFetch(path: String, firstBlock: Int) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        // Exercise a later super block and a partial final block without allocating per-block arrays.
        var bytes = Data(repeating: 0, count: (firstBlock + 3) * 64 - 7)
        for block in (firstBlock - 1)..<(firstBlock + 3) {
            let range = block * 64..<min((block + 1) * 64, bytes.count)
            bytes.replaceSubrange(range, with: repeatElement(UInt8(truncatingIfNeeded: block), count: range.count))
        }
        let contents = bytes
        let reader = OmReaderBlockCache(backend: DataAsClass(data: contents), cache: cache, cacheKey: 123)
        let original = Task {
            switch path {
            case "read":
                #expect(try await reader.getData(offset: firstBlock * 64, count: 3 * 64 - 7) == contents.subdata(in: firstBlock * 64..<contents.count))
            case "preload":
                try await reader.preloadBlocks(blocks: [firstBlock..<(firstBlock + 3)])
            default:
                try await reader.prefetchData(offset: firstBlock * 64, count: 3 * 64 - 7)
            }
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        // Ordinary prefetch returns after scheduling; preload waits for delivery like a read.
        if path == "prefetch" { try await original.value }
        let prepended = Task<Void, Error> {
            let data = try await reader.getData(offset: (firstBlock - 1) * 64 + 7, count: 42)
            #expect(data == Data(repeating: UInt8(truncatingIfNeeded: firstBlock - 1), count: 42))
        }
        try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: reader.cacheKey, block: firstBlock - 1)) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(100)
        for task in [running, original, prepended] { try await task.value }
        for block in (firstBlock - 1)..<(firstBlock + 3) {
            let cached = try #require(cache.cache.get(key: cache.calculateCacheKey(fileKey: reader.cacheKey, block: block), count: 1))
            #expect(cached[0] == UInt8(truncatingIfNeeded: block))
        }
    }

    @Test func adjacentBlocksInDifferentFilesStaySeparate() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        // Adjacent file block indices in different files must remain separate jobs.
        var readers: [Task<Void, Error>] = []
        for (index, key) in [UInt64(5), 7, 6].enumerated() {
            readers.append(request(cache, probe, key: key, allowedWait: .zero))
            try await waitUntil { await cache.testWaiterCount(forBlock: key, fileKey: key) == 1 }
            #expect(await cache.queuedFetchCount == index + 1)
        }
        await probe.finish(100)
        for (index, key) in [UInt64(5), 7, 6].enumerated() {
            try await waitUntil { await probe.started.count == index + 2 }
            #expect(await probe.started.last == key)
            await probe.finish(key)
        }
        for task in [running] + readers { try await task.value }
        #expect(await probe.startedCounts == [1, 1, 1, 1])
    }

    @Test func runningFetchDoesNotExpand() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 5, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await probe.started.count == 1 }
        let adjacent = request(cache, probe, key: 6, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        #expect(await probe.startedCounts == [1])
        await probe.finish(5)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [5, 6])
        #expect(await probe.startedCounts == [1, 1])
        await probe.finish(6)
        for task in [running, adjacent] { try await task.value }
    }

    @Test func spanningRequestMergesMultipleQueuedRanges() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        var readers: [Task<Void, Error>] = []
        for key: UInt64 in [5, 7, 9] {
            readers.append(request(cache, probe, key: key, allowedWait: .seconds(120), mergeAdjacent: true))
            let queuedCount = readers.count
            try await waitUntil { await cache.queuedFetchCount == queuedCount }
        }
        let spanning = Task {
            try await cache.checkRead(key: 4, count: 7, allowedWait: .zero, fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect((4...10).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.testWaiterCount(forBlock: 4) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [100, 4])
        #expect(await probe.startedCounts == [1, 7])
        await probe.finish(4)
        for task in [running, spanning] + readers { try await task.value }
    }

    @Test func fullQueueAllowsSharingAndMergingAndRejectedRequestsCanRetry() async throws {
        let cache = try coordinator(limit: 1, pendingLimit: 2)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let left = request(cache, probe, key: 5, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let right = request(cache, probe, key: 7, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 2 }

        for _ in 0..<2 {
            await #expect(throws: Coordinator.CacheCoordinatorError.pendingQueueFull) {
                try await cache.checkRead(key: 20, count: 2, allowedWait: .zero, fileKey: 20, provider: { _, _ in
                    Issue.record("A rejected fetch must not call the backend")
                    return Data()
                }, check: { _, _ in Issue.record("A rejected fetch must not deliver data") })
            }
        }
        #expect(await cache.queuedFetchCount == 2)
        #expect(await probe.started == [100])

        // Cached reads and readers joining either queued or running work need no queue entry.
        Data(repeating: 231, count: 64).withUnsafeBytes { _ = cache.cache.set(key: cache.calculateCacheKey(fileKey: 999, block: 999), value: $0) }
        try await request(cache, probe, key: 999, allowedWait: .zero).value
        let sharedRunning = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await cache.testWaiterCount(forBlock: 100, fileKey: 100) == 2 }
        let shared = request(cache, probe, key: 5, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 5) == 2 }
        let middle = request(cache, probe, key: 6, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 6) == 1 }
        #expect(await cache.queuedFetchCount == 1)

        // Merging frees a queue entry; neither rejected block may retain a reservation.
        let retry = Task {
            try await cache.checkRead(key: 20, count: 2, allowedWait: .seconds(60), fileKey: 20, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in #expect(data[0] == UInt8(key)) })
        }
        try await waitUntil { await cache.queuedFetchCount == 2 }
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [100, 5])
        await probe.finish(5)
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [100, 5, 20])
        #expect(await probe.startedCounts == [1, 3, 2])
        await probe.finish(20)
        for task in [running, left, right, sharedRunning, shared, middle, retry] { try await task.value }
        #expect(await cache.queuedFetchCount == 0)
        #expect(await probe.maximumActive == 1)
    }

    // Inverse FNV multiplier places the first cache key at UInt64.max - 63.
    @Test(arguments: [UInt64(0), (UInt64.max - 73) &* 14886173955864302971], [16, 110])
    func requestInsideLargeQueuedRange(fileKey: UInt64, requestedCount: Int) async throws {
        let start: UInt64 = 10
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 500, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let original = Task {
            try await cache.checkRead(key: start, count: 128, allowedWait: .seconds(120), fileKey: fileKey, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect(key &- start < 128)
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let requestedStart = start &+ 32
        let overlapping = Task {
            try await cache.checkRead(key: requestedStart, count: requestedCount, allowedWait: .zero, fileKey: fileKey, provider: { key, count in
                Issue.record("The overlapping request should share the existing queued fetch")
                return try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect(key &- requestedStart < UInt64(requestedCount))
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: fileKey, block: Int(requestedStart))) == 2 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(500)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [500, start])
        // An interior request stays within the range; a longer request extends its tail.
        #expect(await probe.startedCounts == [1, max(128, 32 + requestedCount)])
        await probe.finish(start)
        for task in [running, original, overlapping] { try await task.value }
    }

    @Test(arguments: [false, true])
    func immediateRangesStopAtCachedAndRunningBlocks(runningMiddle: Bool) async throws {
        let cache = try coordinator(limit: 3)
        let probe = FetchProbe()
        if !runningMiddle {
            Data(repeating: 7, count: 64).withUnsafeBytes { _ = cache.cache.set(key: 7, value: $0) }
        }
        let runningKey: UInt64 = runningMiddle ? 7 : 9
        let running = request(cache, probe, key: runningKey, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await probe.started.count == 1 }
        let reader = Task {
            try await cache.checkRead(key: 5, count: 5, allowedWait: .zero, fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect((5...9).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        // Both missing ranges start before either is released; the running range stays shared.
        try await waitUntil { await probe.started.count == 3 }
        #expect(Set(await probe.started) == [runningKey, 5, 8])
        let counts = Dictionary(uniqueKeysWithValues: zip(await probe.started, await probe.startedCounts))
        #expect(counts == [runningKey: 1, 5: 2, 8: runningMiddle ? 2 : 1])
        await probe.finish(8)
        try await waitUntil { await cache.testWaiterCount(forBlock: runningKey) == 2 }
        await probe.finish(5)
        await probe.finish(runningKey)
        for task in [running, reader] { try await task.value }
        #expect(await cache.queuedFetchCount == 0)
        #expect(await probe.maximumActive == 3)
    }

    // Start at a valid file block while its cache key wraps across UInt64.max.
    @Test(arguments: [false, true], [UInt64(0), (UInt64.max - 5) &* 14886173955864302971])
    func fragmentedReadsRetainEarlyResults(failLaterRange: Bool, fileKey: UInt64) async throws {
        let first: UInt64 = 5
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let middle = first &+ 1
        let last = first &+ 2
        Data(repeating: UInt8(truncatingIfNeeded: middle), count: 64).withUnsafeBytes {
            _ = cache.cache.set(key: cache.calculateCacheKey(fileKey: fileKey, block: Int(middle)), value: $0)
        }
        let delivered = Mutex<[UInt64]>([])
        let reader = Task {
            try await cache.checkRead(key: first, count: 3, allowedWait: .zero, fileKey: fileKey, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
                delivered.withLock { $0.append(key) }
            })
        }
        try await waitUntil { await probe.started.count == 2 }
        #expect(Set(await probe.started) == [first, last])
        // Complete the later range first: neither its result nor its error may be lost.
        await probe.finish(last, fail: failLaterRange)
        try await waitUntil { await cache.waiterCount(for: cache.calculateCacheKey(fileKey: fileKey, block: Int(last))) == 0 }
        #expect(delivered.withLock { $0 }.isEmpty)
        await probe.finish(first)
        if failLaterRange {
            #expect(delivered.withLock { $0 }.isEmpty)
            await #expect(throws: FetchProbe.Failure.self) { try await reader.value }
            let retry = request(cache, probe, key: last, allowedWait: .zero)
            try await waitUntil { await probe.started.count == 3 }
            await probe.finish(last)
            try await retry.value
        } else {
            try await reader.value
            #expect(delivered.withLock { $0 } == [first, middle, last])
        }
        #expect(await probe.maximumActive == 2)
    }

    @Test(arguments: [1, 2])
    func fragmentedReadsQueueOrShareRunningPrefix(limit: Int) async throws {
        let cache = try coordinator(limit: limit)
        let probe = FetchProbe()
        Data(repeating: 2, count: 64).withUnsafeBytes { _ = cache.cache.set(key: 2, value: $0) }
        var existing: Task<Void, Error>?
        if limit == 2 {
            existing = request(cache, probe, key: 1, allowedWait: .zero, mergeAdjacent: true)
            try await waitUntil { await probe.started.count == 1 }
        }
        let delivered = Mutex<[UInt64]>([])
        let reader = Task {
            try await cache.checkRead(key: 1, count: 3, allowedWait: .zero, fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in
                #expect(data[0] == UInt8(key))
                delivered.withLock { $0.append(key) }
            })
        }
        if limit == 1 {
            // The second range must queue before the first range finishes.
            try await waitUntil { await cache.queuedFetchCount == 1 }
            try await waitUntil { await probe.started.count == 1 }
            let first = try #require(await probe.started.first)
            await probe.finish(first)
            try await waitUntil { await probe.started.count == 2 }
            await probe.finish(first == 1 ? 3 : 1)
        } else {
            // Waiting on an already-running prefix must not delay the independent tail.
            try await waitUntil { await probe.started.count == 2 }
            try await waitUntil { await cache.testWaiterCount(forBlock: 1) == 2 }
            await probe.finish(3)
            await probe.finish(1)
        }
        try await reader.value
        try await existing?.value
        #expect(delivered.withLock { $0 }.sorted() == [1, 2, 3])
        #expect(Set(await probe.started) == [1, 3])
        #expect(await probe.maximumActive == limit)
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test func schedulingFailureReturnsAndDisablesRegisteredWrites() async throws {
        let cache = try coordinator(limit: 1, pendingLimit: 1)
        let probe = FetchProbe()
        for key: UInt64 in [2, 4] {
            Data(repeating: UInt8(key), count: 64).withUnsafeBytes { _ = cache.cache.set(key: key, value: $0) }
        }
        let returned = Mutex(false)
        let reader = Task {
            defer { returned.withLock { $0 = true } }
            let result = try await cache.get(fileKey: 0, byteRange: 64..<(6 * 64), allowedWait: .zero, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            })
            return result.intoData()
        }
        try await waitUntil { await probe.started.count == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await #expect(throws: Coordinator.CacheCoordinatorError.pendingQueueFull) { try await reader.value }
        #expect(returned.withLock { $0 })
        // A different request sharing the queued block must still receive its data.
        let shared = request(cache, probe, key: 3, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 3) == 2 }
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        #expect(returned.withLock { $0 })
        await probe.finish(3)
        try await shared.value
        #expect(await probe.started == [1, 3])
        #expect(await cache.queuedFetchCount == 0)
    }

    @Test func fileReadCopiesBeforeCacheSlotReuse() async throws {
        let cache = try coordinator(limit: 1, blockCount: 1)
        let blockSize = cache.cache.blockSize
        let boundary = cache.superBlockLength * blockSize
        // Straddle a super-block boundary with two small blocks. The owned result must preserve
        // the first block when the second fetch reuses the cache's only slot.
        let result = try await cache.get(fileKey: 123, byteRange: (boundary - blockSize)..<(boundary + blockSize), provider: { key, count in
            #expect(count == 1)
            return Data(repeating: UInt8(truncatingIfNeeded: key), count: blockSize)
        })
        guard case .owned(let bytes) = result else { Issue.record("Cross-super-block reads must allocate"); return }
        let first = UInt8(truncatingIfNeeded: cache.superBlockLength - 1)
        let second = UInt8(truncatingIfNeeded: cache.superBlockLength)
        bytes.withUnsafeBytes { #expect(Data($0) == Data(repeating: first, count: blockSize) + Data(repeating: second, count: blockSize)) }
    }

    @Test func runningRangeSharesEveryRegisteredBlock() async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let original = Task {
            try await cache.checkRead(key: 10, count: 3, allowedWait: .zero, fileKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, check: { key, data in #expect(data[0] == UInt8(key)) })
        }
        try await waitUntil { await probe.started.count == 1 }
        #expect(await cache.testWaiterCount(forBlock: 12) == 1)
        let overlapping = request(cache, probe, key: 12, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.testWaiterCount(forBlock: 12) == 2 }
        #expect(await probe.started == [10])
        #expect(await probe.startedCounts == [3])
        #expect(await cache.queuedFetchCount == 0)
        await probe.finish(10)
        for task in [original, overlapping] { try await task.value }
    }

}
