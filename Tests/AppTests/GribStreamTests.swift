import Foundation
import NIOCore
import Testing
@preconcurrency import SwiftEccodes
@testable import App

@Suite struct GribStreamTests {
    private static let windFixture = "R1JJQv//AAIAAAAAAAAA9QAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAAQAAAAABv///////////////////wAAAAIAAAACAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAICAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAEBAAAAAAAAAAAAAAAAGBv8AAAAFBwAAACIEAAAAAAIDAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAECAAAAAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="

    @Test(arguments: [false, true])
    func concurrentWindSubmessagesStayInTheirStreams(mixedDecoders: Bool) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                let chunkSize = [1, 17, 245, 490][index % 4]
                group.addTask {
                    if mixedDecoders && index.isMultiple(of: 2) {
                        try await preservesBufferedWindSubmessageOrder()
                    } else {
                        try await preservesWindSubmessageOrder(chunkSize: chunkSize)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func preservesBufferedWindSubmessageOrder() async throws {
        let packed = try #require(Data(base64Encoded: Self.windFixture))
        let buffer = ByteBuffer(bytes: packed + packed)
        try await BufferedDownloadSequence.withDownloads(
            ranges: [0..<buffer.readableBytes], concurrent: 1,
            byteLimit: buffer.readableBytes, download: { _ in buffer }
        ) { downloads in
            var wind = WindMessages()
            for try await item in BufferedGribSequence(downloads: downloads) {
                defer { withExtendedLifetime(item.download) {} }
                try wind.append(item.message)
            }
            wind.check()
        }
    }

    private struct WindMessages {
        var parameters = [Int]()
        var values = [[Double]]()

        mutating func append(_ message: GribMessage) throws {
            parameters.append(try #require(message.get(attribute: "parameterNumber").flatMap(Int.init)))
            values.append(try message.getDouble())
        }

        func check() {
            #expect(parameters == [2, 3, 2, 3])
            #expect(values == [[3, 3, 3, 3], [4, 4, 4, 4], [3, 3, 3, 3], [4, 4, 4, 4]])
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
        var wind = WindMessages()
        for try await message in stream.decodeGrib() {
            try wind.append(message)
        }
        wind.check()
    }
}
