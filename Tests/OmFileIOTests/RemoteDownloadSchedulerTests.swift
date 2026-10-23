import Foundation
import Testing
import OmFileFormat
import Synchronization
@testable import OmFileIO

private actor DownloadGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

private actor DownloadLog {
    var entries: [String] = []
    func add(_ entry: String) { entries.append(entry) }
}

private func eventually(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !(await condition()) {
        try #require(ContinuousClock.now < deadline, "Timed out waiting for scheduler state")
        await Task.yield()
    }
}

private final class PrefetchRecordingStorage: AtomicBlockCacheStorable {
    let storage = DataAsClass(data: Data(count: (64 + 16) * 16))
    let ranges = Mutex<[Range<Int>]>([])
    var count: Int { storage.count }
    func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withMutableUnsafeBytes(body)
    }
    func prefetchData(offset: Int, count: Int) {
        ranges.withLock { $0.append(offset..<offset + count) }
    }
}

@Suite struct RemoteDownloadSchedulerTests {
    @Test func foregroundOvertakesQueuedBackground() async throws {
        let scheduler = RemoteDownloadScheduler(limit: 1, backgroundLimit: 1)
        let gate = DownloadGate()
        let log = DownloadLog()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { await gate.wait() } }
        try await eventually { await scheduler.snapshot.activeBackground == 1 }
        let background = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { await log.add("background") } }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        let foreground = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .foreground)) { await log.add("foreground") } }
        try await eventually { await scheduler.snapshot.queuedForeground == 1 }
        await gate.open()
        try await first.value
        try await foreground.value
        try await background.value
        #expect(await log.entries == ["foreground", "background"])
    }

    @Test func backgroundLeavesCapacityForForegroundAndCancellationReleasesQueue() async throws {
        let scheduler = RemoteDownloadScheduler(limit: 2, backgroundLimit: 1)
        let gate = DownloadGate()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { await gate.wait() } }
        try await eventually { await scheduler.snapshot.activeBackground == 1 }
        let queued = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { _ = Issue.record("Cancelled job ran") } }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        try await scheduler.execute(job: RemoteDownloadJob(priority: .foreground)) {}
        #expect(await scheduler.snapshot.activeBackground == 1)
        queued.cancel()
        do { try await queued.value; Issue.record("Expected cancellation") } catch is CancellationError {}
        #expect(await scheduler.snapshot.queuedBackground == 0)
        await gate.open()
        try await first.value
        #expect(await scheduler.snapshot.activeBackground == 0)
    }

    @Test func errorsReleaseSlotsAndBackgroundQueueIsBounded() async throws {
        enum Expected: Error { case failure }
        let scheduler = RemoteDownloadScheduler(limit: 1, backgroundLimit: 1, backgroundQueueLimit: 1)
        let gate = DownloadGate()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { await gate.wait(); throw Expected.failure } }
        try await eventually { await scheduler.snapshot.activeBackground == 1 }
        let second = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) {} }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        do {
            try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) {}
            Issue.record("Expected full queue")
        } catch RemoteDownloadSchedulerError.backgroundQueueFull {}
        await gate.open()
        do { try await first.value; Issue.record("Expected failure") } catch Expected.failure {}
        try await second.value
        #expect(await scheduler.snapshot.activeBackground == 0)
    }

    @Test func overlappingForegroundPromotesOneDownloadAndSurvivesPreloadCancellation() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 16)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        let scheduler = RemoteDownloadScheduler(limit: 1, backgroundLimit: 1)
        let gate = DownloadGate()
        let log = DownloadLog()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .foreground)) { await gate.wait() } }
        try await eventually { await scheduler.snapshot.activeForeground == 1 }
        let unrelated = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .background)) { await log.add("unrelated") } }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        let preload = Task {
            try await coordinator.get(key: 100, count: 3, priority: .background, provider: { _, count in
                let job = try #require(RemoteDownloadJob.current)
                return try await scheduler.execute(job: job) {
                    await log.add("download")
                    return Data(repeating: 42, count: count * 64)
                }
            }, dataCallback: { _, _ in })
        }
        try await eventually { await scheduler.snapshot.queuedBackground == 2 }
        let foreground = Task {
            try await coordinator.get(key: 101, count: 1, provider: { _, _ in
                Issue.record("Overlapping read must reuse the preload")
                return Data(repeating: 0, count: 64)
            }, dataCallback: { key, bytes in
                #expect(key == 101)
                #expect(Data(bytes) == Data(repeating: 42, count: 64))
            })
        }
        try await eventually { await scheduler.snapshot.queuedForeground == 1 }
        preload.cancel()
        do { try await preload.value; Issue.record("Expected cancellation") } catch is CancellationError {}
        await gate.open()
        try await first.value
        try await foreground.value
        try await unrelated.value
        #expect(await log.entries == ["download", "unrelated"])
        #expect(await scheduler.snapshot.promotions == 1)
        #expect(cache.get(key: 100, count: 1) != nil)
        #expect(cache.get(key: 102, count: 1) != nil)
    }

    @Test func abandonedPreloadIsRemovedAndCanBeRetried() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 16)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        let scheduler = RemoteDownloadScheduler(limit: 1, backgroundLimit: 1)
        let gate = DownloadGate()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .foreground)) { await gate.wait() } }
        try await eventually { await scheduler.snapshot.activeForeground == 1 }
        let preload = Task {
            try await coordinator.get(key: 100, count: 1, priority: .background, provider: { _, _ in
                try await scheduler.execute(job: #require(RemoteDownloadJob.current)) {
                    Issue.record("Abandoned preload ran")
                    return Data(repeating: 42, count: 64)
                }
            }, dataCallback: { _, _ in })
        }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        preload.cancel()
        do { try await preload.value; Issue.record("Expected cancellation") } catch is CancellationError {}
        try await eventually { await scheduler.snapshot.queuedBackground == 0 }
        try await coordinator.get(key: 100, count: 1, provider: { _, _ in Data(repeating: 7, count: 64) }, dataCallback: { _, bytes in
            #expect(Data(bytes) == Data(repeating: 7, count: 64))
        })
        await gate.open()
        try await first.value
    }

    @Test func failedSharedDownloadClearsAllKeysForRetry() async throws {
        enum Expected: Error { case failure }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 16)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        let scheduler = RemoteDownloadScheduler(limit: 1, backgroundLimit: 1)
        let gate = DownloadGate()
        let first = Task { try await scheduler.execute(job: RemoteDownloadJob(priority: .foreground)) { await gate.wait() } }
        try await eventually { await scheduler.snapshot.activeForeground == 1 }
        let preload = Task {
            try await coordinator.get(key: 100, count: 2, priority: .background, provider: { _, _ -> Data in
                try await scheduler.execute(job: #require(RemoteDownloadJob.current)) { throw Expected.failure }
            }, dataCallback: { _, _ in Issue.record("Failed read produced data") })
        }
        try await eventually { await scheduler.snapshot.queuedBackground == 1 }
        let foreground = Task {
            try await coordinator.get(key: 101, count: 1, provider: { _, _ -> Data in
                Issue.record("Expected shared download")
                throw Expected.failure
            }, dataCallback: { _, _ in Issue.record("Failed read produced data") })
        }
        try await eventually { await scheduler.snapshot.queuedForeground == 1 }
        await gate.open()
        try await first.value
        do { try await foreground.value; Issue.record("Expected failure") } catch Expected.failure {}
        do { try await preload.value; Issue.record("Expected failure") } catch Expected.failure {}
        try await coordinator.get(key: 100, count: 2, provider: { _, count in Data(repeating: 7, count: count * 64) }, dataCallback: { _, data in
            #expect(Data(data) == Data(repeating: 7, count: 64))
        })
    }

    @Test func replacementCancelsRunningWarmupAndQueueDropsOldest() async throws {
        let warmer = RemoteCacheWarmer(concurrency: 1, capacity: 1)
        let log = DownloadLog()
        let running = await warmer.stage(key: "running") {
            await log.add("started")
            do { try await Task.sleep(for: .seconds(60)) } catch { await log.add("cancelled") }
        }
        await warmer.activate(running)
        try await eventually { await log.entries == ["started"] }
        let discarded = await warmer.stage(key: "discarded") { await log.add("discarded") }
        await warmer.activate(discarded)
        let latest = await warmer.stage(key: "running") { await log.add("latest") }
        await warmer.activate(latest)
        try await eventually { await log.entries == ["started", "cancelled", "latest"] }
        await warmer.shutdown()
    }

    @Test func prefetchMissUsesCacheStorageOffsets() async throws {
        let storage = PrefetchRecordingStorage()
        let cache = AtomicBlockCache(data: storage, blockSize: 64)
        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: 128)), cache: AtomicCacheCoordinator(cache: cache), cacheKey: 123)
        try await reader.prefetchData(offset: 0, count: 128)
        try await eventually { storage.ranges.withLock { $0.count == 2 } }
        for range in storage.ranges.withLock({ $0 }) {
            #expect(range.lowerBound >= 0)
            #expect(range.upperBound <= storage.count)
        }
        #expect(try await reader.getData(offset: 0, count: 128) == Data(repeating: 7, count: 128))
    }

    @Test func schedulerIsPerOriginNotPerPathOrCredential() async throws {
        let servers = S3ServerHealth(logger: .init(label: "test"), servers: [])
        let first = await servers.downloadScheduler(for: .init(rawEndpoint: "https://one.example/data/", profile: nil))
        let same = await servers.downloadScheduler(for: .init(rawEndpoint: "https://user:password@one.example/other/", profile: nil))
        let second = await servers.downloadScheduler(for: .init(rawEndpoint: "https://two.example/data/", profile: nil))
        #expect(first === same)
        #expect(first !== second)
    }

    @Test func warmingWaitsForPublicationAndReplacesObsoleteWork() async throws {
        let warmer = RemoteCacheWarmer(concurrency: 1, capacity: 2)
        let log = DownloadLog()
        let obsolete = await warmer.stage(key: "file") { await log.add("obsolete") }
        let latest = await warmer.stage(key: "file") { await log.add("latest") }
        await warmer.activate(obsolete)
        #expect(await log.entries.isEmpty)
        await warmer.activate(latest)
        try await eventually { await log.entries == ["latest"] }
        await warmer.shutdown()
    }
}
