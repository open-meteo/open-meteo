import Foundation
import OmFileFormat
@testable import OmFileIO
import Testing

private typealias Coordinator = AtomicCacheCoordinator<MmapFile>

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

struct AtomicCacheCoordinatorTests {
    private func coordinator(limit: Int? = nil, pendingLimit: Int = 16_384) throws -> Coordinator {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        // Use the production mmap storage: Data's mutable access is not safe for concurrent cache hits.
        let cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 1024)
        if let limit { return Coordinator(cache: cache, maxConcurrentFetches: limit, maxPendingFetches: pendingLimit) }
        return Coordinator(cache: cache, maxPendingFetches: pendingLimit)
    }

    private func request(_ cache: Coordinator, _ probe: FetchProbe, key: UInt64, allowedWait: Duration, mergeAdjacent: Bool = false) -> Task<Void, Error> {
        // Scheduling tests use separate super block keys unless they explicitly exercise merging.
        Task {
            try await cache.get(key: key, count: 1, allowedWait: allowedWait, superBlockKey: mergeAdjacent ? 0 : key, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { _, data in
                #expect(data.count == 64)
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await condition()) {
            try #require(ContinuousClock.now < deadline)
            try await Task.sleep(for: .milliseconds(1))
        }
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

    @Test(arguments: [Duration.seconds(120), .seconds(60), .zero])
    func defaultLimitAndCacheHitsBypassQueue(allowedWait: Duration) async throws {
        let limit = 16
        let cache = try coordinator()
        let probe = FetchProbe()
        Data(repeating: 231, count: 64).withUnsafeBytes {
            _ = cache.cache.set(key: 999, value: $0)
        }
        let tasks = (0..<(limit + 1)).map { request(cache, probe, key: UInt64($0), allowedWait: allowedWait) }
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

    @Test func sharedFetchIsPromotedWithoutDuplicateBackendCall() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .seconds(120))
        try await waitUntil { await probe.started.count == 1 }
        let low = request(cache, probe, key: 2, allowedWait: .seconds(120))
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let mid = request(cache, probe, key: 3, allowedWait: .seconds(60))
        try await waitUntil { await cache.queuedFetchCount == 2 }
        let earlierHigh = request(cache, probe, key: 4, allowedWait: .zero)
        try await waitUntil { await cache.queuedFetchCount == 3 }
        let high = request(cache, probe, key: 2, allowedWait: .zero)
        try await waitUntil { await cache.waiterCount(for: 2) == 2 }
        #expect(await cache.queuedFetchCount == 3)
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        // The earlier zero-wait reader retains its earlier deadline after promotion.
        #expect(await probe.started == [1, 4])
        await probe.finish(4)
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [1, 4, 2])
        await probe.finish(2)
        try await waitUntil { await probe.started.count == 4 }
        await probe.finish(3)
        for task in [running, low, mid, earlierHigh, high] { try await task.value }
        #expect(await probe.started == [1, 4, 2, 3])
    }

    @Test func cancellationAndFailureReleaseReservationsAndSlots() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 1, allowedWait: .seconds(60))
        try await waitUntil { await probe.started.count == 1 }
        let cancelled = request(cache, probe, key: 2, allowedWait: .seconds(120))
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let shared = request(cache, probe, key: 2, allowedWait: .zero)
        try await waitUntil { await cache.waiterCount(for: 2) == 2 }
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
            try await waitUntil { await cache.waiterCount(for: 2) == 2 }
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
            try await cache.get(key: 10, count: 3, allowedWait: .seconds(120), superBlockKey: 0, provider: { key, count in
                #expect(key == 10)
                #expect(count == 3)
                return try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in #expect(data[0] == UInt8(key)) })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let overlapping = Task {
            try await cache.get(key: 11, count: 1, allowedWait: .zero, superBlockKey: 0, provider: { _, _ in
                Issue.record("An overlapping reader must share the combined fetch")
                return Data(repeating: 0, count: 64)
            }, dataCallback: { key, data in
                #expect(key == 11)
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: 11) == 1 }
        let anotherBlock = Task {
            try await cache.get(key: 12, count: 1, allowedWait: .zero, superBlockKey: 0, provider: { _, _ in
                Issue.record("All block reservations must share the promoted fetch")
                return Data(repeating: 0, count: 64)
            }, dataCallback: { key, data in
                #expect(key == 12)
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: 12) == 1 }
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
        let later = request(cache, probe, key: 3, allowedWait: .seconds(3000))
        try await waitUntil { await cache.queuedFetchCount == 2 }
        var readers: [Task<Void, Error>] = []
        for index in 0..<8 {
            readers.append(request(cache, probe, key: 2, allowedWait: .seconds(1000 - index)))
            try await waitUntil { await cache.waiterCount(for: 2) == index + 2 }
        }
        #expect(await cache.queuedFetchCount == 2)
        if cancelPromoted { original.cancel() }
        await probe.finish(1)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [1, 2])
        await probe.finish(2)
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [1, 2, 3])
        await probe.finish(3)
        for task in [running, later] + readers { try await task.value }
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
            try await cache.get(key: 5, count: 3, allowedWait: .seconds(120), superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect((5...7).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let reader = request(cache, probe, key: adjacent, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: adjacent) == 1 }
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
            try await cache.get(key: 7, count: 2, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect((7...8).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 2 }
        let sharedRight = request(cache, probe, key: 7, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: 7) == 2 }
        let middle = request(cache, probe, key: 6, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: 6) == 1 }
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

    @Test func overlappingRequestExtendsQueuedTail() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let original = request(cache, probe, key: 5, allowedWait: .seconds(120), mergeAdjacent: true)
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let overlapping = Task {
            try await cache.get(key: 5, count: 4, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect((5...8).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: 5) == 2 }
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [100, 5])
        #expect(await probe.startedCounts == [1, 4])
        await probe.finish(5)
        for task in [running, original, overlapping] { try await task.value }
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
        let prepended = Task<Void, Error> {
            let data = try await reader.getData(offset: (firstBlock - 1) * 64 + 7, count: 42)
            #expect(data == Data(repeating: UInt8(truncatingIfNeeded: firstBlock - 1), count: 42))
        }
        try await waitUntil { await cache.waiterCount(for: reader.calculateCacheKey(block: firstBlock - 1)) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(100)
        for task in [running, original, prepended] { try await task.value }
        for block in (firstBlock - 1)..<(firstBlock + 3) {
            let cached = try #require(cache.cache.get(key: reader.calculateCacheKey(block: block), count: 1))
            #expect(cached[0] == UInt8(truncatingIfNeeded: block))
        }
    }

    @Test func adjacentKeysInDifferentSuperBlocksStaySeparate() async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        // The middle request encounters both neighbours, but none share its super-block key.
        var readers: [Task<Void, Error>] = []
        for (index, key) in [UInt64(5), 7, 6].enumerated() {
            readers.append(request(cache, probe, key: key, allowedWait: .zero))
            try await waitUntil { await cache.waiterCount(for: key) == 1 }
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

    @Test(arguments: [
        [UInt64(5), 6, 7, 8],
        [UInt64(7), 6, 5, 4],
        [UInt64.max - 1, UInt64.max, 0, 1]
    ])
    func individualQueuedReadsMerge(keys: [UInt64]) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        var readers: [Task<Void, Error>] = []
        for (index, key) in keys.enumerated() {
            readers.append(request(cache, probe, key: key, allowedWait: .seconds(120), mergeAdjacent: true))
            if index == 0 {
                try await waitUntil { await cache.queuedFetchCount == 1 }
            } else {
                try await waitUntil { await cache.waiterCount(for: key) == 1 }
            }
            #expect(await cache.queuedFetchCount == 1)
        }
        await probe.finish(100)
        try await waitUntil { await probe.started.count == 2 }
        let start = keys[0] == 7 ? UInt64(4) : keys[0]
        #expect(await probe.started == [100, start])
        #expect(await probe.startedCounts == [1, 4])
        await probe.finish(start)
        for task in [running] + readers { try await task.value }
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
            try await cache.get(key: 4, count: 7, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect((4...10).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: 4) == 1 }
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
                try await cache.get(key: 20, count: 2, allowedWait: .zero, superBlockKey: 20, provider: { _, _ in
                    Issue.record("A rejected fetch must not call the backend")
                    return Data()
                }, dataCallback: { _, _ in Issue.record("A rejected fetch must not deliver data") })
            }
        }
        #expect(await cache.queuedFetchCount == 2)
        #expect(await probe.started == [100])

        // Cached reads and readers joining either queued or running work need no queue entry.
        Data(repeating: 231, count: 64).withUnsafeBytes { _ = cache.cache.set(key: 999, value: $0) }
        try await request(cache, probe, key: 999, allowedWait: .zero).value
        let sharedRunning = request(cache, probe, key: 100, allowedWait: .zero)
        try await waitUntil { await cache.waiterCount(for: 100) == 2 }
        let shared = request(cache, probe, key: 5, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: 5) == 2 }
        let middle = request(cache, probe, key: 6, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: 6) == 1 }
        #expect(await cache.queuedFetchCount == 1)

        // Merging frees a queue entry; neither rejected block may retain a reservation.
        let retry = Task {
            try await cache.get(key: 20, count: 2, allowedWait: .seconds(60), superBlockKey: 20, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in #expect(data[0] == UInt8(key)) })
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

    @Test(arguments: [UInt64(10), UInt64.max - 63], [16, 110])
    func requestInsideLargeQueuedRange(start: UInt64, requestedCount: Int) async throws {
        let cache = try coordinator(limit: 1)
        let probe = FetchProbe()
        let running = request(cache, probe, key: 500, allowedWait: .zero)
        try await waitUntil { await probe.started.count == 1 }
        let original = Task {
            try await cache.get(key: start, count: 128, allowedWait: .seconds(120), superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect(key &- start < 128)
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
        try await waitUntil { await cache.queuedFetchCount == 1 }
        let requestedStart = start &+ 32
        let overlapping = Task {
            try await cache.get(key: requestedStart, count: requestedCount, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                Issue.record("The overlapping request should share the existing queued fetch")
                return try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect(key &- requestedStart < UInt64(requestedCount))
                #expect(data[0] == UInt8(truncatingIfNeeded: key))
            })
        }
        try await waitUntil { await cache.waiterCount(for: requestedStart) == 1 }
        #expect(await cache.queuedFetchCount == 1)
        await probe.finish(500)
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [500, start])
        // An interior request stays within the range; a longer request extends its tail.
        #expect(await probe.startedCounts == [1, max(128, 32 + requestedCount)])
        await probe.finish(start)
        for task in [running, original, overlapping] { try await task.value }
    }

    @Test func immediateRangesStopAtCachedAndRunningBlocks() async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        Data(repeating: 7, count: 64).withUnsafeBytes { _ = cache.cache.set(key: 7, value: $0) }
        let running = request(cache, probe, key: 9, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await probe.started.count == 1 }
        let reader = Task {
            try await cache.get(key: 5, count: 5, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in
                #expect((5...9).contains(key))
                #expect(data[0] == UInt8(key))
            })
        }
        try await waitUntil { await probe.started.count == 2 }
        #expect(await probe.started == [9, 5])
        #expect(await probe.startedCounts == [1, 2])
        await probe.finish(5)
        try await waitUntil { await probe.started.count == 3 }
        #expect(await probe.started == [9, 5, 8])
        #expect(await probe.startedCounts == [1, 2, 1])
        await probe.finish(8)
        try await waitUntil { await cache.waiterCount(for: 9) == 2 }
        await probe.finish(9)
        for task in [running, reader] { try await task.value }
        #expect(await cache.queuedFetchCount == 0)
        #expect(await probe.maximumActive == 2)
    }

    @Test func runningRangeReservesBlocksWithoutWaiters() async throws {
        let cache = try coordinator(limit: 2)
        let probe = FetchProbe()
        let original = Task {
            try await cache.get(key: 10, count: 3, allowedWait: .zero, superBlockKey: 0, provider: { key, count in
                try await probe.fetch(key: key, count: count)
            }, dataCallback: { key, data in #expect(data[0] == UInt8(key)) })
        }
        try await waitUntil { await probe.started.count == 1 }
        #expect(await cache.waiterCount(for: 12) == 0)
        let overlapping = request(cache, probe, key: 12, allowedWait: .zero, mergeAdjacent: true)
        try await waitUntil { await cache.waiterCount(for: 12) == 1 }
        #expect(await probe.started == [10])
        #expect(await probe.startedCounts == [3])
        #expect(await cache.queuedFetchCount == 0)
        await probe.finish(10)
        for task in [original, overlapping] { try await task.value }
    }

}
