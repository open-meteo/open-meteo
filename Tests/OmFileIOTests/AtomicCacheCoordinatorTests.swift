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

private func eventually(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !(await condition()) {
        try #require(ContinuousClock.now < deadline, "Timed out waiting for scheduler state")
        await Task.yield()
    }
}

private final class PrefetchRecordingStorage: AtomicBlockCacheStorable {
    let storage: MmapFile

    init() throws {
        // Cache operations need stable shared memory, not concurrently mutated Data storage.
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let file = try FileHandle.createNewFile(file: path, size: (64 + 16) * 16, overwrite: true)
        defer { try? FileManager.default.removeItem(atPath: path) }
        storage = try MmapFile(fn: file, mode: .readWrite)
    }
    let ranges = Mutex<[Range<Int>]>([])
    var count: Int { storage.count }
    func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withMutableUnsafeBytes(body)
    }
    func prefetchData(offset: Int, count: Int) {
        ranges.withLock { $0.append(offset..<offset + count) }
    }
    func adviseData(offset: Int, count: Int, advice: MmapFile.MAdvice) {
        storage.adviseData(offset: offset, count: count, advice: advice)
    }
}

@Suite struct AtomicCacheCoordinatorTests {
    @Test(.timeLimit(.minutes(1)))
    func abandonedDownloadCanBeRetried() async throws {
        let coordinator = AtomicCacheCoordinator(cache: AtomicBlockCache(data: try PrefetchRecordingStorage(), blockSize: 64))
        let started = Mutex(false)
        let reader = Task {
            try await coordinator.get(key: 1, count: 1, provider: { _, _ in
                started.withLock { $0 = true }
                try await Task.sleep(for: .seconds(60))
                return Data(repeating: 0, count: 64)
            }, dataCallback: { _, _ in Issue.record("Cancelled download returned data") })
        }
        do {
            try await eventually { started.withLock { $0 } }
            reader.cancel()
            do { try await reader.value; Issue.record("Expected cancellation") } catch is CancellationError { }
            try await coordinator.get(key: 1, count: 1, provider: { _, _ in Data(repeating: 7, count: 64) },
                                      dataCallback: { _, bytes in #expect(Data(bytes) == Data(repeating: 7, count: 64)) })
        } catch {
            reader.cancel()
            _ = await reader.result
            throw error
        }
    }

    @Test
    func failedDownloadCanBeRetried() async throws {
        let coordinator = AtomicCacheCoordinator(cache: AtomicBlockCache(data: try PrefetchRecordingStorage(), blockSize: 64))
        do {
            try await coordinator.get(key: 1, count: 2, provider: { _, _ -> Data in
                throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
            }, dataCallback: { _, _ in Issue.record("Failed download returned data") })
            Issue.record("Expected failure")
        } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed { }
        try await coordinator.get(key: 1, count: 2, provider: { _, count in Data(repeating: 7, count: count * 64) },
                                  dataCallback: { _, bytes in #expect(Data(bytes) == Data(repeating: 7, count: 64)) })
    }

    @Test
    func warmingChunksRespectFileEndAndSuperBlocks() {
        let chunks = OmPreloadBlockChunks(ranges: [120..<160, 260..<280, 400..<410],
                                         blockCount: 270, superBlockLength: 128, chunkLength: 16)
        #expect(Array(chunks) == [120..<128, 128..<144, 144..<160, 260..<270])
    }

    @Test(.timeLimit(.minutes(1)))
    func demandPromotesQueuedPreloadAndSurvivesItsCancellation() async throws {
        let cache = AtomicBlockCache(data: try PrefetchRecordingStorage(), blockSize: 64)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        let executor = RemotePreloadExecutor(concurrency: 1)
        let admission = executor.admission
        let blocker = RemotePayloadDownload(owner: RemotePreloadSession(admission: admission, concurrency: 1))
        #expect(try await admission.acquire(blocker))
        let gate = DownloadGate()
        let downloads = Mutex(0)
        let preload = Task { @Sendable in
            try await executor.run(count: 1, concurrency: 1) { _ in
                do {
                    try await coordinator.get(key: 100, count: 1, prefetch: true, provider: { _, _ in
                        let job = try #require(RemotePayloadDownload.current)
                        let leased = try await admission.acquire(job)
                        downloads.withLock { $0 += 1 }
                        await gate.wait()
                        if leased { await admission.release(job) }
                        return Data(repeating: 7, count: 64)
                    }, dataCallback: { _, _ in })
                } catch is CancellationError { }
                catch { Issue.record("Unexpected preload failure: \(error)") }
            }
        }
        do {
            try await eventually { await admission.snapshot.queuedRequests == 1 }
            #expect(downloads.withLock { $0 } == 0)
            let demand = Task {
                try await coordinator.get(key: 100, count: 1, provider: { _, _ in
                    Issue.record("Demand must promote the existing download")
                    return Data(repeating: 0, count: 64)
                }, dataCallback: { _, bytes in #expect(Data(bytes) == Data(repeating: 7, count: 64)) })
            }
            try await eventually { downloads.withLock { $0 } == 1 }
            preload.cancel()
            await gate.open()
            try await demand.value
            do { try await preload.value; Issue.record("Expected stopped request") } catch is CancellationError { }
            #expect(downloads.withLock { $0 } == 1)
            #expect(cache.get(key: 100, count: 1) != nil)
            await admission.release(blocker)
        } catch {
            preload.cancel()
            await gate.open()
            await admission.release(blocker)
            _ = await preload.result
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1))) func prefetchReturnsBeforeDownloadAndDemandSharesIt() async throws {
        let cache = AtomicBlockCache(data: try PrefetchRecordingStorage(), blockSize: 64)
        let coordinator = AtomicCacheCoordinator(cache: cache, speculativeCapacity: 1)
        let gate = DownloadGate()
        let calls = Mutex(0)
        try await coordinator.get(key: 123, count: 2, prefetch: true, enqueueOnly: true, provider: { _, _ in
            calls.withLock { $0 += 1 }
            await gate.wait()
            return Data(repeating: 7, count: 128)
        }, dataCallback: { _, _ in Issue.record("Uncached prefetch must not wait for payloads") })
        // This line cannot be reached if discovery waits for the payload.
        #expect(cache.get(key: 123, count: 1) == nil)
        try await coordinator.get(key: 999, count: 1, prefetch: true, enqueueOnly: true, provider: { _, _ in
            Issue.record("Speculative backlog must stay bounded")
            return Data(repeating: 0, count: 64)
        }, dataCallback: { _, _ in })
        // Demand bypasses the full speculative backlog.
        try await coordinator.get(key: 999, count: 1, provider: { _, _ in Data(repeating: 9, count: 64) },
                                  dataCallback: { _, bytes in #expect(Data(bytes) == Data(repeating: 9, count: 64)) })
        await gate.open()
        try await coordinator.get(key: 123, count: 2, provider: { _, _ in
            Issue.record("Demand should share the registered download")
            return Data(repeating: 0, count: 128)
        }, dataCallback: { _, bytes in #expect(Data(bytes) == Data(repeating: 7, count: 64)) })
        #expect(calls.withLock { $0 } == 1)
    }

    @Test(.timeLimit(.minutes(1))) func fileModificationCompletionRacesWithWaiterRegistration() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let cache = try AtomicBlockCache(file: path, blockSize: 64, blockCount: 16)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        for iteration in 0..<200 {
            let readers = (0..<32).map { index in
                Task {
                    do {
                        try await coordinator.get(key: UInt64(index % 3), count: 3, provider: { _, _ -> Data in
                            await Task.yield()
                            if iteration % 2 == 0 { await Task.yield() }
                            throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
                        }, dataCallback: { _, _ in Issue.record("Failed fetch produced data") })
                        Issue.record("Expected file modification or cancellation")
                    } catch is CancellationError {
                    } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {
                    } catch {
                        Issue.record("Unexpected error: \(error)")
                    }
                }
            }
            for (index, reader) in readers.enumerated() where index % 3 == 0 { reader.cancel() }
            for reader in readers { await reader.value }
        }
    }

    @Test func cachedPrefetchUsesCacheStorageOffsets() async throws {
        let storage = try PrefetchRecordingStorage()
        let cache = AtomicBlockCache(data: storage, blockSize: 64)
        let reader = OmReaderBlockCache(backend: DataAsClass(data: Data(repeating: 7, count: 128)), cache: AtomicCacheCoordinator(cache: cache), cacheKey: 123)
        try await reader.prefetchData(offset: 0, count: 128)
        #expect(try await reader.getData(offset: 0, count: 128) == Data(repeating: 7, count: 128))
        try await reader.prefetchData(offset: 0, count: 128)
        #expect(storage.ranges.withLock { $0.count } == 1)
        for range in storage.ranges.withLock({ $0 }) {
            #expect(range.lowerBound >= 0)
            #expect(range.upperBound <= storage.count)
        }
        #expect(try await reader.getData(offset: 0, count: 128) == Data(repeating: 7, count: 128))
    }
}
