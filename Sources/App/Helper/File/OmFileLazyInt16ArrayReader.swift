import Foundation
import OmFileFormat

/// Random-access capability for float readers that can serve several flattened positions at once.
protocol OmFileIndexedFloatReaderProtocol: Sendable {
    func read(pointID: Int) async throws -> Float
    func read(
        pointIDs: InlineArray<10, Int>,
        count: Int
    ) async throws -> InlineArray<10, Float>
}

/// Provides compact, lazy random access to an integer-metre `[1, n]` float array.
///
/// Ordinary OM operations remain unchanged. Only the indexed capability uses the decoded cache.
final class OmFileLazyInt16ArrayReader:
    OmFileReaderArrayForwarding,
    OmFileIndexedFloatReaderProtocol,
    Sendable
{
    typealias OmType = Float

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

    let wrappedReader: any OmFileReaderArrayProtocol<Float>
    private let elementCount: Int
    private let cache: OmFileLazyInt16ArrayCache

    init?(wrapping reader: any OmFileReaderArrayProtocol<Float>) {
        guard
            reader.compression == .pfor_delta2d_int16,
            reader.scaleFactor == 1,
            reader.addOffset == 0,
            reader.getDimensionsCount() == 2
        else {
            return nil
        }
        let dimensions: InlineArray<2, UInt64> = reader.getDimensionsInline()
        guard
            dimensions[0] == 1,
            dimensions[1] > 0,
            dimensions[1] <= UInt64(Int.max)
        else {
            return nil
        }
        let elementCount = Int(dimensions[1])
        wrappedReader = reader
        self.elementCount = elementCount
        cache = OmFileLazyInt16ArrayCache(reader: reader, elementCount: elementCount)
    }

    func read(pointID: Int) async throws -> Float {
        precondition(pointID >= 0 && pointID < elementCount, "OM array index out of range")
        return Self.decode(try await cache.values()[pointID])
    }

    func read(
        pointIDs: InlineArray<10, Int>,
        count: Int
    ) async throws -> InlineArray<10, Float> {
        precondition(count > 0 && count <= 10, "Invalid indexed OM read count")
        for position in 0..<count {
            precondition(
                pointIDs[position] >= 0 && pointIDs[position] < elementCount,
                "OM array index out of range"
            )
        }

        let values = try await cache.values()
        var result = InlineArray<10, Float>(repeating: Self.decode(values[pointIDs[0]]))
        for position in 0..<count {
            result[position] = Self.decode(values[pointIDs[position]])
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

private actor OmFileLazyInt16ArrayCache {
    private enum State: Sendable {
        case empty
        case loading(Task<[Int16], any Error>)
        case ready([Int16])
    }

    private let reader: any OmFileReaderArrayProtocol<Float>
    private let elementCount: Int
    private var state = State.empty

    init(
        reader: any OmFileReaderArrayProtocol<Float>,
        elementCount: Int
    ) {
        self.reader = reader
        self.elementCount = elementCount
    }

    func values() async throws -> [Int16] {
        let load: Task<[Int16], any Error>
        switch state {
        case .ready(let values):
            return values
        case .loading(let activeLoad):
            load = activeLoad
        case .empty:
            let reader = self.reader
            let elementCount = self.elementCount
            load = Task {
                let decoded = try await reader.read(
                    range: [0..<1, 0..<UInt64(elementCount)]
                )
                return try OmFileLazyInt16ArrayReader.encode(decoded)
            }
            state = .loading(load)
        }

        do {
            let values = try await load.value
            if case .loading(let activeLoad) = state, activeLoad == load {
                state = .ready(values)
            }
            return values
        } catch {
            if case .loading(let activeLoad) = state, activeLoad == load {
                state = .empty
            }
            throw error
        }
    }
}
