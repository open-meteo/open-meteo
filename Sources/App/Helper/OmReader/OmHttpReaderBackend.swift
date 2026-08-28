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
        /// Size of remote http file
    let count: Int
    
    let eTag: String
    
    let server: S3ServerHealth
    
    let object: String
        
    let lastModified: Timestamp
    
    /// Timestamp in seconds when the last data was successfully fetched from the backend.
    /// If set to `0`, the file has been deleted or modified. In both cases, it is not valid anymore
    /// TODO: this is only used to store HTTP etag/modified errors
    private let lastValidatedAtomic: Atomic<Int>
    
    typealias DataType = ByteBuffer
    
    /// Hash object name, content size and last modified timestamp. Does not use etag, because servers present different etags.
    var cacheKey: UInt64 {
        return object.fnv1aHash64.addFnv1aHash(UInt64(count)).addFnv1aHash(UInt64(lastModified.timeIntervalSince1970))
    }
    
    /// Note: Only used if S3 based eTag throws an error after the file got updated on the remote end. Per default S3 List attributes are used to initialise this client.
    init(context: S3ServerHealth, object: String) async throws {
        self.server = context
        let serverUrl = try await context.getServerFor(hash: object.fnv1aHash64)
        var headRequest = HTTPClientRequest(url: serverUrl.uploadURL(remotePath: object))
        headRequest.method = .HEAD
        context.logger.debug("Sending HEAD requests to \(headRequest.url.stripHttpPassword())")
        let backoff = ExponentialBackOff(factor: .milliseconds(500), maximum: .seconds(2))
        let headResponse = try await HTTPClient.shared.executeRetry(headRequest, logger: context.logger, deadline: .seconds(10), timeoutPerRequest: .seconds(2), backOffSettings: backoff)
        guard let contentLength = headResponse.headers["Content-Length"].first.flatMap(Int.init) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }
        guard
            let lastModifiedString = headResponse.headers["Last-Modified"].first,
            let lastModified = DateFormatter.httpLastModifiedFormater.date(from: lastModifiedString)?.toTimestamp()
        else {
            throw OmHttpReaderBackendError.lastModifiedMissing
        }
        
        guard let eTag = headResponse.headers["ETag"].first else {
            throw OmHttpReaderBackendError.eTagMissing
        }
        assert(eTag.hasPrefix("\""))
        assert(eTag.hasSuffix("\""))
        self.lastModified = lastModified
        self.eTag = eTag
        self.count = contentLength
        self.object = object
        self.lastValidatedAtomic = .init(Timestamp.now().timeIntervalSince1970)
    }
    
    /// Last modified, eTag and count is used from S3 list operations
    init(context: S3ServerHealth, object: String, count: Int, eTag: String, lastModified: Timestamp) {
        assert(eTag.hasPrefix("\""))
        assert(eTag.hasSuffix("\""))
        self.server = context
        self.object = object
        self.count = count
        self.eTag = eTag
        self.lastValidatedAtomic = .init(Timestamp.now().timeIntervalSince1970)
        self.lastModified = lastModified
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
        let serverUrl = try await server.getServerFor(hash: object.fnv1aHash64)
        var request = HTTPClientRequest(url: serverUrl.uploadURL(remotePath: object))
        request.headers.add(name: "If-Match", value: eTag)
        request.headers.add(name: "Range", value: "bytes=\(offset)-\(offset + count - 1)")
        request.headers.replaceOrAdd(name: "Accept-Encoding", value: "identity")
        let logger = server.logger
        logger.debug("Getting data range \(offset)-\(offset + count - 1) from \(request.url)")
        let backoff = ExponentialBackOff(factor: .milliseconds(500), maximum: .seconds(5))
        do {
            let buffer = try await HTTPClient.shared.executeRetryAndCollect(request, logger: logger, upTo: count, deadline: .seconds(30), timeoutPerRequest: .seconds(10), backOffSettings: backoff)
            lastValidatedAtomic.store(Timestamp.now().timeIntervalSince1970, ordering: .relaxed)
            return buffer
        } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {
            OmMetrics.fileRemoteModifiedUnexpectedlyTotal.add(1, ordering: .relaxed)
            self.lastValidatedAtomic.store(0, ordering: .relaxed)
            throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
        } catch CurlError.fileNotFound {
            OmMetrics.fileRemoteModifiedUnexpectedlyTotal.add(1, ordering: .relaxed)
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

extension DateFormatter {
    /// rfc1123
    static var httpLastModifiedFormater: DateFormatter {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return fmt
    }
}
