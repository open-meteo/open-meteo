import Logging
import Collections

/// Executes jobs in completion order. Optional backpressure bounds pending and active work.
/// Collected results are retained until collect(); use withResults for large, bounded results.
public final class ProcessingParallelQueue<T: Sendable>: Sendable {
    private let state: ProcessingQueueState<T>
    private let processingTask: Task<Void, Never>
    private let onError: @Sendable () -> Void

    public init(executor: LimitedConcurrencyExecutor, maxPending: Int? = nil, onError: @escaping @Sendable () -> Void = {}) {
        let state = ProcessingQueueState<T>(capacity: maxPending ?? Int.max, maxPending: maxPending ?? Int.max, streaming: false)
        self.state = state
        self.onError = onError
        self.processingTask = Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<executor.maxConcurrency {
                    group.addTask { try? await state.run(executor: executor) }
                }
            }
        }
    }

    /// With maxPending configured, suspends until pending/active work has capacity.
    public func enqueue(_ work: @escaping @Sendable () async -> T) async {
        do { try await state.enqueue(cost: 1, work: work) } catch { onError() }
    }

    public func enqueueIgnoreError(logger: Logger, _ work: @escaping @Sendable () async throws -> T) async {
        let onError = onError
        do {
            try await state.enqueue(cost: 1) {
                do { return try await work() } catch {
                    logger.error("Error during queued work: \(error)")
                    onError()
                    return nil
                }
            }
        } catch { onError() }
    }

    public func collect() async -> [T] {
        await state.finish()
        await processingTask.value
        return await state.collected
    }

    deinit {
        let state = state
        Task { await state.finish() }
    }

    /// A reservation follows the result through consumption, including tasks retaining it.
    /// Retain the lease (not just its value) for as long as processing needs that capacity.
    public final class ResultLease: Sendable {
        public let value: T
        private let id: Int
        private let state: ProcessingQueueState<T>

        fileprivate init(value: T, id: Int, state: ProcessingQueueState<T>) {
            self.value = value
            self.id = id
            self.state = state
        }

        deinit {
            let state = state
            let id = id
            Task { await state.release(id: id) }
        }
    }

    public struct Results: AsyncSequence, Sendable {
        public typealias Element = ResultLease
        fileprivate let state: ProcessingQueueState<T>

        public var peakCost: Int { get async { await state.peakCost } }
        public var reservedCost: Int { get async { await state.reservedCost } }

        public func fail(_ error: any Error) async { await state.fail(error) }

        public struct AsyncIterator: AsyncIteratorProtocol {
            fileprivate let state: ProcessingQueueState<T>
            public mutating func next() async throws -> ResultLease? {
                guard let item = try await state.next() else { return nil }
                return ResultLease(value: item.value, id: item.id, state: state)
            }
        }

        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(state: state) }
    }

    /// Reserve cost before work starts and hold it until the consumer releases the result.
    /// All workers are cancelled and drained on failure, cancellation or early consumer return.
    public static func withResults<Input: Sendable, Result>(
        inputs: [Input], concurrent: Int, capacity: Int, maxPending: Int = 64,
        cost: @escaping @Sendable (Input) -> Int,
        work: @escaping @Sendable (Input) async throws -> T,
        body: (Results) async throws -> Result
    ) async throws -> Result {
        precondition(concurrent > 0)
        let state = ProcessingQueueState<T>(capacity: capacity, maxPending: maxPending, streaming: true)
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        for input in inputs {
                            try await state.enqueue(cost: cost(input)) { try await work(input) }
                        }
                        await state.finish()
                    } catch {
                        await state.fail(error)
                        throw error
                    }
                }
                for _ in 0..<min(concurrent, inputs.count) {
                    group.addTask { try await state.run() }
                }
                do {
                    let result = try await body(Results(state: state))
                    try await state.checkFailure()
                    await state.fail(CancellationError())
                    group.cancelAll()
                    while let _ = await group.nextResult() { }
                    return result
                } catch {
                    await state.fail(error)
                    group.cancelAll()
                    throw error
                }
            }
        } onCancel: {
            Task { await state.fail(CancellationError()) }
        }
    }
}

