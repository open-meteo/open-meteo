import Testing
@testable import OmFileIO

@Suite(.timeLimit(.minutes(1)))
struct ProcessingParallelQueueTests {
    actor Signal {
        var count = 0
        var waiters = [(Int, CheckedContinuation<Void, Never>)]()
        func increment() {
            count += 1
            let ready = waiters.filter { $0.0 <= count }
            waiters.removeAll { $0.0 <= count }
            for (_, waiter) in ready { waiter.resume() }
        }
        func wait(for target: Int = 1) async {
            if count >= target { return }
            await withCheckedContinuation { waiters.append((target, $0)) }
        }
    }

    @Test func boundedEnqueueBackpressuresAndCollects() async throws {
        let queue = ProcessingParallelQueue<Int>(executor: .init(maxConcurrency: 2), maxPending: 2)
        let started = Signal()
        let gate = Signal()
        let enqueued = Signal()
        let producer = Task {
            for value in 0..<8 {
                await queue.enqueue {
                    await started.increment()
                    await gate.wait()
                    return value
                }
                await enqueued.increment()
            }
        }
        await started.wait(for: 2)
        try await Task.sleep(for: .milliseconds(30))
        #expect(await enqueued.count == 2)
        await gate.increment()
        await producer.value
        #expect(await queue.collect().sorted() == Array(0..<8))
    }

    @Test func queuesRespectSharedExecutor() async throws {
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let queues = (0..<2).map { _ in ProcessingParallelQueue<Int>(executor: executor, maxPending: 2) }
        let started = Signal()
        let gate = Signal()
        for queue in queues {
            for value in 0..<2 {
                await queue.enqueue {
                    await started.increment()
                    await gate.wait()
                    return value
                }
            }
        }
        await started.wait(for: 2)
        try await Task.sleep(for: .milliseconds(30))
        #expect(await started.count == 2)
        await gate.increment()
        for queue in queues { #expect(await queue.collect().sorted() == [0, 1]) }
    }

    @Test func cancellingBlockedEnqueueDoesNotCloseQueue() async throws {
        let queue = ProcessingParallelQueue<Int>(executor: .init(maxConcurrency: 1), maxPending: 1)
        let started = Signal()
        let gate = Signal()
        await queue.enqueue {
            await started.increment()
            await gate.wait()
            return 1
        }
        await started.wait()
        let producer = Task { await queue.enqueue { 2 } }
        try await Task.sleep(for: .milliseconds(30))
        producer.cancel()
        await producer.value
        await gate.increment()
        await queue.enqueue { 3 }
        #expect(await queue.collect().sorted() == [1, 3])
    }

    @Test(arguments: [(capacity: 4, maxPending: 2), (capacity: 100, maxPending: 1)])
    func streamingRetainsCapacityUntilResultReleased(limits: (capacity: Int, maxPending: Int)) async throws {
        let started = Signal()
        try await ProcessingParallelQueue<Int>.withResults(
            inputs: [1, 2], concurrent: 2, capacity: limits.capacity, maxPending: limits.maxPending,
            cost: { _ in 4 }, work: { value in
                await started.increment()
                return value
            }
        ) { results in
            var iterator = results.makeAsyncIterator()
            var first = try await iterator.next()
            #expect(first?.value == 1)
            try await Task.sleep(for: .milliseconds(30))
            #expect(await started.count == 1)
            #expect(await results.reservedCost == 4)
            withExtendedLifetime(first) {}
            first = nil
            let second = try await iterator.next()
            #expect(second?.value == 2)
            #expect(await results.peakCost == 4)
        }
    }

    @Test func streamingDoesNotWaitForEarlierWork() async throws {
        let slowStarted = Signal()
        let slowStopped = Signal()
        let value = try await ProcessingParallelQueue<Int>.withResults(
            inputs: [0, 1], concurrent: 2, capacity: 2,
            cost: { _ in 1 }, work: { value in
                if value == 0 {
                    await slowStarted.increment()
                    do { try await Task.sleep(for: .seconds(120)) } catch {
                        await slowStopped.increment()
                        throw error
                    }
                }
                await slowStarted.wait()
                return value
            }
        ) { results in
            var iterator = results.makeAsyncIterator()
            return try await iterator.next()?.value
        }
        #expect(value == 1)
        #expect(await slowStopped.count == 1)
    }

    @Test func boundedPipelineCompletes() async throws {
        let count = try await ProcessingParallelQueue<Int>.withResults(
            inputs: Array(0..<100), concurrent: 12, capacity: 16, maxPending: 2,
            cost: { _ in 4 }, work: { $0 }
        ) { results in
            var count = 0
            for try await _ in results { count += 1 }
            #expect(await results.peakCost <= 8)
            return count
        }
        #expect(count == 100)
    }

    @Test func earlyReturnWakesCapacityWaiters() async throws {
        try await ProcessingParallelQueue<Int>.withResults(
            inputs: [0, 1, 2], concurrent: 3, capacity: 4,
            cost: { _ in 4 }, work: { $0 }
        ) { results in
            var iterator = results.makeAsyncIterator()
            _ = try #require(await iterator.next())
        }
    }

    enum Failure: Error { case injected }

    @Test func workerFailureWakesConsumer() async {
        await #expect(throws: Failure.self) {
            try await ProcessingParallelQueue<Int>.withResults(
                inputs: [0, 1], concurrent: 2, capacity: 4,
                cost: { _ in 4 }, work: { _ in throw Failure.injected }
            ) { results in
                for try await _ in results { }
            }
        }
    }

    @Test func cancellationWakesConsumerAndCapacityWaiters() async throws {
        let started = Signal()
        let stopped = Signal()
        let task = Task {
            try await ProcessingParallelQueue<Int>.withResults(
                inputs: [0, 1], concurrent: 2, capacity: 4,
                cost: { _ in 4 }, work: { value in
                    await started.increment()
                    do { try await Task.sleep(for: .seconds(120)) } catch {
                        await stopped.increment()
                        throw error
                    }
                    return value
                }
            ) { results in
                for try await _ in results { }
            }
        }
        await started.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await stopped.count == 1)
    }

    @Test func consumerFailureWakesCapacityWaiters() async {
        await #expect(throws: Failure.self) {
            try await ProcessingParallelQueue<Int>.withResults(
                inputs: [0, 1], concurrent: 2, capacity: 4,
                cost: { _ in 4 }, work: { $0 }
            ) { results in
                for try await _ in results { throw Failure.injected }
            }
        }
    }

    @Test func invalidCostFailsBeforeWork() async {
        for cost in [0, -1, 9] {
            await #expect(throws: ProcessingQueueError.self) {
                try await ProcessingParallelQueue<Int>.withResults(
                    inputs: [0], concurrent: 1, capacity: 8,
                    cost: { _ in cost }, work: { value in
                        Issue.record("Invalid-cost work must not run")
                        return value
                    }
                ) { results in
                    for try await _ in results { }
                }
            }
        }
    }

    @Test func emptyInputCompletes() async throws {
        try await ProcessingParallelQueue<Int>.withResults(
            inputs: [Int](), concurrent: 2, capacity: 4, cost: { _ in 1 }, work: { $0 }
        ) { results in
            for try await _ in results { Issue.record("Unexpected result") }
        }
    }
}
