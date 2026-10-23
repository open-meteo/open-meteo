import NIOCore
import OmFileIO
@preconcurrency import SwiftEccodes

struct BufferedGribMessage: Sendable {
    let message: GribMessage
    let download: BufferedDownload
}

/// Decode one batch incrementally. Each emitted message retains the batch's byte reservation.
struct BufferedGribSequence: AsyncSequence, Sendable {
    typealias Element = BufferedGribMessage
    let downloads: ProcessingParallelQueue<ByteBuffer>.Results

    struct AsyncIterator: AsyncIteratorProtocol {
        var downloads: ProcessingParallelQueue<ByteBuffer>.Results.AsyncIterator
        var current: BufferedDownload?
        var remaining = ByteBuffer()
        var messages = [GribMessage]()

        mutating func next() async throws -> BufferedGribMessage? {
            while true {
                try Task.checkCancellation()
                if let current, let message = messages.popLast() {
                    return BufferedGribMessage(message: message, download: current)
                }
                if remaining.readableBytes > 0 {
                    guard let seek = try remaining.withUnsafeReadableBytes(GribAsyncStreamHelper.seekGrib) else {
                        throw GribAsyncStreamError.didNotFindGibHeader
                    }
                    guard seek.length > 0, seek.length <= remaining.readableBytes - seek.offset else {
                        throw GribAsyncStreamError.unexpectedEndOfFile
                    }
                    messages = try remaining.withUnsafeReadableBytes {
                        // popLast() must yield submessages in inventory order.
                        Array(try GribAsyncStreamHelper.decodeMessages(memory: UnsafeRawBufferPointer(rebasing: $0[seek.offset..<seek.offset + seek.length])).reversed())
                    }
                    // Only move indices; the leased buffer must remain immutable for ecCodes.
                    remaining.moveReaderIndex(forwardBy: seek.offset + seek.length)
                    continue
                }
                remaining = ByteBuffer()
                current = nil
                guard let batch = try await downloads.next() else { return nil }
                current = batch
                remaining = batch.value
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(downloads: downloads.makeAsyncIterator())
    }
}
