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

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func stoppingStreamCancelsPendingWork(failInMapping: Bool) async throws {
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        var didThrow = false
        do {
            let stream = [0, 1].mapStream(nConcurrent: 2) { value in
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

    @Test(.timeLimit(.minutes(1)))
    func cancellingConsumerCancelsActiveRead() async throws {
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        let consumer = Task {
            let stream = [0].mapStream(nConcurrent: 1) { value in
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
}
