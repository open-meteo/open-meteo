import Testing
@testable import OmFileIO

@Suite struct ConcurrentSequenceTests {
    enum Failure: Error { case expected }

    @Test func synchronousMappingPreservesOrderAndPropagatesErrors() async throws {
        let stream = Array(0..<20).mapStream(nConcurrent: 3) { value -> Int in value * 2 }
        var values = [Int]()
        for try await value in stream { values.append(value) }
        #expect(values == Array(0..<20).map { $0 * 2 })

        let failing = [0, 1, 2].mapStream(nConcurrent: 2) { value throws -> Int in
            if value == 1 { throw Failure.expected }
            return value
        }
        var iterator = failing.makeAsyncIterator()
        #expect(try await iterator.next() == 0)
        await #expect(throws: Failure.self) { _ = try await iterator.next() }
    }

    @Test func synchronousMappingChecksConsumerCancellation() async {
        let consumer = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let stream = [0].mapConcurrent(nConcurrent: 1) { value -> Int in
                Issue.record("Cancelled consumer must not start mapping")
                return value
            }
            for try await _ in stream {}
        }
        await #expect(throws: CancellationError.self) { try await consumer.value }
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true], [nil, 5] as [Int?])
    func stoppingStreamCancelsPendingWork(failInMapping: Bool, nBuffered: Int?) async throws {
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        var didThrow = false
        do {
            let stream = [0, 1].mapStream(nConcurrent: 2, nBuffered: nBuffered) { value in
                if value == 0 {
                    for await _ in started.stream { break }
                    if failInMapping { throw Failure.expected }
                    return value
                }
                started.continuation.yield(())
                started.continuation.finish()
                do {
                    try await Task.sleep(for: .seconds(60))
                    return value
                } catch {
                    cancelled.continuation.yield(())
                    cancelled.continuation.finish()
                    throw error
                }
            }
            for try await value in stream {
                #expect(value == 0)
                break
            }
        } catch Failure.expected {
            didThrow = true
        }
        #expect(didThrow == failInMapping)
        for await _ in cancelled.stream { break }
    }

    @Test(.timeLimit(.minutes(1)), arguments: [nil, 5] as [Int?])
    func cancellingConsumerCancelsActiveRead(nBuffered: Int?) async throws {
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        let consumer = Task {
            let stream = [0].mapStream(nConcurrent: 1, nBuffered: nBuffered) { value in
                started.continuation.yield(())
                started.continuation.finish()
                do {
                    try await Task.sleep(for: .seconds(60))
                    return value
                } catch {
                    cancelled.continuation.yield(())
                    cancelled.continuation.finish()
                    throw error
                }
            }
            for try await _ in stream {}
        }
        for await _ in started.stream { break }
        consumer.cancel()
        await #expect(throws: CancellationError.self) { try await consumer.value }
        for await _ in cancelled.stream { break }
    }

    private actor WorkCounter {
        var active = 0
        var peak = 0
        var completed = 0
        var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

        func start() {
            active += 1
            peak = max(peak, active)
        }

        func finish() {
            active -= 1
            completed += 1
            let ready = waiters.filter { completed >= $0.0 }
            waiters.removeAll { completed >= $0.0 }
            for (_, continuation) in ready { continuation.resume() }
        }

        func waitForCompleted(_ count: Int) async {
            if completed >= count { return }
            await withCheckedContinuation { waiters.append((count, $0)) }
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func buffersFiveResultsWhileRunningOnlyTwoJobs() async throws {
        let counter = WorkCounter()
        let stream = Array(0..<20).mapStream(nConcurrent: 2, nBuffered: 5) { value in
            await counter.start()
            // Vary completion order; the stream must still deliver input order.
            try await Task.sleep(for: .milliseconds(value.isMultiple(of: 2) ? 10 : 1))
            await counter.finish()
            return value
        }
        var iterator = stream.makeAsyncIterator()
        #expect(try await iterator.next() == 0)
        // Do not ask for another item: the five reserved slots must fill independently.
        await counter.waitForCompleted(6)
        #expect(await counter.completed == 6)
        #expect(await counter.active == 0)
        #expect(await counter.peak == 2)
        var values = [0]
        while let value = try await iterator.next() { values.append(value) }
        #expect(values == Array(0..<20))
        #expect(await counter.peak == 2)
        #expect(try await iterator.next() == nil)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [nil, 2] as [Int?])
    func defaultBufferMatchesConcurrency(nBuffered: Int?) async throws {
        let counter = WorkCounter()
        let stream = Array(0..<10).mapStream(nConcurrent: 2, nBuffered: nBuffered) { value in
            await counter.start()
            await counter.finish()
            return value
        }
        var iterator = stream.makeAsyncIterator()
        #expect(try await iterator.next() == 0)
        await counter.waitForCompleted(3)
        #expect(await counter.completed == 3)
        #expect(stream.nBuffered == 2)
    }

    @Test func smallBuffersAndEmptyInputs() async throws {
        let stream = [0, 1, 2].mapConcurrent(nConcurrent: 4, nBuffered: 1) { value async in value }
        var values = [Int]()
        for try await value in stream { values.append(value) }
        #expect(values == [0, 1, 2])
        let synchronous = [1, 2].mapStream(nConcurrent: 2, nBuffered: 5) { $0 * 2 }
        var synchronousValues = [Int]()
        for try await value in synchronous { synchronousValues.append(value) }
        #expect(synchronousValues == [2, 4])
        let empty = ConcurrentAsyncMapSequence(sequence: [Int](), fn: { $0 }, nConcurrent: 2, nBuffered: 5)
        var iterator = empty.makeAsyncIterator()
        #expect(try await iterator.next() == nil)
    }

}
