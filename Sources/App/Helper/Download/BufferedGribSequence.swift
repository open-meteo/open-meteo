import OmFileIO
@preconcurrency import SwiftEccodes

/// Buffered messages retain their compressed batch; legacy messages have no batch reservation.
/// The raw handle never escapes this wrapper.
final class BufferedGribMessage: Sendable {
    private let message: GribMessage
    private let download: BufferedGribBatch?

    init(message: GribMessage, download: BufferedGribBatch) {
        self.message = message
        self.download = download
    }

    /// Wrap a message from the legacy full-file or multi-range download path.
    init(unbufferedMessage message: GribMessage) {
        self.message = message
        self.download = nil
    }

    func get(attribute: String) -> String? { message.get(attribute: attribute) }
    func getLong(attribute: String) -> Int? { message.getLong(attribute: attribute) }
    func getDouble() throws -> [Double] { try message.getDouble() }

    func load(into array: inout GribArray2D) throws {
        try array.load(message: message)
    }
}

/// Decode batches incrementally. Each emitted message owns its backing batch through ARC.
struct BufferedGribSequence: AsyncSequence, Sendable {
    typealias Element = BufferedGribMessage
    let downloads: ProcessingParallelQueue<BufferedGribBatch>.Results

    struct AsyncIterator: AsyncIteratorProtocol {
        var downloads: ProcessingParallelQueue<BufferedGribBatch>.Results.AsyncIterator
        var current: BufferedGribBatch?
        var offset = 0
        var messages = [BufferedGribMessage]()

        mutating func next() async throws -> BufferedGribMessage? {
            while true {
                try Task.checkCancellation()
                if let message = messages.popLast() { return message }
                if let current, let decoded = try current.decodeNext(at: &offset) {
                    // popLast() must yield submessages in inventory order.
                    messages = Array(decoded.reversed())
                    continue
                }
                current = nil
                guard let batch = try await downloads.next() else { return nil }
                current = batch
                offset = 0
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(downloads: downloads.makeAsyncIterator())
    }
}
