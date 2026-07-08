@testable import App
import Testing

@Suite struct LimitedConcurrencyExecutorTests {
    @Test func mapEnumeratedConcurrentDoesNotPrefetchPastExecutorCapacity() async throws {
        let nextCounter = Counter()
        let startCounter = Counter()
        let gate = Gate()
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let sequence = CountingAsyncSequence(count: 20, nextCounter: nextCounter)

        let task = Task {
            await sequence.mapEnumeratedConcurrent(executor: executor) { _, element in
                await startCounter.increment()
                await gate.wait()
                return element
            }
        }

        await startCounter.wait(untilAtLeast: executor.maxConcurrency)
        try await Task.sleep(nanoseconds: 50_000_000)
        let nextCalls = await nextCounter.value
        // The executor slot is acquired before reading the next async element.
        #expect(nextCalls == executor.maxConcurrency)

        await gate.open()
        let result = await task.value
        #expect(result == Array(0..<20))
    }

    @Test func mapEnumeratedConcurrentPropagatesChildErrors() async {
        enum TestError: Error {
            case failed
        }

        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let sequence = CountingAsyncSequence(count: 4, nextCounter: Counter())

        await #expect(throws: TestError.failed) {
            try await sequence.mapEnumeratedConcurrent(executor: executor) { _, element in
                if element == 2 {
                    throw TestError.failed
                }
                return element
            }
        }
    }

    @Test func mapEnumeratedConcurrentReleasesPermitWhenIteratorThrows() async {
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 1)
        let sequence = ThrowingAsyncSequence()

        await #expect(throws: IteratorTestError.failed) {
            try await sequence.mapEnumeratedConcurrent(executor: executor) { _, element in
                element
            }
        }

        let result = await executor.execute {
            42
        }
        #expect(result == 42)
    }

    @Test func processingParallelQueueLimitsStartedWorkAndCompletes() async throws {
        let executor = LimitedConcurrencyExecutor(maxConcurrency: 2)
        let queue = ProcessingParallelQueue<Int>(executor: executor)
        let startCounter = Counter()
        let gate = Gate()

        for value in 0..<20 {
            await queue.enqueue {
                await startCounter.increment()
                await gate.wait()
                return value
            }
        }

        await startCounter.wait(untilAtLeast: executor.maxConcurrency)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await startCounter.value == executor.maxConcurrency)

        let collectTask = Task {
            await queue.collect()
        }
        await gate.open()

        let results = await collectTask.value
        #expect(results.sorted() == Array(0..<20))
    }
}

private enum IteratorTestError: Error {
    case failed
}

private struct ThrowingAsyncSequence: AsyncSequence, Sendable {
    typealias Element = Int

    func makeAsyncIterator() -> Iterator {
        Iterator()
    }

    struct Iterator: AsyncIteratorProtocol {
        var current = 0

        mutating func next() async throws -> Int? {
            defer { current += 1 }
            if current == 0 {
                return 0
            }
            throw IteratorTestError.failed
        }
    }
}

private struct CountingAsyncSequence: AsyncSequence, Sendable {
    typealias Element = Int

    let count: Int
    let nextCounter: Counter

    func makeAsyncIterator() -> Iterator {
        Iterator(count: count, nextCounter: nextCounter)
    }

    struct Iterator: AsyncIteratorProtocol {
        let count: Int
        let nextCounter: Counter
        var current = 0

        mutating func next() async -> Int? {
            guard current < count else {
                return nil
            }
            let element = current
            current += 1
            await nextCounter.increment()
            return element
        }
    }
}

private actor Counter {
    private(set) var value = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func increment() {
        value += 1
        resumeWaiters()
    }

    func wait(untilAtLeast count: Int) async {
        guard value < count else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    private func resumeWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for waiter in waiters {
            if value >= waiter.0 {
                waiter.1.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }
}

private actor Gate {
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