public enum ProcessingQueueError: Error {
    case invalidCost(Int)
    case costExceedsCapacity(cost: Int, capacity: Int)
    case finished
}

/// Shared scheduler for collecting queues and scoped streaming consumers.
private actor ProcessingQueueState<T: Sendable> {
    struct Job: Sendable {
        let id: Int
        let work: @Sendable () async throws -> T?
    }
    let capacity: Int
    let maxPending: Int
    let streaming: Bool
    private var pending = Deque<Job>()
    private var ready = Deque<(id: Int, value: T)>()
    private var reservations = [Int: Int]()
    private var waiters = [Int: CheckedContinuation<Void, any Error>]()
    private var nextWaiter = 0
    private var nextID = 0
    private var finished = false
    private var failure: (any Error)?
    private(set) var collected = [T]()
    private(set) var reservedCost = 0
    private(set) var peakCost = 0

    init(capacity: Int, maxPending: Int, streaming: Bool) {
        precondition(capacity > 0 && maxPending > 0)
        self.capacity = capacity
        self.maxPending = maxPending
        self.streaming = streaming
    }

    func checkFailure() throws {
        try Task.checkCancellation()
        if let failure { throw failure }
    }

    func enqueue(cost: Int, work: @escaping @Sendable () async throws -> T?) async throws {
        guard cost > 0 else { throw ProcessingQueueError.invalidCost(cost) }
        guard cost <= capacity else { throw ProcessingQueueError.costExceedsCapacity(cost: cost, capacity: capacity) }
        while true {
            try checkFailure()
            guard !finished else { throw ProcessingQueueError.finished }
            if reservations.count < maxPending && cost <= capacity - reservedCost {
                let id = nextID
                nextID += 1
                reservations[id] = cost
                reservedCost += cost
                peakCost = max(peakCost, reservedCost)
                pending.append(Job(id: id, work: work))
                wakeWaiters()
                return
            }
            try await wait()
        }
    }

    private func take() async throws -> Job? {
        while true {
            try checkFailure()
            if !pending.isEmpty { return pending.removeFirst() }
            if finished { return nil }
            try await wait()
        }
    }

    func run(executor: LimitedConcurrencyExecutor? = nil) async throws {
        do {
            while let job = try await take() {
                let value: T?
                if let executor {
                    value = try await executor.execute { try await job.work() }
                } else {
                    value = try await job.work()
                }
                try checkFailure()
                if let value {
                    if streaming { ready.append((job.id, value)) } else { collected.append(value) }
                }
                if !streaming || value == nil { release(id: job.id) }
                wakeWaiters()
            }
        } catch {
            fail(error)
            throw error
        }
    }

    func next() async throws -> (id: Int, value: T)? {
        while true {
            try checkFailure()
            if !ready.isEmpty { return ready.removeFirst() }
            if finished && reservations.isEmpty { return nil }
            try await wait()
        }
    }

    func release(id: Int) {
        if let cost = reservations.removeValue(forKey: id) { reservedCost -= cost }
        wakeWaiters()
    }

    func finish() {
        finished = true
        wakeWaiters()
    }

    func fail(_ error: any Error) {
        if failure == nil { failure = error }
        pending.removeAll()
        ready.removeAll()
        reservations.removeAll()
        reservedCost = 0
        wakeWaiters()
    }

    private func wait() async throws {
        let id = nextWaiter
        nextWaiter += 1
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { waiters[id] = $0 }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    private func cancelWaiter(id: Int) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func wakeWaiters() {
        let pending = waiters.values
        waiters.removeAll(keepingCapacity: true)
        for continuation in pending { continuation.resume() }
    }
}
