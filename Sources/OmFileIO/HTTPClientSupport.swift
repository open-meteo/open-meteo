import AsyncHTTPClient
import Foundation
import Vapor

public enum CurlError: Error {
    case didNotFindAllVariablesInGribIndex
    case gribIndexMatchedTwice
    case sizeTooSmall
    case didNotGetAllGribMessages(got: Int, expected: Int)
    case downloadFailed(code: HTTPStatus)
    case fileNotFound
    case timeoutReached
    case timeoutPerChunkReached(httpRange: Range<Int>)
    case futimes(error: String)
    case contentLengthHeaderTooLarge(got: Int)
    case couldNotGetContentLengthForConcurrentDownload
    case invalidURL(String)
}

public extension HTTPClientResponse {
    func contentLength() throws -> Int? {
        guard let length = headers["Content-Length"].first.flatMap(Int.init), length >= 0 else {
            return nil
        }
        if length > 512 * (1 << 30) {
            throw CurlError.contentLengthHeaderTooLarge(got: length)
        }
        return length
    }

    func readStringImmutable(upTo: Int = 1024 * 1024) async throws -> String? {
        var buffer = try await body.collect(upTo: upTo)
        if buffer.readableBytes == upTo {
            fatalError("Response size too large")
        }
        return buffer.readString(length: buffer.readableBytes)
    }
}

public extension String {
    func stripHttpPassword() -> String {
        guard
            let slashIndex = firstRange(of: "://")?.lowerBound,
            let atIndex = self[slashIndex...].firstIndex(of: "@")
        else {
            return self
        }
        return "\(self[..<slashIndex])://\(self[index(after: atIndex)...])"
    }
}
