import Foundation
import Testing
import OmFileIO
import NIOCore
@testable import App

@Suite(.timeLimit(.minutes(1)))
struct BufferedDownloadTests {
    @Test func boundedPipelineCompletes() async throws {
        let count = try await BufferedDownloadSequence.withDownloads(
            ranges: (0..<100).map { $0 * 4..<($0 + 1) * 4 }, concurrent: 12, byteLimit: 16, batchLimit: 2,
            download: { _ in ByteBuffer(repeating: 0, count: 4) }
        ) { downloads in
            var count = 0
            for try await item in downloads {
                #expect(item.value.readableBytes == 4)
                count += 1
            }
            #expect(await downloads.peakCost <= 8)
            return count
        }
        #expect(count == 100)
    }

    @Test func earlyReturnWakesCapacityWaiters() async throws {
        try await BufferedDownloadSequence.withDownloads(
            ranges: [0..<4, 4..<8, 8..<12], concurrent: 3, byteLimit: 4,
            download: { _ in ByteBuffer(repeating: 0, count: 4) }
        ) { downloads in
            var iterator = downloads.makeAsyncIterator()
            _ = try #require(await iterator.next())
        }
    }

    enum Failure: Error { case injected }

    @Test func downloadFailureWakesConsumer() async {
        await #expect(throws: Failure.self) {
            try await BufferedDownloadSequence.withDownloads(
                ranges: [0..<4, 4..<8], concurrent: 2, byteLimit: 4,
                download: { _ in throw Failure.injected }
            ) { downloads in
                for try await _ in downloads { }
            }
        }
    }

    actor Signal {
        var signalled = false
        var count = 0
        var waiters = [CheckedContinuation<Void, Never>]()
        func wait() async {
            if signalled { return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func signal() {
            signalled = true
            count += 1
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }

    @Test func slowFirstDownloadDoesNotBlockAndIsCancelledOnEarlyReturn() async throws {
        let started = Signal()
        let stopped = Signal()
        let first = try await BufferedDownloadSequence.withDownloads(
            ranges: [0..<4, 4..<8], concurrent: 2, byteLimit: 8,
            download: { range in
                if range.lowerBound == 0 {
                    await started.signal()
                    do { try await Task.sleep(for: .seconds(120)) } catch {
                        await stopped.signal()
                        throw error
                    }
                }
                await started.wait()
                return ByteBuffer(repeating: UInt8(range.lowerBound), count: 4)
            }
        ) { downloads in
            var iterator = downloads.makeAsyncIterator()
            let batch = try #require(await iterator.next())
            return batch.value.getInteger(at: 0, as: UInt8.self)
        }
        #expect(first == 4)
        #expect(await stopped.signalled)
    }

    @Test func cancellationWakesConsumerAndCapacityWaiters() async throws {
        let started = Signal()
        let stopped = Signal()
        let task = Task {
            try await BufferedDownloadSequence.withDownloads(
                ranges: [0..<4, 4..<8], concurrent: 2, byteLimit: 4,
                download: { _ in
                    await started.signal()
                    do { try await Task.sleep(for: .seconds(120)) } catch {
                        await stopped.signal()
                        throw error
                    }
                    return ByteBuffer(repeating: 0, count: 4)
                }
            ) { downloads in
                for try await _ in downloads { }
            }
        }
        await started.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await stopped.signalled)
    }

    @Test func consumerFailureWakesCapacityWaiters() async {
        await #expect(throws: Failure.self) {
            try await BufferedDownloadSequence.withDownloads(
                ranges: [0..<4, 4..<8], concurrent: 2, byteLimit: 4,
                download: { _ in ByteBuffer(repeating: 0, count: 4) }
            ) { downloads in
                for try await _ in downloads { throw Failure.injected }
            }
        }
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

    @Test func decoderRetainsCompressedBatchesThroughProcessing() async throws {
        // ecCodes regular_ll_sfc_grib2 sample: a small constant field.
        let data = try #require(Data(base64Encoded: "R1JJQv//AAIAAAAAAAAAswAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAfAAAAAABv///////////////////wAAABAAAAAfAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAAAAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAfAAAEOIkzMAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="))
        let buffer = ByteBuffer(bytes: data)
        let count = data.count
        let processed = Signal()
        try await BufferedDownloadSequence.withDownloads(
            ranges: [0..<count, count..<2 * count], concurrent: 2, byteLimit: count,
            download: { _ in buffer }
        ) { downloads in
            try await BufferedGribSequence(downloads: downloads).foreachConcurrent(nConcurrent: 2) { item in
                defer { withExtendedLifetime(item.download) {} }
                #expect(item.message.get(attribute: "shortName") != nil)
                await processed.signal()
                #expect(await downloads.reservedCost == count)
            }
            #expect(await processed.count == 2)
            #expect(await downloads.peakCost == count)
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
