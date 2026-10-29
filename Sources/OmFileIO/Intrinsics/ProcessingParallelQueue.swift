import AsyncAlgorithms
import NIOConcurrencyHelpers

/// Executes jobs in completion order, with at most `concurrent` jobs running or awaiting delivery.
/// Consume results concurrently with enqueueing: both channels apply backpressure.
public final class ProcessingParallelQueue<T: Sendable>: Sendable {
    private let state = ProcessingQueueState<T>()
    private let processingTask: Task<Void, Never>

    public var results: Results { Results(state: state) }

    public init(concurrent: Int) {
        precondition(concurrent > 0)
        self.processingTask = Task { [state, concurrent] in
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for _ in 0..<concurrent {
                        group.addTask {
                            do {
                                for await work in state.jobs {
                                    try Task.checkCancellation()
                                    let result = try await work()
                                    await state.output.send(result)
                                    try Task.checkCancellation()
                                }
                            } catch {
                                state.fail(error)
                                throw error
                            }
                        }
                    }
                    while try await group.next() != nil { }
                }
                state.output.finish()
            } catch {
                state.fail(error)
            }
        }
    }

    /// Suspends until a worker accepts the job. Cancelling this call leaves the queue open.
    public func enqueue(_ work: @escaping @Sendable () async throws -> T) async throws {
        try state.beginEnqueue()
        defer { state.endEnqueue() }
        await state.jobs.send(work)
        try state.checkFailure()
    }

    /// Reject new submissions, drain enqueues already in progress, and join workers.
    /// The consumer must keep iterating concurrently.
    public func finish() async {
        state.finish()
        await processingTask.value
    }

    public func cancel() async {
        state.fail(CancellationError())
        processingTask.cancel()
        await processingTask.value
    }

    deinit {
        state.fail(CancellationError())
        processingTask.cancel()
    }

    public struct Results: AsyncSequence, Sendable {
        public typealias Element = T
        fileprivate let state: ProcessingQueueState<T>

        public func fail(_ error: any Error) { state.fail(error) }

        public struct AsyncIterator: AsyncIteratorProtocol {
            fileprivate var iterator: AsyncThrowingChannel<T, any Error>.Iterator
            fileprivate let state: ProcessingQueueState<T>

            public mutating func next() async throws -> T? {
                try state.checkFailure()
                let value = try await iterator.next()
                try state.checkFailure()
                return value
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(iterator: state.output.makeAsyncIterator(), state: state)
        }
    }

    /// Own the producer and workers until consumption finishes, fails or returns early.
    public static func withResults<Input: Sendable, Result>(
        inputs: [Input], concurrent: Int,
        work: @escaping @Sendable (Input) async throws -> T,
        body: (Results) async throws -> Result
    ) async throws -> Result {
        let queue = ProcessingParallelQueue(concurrent: concurrent)
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        for input in inputs {
                            try await queue.enqueue { try await work(input) }
                        }
                        await queue.finish()
                    } catch {
                        queue.state.fail(error)
                        throw error
                    }
                }
                do {
                    let result = try await body(queue.results)
                    try queue.state.checkFailure()
                    group.cancelAll()
                    await queue.cancel()
                    return result
                } catch {
                    queue.state.fail(error)
                    group.cancelAll()
                    await queue.cancel()
                    throw error
                }
            }
        } onCancel: {
            queue.state.fail(CancellationError())
            queue.processingTask.cancel()
        }
    }
}

public enum ProcessingQueueError: Error {
    case finished
}

/// Channels own scheduling and waiters. Admission tracking keeps input open until accepted sends finish.
private final class ProcessingQueueState<T: Sendable>: Sendable {
    let jobs = AsyncChannel<@Sendable () async throws -> T>()
    let output = AsyncThrowingChannel<T, any Error>()
    private let status = NIOLockedValueBox((finished: false, enqueuing: 0, failure: Optional<any Error>.none))

    func checkFailure() throws {
        try Task.checkCancellation()
        if let error = status.withLockedValue({ $0.failure }) { throw error }
    }

    func beginEnqueue() throws {
        try Task.checkCancellation()
        try status.withLockedValue { status in
            if let error = status.failure { throw error }
            guard !status.finished else { throw ProcessingQueueError.finished }
            status.enqueuing += 1
        }
    }

    func endEnqueue() {
        let closeInput = status.withLockedValue { status in
            status.enqueuing -= 1
            return status.finished && status.enqueuing == 0
        }
        if closeInput { jobs.finish() }
    }

    func finish() {
        let closeInput = status.withLockedValue { status in
            status.finished = true
            return status.enqueuing == 0
        }
        if closeInput { jobs.finish() }
    }

    func fail(_ error: any Error) {
        let failure = status.withLockedValue { status in
            status.finished = true
            if status.failure == nil { status.failure = error }
            return status.failure!
        }
        // Abort immediately, including sends suspended before input was closed.
        jobs.finish()
        output.fail(failure)
    }
}
