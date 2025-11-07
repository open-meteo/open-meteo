import Foundation
import AsyncAlgorithms

/*extension Optional {
    func asyncMap<T>(
        _ transform: (WrappedType) async throws -> T
    ) async rethrows -> T? {
        guard let value = self else {
            return nil
        }
        return try await transform(value)
    }
}*/

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        values.reserveCapacity(self.underestimatedCount)
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
    
    func asyncFlatMap<T>(
        _ transform: (Element) async throws -> [T]
    ) async rethrows -> [T] {
        var values = [T]()
        values.reserveCapacity(self.underestimatedCount)
        for element in self {
            let transformed = try await transform(element)
            values.append(contentsOf: transformed)
        }
        return values
    }
    
    func asyncCompactMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()
        values.reserveCapacity(self.underestimatedCount)
        
        for element in self {
            guard let result = try await transform(element) else {
                continue
            }
            values.append(result)
        }
        return values
    }
}

extension Sequence where Element: Sendable {
    /// Execute a closure for each element concurrently
    /// `nConcurrent` limits the number of concurrent tasks
    func foreachConcurrent(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> Void
    ) async rethrows {
        assert(nConcurrent > 0)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, element) in self.enumerated() {
                if index >= nConcurrent {
                    _ = try await group.next()
                }
                group.addTask { try await body(element) }
            }
            try await group.waitForAll()
        }
    }
    
    /// Execute a closure for each element concurrently and return a new value
    /// `nConcurrent` limits the number of concurrent tasks
    /// Note: Results are ordered which may have a performance penalty
    func mapConcurrent<T: Sendable>(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> T
    ) async rethrows -> [T] {
        assert(nConcurrent > 0)
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results = [(Int, T)]()
            results.reserveCapacity(self.underestimatedCount)
            for (index, element) in self.enumerated() {
                if index >= nConcurrent, let result = try await group.next() {
                    results.append(result)
                }
                group.addTask { return (index, try await body(element)) }
            }
            while let result = try await group.next() {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}

extension Sequence where Element: Sendable, Self: Sendable {
    /// Execute a closure for each element concurrently and return a new value
    /// Returns an `AsyncThrowingChannel` to process in a pipeline and propagate back pressure
    /// `nConcurrent` limits the number of concurrent tasks
    /// Note: Results are ordered which may have a performance penalty
    func mapStream<T: Sendable>(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> T
    ) -> AsyncThrowingChannel<T, Error> {
        assert(nConcurrent > 0)
        
        let stream = AsyncThrowingChannel<T, Error>()
        _ = Task {
            do {
                try await withThrowingTaskGroup(of: (Int, T).self) { group in
                    var results = [Int: T]()
                    var pos = 0
                    for (index, element) in self.enumerated() {
                        if index >= nConcurrent, let result = try await group.next() {
                            results[result.0] = result.1
                            while let nextReturn = results.removeValue(forKey: pos) {
                                pos += 1
                                await stream.send(nextReturn)
                            }
                        }
                        group.addTask {
                            return (index, try await body(element))
                        }
                    }
                    while let result = try await group.next() {
                        results[result.0] = result.1
                        while let nextReturn = results.removeValue(forKey: pos) {
                            pos += 1
                            await stream.send(nextReturn)
                        }
                    }
                    stream.finish()
                }
            } catch {
                stream.fail(error)
            }
        }
        return stream
        // Version below does not support backpressure
        /*return AsyncThrowingStream<T, Error> { continuation in
            let task = Task {
                do {
                    try await withThrowingTaskGroup(of: (Int, T).self) { group in
                        var results = [Int: T]()
                        var pos = 0
                        for (index, element) in self.enumerated() {
                            if index >= nConcurrent, let result = try await group.next() {
                                results[result.0] = result.1
                                while let nextReturn = results.removeValue(forKey: pos) {
                                    pos += 1
                                    continuation.yield(nextReturn)
                                }
                            }
                            group.addTask {
                                return (index, try await body(element))
                            }
                        }
                        while let result = try await group.next() {
                            results[result.0] = result.1
                            while let nextReturn = results.removeValue(forKey: pos) {
                                pos += 1
                                continuation.yield(nextReturn)
                            }
                        }
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }*/
    }
    
    
    /// Execute a closure for each element sequentially and return a new value
    /// Returns an `AsyncStream` to process in a pipeline
    /*func mapStream<T: Sendable>(
        _ body: @escaping (Element) throws -> T
    ) -> AsyncThrowingStream<T, Error> {
        return AsyncThrowingStream<T, Error> { continuation in
            do {
                for (index, element) in self.enumerated() {
                    let result = try body(element)
                    continuation.yield(result)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }*/
}

extension AsyncSequence {
    func collect() async rethrows -> [Element] {
        var results = [Element]()
        for try await element in self {
            results.append(element)
        }
        return results
    }
}

extension AsyncSequence where Element: Sendable, Self: Sendable {
    /// Execute a closure for each element concurrently and return a new value
    /// Returns an `AsyncStream` to process in a pipeline
    /// `nConcurrent` limits the number of concurrent tasks
    /// Note: Results are ordered which may have a performance penalty
    func mapStream<T: Sendable>(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> T
    ) -> AsyncThrowingStream<T, Error> {
        assert(nConcurrent > 0)
        return AsyncThrowingStream<T, Error> { continuation in
            let task = Task {
                do {
                    try await withThrowingTaskGroup(of: (Int, T).self) { group in
                        var results = [Int: T]()
                        var readerIndex = 0
                        var writerIndex = 0
                        for try await element in self {
                            if writerIndex >= nConcurrent, let result = try await group.next() {
                                results[result.0] = result.1
                                while let nextReturn = results.removeValue(forKey: readerIndex) {
                                    readerIndex += 1
                                    continuation.yield(nextReturn)
                                }
                            }
                            let indexCopy = writerIndex
                            group.addTask {
                                return (indexCopy, try await body(element))
                            }
                            writerIndex += 1
                        }
                        while let result = try await group.next() {
                            results[result.0] = result.1
                            while let nextReturn = results.removeValue(forKey: readerIndex) {
                                readerIndex += 1
                                continuation.yield(nextReturn)
                            }
                        }
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Execute a closure for each element concurrently
    /// `nConcurrent` limits the number of concurrent tasks
    func foreachConcurrent(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> Void
    ) async rethrows {
        assert(nConcurrent > 0)
        try await withThrowingTaskGroup(of: Void.self) { group in
            var index = 0
            for try await element in self {
                if index >= nConcurrent {
                    _ = try await group.next()
                }
                group.addTask { try await body(element) }
                index += 1
            }
            try await group.waitForAll()
        }
    }
}

/// Thread safe dictionary
actor DictionaryActor<Key: Hashable, Value> {
    private var variables = [Key: Value]()

    func set(_ key: Key, _ value: Value) {
        variables[key] = value
    }

    func get(_ key: Key) -> Value? {
        return variables[key]
    }
}
