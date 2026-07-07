@testable import App
import Testing

@Suite struct LimitedConcurrencyExecutorTests {
    @Test func mapEnumeratedConcurrentDoesNotPrefetchPastExecutorCapacity() async throws {
        let probe = SequenceProbe()
        let gate = AsyncGate()
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let sequence = CountingAsyncSequence(count: 20, probe: probe)

        let task = Task {
            await sequence.mapEnumeratedConcurrent(executor: executor) { _, element in
                await probe.recordBodyStart()
                await gate.wait()
                return element
            }
        }

        await probe.waitForBodyStarts(2)
        try await Task.sleep(nanoseconds: 50_000_000)
        let nextCalls = await probe.nextCalls
        // `for try await` reads the current element before the capacity check runs,
        // so one element over `maxConcurrency` is the documented bound.
        #expect(nextCalls <= executor.maxConcurrency + 1)

        await gate.open()
        let result = await task.value
        #expect(result == Array(0..<20))
    }

    @Test func mapEnumeratedConcurrentPropagatesChildErrors() async {
        enum TestError: Error {
            case failed
        }

        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let sequence = CountingAsyncSequence(count: 4, probe: SequenceProbe())

        await #expect(throws: TestError.failed) {
            try await sequence.mapEnumeratedConcurrent(executor: executor) { _, element in
                if element == 2 {
                    throw TestError.failed
                }
                return element
            }
        }
    }
}

private struct CountingAsyncSequence: AsyncSequence, Sendable {
    typealias Element = Int

    let count: Int
    let probe: SequenceProbe

    func makeAsyncIterator() -> Iterator {
        Iterator(count: count, probe: probe)
    }

    struct Iterator: AsyncIteratorProtocol {
        let count: Int
        let probe: SequenceProbe
        var current = 0

        mutating func next() async -> Int? {
            guard current < count else {
                return nil
            }
            let element = current
            current += 1
            await probe.recordNext()
            return element
        }
    }
}

private actor SequenceProbe {
    private(set) var nextCalls = 0
    private var bodyStarts = 0
    private var bodyStartWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func recordNext() {
        nextCalls += 1
    }

    func recordBodyStart() {
        bodyStarts += 1
        resumeBodyStartWaiters()
    }

    func waitForBodyStarts(_ count: Int) async {
        guard bodyStarts < count else {
            return
        }
        await withCheckedContinuation { continuation in
            bodyStartWaiters.append((count, continuation))
        }
    }

    private func resumeBodyStartWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for waiter in bodyStartWaiters {
            if bodyStarts >= waiter.0 {
                waiter.1.resume()
            } else {
                remaining.append(waiter)
            }
        }
        bodyStartWaiters = remaining
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiters = self.waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
