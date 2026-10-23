import Foundation
import NIOCore
import Testing
@testable import App

@Suite struct GribStreamTests {
    @Test(arguments: [1, 17, 245, 490])
    func preservesWindSubmessageOrder(chunkSize: Int) async throws {
        // Synthetic ecCodes regular_ll_sfc_grib2 fixture: one message containing
        // U = 3 m/s followed by V = 4 m/s, each on a 2 x 2 grid, as in NAM packing.
        let packed = try #require(Data(base64Encoded:
            "R1JJQv//AAIAAAAAAAAA9QAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAAQAAAAABv///////////////////wAAAAIAAAACAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAICAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAEBAAAAAAAAAAAAAAAAGBv8AAAAFBwAAACIEAAAAAAIDAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAECAAAAAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="
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
