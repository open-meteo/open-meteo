import Testing
@testable import App

struct CurlMemoryDownloadTests {
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
