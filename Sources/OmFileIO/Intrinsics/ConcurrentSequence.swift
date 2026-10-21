import Collections

/// Shared ownership makes dropping an iterator cancel its unconsumed work.
private final class PendingTasks<R: Sendable> {
    var tasks = Deque<Task<R, any Error>>()

    func cancelAll() {
        for task in tasks { task.cancel() }
        tasks.removeAll()
    }

    deinit {
        for task in tasks { task.cancel() }
    }
}

/// Execute an async mapping function over a Sequence concurrently
public struct ConcurrentAsyncMapSequence<T: Sequence, R>: AsyncSequence where T.Element: Sendable, R: Sendable {
    public typealias Element = R

    let sequence: T
    let fn: @Sendable (T.Element) async throws -> (R)
    let nConcurrent: Int

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: T.Iterator
        private let pending = PendingTasks<R>()
        let fn: @Sendable (T.Element) async throws -> R
        let nConcurrent: Int

        fileprivate init(iterator: T.Iterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) async throws -> R) {
            self.iterator = iterator
            self.fn = fn
            self.nConcurrent = nConcurrent
        }

        mutating public func next() async throws -> R? {
            do {
                try Task.checkCancellation()
                // Refill when the consumer asks for a result, not before yielding the previous one.
                // This bounds pending results plus the consumer's current result to nConcurrent.
                while pending.tasks.count < nConcurrent, let element = iterator.next() {
                    pending.tasks.append(Task { [fn] in
                        try Task.checkCancellation()
                        return try await fn(element)
                    })
                }
                guard let task = pending.tasks.popFirst() else { return nil }
                let result = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                try Task.checkCancellation()
                return result
            } catch {
                pending.cancelAll()
                throw error
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeIterator(), nConcurrent: nConcurrent, fn: fn)
    }
}

extension ConcurrentAsyncMapSequence: Sendable where T: Sendable {
    
}

public extension Sequence where Self.Element: Sendable {
    func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) async throws -> (R)) -> ConcurrentAsyncMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentAsyncMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
    }
    
    func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) async throws -> (R)) -> ConcurrentAsyncMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentAsyncMapSequence<Self, R>(sequence: self, fn: body, nConcurrent: nConcurrent)
    }
}

/// Execute a mapping function over a Sequence concurrently
public struct ConcurrentMapSequence<T: Sequence, R>: AsyncSequence where T.Element: Sendable, R: Sendable {
    public typealias Element = R

    let sequence: T
    let fn: @Sendable (T.Element) throws -> (R)
    let nConcurrent: Int

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: T.Iterator
        private let pending = PendingTasks<R>()
        let fn: @Sendable (T.Element) throws -> R
        let nConcurrent: Int

        fileprivate init(iterator: T.Iterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) throws -> R) {
            self.iterator = iterator
            self.fn = fn
            self.nConcurrent = nConcurrent
        }

        mutating public func next() async throws -> R? {
            do {
                try Task.checkCancellation()
                // Refill when the consumer asks for a result, not before yielding the previous one.
                // This bounds pending results plus the consumer's current result to nConcurrent.
                while pending.tasks.count < nConcurrent, let element = iterator.next() {
                    pending.tasks.append(Task { [fn] in
                        try Task.checkCancellation()
                        return try fn(element)
                    })
                }
                guard let task = pending.tasks.popFirst() else { return nil }
                let result = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                try Task.checkCancellation()
                return result
            } catch {
                pending.cancelAll()
                throw error
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeIterator(), nConcurrent: nConcurrent, fn: fn)
    }
}

extension ConcurrentMapSequence: Sendable where T: Sendable {
    
}

public extension Sequence where Self.Element: Sendable {
    /// Execute a mapping function over a Sequence concurrently
    func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) throws -> (R)) -> ConcurrentMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
    }
    
    /// Execute a mapping function over a Sequence concurrently
    func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) throws -> (R)) -> ConcurrentMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentMapSequence<Self, R>(sequence: self, fn: body, nConcurrent: nConcurrent)
    }
}
