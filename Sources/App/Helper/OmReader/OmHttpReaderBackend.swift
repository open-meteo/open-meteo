import OmFileFormat
import AsyncHTTPClient
import Foundation
import Logging
import NIO

enum OmHttpReaderBackendError: Error {
    case contentLengthMissing
}

extension String {
    /// Get FNV hash of the string
    var fnv1aHash64: UInt64 {
        let fnvOffsetBasis: UInt64 = 0xcbf29ce484222325
        let fnvPrime: UInt64 = 0x100000001b3
        return self.withContiguousStorageIfAvailable { ptr in
            var hash = fnvOffsetBasis
            for byte in UnsafeRawBufferPointer(ptr) {
                hash ^= UInt64(byte)
                hash = hash &* fnvPrime
            }
            return hash
        } ?? {
            var hash = fnvOffsetBasis
            for byte in self.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* fnvPrime
            }
            return hash
        }()
    }
}

/**
 Reader backend to read from an HTTP server on demand. Checks last modified header and ETag.
 */
final class OmHttpReaderBackend: OmFileReaderBackend, Sendable {
    let client: HTTPClient
    
    /// Size of remote http file
    let count: Int
    
    /// Last modified date from http server
    let lastModified: String?
    
    let eTag: String?
    
    let url: String
    
    let logger: Logger
    
    typealias DataType = ByteBuffer
    
    var cacheKey: UInt64 {
        return url.fnv1aHash64 ^ (eTag?.fnv1aHash64 ?? 0) ^ (lastModified?.fnv1aHash64 ?? 0)
    }
    
    init?(client: HTTPClient, logger: Logger, url: String) async throws {
        self.client = client
        var headRequest = HTTPClientRequest(url: url)
        headRequest.method = .HEAD
        do {
            logger.debug("Sending HEAD requests to \(url)")
            let backoff = ExponentialBackOff(maximum: .milliseconds(500))
            let headResponse = try await client.executeRetry(headRequest, logger: logger, deadline: .seconds(5), timeoutPerRequest: .seconds(1), backOffSettings: backoff)
            guard let contentLength = headResponse.headers["Content-Length"].first.flatMap(Int.init) else {
                throw OmHttpReaderBackendError.contentLengthMissing
            }
            self.lastModified = headResponse.headers["Last-Modified"].first
            self.eTag = headResponse.headers["ETag"].first
            self.count = contentLength
            self.url = url
            self.logger = logger
        } catch CurlError.fileNotFound {
            return nil
        }
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        // nothing do do here
    }
    
    func getData(offset: Int, count: Int) async throws -> ByteBuffer {
        var request = HTTPClientRequest(url: url)
        if let lastModified {
            request.headers.add(name: "If-Unmodified-Since", value: lastModified)
        }
        if let eTag {
            request.headers.add(name: "If-Match", value: eTag)
        }
        request.headers.add(name: "Range", value: "bytes=\(offset)-\(offset + count - 1)")
        logger.debug("Getting data range \(offset)-\(offset + count - 1) from \(url)")
        let response = try await client.executeRetry(request, logger: logger, deadline: .seconds(5))
        return try await response.body.collect(upTo: count)
    }
    
    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let buffer = try await getData(offset: offset, count: count)
        return try buffer.withUnsafeReadableBytes(fn)
    }
    
}

extension ByteBuffer: @retroactive ContiguousBytes {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try self.withUnsafeReadableBytes(body)
    }
}
