import Foundation

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
            try await values.append(contentsOf: transform(element))
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
                    let _ = try await group.next()
                }
                group.addTask { try await body(element) }
            }
            try await group.waitForAll()
        }
    }
    
    /// Execute a closure for each element concurrently and return a new value
    /// `nConcurrent` limits the number of concurrent tasks
    /// Note: Results are ordered which may have a performance penalty
    func mapConcurrent<T>(
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
            return results.sorted(by: {$0.0 < $1.0}).map{$0.1}
        }
    }
    
    /// Execute a closure for each element concurrently and return a new value
    /// Returns an `AsyncStream` to process in a pipeline
    /// `nConcurrent` limits the number of concurrent tasks
    /// Note: Results are ordered which may have a performance penalty
    func mapStream<T>(
        nConcurrent: Int,
        body: @escaping @Sendable (Element) async throws -> T
    ) -> AsyncThrowingStream<T, Error> {
        assert(nConcurrent > 0)
        return AsyncThrowingStream<T, Error> { continuation in
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
        }
    }
}

extension AsyncSequence {
    func collect() async rethrows -> [Element] {
        try await reduce(into: [Element]()) { $0.append($1) }
    }
}
