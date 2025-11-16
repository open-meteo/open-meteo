//import Collections
//
///// Execute an async mapping function over a AsyncSequence concurrently
//public struct AsyncConcurrentAsyncMapSequence<T: AsyncSequence, R>: AsyncSequence where T.Element: Sendable, R: Sendable {
//    public typealias Element = R
//
//    let sequence: T
//    let fn: @Sendable (T.Element) async throws -> (R)
//    let nConcurrent: Int
//
//    public struct AsyncIterator: AsyncIteratorProtocol {
//        /// Collect enough bytes to decompress a single message
//        var iterator: T.AsyncIterator
//        /// nil on startup, empty if all tasks have been completed
//        var tasks: Deque<Task<R, any Error>>? = nil
//        let fn: @Sendable (T.Element) async throws -> (R)
//        let nConcurrent: Int
//
//        fileprivate init(iterator: T.AsyncIterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) async throws -> (R)) {
//            self.iterator = iterator
//            self.fn = fn
//            self.nConcurrent = nConcurrent
//        }
//
//        mutating public func next() async throws -> R? {
//            if tasks == nil {
//                // fill initial task list
//                var tasks = Deque<Task<R, any Error>>(minimumCapacity: nConcurrent)
//                for _ in 0..<nConcurrent {
//                    guard let next = try await iterator.next() else {
//                        break
//                    }
//                    tasks.append(Task { [fn] in
//                        return try await fn(next)
//                    })
//                }
//                self.tasks = tasks
//            }
//            guard tasks?.isEmpty == false else {
//                return nil // all tasks completed
//            }
//            let result = try await tasks?.removeFirst().value
//            if tasks?.count == nConcurrent - 1 {
//                guard let next = try await iterator.next() else {
//                    return result
//                }
//                let task = Task { [fn] in
//                    return try await fn(next)
//                }
//                tasks?.append(task)
//            }
//            return result
//        }
//    }
//
//    public func makeAsyncIterator() -> AsyncIterator {
//        AsyncIterator(iterator: sequence.makeAsyncIterator(), nConcurrent: nConcurrent, fn: fn)
//    }
//}
//
//extension AsyncConcurrentAsyncMapSequence: Sendable where T: Sendable {
//    
//}
//
//extension AsyncSequence where Self.Element: Sendable {
//    public func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) async throws -> (R)) -> AsyncConcurrentAsyncMapSequence<Self, R> where R: Sendable {
//        precondition(nConcurrent > 0)
//        return AsyncConcurrentAsyncMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
//    }
//    
//    public func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) async throws -> (R)) -> AsyncConcurrentAsyncMapSequence<Self, R> where R: Sendable {
//        precondition(nConcurrent > 0)
//        return AsyncConcurrentAsyncMapSequence<Self, R>(sequence: self, fn: body, nConcurrent: nConcurrent)
//    }
//}
//
///// Execute a mapping function over a AsyncSequence concurrently
//public struct AsyncConcurrentMapSequence<T: AsyncSequence, R>: AsyncSequence where T.Element: Sendable, R: Sendable {
//    public typealias Element = R
//
//    let sequence: T
//    let fn: @Sendable (T.Element) throws -> (R)
//    let nConcurrent: Int
//
//    public struct AsyncIterator: AsyncIteratorProtocol {
//        /// Collect enough bytes to decompress a single message
//        var iterator: T.AsyncIterator
//        /// nil on startup, empty if all tasks have been completed
//        var tasks: Deque<Task<R, any Error>>? = nil
//        let fn: @Sendable (T.Element) throws -> (R)
//        let nConcurrent: Int
//
//        fileprivate init(iterator: T.AsyncIterator, nConcurrent: Int, fn: @Sendable @escaping (T.Element) throws -> (R)) {
//            self.iterator = iterator
//            self.fn = fn
//            self.nConcurrent = nConcurrent
//        }
//
//        mutating public func next() async throws -> R? {
//            if tasks == nil {
//                // fill initial task list
//                var tasks = Deque<Task<R, any Error>>(minimumCapacity: nConcurrent)
//                for _ in 0..<nConcurrent {
//                    guard let next = try await iterator.next() else {
//                        break
//                    }
//                    tasks.append(Task { [fn] in
//                        return try fn(next)
//                    })
//                }
//                self.tasks = tasks
//            }
//            guard tasks?.isEmpty == false else {
//                return nil // all tasks completed
//            }
//            let result = try await tasks?.removeFirst().value
//            if tasks?.count == nConcurrent - 1 {
//                guard let next = try await iterator.next() else {
//                    return result
//                }
//                let task = Task { [fn] in
//                    return try fn(next)
//                }
//                tasks?.append(task)
//            }
//            return result
//        }
//    }
//
//    public func makeAsyncIterator() -> AsyncIterator {
//        AsyncIterator(iterator: sequence.makeAsyncIterator(), nConcurrent: nConcurrent, fn: fn)
//    }
//}
//
//extension AsyncConcurrentMapSequence: Sendable where T: Sendable {
//    
//}
//
//extension AsyncSequence where Self.Element: Sendable {
//    /// Execute a mapping function over a AsyncSequence concurrently
//    public func mapConcurrent<R>(nConcurrent: Int, fn: @Sendable @escaping (Element) throws -> (R)) -> AsyncConcurrentMapSequence<Self, R> where R: Sendable {
//        precondition(nConcurrent > 0)
//        return AsyncConcurrentMapSequence<Self, R>(sequence: self, fn: fn, nConcurrent: nConcurrent)
//    }
//    
//    /// Execute a mapping function over a AsyncSequence concurrently
//    public func mapStream<R>(nConcurrent: Int, body: @Sendable @escaping (Element) throws -> (R)) -> AsyncConcurrentMapSequence<Self, R> where R: Sendable {
//        precondition(nConcurrent > 0)
//        return AsyncConcurrentMapSequence<Self, R>(sequence: self, fn: body, nConcurrent: nConcurrent)
//    }
//}
//
