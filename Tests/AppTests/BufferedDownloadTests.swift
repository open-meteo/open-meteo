import Foundation
import Testing
import OmFileIO
import NIOCore
@testable import App

@Suite(.timeLimit(.minutes(1)))
struct BufferedDownloadTests {
    actor Counter {
        var count = 0
        func increment() { count += 1 }
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
        let buffer = try Self.sampleBuffer()
        let count = buffer.readableBytes
        let processed = Counter()
        try await BufferedDownloadSequence.withDownloads(
            ranges: [0..<count, count..<2 * count], concurrent: 2, byteLimit: count,
            download: { _ in buffer }
        ) { downloads in
            try await BufferedGribSequence(downloads: downloads).process(concurrent: 2) { message in
                #expect(message.get(attribute: "shortName") != nil)
                await processed.increment()
                #expect(await downloads.reservedCost == count)
            }
            #expect(await processed.count == 2)
            #expect(await downloads.peakCost == count)
        }
    }

    @Test func processingFailureWakesInputAndCancelsPendingDownloads() async throws {
        enum Failure: Error { case processing }
        let buffer = try Self.sampleBuffer()
        let count = buffer.readableBytes
        await #expect(throws: Failure.self) {
            try await BufferedDownloadSequence.withDownloads(
                ranges: [0..<count, count..<2 * count], concurrent: 2, byteLimit: 2 * count,
                download: { range in
                    if range.lowerBound > 0 {
                        try await Task.sleep(for: .seconds(120))
                    }
                    return buffer
                }
            ) { downloads in
                try await BufferedGribSequence(downloads: downloads).process(concurrent: 1) { _ in
                    throw Failure.processing
                }
            }
        }
    }

    @Test func incorrectDownloadedSizeFails() async {
        await #expect(throws: BufferedDownloadSequence.Failure.self) {
            try await BufferedDownloadSequence.withDownloads(
                ranges: [0..<4], concurrent: 1, byteLimit: 4,
                download: { _ in ByteBuffer(repeating: 0, count: 5) }
            ) { downloads in
                for try await _ in downloads { }
            }
        }
    }

    @Test func invalidSizesAndResponses() async throws {
        await #expect(throws: BufferedDownloadSequence.Failure.self) {
            try await BufferedDownloadSequence.withDownloads(ranges: [0..<9], concurrent: 1, byteLimit: 8, download: { _ in ByteBuffer() }) { _ in }
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
