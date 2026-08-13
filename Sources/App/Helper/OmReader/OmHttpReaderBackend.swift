import OmFileFormat
import AsyncHTTPClient
import Foundation
import Logging
import NIO
import Synchronization

enum OmHttpReaderBackendError: Error {
    case contentLengthMissing
    case eTagMissing
    case lastModifiedMissing
}

/**
 Reader backend to read from an HTTP server on demand. Checks last modified header and ETag.
 */
final class OmHttpReaderBackend: OmFileReaderBackend, Sendable {
    let client: HTTPClient
    
    /// Size of remote http file
    let count: Int
    
    /// Last modified date from http server
    /// Consider to replace it with a unix timestamp
    let lastModified: String
    
    let eTag: String
    
    let url: String
    
    let logger: Logger
    
    /// Timestamp in seconds when the last data was successfully fetched from the backend.
    /// If set to `0`, the file has been deleted or modified. In both cases, it is not valid anymore
    /// TODO: this is only used to store HTTP etag/modified errors
    private let lastValidatedAtomic: Atomic<Int>
    
    /// Timestamp when the last data was successfully fetched from the backend.
    /*var lastValidated: Timestamp {
        get {
            return Timestamp(lastValidatedAtomic.load(ordering: .relaxed))
        }
        set {
            lastValidatedAtomic.store(newValue.timeIntervalSince1970, ordering: .relaxed)
        }
    }*/
    
    typealias DataType = ByteBuffer
    
    var cacheKey: UInt64 {
        return url.fnv1aHash64.addFnv1aHash(eTag).addFnv1aHash(lastModified)
    }
    
    var lastModifiedTimestamp: Timestamp {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = fmt.date(from: lastModified) else {
            fatalError("Date format failed")
        }
        return Timestamp(Int(date.timeIntervalSince1970))
    }
    
    /// Note: Only used if S3 based eTag throws an error after the file got updated on the remote end. Per default S3 List attributes are used to initialise this client.
    init(client: HTTPClient, logger: Logger, url: String) async throws {
        self.client = client
        var headRequest = HTTPClientRequest(url: url)
        headRequest.method = .HEAD
        logger.debug("Sending HEAD requests to \(headRequest.url.stripHttpPassword())")
        let backoff = ExponentialBackOff(factor: .milliseconds(500), maximum: .seconds(2))
        let headResponse = try await client.executeRetry(headRequest, logger: logger, deadline: .seconds(10), timeoutPerRequest: .seconds(2), backOffSettings: backoff)
        guard let contentLength = headResponse.headers["Content-Length"].first.flatMap(Int.init) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }
        guard let lastModified = headResponse.headers["Last-Modified"].first else {
            throw OmHttpReaderBackendError.lastModifiedMissing
        }
        guard let eTag = headResponse.headers["ETag"].first else {
            throw OmHttpReaderBackendError.eTagMissing
        }
        self.lastModified = lastModified
        self.eTag = eTag
        self.count = contentLength
        self.url = url
        self.logger = logger
        self.lastValidatedAtomic = .init(Timestamp.now().timeIntervalSince1970)
    }
    
    /// Last modified, eTag and count is used from S3 list operations
    init(client: HTTPClient, logger: Logger, url: String, count: Int, lastModified: Timestamp, eTag: String) {
        self.client = client
        self.logger = logger
        self.url = url
        self.count = count
        self.lastModified = lastModified.lastModifiedHttpDateFormat
        self.eTag = eTag
        self.lastValidatedAtomic = .init(Timestamp.now().timeIntervalSince1970)
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        // nothing do do here
    }
    
    func getData(offset: Int, count: Int) async throws -> ByteBuffer {
        /// If `lastValidated` is set to `0`, the file received a file modified error,
        /// if `1` received a file not found error
        switch lastValidatedAtomic.load(ordering: .relaxed) {
        case 0: throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
        case 1: throw CurlError.fileNotFound
        default: break
        }
        
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "If-Unmodified-Since", value: lastModified)
        request.headers.add(name: "If-Match", value: eTag)
        request.headers.add(name: "Range", value: "bytes=\(offset)-\(offset + count - 1)")
        try request.applyS3Credentials()
        logger.debug("Getting data range \(offset)-\(offset + count - 1) from \(request.url)")
        let backoff = ExponentialBackOff(factor: .milliseconds(500), maximum: .seconds(5))
        do {
            let buffer = try await client.executeRetryAndCollect(request, logger: logger, upTo: count, deadline: .seconds(30), timeoutPerRequest: .seconds(10), backOffSettings: backoff)
            lastValidatedAtomic.store(Timestamp.now().timeIntervalSince1970, ordering: .relaxed)
            return buffer
        } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {
            self.lastValidatedAtomic.store(0, ordering: .relaxed)
            throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
        } catch CurlError.fileNotFound {
            self.lastValidatedAtomic.store(1, ordering: .relaxed)
            throw CurlError.fileNotFound
        }
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
