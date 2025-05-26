import OmFileFormat
import AsyncHTTPClient
import Foundation
import Logging

enum OmHttpReaderBackendError: Error {
    case contentLengthMissing
}

/**
 Reader backend to read from an HTTP server on demand. Checks last modified header and ETag.
 */
final class OmHttpReaderBackend: OmFileReaderBackendAsyncData, Sendable {
    let client: HTTPClient
    
    /// Size of remote http file
    let count: Int
    
    /// Last modified date from http server
    let lastModified: String?
    
    let eTag: String?
    
    let url: String
    
    let logger: Logger
    
    typealias DataType = Data
    
    init(client: HTTPClient, logger: Logger, url: String) async throws {
        self.client = client
        var headRequest = HTTPClientRequest(url: url)
        headRequest.method = .HEAD
        let headResponse = try await client.executeRetry(headRequest, logger: logger, deadline: .seconds(5))
        guard let contentLength = headResponse.headers["Content-Length"].first.flatMap(Int.init) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }
        self.lastModified = headResponse.headers["Last-Modified"].first
        self.eTag = headResponse.headers["ETag"].first
        self.count = contentLength
        self.url = url
        self.logger = logger
    }
    
    func getCount() async throws -> UInt64 {
        return UInt64(count)
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        // nothing do do here
    }
    
    func getData(offset: Int, count: Int) async throws -> Data {
        var request = HTTPClientRequest(url: url)
        if let lastModified {
            request.headers.add(name: "If-Unmodified-Since", value: lastModified)
        }
        if let eTag {
            request.headers.add(name: "If-Match", value: eTag)
        }
        request.headers.add(name: "Range", value: "bytes=\(offset)-\(offset + count - 1)")
        let response = try await client.executeRetry(request, logger: logger, deadline: .seconds(5))
        var buffer = try await response.body.collect(upTo: count)
        return buffer.readData(length: count, byteTransferStrategy: .noCopy)!
    }
}
