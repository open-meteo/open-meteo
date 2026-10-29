import NIOCore
import OmFileIO

/// An immutable compressed batch. Its byte reservation follows its ARC lifetime.
final class BufferedGribBatch: Sendable {
    private let buffer: ByteBuffer
    private let budget: DownloadByteBudget

    fileprivate init(buffer: ByteBuffer, budget: DownloadByteBudget) {
        self.buffer = buffer
        self.budget = budget
    }

    /// Decode one GRIB field and retain this batch in each returned submessage.
    func decodeNext(at offset: inout Int) throws -> [BufferedGribMessage]? {
        guard offset < buffer.readableBytes else { return nil }
        return try buffer.withUnsafeReadableBytes { bytes in
            let remaining = UnsafeRawBufferPointer(rebasing: bytes[offset...])
            guard let seek = try GribAsyncStreamHelper.seekGrib(memory: remaining) else {
                throw GribAsyncStreamError.didNotFindGibHeader
            }
            guard seek.length > 0, seek.length <= remaining.count - seek.offset else {
                throw GribAsyncStreamError.unexpectedEndOfFile
            }
            let memory = UnsafeRawBufferPointer(rebasing: remaining[seek.offset..<seek.offset + seek.length])
            let messages = try GribAsyncStreamHelper.decodeMessages(memory: memory)
            offset += seek.offset + seek.length
            return messages.map { BufferedGribMessage(message: $0, download: self) }
        }
    }

    deinit {
        let budget = budget
        let bytes = buffer.readableBytes
        Task { await budget.release(bytes) }
    }
}

/// Own downloading, decoding and concurrent processing in one scope.
enum BufferedGribDownload {
    enum ValidationError: NonRetryError {
        case invalidRange(Range<Int>)
        case rangeExceedsBudget(bytes: Int, limit: Int)
        case unexpectedSize(expected: Int, actual: Int)
    }

    /// Returns the peak compressed-byte reservation, including messages retained by consumers.
    @discardableResult
    static func process(
        ranges: [Range<Int>], downloadConcurrent: Int, processingConcurrent: Int, byteLimit: Int,
        download: @escaping @Sendable (Range<Int>) async throws -> ByteBuffer,
        body: @escaping @Sendable (BufferedGribMessage) async throws -> Void
    ) async throws -> Int {
        precondition(processingConcurrent > 0)
        for range in ranges {
            guard range.lowerBound >= 0, !range.isEmpty else { throw ValidationError.invalidRange(range) }
            guard range.count <= byteLimit else { throw ValidationError.rangeExceedsBudget(bytes: range.count, limit: byteLimit) }
        }
        let budget = DownloadByteBudget(capacity: byteLimit)
        return try await ProcessingParallelQueue<BufferedGribBatch>.withResults(
            inputs: ranges, concurrent: downloadConcurrent,
            work: { range in
                try await budget.reserve(range.count)
                do {
                    let buffer = try await download(range)
                    guard buffer.readableBytes == range.count else {
                        throw ValidationError.unexpectedSize(expected: range.count, actual: buffer.readableBytes)
                    }
                    return BufferedGribBatch(buffer: buffer, budget: budget)
                } catch {
                    await budget.release(range.count)
                    throw error
                }
            }, body: { results in
                try await BufferedGribSequence(downloads: results).foreachConcurrent(nConcurrent: processingConcurrent) { message in
                    do {
                        try await body(message)
                    } catch {
                        // Interrupt an input wait so foreachConcurrent can observe the processing failure.
                        results.fail(error)
                        throw error
                    }
                }
                return await budget.peakBytes
            }
        )
    }
}

/// Private to downloading: reservations cover in-flight requests and all live compressed batches.
private actor DownloadByteBudget {
    let capacity: Int
    private(set) var reservedBytes = 0
    private(set) var peakBytes = 0
    private var waiters = [Int: CheckedContinuation<Void, any Error>]()
    private var nextWaiter = 0

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    func reserve(_ bytes: Int) async throws {
        precondition(bytes > 0 && bytes <= capacity)
        while true {
            try Task.checkCancellation()
            if bytes <= capacity - reservedBytes {
                reservedBytes += bytes
                peakBytes = max(peakBytes, reservedBytes)
                return
            }
            let id = nextWaiter
            nextWaiter += 1
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { waiters[id] = $0 }
            } onCancel: {
                Task { await self.cancelWaiter(id) }
            }
        }
    }

    func release(_ bytes: Int) {
        reservedBytes -= bytes
        let pending = waiters.values
        waiters.removeAll(keepingCapacity: true)
        for waiter in pending { waiter.resume() }
    }

    private func cancelWaiter(_ id: Int) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}
