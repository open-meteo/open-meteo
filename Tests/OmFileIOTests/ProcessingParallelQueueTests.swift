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

    @Test(arguments: [1, 2])
    func boundedEnqueueBackpressuresWhileConsumerDrains(concurrent: Int) async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: concurrent)
        let consumer = Task {
            var values = [Int]()
            for try await result in queue.results { values.append(result) }
            return values
        }
        let started = Signal()
        let gate = Signal()
        let enqueued = Signal()
        let producer = Task {
            for value in 0..<16 {
                try await queue.enqueue {
                    await started.increment()
                    await gate.wait()
                    return value
                }
                await enqueued.increment()
            }
        }
        await started.wait(for: concurrent)
        try await Task.sleep(for: .milliseconds(30))
        #expect(await enqueued.count == concurrent)
        #expect(await started.count == concurrent)
        await gate.increment()
        try await producer.value
        queue.finish()
        #expect(try await consumer.value.sorted() == Array(0..<16))
    }

    @Test func queuesRespectSharedExecutor() async throws {
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let queues = (0..<2).map { _ in ProcessingParallelQueue<Int>(concurrent: 2) }
        let started = Signal()
        let gate = Signal()
        for queue in queues {
            for value in 0..<2 {
                try await queue.enqueue {
                    await executor.execute {
                        await started.increment()
                        await gate.wait()
                        return value
                    }
                }
            }
        }
        await started.wait(for: 2)
        try await Task.sleep(for: .milliseconds(30))
        #expect(await started.count == 2)
        await gate.increment()
        for queue in queues {
            let consumer = Task {
                var values = [Int]()
                for try await result in queue.results { values.append(result) }
                return values
            }
            queue.finish()
            #expect(try await consumer.value.sorted() == [0, 1])
        }
    }

    @Test func cancellingBlockedEnqueueDoesNotCloseQueue() async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: 1)
        let consumer = Task {
            var values = [Int]()
            for try await result in queue.results { values.append(result) }
            return values
        }
        let started = Signal()
        let gate = Signal()
        try await queue.enqueue {
            await started.increment()
            await gate.wait()
            return 1
        }
        await started.wait()
        let producer = Task { try await queue.enqueue { 2 } }
        try await Task.sleep(for: .milliseconds(30))
        producer.cancel()
        await #expect(throws: CancellationError.self) { try await producer.value }
        await gate.increment()
        try await queue.enqueue { 3 }
        queue.finish()
        #expect(try await consumer.value.sorted() == [1, 3])
    }

    @Test(arguments: [false, true])
    func finishingDrainsEnqueuesAlreadyInProgress(cancelWaitingEnqueue: Bool) async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: 1)
        let gate = Signal()
        let entered = Signal()
        let admitted = Signal()
        let consumer = Task {
            var values = [Int]()
            for try await result in queue.results { values.append(result) }
            return values
        }
        try await queue.enqueue {
            await gate.wait()
            return 1
        }
        let producer = Task {
            await entered.increment()
            try await queue.enqueue { 2 }
            await admitted.increment()
        }
        await entered.wait()
        try await Task.sleep(for: .milliseconds(30))
        queue.finish()
        #expect(await admitted.count == 0)
        await #expect(throws: ProcessingQueueError.finished) { try await queue.enqueue { 3 } }
        if cancelWaitingEnqueue {
            producer.cancel()
            await #expect(throws: CancellationError.self) { try await producer.value }
        }
        await gate.increment()
        if !cancelWaitingEnqueue { try await producer.value }
        #expect(try await consumer.value == (cancelWaitingEnqueue ? [1] : [1, 2]))
    }

    final class Output: Sendable {
        let value: Int
        init(_ value: Int) { self.value = value }
    }

    @Test func completedWorkBackpressuresUntilDelivered() async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: 1)
        let completed = Signal()
        let admitted = Signal()
        try await queue.enqueue {
            await completed.increment()
            return 1
        }
        await completed.wait()
        let producer = Task {
            try await queue.enqueue { 2 }
            await admitted.increment()
            queue.finish()
        }
        try await Task.sleep(for: .milliseconds(30))
        #expect(await admitted.count == 0)
        var iterator = queue.results.makeAsyncIterator()
        let first = try #require(await iterator.next())
        #expect(try await iterator.next() == 2)
        try await producer.value
        #expect(await admitted.count == 1)
        #expect(try await iterator.next() == nil)
        #expect(first == 1)
    }

    @Test func retainedOutputsDoNotBlockDeliveryOrCompletion() async throws {
        try await ProcessingParallelQueue<Output>.withResults(
            inputs: [1, 2], concurrent: 1, work: { Output($0) }
        ) { results in
            var iterator = results.makeAsyncIterator()
            let first = try #require(await iterator.next())
            let last = try #require(await iterator.next())
            #expect(try await iterator.next() == nil)
            // Both outputs remain usable after EOF, even with a single worker.
            #expect(first.value == 1)
            #expect(last.value == 2)
        }
    }

    @Test func streamingDoesNotWaitForEarlierWork() async throws {
        let slowStarted = Signal()
        let slowStopped = Signal()
        let value = try await ProcessingParallelQueue<Int>.withResults(
            inputs: [0, 1], concurrent: 2,
            work: { value in
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
            return try await iterator.next()
        }
        #expect(value == 1)
        #expect(await slowStopped.count == 1)
    }

    @Test func boundedPipelineCompletes() async throws {
        let count = try await ProcessingParallelQueue<Int>.withResults(
            inputs: Array(0..<100), concurrent: 12,
            work: { $0 }
        ) { results in
            var count = 0
            for try await _ in results { count += 1 }
            return count
        }
        #expect(count == 100)
    }

    @Test func earlyReturnWakesCapacityWaiters() async throws {
        try await ProcessingParallelQueue<Int>.withResults(
            inputs: [0, 1, 2], concurrent: 3,
            work: { $0 }
        ) { results in
            var iterator = results.makeAsyncIterator()
            _ = try #require(await iterator.next())
        }
    }

    enum Failure: Error { case injected }

    @Test func queueFailureCancelsOtherWorkersAndWakesProducer() async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: 2)
        let started = Signal()
        let stopped = Signal()
        let fail = Signal()
        try await queue.enqueue {
            await started.increment()
            do { try await Task.sleep(for: .seconds(120)) } catch {
                await stopped.increment()
                throw error
            }
            return 0
        }
        try await queue.enqueue {
            await fail.wait()
            throw Failure.injected
        }
        await started.wait()
        let producer = Task { try await queue.enqueue { 2 } }
        await fail.increment()
        await #expect(throws: Failure.self) { try await producer.value }
        await #expect(throws: Failure.self) {
            for try await _ in queue.results { Issue.record("Unexpected result") }
        }
        queue.finish()
        await queue.waitForCompletion()
        #expect(await stopped.count == 1)
    }

    @Test func cancellingQueueDrainsWorkersAndWakesConsumer() async throws {
        let queue = ProcessingParallelQueue<Int>(concurrent: 1)
        let started = Signal()
        let stopped = Signal()
        try await queue.enqueue {
            await started.increment()
            do { try await Task.sleep(for: .seconds(120)) } catch {
                await stopped.increment()
                throw error
            }
            return 0
        }
        let consumer = Task {
            for try await _ in queue.results { Issue.record("Unexpected result") }
        }
        await started.wait()
        await queue.cancel()
        await #expect(throws: CancellationError.self) { try await consumer.value }
        await #expect(throws: CancellationError.self) { try await queue.enqueue { 1 } }
        #expect(await stopped.count == 1)
    }

    @Test func workerFailureWakesConsumer() async {
        await #expect(throws: Failure.self) {
            try await ProcessingParallelQueue<Int>.withResults(
                inputs: [0, 1], concurrent: 2,
                work: { _ in throw Failure.injected }
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
                inputs: [0, 1], concurrent: 1,
                work: { value in
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
                inputs: [0, 1], concurrent: 2,
                work: { $0 }
            ) { results in
                for try await _ in results { throw Failure.injected }
            }
        }
    }

    @Test func emptyInputCompletes() async throws {
        try await ProcessingParallelQueue<Int>.withResults(
            inputs: [Int](), concurrent: 2, work: { $0 }
        ) { results in
            for try await _ in results { Issue.record("Unexpected result") }
        }
    }
}
