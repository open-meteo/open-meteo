import OmFileFormat
import AsyncHTTPClient
import Foundation
import Logging

enum OmHttpReaderBackendError: Error {
    case contentLengthMissing
}

func fnv1aHash64(_ string: String) -> UInt64 {
    let fnvOffsetBasis: UInt64 = 0xcbf29ce484222325
    let fnvPrime: UInt64 = 0x100000001b3

    var hash = fnvOffsetBasis
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* fnvPrime
    }
    return hash
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
    
    var cacheKey: UInt64 {
        return fnv1aHash64(url) &+ (eTag.map(fnv1aHash64) ?? 0) &+ (lastModified.map(fnv1aHash64) ?? 0)
    }
    
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
