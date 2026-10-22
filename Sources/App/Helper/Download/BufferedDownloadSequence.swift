import NIOCore
import OmFileIO

typealias BufferedDownload = ProcessingParallelQueue<ByteBuffer>.ResultLease

/// Download-specific validation; scheduling and backpressure live in ProcessingParallelQueue.
enum BufferedDownloadSequence {
    enum Failure: NonRetryError {
        case invalidRange(Range<Int>)
        case rangeExceedsBudget(bytes: Int, limit: Int)
        case unexpectedSize(expected: Int, actual: Int)
    }

    static func withDownloads<T>(
        ranges: [Range<Int>], concurrent: Int, byteLimit: Int, batchLimit: Int = 64,
        download: @escaping @Sendable (Range<Int>) async throws -> ByteBuffer,
        body: (ProcessingParallelQueue<ByteBuffer>.Results) async throws -> T
    ) async throws -> T {
        for range in ranges {
            guard range.lowerBound >= 0, !range.isEmpty else { throw Failure.invalidRange(range) }
            guard range.count <= byteLimit else { throw Failure.rangeExceedsBudget(bytes: range.count, limit: byteLimit) }
        }
        return try await ProcessingParallelQueue<ByteBuffer>.withResults(
            inputs: ranges, concurrent: concurrent, capacity: byteLimit, maxPending: batchLimit,
            cost: { $0.count }, work: { range in
                let buffer = try await download(range)
                guard buffer.readableBytes == range.count else {
                    throw Failure.unexpectedSize(expected: range.count, actual: buffer.readableBytes)
                }
                return buffer
            }, body: body
        )
    }
}
