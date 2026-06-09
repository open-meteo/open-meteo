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
