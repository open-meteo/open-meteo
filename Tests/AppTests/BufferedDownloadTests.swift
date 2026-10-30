import Foundation
import Testing
import OmFileIO
import NIOCore
@testable import App

@Suite(.timeLimit(.minutes(1)))
struct BufferedDownloadTests {
    actor Counter {
        var count = 0
        @discardableResult
        func increment() -> Int {
            count += 1
            return count
        }
    }

    actor RetainedMessage {
        var message: BufferedGribMessage?
        private var waiter: CheckedContinuation<Void, Never>?

        func retain(_ message: BufferedGribMessage) {
            self.message = message
            waiter?.resume()
            waiter = nil
        }

        func wait() async {
            if message != nil { return }
            await withCheckedContinuation { waiter = $0 }
        }

        func valueCount() throws -> Int { try message?.getDouble().count ?? 0 }
        func release() { message = nil }
    }

    @Test func batchesRespectGapsAndMessageBoundaries() throws {
        func entry(_ offset: Int, _ length: Int) -> Curl.EcmwfIndexEntry {
            .init(levtype: .sfc, levelist: nil, number: nil, param: "2t", _offset: offset, _length: length)
        }
        let entries = [entry(0, 4), entry(4, 4), entry(8, 4), entry(20, 12), entry(32, 4)]
        #expect(try entries.downloadBatches(targetBytes: 8) == [0..<8, 8..<12, 20..<32, 32..<36])
        #expect(throws: CurlMemoryDownloadError.self) {
            try [entry(Int.max, 4)].downloadBatches(targetBytes: 8)
        }
    }

    private static func sampleBuffer() throws -> ByteBuffer {
        // ecCodes regular_ll_sfc_grib2 sample: a small constant field.
        let data = try #require(Data(base64Encoded: "R1JJQv//AAIAAAAAAAAAswAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAfAAAAAABv///////////////////wAAABAAAAAfAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAAAAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAfAAAEOIkzMAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="))
        return ByteBuffer(bytes: data)
    }

    @Test func decoderRetainsCompressedBatchesThroughProcessing() async throws {
        let count = try Self.sampleBuffer().readableBytes
        let processed = Counter()
        let peak = try await BufferedGribDownload.process(
            ranges: [0..<count, count..<2 * count], downloadConcurrent: 2, processingConcurrent: 2, byteLimit: count,
            download: { _ in try Self.sampleBuffer() }
        ) { message in
            #expect(message.get(attribute: "shortName") != nil)
            await processed.increment()
            #expect(message.get(attribute: "shortName") != nil)
        }
        #expect(await processed.count == 2)
        #expect(peak == count)
    }

    @Test func messageOwnsBatchAndBackpressuresDownloads() async throws {
        let count = try Self.sampleBuffer().readableBytes
        let started = Counter()
        let processed = Counter()
        let retained = RetainedMessage()
        let task = Task {
            try await BufferedGribDownload.process(
                ranges: [0..<count, count..<2 * count], downloadConcurrent: 2, processingConcurrent: 2, byteLimit: count,
                download: { _ in
                    await started.increment()
                    return try Self.sampleBuffer()
                }
            ) { message in
                if await processed.increment() == 1 { await retained.retain(message) }
            }
        }
        await retained.wait()
        try await Task.sleep(for: .milliseconds(30))
        #expect(await started.count == 1)
        #expect(try await retained.valueCount() > 0)
        // The first callback has returned, but its retained message still blocks the next download.
        await retained.release()
        let peak = try await task.value
        #expect(await started.count == 2)
        #expect(await processed.count == 2)
        #expect(peak == count)
    }

    @Test func retainedMessageSurvivesDownloadScope() async throws {
        let count = try Self.sampleBuffer().readableBytes
        let retained = RetainedMessage()
        let peak = try await BufferedGribDownload.process(
            ranges: [0..<count], downloadConcurrent: 1, processingConcurrent: 1, byteLimit: count,
            download: { _ in try Self.sampleBuffer() }
        ) { message in
            await retained.retain(message)
        }
        let message = try #require(await retained.message)
        #expect(peak == count)
        #expect(message.get(attribute: "shortName") != nil)
        #expect(try message.getDouble().count > 0)
    }

    @Test func cancellationDrainsWorkersWaitingForByteCapacity() async throws {
        let count = try Self.sampleBuffer().readableBytes
        let retained = RetainedMessage()
        let task = Task {
            try await BufferedGribDownload.process(
                ranges: (0..<8).map { $0 * count..<($0 + 1) * count },
                downloadConcurrent: 2, processingConcurrent: 1, byteLimit: count,
                download: { _ in try Self.sampleBuffer() }
            ) { message in
                await retained.retain(message)
                try await Task.sleep(for: .seconds(120))
            }
        }
        await retained.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        // Cancellation drains the workers even though the retained message still owns the entire budget.
        #expect(try await retained.valueCount() > 0)
    }

    @Test func processingFailureWakesInputAndCancelsPendingDownloads() async throws {
        enum Failure: Error { case processing }
        let count = try Self.sampleBuffer().readableBytes
        await #expect(throws: Failure.self) {
            try await BufferedGribDownload.process(
                ranges: [0..<count, count..<2 * count], downloadConcurrent: 2, processingConcurrent: 1, byteLimit: 2 * count,
                download: { range in
                    if range.lowerBound > 0 {
                        try await Task.sleep(for: .seconds(120))
                    }
                    return try Self.sampleBuffer()
                }
            ) { _ in
                throw Failure.processing
            }
        }
    }

    @Test func incorrectDownloadedSizeFails() async {
        await #expect(throws: BufferedGribDownload.ValidationError.self) {
            try await BufferedGribDownload.process(
                ranges: [0..<4], downloadConcurrent: 1, processingConcurrent: 1, byteLimit: 4,
                download: { _ in ByteBuffer(repeating: 0, count: 5) }
            ) { _ in Issue.record("Invalid download must not be processed") }
        }
    }

    @Test func invalidSizesAndResponses() async throws {
        await #expect(throws: BufferedGribDownload.ValidationError.self) {
            try await BufferedGribDownload.process(ranges: [0..<9], downloadConcurrent: 1, processingConcurrent: 1, byteLimit: 8, download: { _ in ByteBuffer() }) { _ in }
        }
        try CurlMemoryDownloadError.validateSize(current: 4, additional: 4, limit: 8)
        #expect(throws: CurlMemoryDownloadError.self) {
            try CurlMemoryDownloadError.validateSize(current: 4, additional: 5, limit: 8)
        }
        try CurlMemoryDownloadError.validateRange(status: 206, contentRange: "bytes 4-7/8", expected: 4..<8)
        for (status, header) in [(200, "bytes 4-7/8"), (206, "bytes 0-7/8"), (206, "bytes 4-7/7")] {
            #expect(throws: CurlMemoryDownloadError.self) {
                try CurlMemoryDownloadError.validateRange(status: status, contentRange: header, expected: 4..<8)
            }
        }
    }
}
