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
            throw ElevationValuesError.unexpectedCount(expected: expectedCount, actual: decoded.count)
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

enum ElevationValuesError: Error, Equatable {
    case unexpectedCount(expected: Int, actual: Int)
}
