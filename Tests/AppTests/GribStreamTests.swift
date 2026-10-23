import Foundation
import NIOCore
import Testing
@testable import App

@Suite struct GribStreamTests {
    private static let windFixture = "R1JJQv//AAIAAAAAAAAA9QAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAAQAAAAABv///////////////////wAAAAIAAAACAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAICAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAEBAAAAAAAAAAAAAAAAGBv8AAAAFBwAAACIEAAAAAAIDAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAECAAAAAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="

    @Test func concurrentBufferedAndStreamingSubmessagesStaySeparate() async throws {
        let packed = try #require(Data(base64Encoded: Self.windFixture))
        let buffer = ByteBuffer(bytes: packed + packed)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                group.addTask {
                    if index.isMultiple(of: 2) {
                        try await preservesWindSubmessageOrder(chunkSize: 17)
                        return
                    }
                    try await BufferedDownloadSequence.withDownloads(
                        ranges: [0..<buffer.readableBytes], concurrent: 1,
                        byteLimit: buffer.readableBytes, download: { _ in buffer }
                    ) { downloads in
                        var parameters = [Int]()
                        for try await item in BufferedGribSequence(downloads: downloads) {
                            defer { withExtendedLifetime(item.download) {} }
                            let parameter = try #require(item.message.get(attribute: "parameterNumber").flatMap(Int.init))
                            parameters.append(parameter)
                            #expect(try item.message.getDouble() == Array(repeating: Double(parameter + 1), count: 4))
                        }
                        #expect(parameters.sorted() == [2, 2, 3, 3])
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func concurrentWindSubmessagesStayInTheirStreams() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                let chunkSize = [1, 17, 245, 490][index % 4]
                group.addTask {
                    try await preservesWindSubmessageOrder(chunkSize: chunkSize)
                }
            }
            try await group.waitForAll()
        }
    }

    @Test(arguments: [1, 17, 245, 490])
    func preservesWindSubmessageOrder(chunkSize: Int) async throws {
        // Synthetic ecCodes regular_ll_sfc_grib2 fixture: one message containing
        // U = 3 m/s followed by V = 4 m/s, each on a 2 x 2 grid, as in NAM packing.
        let packed = try #require(Data(base64Encoded:
            Self.windFixture
        ))
        // Repeat to exercise draining submessages before reading the next message.
        let bytes = Array(packed + packed)
        let stream = AsyncStream<ByteBuffer> { continuation in
            for offset in stride(from: 0, to: bytes.count, by: chunkSize) {
                continuation.yield(ByteBuffer(bytes: bytes[offset..<min(offset + chunkSize, bytes.count)]))
            }
            continuation.finish()
        }
        var parameters = [Int]()
        var values = [[Double]]()
        for try await message in stream.decodeGrib() {
            parameters.append(try #require(message.get(attribute: "parameterNumber").flatMap(Int.init)))
            values.append(try message.getDouble())
        }
        #expect(parameters == [2, 3, 2, 3])
        #expect(values == [[3, 3, 3, 3], [4, 4, 4, 4], [3, 3, 3, 3], [4, 4, 4, 4]])
    }
}
