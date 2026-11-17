import Testing
@testable import App

struct CurlMemoryDownloadTests {
    @Test func singleRequestRangeDeterminesByteBounds() {
        #expect(CurlMemoryDownloadError.singleRange("4-7") == 4..<8)
        #expect(CurlMemoryDownloadError.singleRange("0-0") == 0..<1)
        for range in ["4-", "-4", "0-3,8-11", "7-4", "-1-4", "invalid", "0-\(Int.max)"] {
            #expect(CurlMemoryDownloadError.singleRange(range) == nil)
        }
    }

    @Test func invalidSizesAndResponses() throws {
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
