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
}
