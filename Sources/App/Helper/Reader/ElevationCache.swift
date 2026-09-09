import OmFileFormat
import Synchronization

/// Immutable integer-metre elevations. Indexed reads never touch the OM reader or an actor.
final class ElevationValues: Sendable {
    enum EncodingError: Error, CustomStringConvertible {
        case notRepresentable(index: Int, value: Float)

        var description: String {
            switch self {
            case .notRepresentable(let index, let value):
                return "OM value at index \(index) cannot be represented losslessly as Int16: \(value)"
            }
        }
    }

    private static let nanSentinel = Int16.min

    private let values: [Int16]
    var count: Int { values.count }

    init(decoded: [Float], expectedCount: Int) throws {
        guard decoded.count == expectedCount else {
            throw ElevationCacheError.unexpectedCount(expected: expectedCount, actual: decoded.count)
        }
        values = try Self.encode(decoded)
    }

    subscript(pointID: Int) -> Float {
        Self.decode(values[pointID])
    }

    func read(pointIDs: InlineArray<10, Int>, count: Int) -> InlineArray<10, Float> {
        precondition(count > 0 && count <= 10, "Invalid elevation read count")
        var result = InlineArray<10, Float>(repeating: .nan)
        for position in 0..<count {
            result[position] = self[pointIDs[position]]
        }
        return result
    }

    static func encode(_ values: [Float]) throws -> [Int16] {
        var encoded = [Int16]()
        encoded.reserveCapacity(values.count)
        for (index, value) in values.enumerated() {
            if value.isNaN {
                encoded.append(nanSentinel)
                continue
            }
            guard
                value.isFinite,
                let integer = Int16(exactly: value),
                integer != nanSentinel
            else {
                throw EncodingError.notRepresentable(index: index, value: value)
            }
            encoded.append(integer)
        }
        return encoded
    }

    static func decode(_ value: Int16) -> Float {
        value == nanSentinel ? .nan : Float(value)
    }
}

enum ElevationCacheError: Error, Equatable {
    case unexpectedCount(expected: Int, actual: Int)
}

/// A lazy snapshot owned by the native grid. Successful loads are immutable; failed loads can be retried.
actor ElevationCache {
    private nonisolated let values = AtomicLazyReference<ElevationValues>()
    private let elementCount: Int
    private let loader: @Sendable () async throws -> [Float]
    private var loading: Task<ElevationValues, any Error>?

    nonisolated var cachedValues: ElevationValues? { values.load() }

    init(elementCount: Int, loader: @escaping @Sendable () async throws -> [Float]) {
        self.elementCount = elementCount
        self.loader = loader
    }

    init?(reader: any OmFileReaderArrayProtocol<Float>) {
        guard reader.compression == .pfor_delta2d_int16,
              reader.scaleFactor == 1, reader.addOffset == 0,
              reader.getDimensionsCount() == 2 else { return nil }
        let dimensions: InlineArray<2, UInt64> = reader.getDimensionsInline()
        guard dimensions[0] == 1, dimensions[1] > 0,
              dimensions[1] <= UInt64(Int.max) else { return nil }
        self.init(elementCount: Int(dimensions[1])) {
            try await reader.read(range: [0..<1, 0..<dimensions[1]])
        }
    }

    func loadValues() async throws -> ElevationValues {
        if let ready = cachedValues { return ready }
        let load: Task<ElevationValues, any Error>
        if let loading {
            load = loading
        } else {
            let loader = self.loader
            let count = elementCount
            // An individual waiter's cancellation must not cancel the shared load.
            load = Task {
                try await ElevationValues(decoded: loader(), expectedCount: count)
            }
            loading = load
        }
        do {
            let decoded = try await load.value
            if loading == load {
                _ = values.storeIfNil(decoded)
                loading = nil
            }
            return decoded
        } catch {
            // A delayed failure from an older attempt must not clear a newer load.
            if loading == load { loading = nil }
            throw error
        }
    }
}
