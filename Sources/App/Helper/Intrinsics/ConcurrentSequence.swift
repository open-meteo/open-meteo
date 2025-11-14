import Collections

/// Execute an async mapping function over a Sequence concurrently
public struct ConcurrentAsyncMapSequence<T: Sequence, R>: AsyncSequence where T.Element: Sendable, R: Sendable {
    public typealias Element = R

    let sequence: T
    let fn: @Sendable (T.Element) async throws -> (R)
    let nConcurrent: Int

    public struct AsyncIterator: AsyncIteratorProtocol {
        /// Collect enough bytes to decompress a single message
        var iterator: T.Iterator
        /// nil on startup, empty if all tasks have been completed
        var tasks: Deque<Task<R, any Error>>? = nil
        let fn: @Sendable (T.Element) async throws -> (R)
        let nConcurrent: Int

        fileprivate init(iterator: T.Iterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) async throws -> (R)) {
            self.iterator = iterator
            self.fn = fn
            self.nConcurrent = nConcurrent
        }

        mutating public func next() async throws -> R? {
            if tasks == nil {
                // fill initial task list
                var tasks = Deque<Task<R, any Error>>(minimumCapacity: nConcurrent)
                for _ in 0..<nConcurrent {
                    guard let next = iterator.next() else {
                        break
                    }
                    tasks.append(Task { [fn] in
                        return try await fn(next)
                    })
                }
                self.tasks = tasks
            }
            guard tasks?.isEmpty == false else {
                return nil // all tasks completed
            }
            let result = try await tasks?.removeFirst().value
            if tasks?.count == nConcurrent - 1 {
                guard let next = iterator.next() else {
                    return result
                }
                let task = Task { [fn] in
                    return try await fn(next)
                }
                tasks?.append(task)
            }
            return result
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeIterator(), nConcurrent: nConcurrent, fn: fn)
    }
}

extension ConcurrentAsyncMapSequence: Sendable where T: Sendable {
    
}

extension Sequence where Self.Element: Sendable {
    public func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) async throws -> (R)) -> ConcurrentAsyncMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentAsyncMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
    }
    
    public func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) async throws -> (R)) -> ConcurrentAsyncMapSequence<Self, R> where R: Sendable {
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
        /// Collect enough bytes to decompress a single message
        var iterator: T.Iterator
        /// nil on startup, empty if all tasks have been completed
        var tasks: Deque<Task<R, any Error>>? = nil
        let fn: @Sendable (T.Element) throws -> (R)
        let nConcurrent: Int

        fileprivate init(iterator: T.Iterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) throws -> (R)) {
            self.iterator = iterator
            self.fn = fn
            self.nConcurrent = nConcurrent
        }

        mutating public func next() async throws -> R? {
            if tasks == nil {
                // fill initial task list
                var tasks = Deque<Task<R, any Error>>(minimumCapacity: nConcurrent)
                for _ in 0..<nConcurrent {
                    guard let next = iterator.next() else {
                        break
                    }
                    tasks.append(Task { [fn] in
                        return try fn(next)
                    })
                }
                self.tasks = tasks
            }
            guard tasks?.isEmpty == false else {
                return nil // all tasks completed
            }
            let result = try await tasks?.removeFirst().value
            if tasks?.count == nConcurrent - 1 {
                guard let next = iterator.next() else {
                    return result
                }
                let task = Task { [fn] in
                    return try fn(next)
                }
                tasks?.append(task)
            }
            return result
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeIterator(), nConcurrent: nConcurrent, fn: fn)
    }
}

extension ConcurrentMapSequence: Sendable where T: Sendable {
    
}

extension Sequence where Self.Element: Sendable {
    /// Execute a mapping function over a Sequence concurrently
    public func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) throws -> (R)) -> ConcurrentMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
    }
    
    /// Execute a mapping function over a Sequence concurrently
    public func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) throws -> (R)) -> ConcurrentMapSequence<Self, R> where R: Sendable {
        precondition(nConcurrent > 0)
        return ConcurrentMapSequence<Self, R>(sequence: self, fn: body, nConcurrent: nConcurrent)
    }
}

