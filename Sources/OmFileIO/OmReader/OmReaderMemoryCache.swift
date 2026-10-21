import Foundation
import OmFileFormat

/// Per-file metadata cache. Read compressed payloads from the underlying backend directly.
public actor OmReaderMemoryCache<Backend: OmFileReaderBackend>: OmFileReaderBackend {
    private let backend: Backend
    public nonisolated let count: Int
    private let blockSize = 4096
    private var blocks = [Int: Data]()

    public init(backend: Backend) {
        self.backend = backend
        self.count = backend.count
    }

    public func getData(offset: Int, count: Int) async throws -> Data {
        guard offset >= 0, count >= 0, offset <= self.count, count <= self.count - offset else {
            throw ReadError.outOfBounds
        }
        try Task.checkCancellation()
        guard count > 0 else { return Data() }
        let end = offset + count
        let lastBlock = (end - 1) / blockSize
        var block = offset / blockSize
        var result = Data()
        result.reserveCapacity(count)

        while block <= lastBlock {
            if blocks[block] == nil {
                // Fetch consecutive missing blocks together, including a partial block at EOF.
                var lastMissing = block
                while lastMissing < lastBlock, blocks[lastMissing + 1] == nil {
                    lastMissing += 1
                }
                let start = block * blockSize
                let lastStart = lastMissing * blockSize
                let readEnd = lastStart + min(blockSize, self.count - lastStart)
                let bytes = try await backend.getData(offset: start, count: readEnd - start)
                try bytes.withUnsafeBytes { buffer in
                    guard buffer.count == readEnd - start else { throw ReadError.shortRead }
                    for index in block...lastMissing {
                        let lower = (index - block) * blockSize
                        let upper = lower + min(blockSize, buffer.count - lower)
                        blocks[index] = Data(buffer[lower..<upper])
                    }
                }
            }
            let data = blocks[block]!
            let start = block * blockSize
            let lower = max(offset - start, 0)
            let upper = min(end - start, data.count)
            result.append(data[lower..<upper])
            block += 1
        }
        return result
    }

    public nonisolated func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let data = try await getData(offset: offset, count: count)
        return try data.withUnsafeBytes(fn)
    }

    public func prefetchData(offset: Int, count: Int) async throws {
        _ = try await getData(offset: offset, count: count)
    }

    enum ReadError: Error, Equatable {
        case outOfBounds
        case shortRead
    }
}
