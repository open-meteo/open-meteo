import NIOCore
import OmFileFormat

/// Per-file metadata cache. Read compressed payloads from the underlying backend directly.
public actor OmReaderMemoryCache<Backend: OmFileReaderBackend>: OmFileReaderBackend {
    private let backend: Backend
    public nonisolated let count: Int
    private let blockSize = 4096
    private var blocks = [Int: ByteBuffer]()

    public init(backend: Backend) {
        self.backend = backend
        self.count = backend.count
    }

    public func getData(offset: Int, count: Int) async throws -> ByteBuffer {
        guard offset >= 0, count >= 0, offset <= self.count, count <= self.count - offset else {
            throw ReadError.outOfBounds
        }
        try Task.checkCancellation()
        guard count > 0 else { return ByteBuffer() }
        let end = offset + count
        let firstBlock = offset / blockSize
        let lastBlock = (end - 1) / blockSize
        let requestedBlocks = firstBlock...lastBlock
        if let firstMissing = requestedBlocks.first(where: { blocks[$0] == nil }),
           let lastMissing = requestedBlocks.last(where: { blocks[$0] == nil }) {
            // Skip cached ends, but include cached blocks between misses in the same request.
            let start = firstMissing * blockSize
            let lastStart = lastMissing * blockSize
            let readEnd = lastStart + min(blockSize, self.count - lastStart)
            let bytes = try await backend.getData(offset: start, count: readEnd - start)
            let buffer = bytes as? ByteBuffer ?? bytes.withUnsafeBytes { ByteBuffer(bytes: $0) }
            guard buffer.readableBytes == readEnd - start else { throw ReadError.shortRead }
            for block in firstMissing...lastMissing {
                let lower = (block - firstMissing) * blockSize
                let size = min(blockSize, buffer.readableBytes - lower)
                blocks[block] = buffer.getSlice(at: buffer.readerIndex + lower, length: size)!
            }
        }

        if firstBlock == lastBlock {
            let data = blocks[firstBlock]!
            return data.getSlice(at: data.readerIndex + offset % blockSize, length: count)!
        }
        var result = ByteBuffer()
        result.reserveCapacity(count)
        for block in requestedBlocks {
            let data = blocks[block]!
            let start = block * blockSize
            let lower = max(offset - start, 0)
            let upper = min(end - start, data.readableBytes)
            result.writeImmutableBuffer(data.getSlice(at: data.readerIndex + lower, length: upper - lower)!)
        }
        return result
    }

    public nonisolated func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let data = try await getData(offset: offset, count: count)
        return try data.withUnsafeReadableBytes(fn)
    }

    public func prefetchData(offset: Int, count: Int) async throws {
        _ = try await getData(offset: offset, count: count)
    }

    enum ReadError: Error, Equatable {
        case outOfBounds
        case shortRead
    }
}
