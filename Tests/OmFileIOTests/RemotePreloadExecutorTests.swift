import Foundation
import Synchronization
import Testing
@testable import OmFileIO

private actor PreloadGate {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        open = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

private func waitForPreload(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() {
        try #require(ContinuousClock.now < deadline)
        try await Task.sleep(for: .milliseconds(1))
    }
}

private func preloadAttempt(_ operation: () async -> Void) async {
    guard let owner = RemotePreloadSession.current, let admission = owner.admission else {
        Issue.record("Missing preload admission context")
        return
    }
    let job = RemotePayloadDownload(owner: owner)
    do {
        let leased = try await admission.acquire(job)
        await operation()
        if leased { await admission.release(job) }
    } catch is CancellationError { }
    catch { Issue.record("Unexpected admission failure: \(error)") }
}

@Suite struct RemotePreloadExecutorTests {
    @Test(.timeLimit(.minutes(1)))
    func rotationYieldsBetweenChunksToRequestWork() async throws {
        let executor = RemotePreloadExecutor(concurrency: 1)
        let gate = PreloadGate()
        let log = Mutex<[String]>([])
        let warming = await executor.stage(key: "file", jobs: 0..<2) { chunk in
            await preloadAttempt {
                log.withLock { $0.append("warm\(chunk)") }
                if chunk == 0 { await gate.wait() }
            }
        }
        #expect(await executor.snapshot.activeWarmups == 0)
        await executor.activate(warming)
        let request = Task { @Sendable in
            try await waitForPreload { log.withLock { $0 == ["warm0"] } }
            try await executor.run(count: 1, concurrency: 1) { _ in
                await preloadAttempt { log.withLock { $0.append("request") } }
            }
        }
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while await executor.snapshot.queuedRequests == 0 {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
            #expect(await executor.snapshot.activeWarmups == 1)
            await gate.release()
            try await request.value
            try await waitForPreload { log.withLock { $0.count == 3 } }
            #expect(log.withLock { $0 } == ["warm0", "request", "warm1"])
            await executor.shutdown()
        } catch {
            request.cancel()
            await gate.release()
            await executor.shutdown()
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func warmingUsesSpareCapacityAndGivesAnotherFileTheNextSlot() async throws {
        let executor = RemotePreloadExecutor(concurrency: 4, warmingConcurrency: 3)
        let gates = (0..<6).map { _ in PreloadGate() }
        let otherGate = PreloadGate()
        let log = Mutex<[String]>([])
        let first = await executor.stage(key: "first", jobs: 0..<6) { chunk in
            await preloadAttempt {
                log.withLock { $0.append("first\(chunk)") }
                await gates[chunk].wait()
            }
        }
        await executor.activate(first)
        do {
            try await waitForPreload { log.withLock { $0.count == 3 } }
            #expect(log.withLock { Set($0) } == ["first0", "first1", "first2"])
            #expect(await executor.snapshot.activeWarmups == 3)
            let other = await executor.stage(key: "other", jobs: 0..<1) { _ in
                await preloadAttempt {
                    log.withLock { $0.append("other") }
                    await otherGate.wait()
                }
            }
            await executor.activate(other)
            await gates[0].release()
            try await waitForPreload { log.withLock { $0.count >= 4 } }
            #expect(log.withLock { $0.count } == 4)
            #expect(log.withLock { $0.last } == "other")
            #expect(await executor.snapshot.activeWarmups == 3)
            for gate in gates { await gate.release() }
            await otherGate.release()
            try await waitForPreload { log.withLock { $0.count == 7 } }
            await executor.shutdown()
        } catch {
            for gate in gates { await gate.release() }
            await otherGate.release()
            await executor.shutdown()
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func replacementStopsFutureChunksButFinishesActiveChunk() async throws {
        let executor = RemotePreloadExecutor(concurrency: 2, warmingConcurrency: 2)
        let gate = PreloadGate()
        let log = Mutex<[String]>([])
        let old = await executor.stage(key: "file", jobs: 0..<3) { chunk in
            log.withLock { $0.append("old\(chunk)") }
            await gate.wait()
            #expect(RemotePreloadSession.current?.isStopped == true)
            #expect(Task.isCancelled)
            log.withLock { $0.append("finished") }
        }
        await executor.activate(old)
        do {
            try await waitForPreload { log.withLock { Set($0) == ["old0", "old1"] } }
            let latest = await executor.stage(key: "file", jobs: 0..<1) { _ in
                log.withLock { $0.append("latest") }
            }
            await executor.activate(latest)
            #expect(await executor.snapshot.activeWarmups == 0) // No HTTP attempt in this chunk.
            #expect(await executor.snapshot.stoppedWarmups == 1)
            await gate.release()
            try await waitForPreload { log.withLock { $0.count == 5 } }
            #expect(log.withLock { $0.filter { $0 == "finished" }.count } == 2)
            #expect(log.withLock { Set($0) } == ["old0", "old1", "finished", "latest"])
            await executor.shutdown()
        } catch {
            await gate.release()
            await executor.shutdown()
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func stagingReplacesUnpublishedWorkAndBoundsPendingFiles() async throws {
        let executor = RemotePreloadExecutor(concurrency: 1, warmingCapacity: 1)
        let log = Mutex<[String]>([])
        let obsolete = await executor.stage(key: "file", jobs: 0..<1) { _ in log.withLock { $0.append("obsolete") } }
        let replaced = await executor.stage(key: "file", jobs: 0..<1) { _ in log.withLock { $0.append("replaced") } }
        let latest = await executor.stage(key: "another", jobs: 0..<1) { _ in log.withLock { $0.append("latest") } }
        await executor.activate(obsolete)
        await executor.activate(replaced)
        #expect(log.withLock { $0.isEmpty })
        #expect(await executor.snapshot.queuedWarmups == 0) // Staged traversal does not reserve HTTP capacity.
        #expect(await executor.snapshot.stoppedWarmups == 2)
        await executor.activate(latest)
        try await waitForPreload { log.withLock { !$0.isEmpty } }
        #expect(log.withLock { $0 } == ["latest"])
        await executor.shutdown()
    }

    @Test(.timeLimit(.minutes(1)))
    func cachedTraversalBypassesExhaustedHTTPCapacity() async throws {
        let executor = RemotePreloadExecutor(concurrency: 1)
        let gate = PreloadGate()
        let started = Mutex(false)
        let request = Task { @Sendable in
            try await executor.run(count: 1, concurrency: 1) { _ in
                await preloadAttempt {
                    started.withLock { $0 = true }
                    await gate.wait()
                }
            }
        }
        do {
            try await waitForPreload { started.withLock { $0 } }
            let visited = Mutex(0)
            try await executor.run(count: 20, concurrency: 3) { _ in visited.withLock { $0 += 1 } }
            #expect(visited.withLock { $0 } == 20)
            #expect(await executor.snapshot.activeRequests == 1)
            await gate.release()
            try await request.value
        } catch {
            request.cancel()
            await gate.release()
            _ = await request.result
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func admissionHonorsRequestCeilingAndDemandPromotionAcrossRetries() async throws {
        let admission = RemoteHTTPAdmission(concurrency: 2, warmingConcurrency: 1)
        let owner = RemotePreloadSession(admission: admission, concurrency: 1)
        let first = RemotePayloadDownload(owner: owner)
        #expect(try await admission.acquire(first))
        let queued = RemotePayloadDownload(owner: owner)
        let next = Task { try await admission.acquire(queued) }
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while await admission.snapshot.queuedRequests != 1 {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
            // A spare global permit does not override the request ceiling.
            #expect(await admission.snapshot.activeRequests == 1)
            await queued.promote()
            #expect(try await next.value == false)
            // Retry backoff holds no permit; a promoted retry still bypasses admission.
            #expect(try await admission.acquire(queued) == false)
            await first.promote()
            #expect(await admission.snapshot.activeRequests == 1)
            await admission.release(first)
            #expect(await admission.snapshot.activeRequests == 0)
        } catch {
            next.cancel()
            await admission.release(first)
            _ = await next.result
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func pendingRequestsTakeTurnsAndCancellationRemovesAdmission() async throws {
        let admission = RemoteHTTPAdmission(concurrency: 1, warmingConcurrency: 1)
        let a = RemotePreloadSession(admission: admission, concurrency: 2)
        let b = RemotePreloadSession(admission: admission, concurrency: 2)
        let first = RemotePayloadDownload(owner: a)
        #expect(try await admission.acquire(first))
        let second = RemotePayloadDownload(owner: a)
        let secondTask = Task { try await admission.acquire(second) }
        let third = RemotePayloadDownload(owner: b)
        var thirdTask: Task<Bool, Error>?
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while await admission.snapshot.queuedRequests != 1 {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
            let other = Task { try await admission.acquire(third) }
            thirdTask = other
            while await admission.snapshot.queuedRequests != 2 {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
            await admission.release(first)
            #expect(try await secondTask.value)
            // A rejoining the queue must go behind B's existing turn.
            let fourth = RemotePayloadDownload(owner: a)
            let cancelled = Task { try await admission.acquire(fourth) }
            while await admission.snapshot.queuedRequests != 2 {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
            await admission.release(second)
            #expect(try await other.value)
            cancelled.cancel()
            do { _ = try await cancelled.value; Issue.record("Expected cancellation") }
            catch is CancellationError { }
            await admission.release(third)
            #expect(await admission.snapshot.activeRequests == 0)
            #expect(await admission.snapshot.queuedRequests == 0)
        } catch {
            secondTask.cancel()
            thirdTask?.cancel()
            await admission.release(first)
            await admission.release(second)
            await admission.release(third)
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func slowJobDoesNotBlockLaterJobsAndPerCallLimitIsRespected() async throws {
        let executor = RemotePreloadExecutor(concurrency: 8)
        let gate = PreloadGate()
        let state = Mutex((active: 0, maximum: 0, finished: 0))
        let request = Task { @Sendable in
            try await executor.run(count: 30, concurrency: 2) { index in
                state.withLock { $0.active += 1; $0.maximum = max($0.maximum, $0.active) }
                if index == 0 { await gate.wait() }
                state.withLock { $0.active -= 1; $0.finished += 1 }
            }
        }
        do {
            try await waitForPreload { state.withLock { $0.finished == 29 } }
            #expect(state.withLock { $0.maximum } <= 2)
            await gate.release()
            try await request.value
            #expect(state.withLock { $0.finished } == 30)
        } catch {
            request.cancel()
            await gate.release()
            _ = await request.result
            throw error
        }
    }
}
