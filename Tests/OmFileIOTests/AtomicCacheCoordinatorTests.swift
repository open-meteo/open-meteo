import Foundation
import OmFileFormat
@testable import OmFileIO
import Testing

@Suite struct AtomicCacheCoordinatorTests {
    @Test func limitsUniqueFetchesAndSharesQueuedRanges() async throws {
        let fixture = try CacheFixture(limit: 2)
        let coordinator = fixture.coordinator
        let provider = ControlledProvider()
        let first = Task { try await read(coordinator, provider, key: 10, count: 2) }
        let second = Task { try await read(coordinator, provider, key: 20) }
        try await eventually { await provider.started.count == 2 }

        let third = Task { try await read(coordinator, provider, key: 30, count: 2) }
        try await eventually { await coordinator.upstreamFetchStatistics().queued == 1 }
        let fourth = Task { try await read(coordinator, provider, key: 40) }
        try await eventually { await coordinator.upstreamFetchStatistics().queued == 2 }
        let duplicates = (0..<10).map { _ in
            Task { try await read(coordinator, provider, key: 31) }
        }

        // Cached reads bypass the saturated limiter entirely.
        fixture.cache.set(key: 100, value: Data(repeating: 100, count: 64))
        try await read(coordinator, provider, key: 100)
        #expect(await coordinator.upstreamFetchStatistics().active == 2)

        await provider.finish(10)
        try await first.value
        try await eventually { await provider.started.count == 3 }
        #expect(await provider.started.last?.key == 30)
        #expect(await provider.started.last?.count == 2)
        await provider.finish(20)
        try await second.value
        try await eventually { await provider.started.count == 4 }
        #expect(await provider.started.last?.key == 40)
        await provider.finish(30)
        await provider.finish(40)
        try await third.value
        try await fourth.value
        for task in duplicates { try await task.value }
        #expect(await provider.started.count == 4)
        #expect(await coordinator.upstreamFetchStatistics().active == 0)
        #expect(await coordinator.upstreamFetchStatistics().queued == 0)
    }

    @Test func failureReleasesPermitAndAllowsRetry() async throws {
        let fixture = try CacheFixture(limit: 1)
        let coordinator = fixture.coordinator
        let provider = ControlledProvider()
        let first = Task { try await read(coordinator, provider, key: 10, count: 2) }
        try await eventually { await provider.started.count == 1 }
        let second = Task { try await read(coordinator, provider, key: 20) }
        try await eventually { await coordinator.upstreamFetchStatistics().queued == 1 }
        await provider.finish(10, error: TestError.failed)
        await #expect(throws: TestError.failed) { try await first.value }
        try await eventually { await provider.started.count == 2 }
        await provider.finish(20)
        try await second.value

        let retry = Task { try await read(coordinator, provider, key: 10, count: 2) }
        try await eventually { await provider.started.count == 3 }
        await provider.finish(10)
        try await retry.value
        #expect(await coordinator.upstreamFetchStatistics().active == 0)
    }

    @Test func cancelledQueuedFetchDoesNotCallProviderOrLeakKeys() async throws {
        let fixture = try CacheFixture(limit: 1)
        let coordinator = fixture.coordinator
        let provider = ControlledProvider()
        let first = Task { try await read(coordinator, provider, key: 10) }
        try await eventually { await provider.started.count == 1 }
        let cancelled = Task { try await read(coordinator, provider, key: 20) }
        try await eventually { await coordinator.upstreamFetchStatistics().queued == 1 }
        cancelled.cancel()
        await provider.finish(10)
        try await first.value
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await provider.started.count == 1)
        #expect(await coordinator.upstreamFetchStatistics().active == 0)
        #expect(await coordinator.upstreamFetchStatistics().queued == 0)

        let retry = Task { try await read(coordinator, provider, key: 20) }
        try await eventually { await provider.started.count == 2 }
        await provider.finish(20)
        try await retry.value
    }
}

private enum TestError: Error { case failed, timedOut }

private func eventually(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw TestError.timedOut }
        try await Task.sleep(for: .milliseconds(1))
    }
}

private func read(
    _ coordinator: AtomicCacheCoordinator<MmapFile>,
    _ provider: ControlledProvider,
    key: UInt64,
    count: Int = 1
) async throws {
    try await coordinator.get(key: key, count: count, provider: { key, count in
        try await provider.fetch(key: key, count: count)
    }, dataCallback: { key, data in
        #expect(data.count == 64)
        #expect(data.allSatisfy { $0 == UInt8(truncatingIfNeeded: key) })
    })
}

private final class CacheFixture {
    let path: String
    let cache: AtomicBlockCache<MmapFile>
    let coordinator: AtomicCacheCoordinator<MmapFile>

    init(limit: Int) throws {
        path = FileManager.default.temporaryDirectory.appendingPathComponent("fetch-limit-\(UUID()).bin").path
        cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 256)
        coordinator = AtomicCacheCoordinator(cache: cache, maxConcurrentUpstreamFetches: limit)
    }

    deinit { try? FileManager.default.removeItem(atPath: path) }
}

private actor ControlledProvider {
    private(set) var started: [(key: UInt64, count: Int)] = []
    private var pending: [UInt64: CheckedContinuation<Void, any Error>] = [:]

    func fetch(key: UInt64, count: Int) async throws -> Data {
        started.append((key, count))
        try await withCheckedThrowingContinuation { pending[key] = $0 }
        return Data((0..<count).flatMap { block in
            Array(repeating: UInt8(truncatingIfNeeded: key + UInt64(block)), count: 64)
        })
    }

    func finish(_ key: UInt64, error: (any Error)? = nil) {
        let continuation = pending.removeValue(forKey: key)
        if let error { continuation?.resume(throwing: error) }
        else { continuation?.resume() }
    }
}
