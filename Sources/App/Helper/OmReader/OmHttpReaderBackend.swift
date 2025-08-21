import OmFileFormat
import AsyncHTTPClient
import Foundation
import Logging
import NIO
import Synchronization

enum OmHttpReaderBackendError: Error {
    case contentLengthMissing
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
    
    /// Timestamp in seconds when the last data was successfully fetched from the backend.
    private let lastValidatedAtomic: Atomic<Int>
    
    /// Timestamp when the last data was successfully fetched from the backend.
    var lastValidated: Timestamp {
        return Timestamp(lastValidatedAtomic.load(ordering: .relaxed))
    }
    
    typealias DataType = ByteBuffer
    
    var cacheKey: UInt64 {
        return url.fnv1aHash64.addFnv1aHash(eTag ?? "").addFnv1aHash(lastModified ?? "")
    }
    
    var lastModifiedTimestamp: Timestamp? {
        guard let lastModified else {
            return nil
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = fmt.date(from: lastModified) else {
            return nil
        }
        return Timestamp(Int(date.timeIntervalSince1970))
    }
    
    init?(client: HTTPClient, logger: Logger, url: String) async throws {
        self.client = client
        var headRequest = HTTPClientRequest(url: url)
        headRequest.method = .HEAD
        try headRequest.applyS3Credentials()
        do {
            logger.debug("Sending HEAD requests to \(headRequest.url)")
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
            self.lastValidatedAtomic = .init(Timestamp.now().timeIntervalSince1970)
        } catch CurlError.fileNotFound {
            return nil
        }
    }
    
    init(client: HTTPClient, logger: Logger, url: String, count: Int, lastModified: Timestamp?, eTag: String?, lastValidated: Timestamp) {
        self.client = client
        self.logger = logger
        self.url = url
        self.count = count
        self.lastModified = lastModified?.lastModifiedHttpDateFormat
        self.eTag = eTag
        self.lastValidatedAtomic = .init(lastValidated.timeIntervalSince1970)
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
        try request.applyS3Credentials()
        logger.debug("Getting data range \(offset)-\(offset + count - 1) from \(request.url)")
        let response = try await client.executeRetry(request, logger: logger, deadline: .seconds(10), timeoutPerRequest: .seconds(2))
        let buffer = try await response.body.collect(upTo: count)
        lastValidatedAtomic.store(Timestamp.now().timeIntervalSince1970, ordering: .relaxed)
        return buffer
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

extension Timestamp {
    var lastModifiedHttpDateFormat: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return fmt.string(from: self.toDate())
    }
}
