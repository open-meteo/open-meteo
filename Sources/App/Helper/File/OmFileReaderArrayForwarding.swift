import OmFileFormat

/// Implements the OM array-reader surface by forwarding every operation to another reader.
protocol OmFileReaderArrayForwarding: OmFileReaderArrayProtocol {
    var wrappedReader: any OmFileReaderArrayProtocol<OmType> { get }
}

extension OmFileReaderArrayForwarding {
    var compression: OmCompressionType { wrappedReader.compression }
    var scaleFactor: Float { wrappedReader.scaleFactor }
    var addOffset: Float { wrappedReader.addOffset }

    func withDimensions<R>(_ body: (_: UnsafeBufferPointer<UInt64>) -> R) -> R {
        wrappedReader.withDimensions(body)
    }

    func withChunkDimensions<R>(_ body: (_: UnsafeBufferPointer<UInt64>) -> R) -> R {
        wrappedReader.withChunkDimensions(body)
    }

    func getDimensionsCount() -> UInt64 { wrappedReader.getDimensionsCount() }
    func getDimensions() -> [UInt64] { wrappedReader.getDimensions() }
    func getChunkDimensions() -> [UInt64] { wrappedReader.getChunkDimensions() }

    func getDimensionsInline<let nDimensions: Int>() -> InlineArray<nDimensions, UInt64> {
        wrappedReader.getDimensionsInline()
    }

    func getChunkDimensionsInline<let nDimensions: Int>() -> InlineArray<nDimensions, UInt64> {
        wrappedReader.getChunkDimensionsInline()
    }

    func willNeed<let nDimensions: Int>(
        range: InlineArray<nDimensions, Range<UInt64>>
    ) async throws {
        try await wrappedReader.willNeed(range: range)
    }

    func willNeed<let nDimensions: Int>(
        offset: InlineArray<nDimensions, UInt64>,
        count: InlineArray<nDimensions, UInt64>
    ) async throws {
        try await wrappedReader.willNeed(offset: offset, count: count)
    }

    func read() async throws -> [OmType] {
        try await wrappedReader.read()
    }

    func read<let nDimensions: Int>(
        offset: InlineArray<nDimensions, UInt64>,
        count: InlineArray<nDimensions, UInt64>
    ) async throws -> [OmType] {
        try await wrappedReader.read(offset: offset, count: count)
    }

    func read<let nDimensions: Int>(
        range: InlineArray<nDimensions, Range<UInt64>>
    ) async throws -> [OmType] {
        try await wrappedReader.read(range: range)
    }

    func read<let nDimensions: Int>(
        into: UnsafeMutablePointer<OmType>,
        range: InlineArray<nDimensions, Range<UInt64>>,
        intoCubeOffset: InlineArray<nDimensions, UInt64>?,
        intoCubeDimension: InlineArray<nDimensions, UInt64>?
    ) async throws {
        try await wrappedReader.read(
            into: into,
            range: range,
            intoCubeOffset: intoCubeOffset,
            intoCubeDimension: intoCubeDimension
        )
    }

    func readConcurrent<let nDimensions: Int>(
        offset: InlineArray<nDimensions, UInt64>,
        count: InlineArray<nDimensions, UInt64>
    ) async throws -> [OmType] {
        try await wrappedReader.readConcurrent(offset: offset, count: count)
    }

    func readConcurrent<let nDimensions: Int>(
        range: InlineArray<nDimensions, Range<UInt64>>
    ) async throws -> [OmType] {
        try await wrappedReader.readConcurrent(range: range)
    }

    func readConcurrent<let nDimensions: Int>(
        into: UnsafeMutablePointer<OmType>,
        range: InlineArray<nDimensions, Range<UInt64>>,
        intoCubeOffset: InlineArray<nDimensions, UInt64>?,
        intoCubeDimension: InlineArray<nDimensions, UInt64>?
    ) async throws {
        try await wrappedReader.readConcurrent(
            into: into,
            range: range,
            intoCubeOffset: intoCubeOffset,
            intoCubeDimension: intoCubeDimension
        )
    }
}
