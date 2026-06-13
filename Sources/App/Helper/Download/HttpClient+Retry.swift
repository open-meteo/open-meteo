import Foundation
import NIOFileSystem
import AsyncHTTPClient
import NIOCore
import Logging
import NIOHTTP1

enum CurlErrorNonRetry: NonRetryError {
    case unauthorized
    case fileModifiedSinceLastDownload
    case forbidden(body: String?)
    case badRequest(body: String?)
    case other(HTTPResponseStatus)
    case timeoutReached
    case chunkSizeMismatch
    case rangeQueriesNotSupportedForFiles
}

enum CurlErrorRetry: Error {
    case requestTimeout
    case tooManyRequests
    case internalServerError
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    case chunkTimeoutReached
}

extension CancellationError: NonRetryError {
    
}

extension HTTPClientResponse {
    /// Throw if a transient error occurred. A retry could be successful. E.g. Gateway timeout or too many requests
    /// `CurlErrorNonRetry` is thrown for error that should not be retried
    func throwOnError() async throws {
        switch status {
        case .notFound:
            throw CurlError.fileNotFound
        case .requestTimeout:
            throw CurlErrorRetry.requestTimeout
        case .tooManyRequests:
            throw CurlErrorRetry.tooManyRequests
        case .internalServerError:
            throw CurlErrorRetry.internalServerError
        case .badGateway:
            throw CurlErrorRetry.badGateway
        case .serviceUnavailable:
            throw CurlErrorRetry.serviceUnavailable
        case .gatewayTimeout:
            throw CurlErrorRetry.gatewayTimeout
        case .unauthorized:
            throw CurlErrorNonRetry.unauthorized
        case .preconditionFailed:
            throw CurlErrorNonRetry.fileModifiedSinceLastDownload
        case .forbidden:
            throw CurlErrorNonRetry.forbidden(body: try await self.readStringImmutable())
        case .badRequest:
            throw CurlErrorNonRetry.badRequest(body: try await self.readStringImmutable())
        case .paymentRequired, .methodNotAllowed, .notAcceptable, .proxyAuthenticationRequired, .gone, .lengthRequired, .uriTooLong, .unsupportedMediaType, .rangeNotSatisfiable, .expectationFailed, .imATeapot, .misdirectedRequest, .unprocessableEntity, .locked, .failedDependency, .upgradeRequired, .preconditionRequired, .unavailableForLegalReasons:
            throw CurlErrorNonRetry.other(status)
        default:
            break
        }
    }
}

/// Calculate exponential backoff times with jtter
struct ExponentialBackOff {
    let factor: TimeAmount
    let maximum: TimeAmount
    
    init(factor: TimeAmount = .milliseconds(1000), maximum: TimeAmount = .seconds(30)) {
        self.factor = factor
        self.maximum = maximum
    }
    
    func waitTime(attempt n: Int) -> TimeAmount {
        let baseWait = min(factor.nanoseconds * Int64(pow(2, Double(min(n, 20) - 1))), maximum.nanoseconds)
        let jitterRange = Int64(baseWait / 4)
        let jitter = Int64.random(in: -jitterRange...jitterRange)
        let jitteredWait = max(0, baseWait + jitter)
        return TimeAmount.nanoseconds(jitteredWait)
    }
    
    func deadLine(attempt n: Int) -> Date {
        Date().addingTimeInterval(Double(waitTime(attempt: n).nanoseconds) / 1_000_000_000)
    }
    
    func sleep(attempt n: Int) async throws {
        let wait = waitTime(attempt: n)
        try await _Concurrency.Task.sleep(nanoseconds: UInt64(wait.nanoseconds))
    }
}

extension HTTPClient {
    /**
     Retry HTTP requests on error. Note this function returns as soon as the HTTP header arrives. Only connection setup + initial header retrieve is retried
     The underlaying HTTP body might still fail to download
     */
    func executeRetry(_ request: HTTPClientRequest,
                      logger: Logger,
                      deadline: Date = .minutes(60),
                      timeoutPerRequest: TimeAmount = .seconds(30),
                      backOffSettings: ExponentialBackOff = .init(),
                      error404WaitTime: TimeAmount? = nil) async throws -> HTTPClientResponse {
        return try await executeMapRetry(
            request,
            logger: logger,
            deadline: deadline,
            timeoutPerRequest: timeoutPerRequest,
            backOffSettings: backOffSettings,
            error404WaitTime:error404WaitTime, {$0}
        )
    }
    
    /**
     Retry HTTP requests on error. Map the HTTPClientResponse with a given closure. If the closure throws an error, it be retried as well
     */
    func executeMapRetry<T>(_ request: HTTPClientRequest,
        logger: Logger,
        deadline: Date = .minutes(60),
        timeoutPerRequest: TimeAmount = .seconds(30),
        backOffSettings: ExponentialBackOff = .init(),
        error404WaitTime: TimeAmount? = nil,
        _ body: @escaping (HTTPClientResponse) async throws -> T
    ) async throws -> T {
        var lastPrint = Date(timeIntervalSince1970: 0)
        let startTime = Date()
        var n = 0
        guard let (schema, user, password, url) = request.url.extractSchemaUserNamePasswordCleanUrl() else {
            throw HTTPClientError.invalidURL
        }
        
        if schema == "file" {
            guard request.headers.first(name: .init("range")) == nil else {
                throw CurlErrorNonRetry.rangeQueriesNotSupportedForFiles
            }
            return try await FileSystem.shared.withFileHandle(forReadingAt: FilePath(url)) { handle in
                let info = try await handle.info()
                var headers = HTTPHeaders()
                headers.add(name: "content-length", value: "\(info.size)")
                headers.lastModified?.value = Date(timeIntervalSince1970: TimeInterval(info.lastDataModificationTime.seconds))
                let response = HTTPClientResponse(status: .ok, headers: headers, body: .stream(handle.readChunks()))
                return try await body(response)
            }
        }
        
        while true {
            do {
                n += 1
                var request = request
                request.url = url
                if let user, let password {
                    // Request need to be signed in the retry loop because the signature expires after 15 minutes
                    if schema == "s3" {
                        let signer = AWSSigner(accessKey: String(user), secretKey: String(password), region: "us-west-2", service: "s3")
                        try signer.sign(request: &request)
                    } else {
                        request.setBasicAuth(username: String(user), password: String(password))
                    }
                }
                
                let response = try await execute(request, timeout: timeoutPerRequest, logger: logger)
                logger.debug("Response for HTTP request #\(n) returned HTTP status code: \(response.status). URL \(request.url)\(request.headers.rangePrettyPrint)")
                //print(try await response.readStringImmutable())
                try await response.throwOnError()
                return try await body(response)
            } catch CurlErrorNonRetry.unauthorized {
                logger.info("Download failed with 401 Unauthorized error, credentials rejected. Possibly outdated API key. URL \(url)\(request.headers.rangePrettyPrint)")
                throw CurlErrorNonRetry.unauthorized
            } catch let error as NonRetryError {
                logger.info("Download failed unrecoverable with \(error). URL \(url)\(request.headers.rangePrettyPrint)")
                throw error
            } catch {
                var wait = backOffSettings.waitTime(attempt: n)

                if let ioerror = error as? IOError, [104, 54].contains(ioerror.errnoCode), n <= 2 {
                    /// MeteoFrance API resets the connection very frequently causing large delays in downloading
                    /// Immediately retry twice
                    wait = .zero
                }
                if case CurlError.fileNotFound = error {
                    guard let error404WaitTime else {
                        throw error
                    }
                    wait = error404WaitTime
                }

                let timeElapsed = Date().timeIntervalSince(startTime)
                if Date().timeIntervalSince(lastPrint) > 60 {
                    logger.info("Download failed. Attempt \(n). Elapsed \(timeElapsed.prettyPrint). Retry in \(wait.prettyPrint). Error '\(error) [\(type(of: error))]' URL \(url)\(request.headers.rangePrettyPrint)")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached. Attempt \(n). Elapsed \(timeElapsed.prettyPrint).  Error '\(error) [\(type(of: error))]' URL \(url)\(request.headers.rangePrettyPrint)")
                    throw CurlError.timeoutReached
                }
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(wait.nanoseconds))
            }
        }
    }
    
    func executeRetryAndCollect(
        _ request: HTTPClientRequest,
        logger: Logger,
        upTo maxBytes: Int,
        deadline: Date = .minutes(60),
        timeoutPerRequest: TimeAmount = .seconds(30),
        backOffSettings: ExponentialBackOff = .init(),
        error404WaitTime: TimeAmount? = nil
    ) async throws -> ByteBuffer {
        return try await executeMapRetry(
            request,
            logger: logger,
            deadline: deadline,
            timeoutPerRequest: timeoutPerRequest,
            backOffSettings: backOffSettings,
            error404WaitTime:error404WaitTime,
            { try await $0.body.collect(upTo: maxBytes) }
        )
    }
    
    /// Download a file and chunk it into 8 MB parts. If HTTP range is set, use this. Otherwise perform a head request, get the content size and divide it info 8MB parts
    /// Returns a HTTPClientResponse with a body stream. The stream does not need to be retried, because each chunk is retried individually
    ///
    /// IMPORTANT: iIt may throw `CurlErrorNonRetry.fileModifiedSinceLastDownload` if the remote file was modified during download
    func executeRetryChunked(
        _ request: HTTPClientRequest,
        logger: Logger,
        chunkSize: Int = 8*1024*1024,
        nConcurrent: Int = 4,
        range: String? = nil,
        deadline: Date = .minutes(60),
        timeoutPerRequest: TimeAmount = .seconds(30),
        backOffSettings: ExponentialBackOff = .init(),
        error404WaitTime: TimeAmount? = nil
    ) async throws -> HTTPClientResponse {
        let chunks: [Range<Int>]
        let responseHeaders: HTTPHeaders
        let length: Int
        if let range = range {
            let parts = range.split(separator: ",")
            chunks = parts.flatMap { part in
                guard let (start, stop) = String(part).splitTo2Integer() else {
                    fatalError()
                }
                let length = (stop - start + 1)
                return (0..<length.divideRoundedUp(divisor: chunkSize)).map {
                    return (start + $0 * chunkSize) ..< (start + min(($0 + 1) * chunkSize, length))
                }
            }
            length = chunks.reduce(0, { $0 + $1.count })
            responseHeaders = HTTPHeaders([("content-length", "\(length)")])
        } else {
            var request = request
            request.method = .HEAD
            let head = try await executeMapRetry(request, logger: logger, deadline: deadline, timeoutPerRequest: timeoutPerRequest, backOffSettings: backOffSettings) {$0}
            responseHeaders = head.headers
            guard let lengthHeader = try head.contentLength(), lengthHeader >= nConcurrent else {
                throw CurlError.couldNotGetContentLengthForConcurrentDownload
            }
            length = lengthHeader
            chunks = (0..<length.divideRoundedUp(divisor: chunkSize)).map {
                return $0 * chunkSize ..< min(($0 + 1) * chunkSize, length)
            }
        }
        
        logger.info("Initiate concurrent download nConcurrent=\(nConcurrent) nChunks=\(chunks.count) length=\(length.bytesHumanReadable) chunkLength=\(chunkSize.bytesHumanReadable)")

        let stream = chunks.mapStream(nConcurrent: nConcurrent) { chunk in
            let range = "\(chunk.lowerBound)-\(chunk.upperBound - 1)"
            var request = request
            request.headers.add(name: "range", value: "bytes=\(range)")
            if let lastModified = responseHeaders.first(name: "Last-Modified") {
                request.headers.replaceOrAdd(name: "Last-Modified", value: lastModified)
            }
            if let etag = responseHeaders.first(name: "ETag") {
                request.headers.replaceOrAdd(name: "If-Match", value: etag)
            }
            return try await self.executeMapRetry(request, logger: logger, deadline: deadline, timeoutPerRequest: timeoutPerRequest, backOffSettings: backOffSettings) { response in
                var buffer = ByteBuffer()
                if let contentLength = try response.contentLength(), contentLength != chunk.count {
                    throw CurlErrorNonRetry.chunkSizeMismatch
                }
                buffer.reserveCapacity(chunk.count)
                // Allow 5 minutes per chunk, then restart
                let deadLineChunk = Date.minutes(5)
                for try await fragement in response.body {
                    if Date() > deadLineChunk {
                        throw CurlErrorRetry.chunkTimeoutReached
                    }
                    if Date() > deadline {
                        throw CurlErrorNonRetry.timeoutReached
                    }
                    buffer.writeImmutableBuffer(fragement)
                }
                guard buffer.readableBytes == chunk.count else {
                    throw CurlErrorNonRetry.chunkSizeMismatch
                }
                return buffer
            }
        }
        
        return HTTPClientResponse(status: .ok, headers: responseHeaders, body: .stream(stream))
    }
}

fileprivate extension HTTPHeaders {
    var rangePrettyPrint: String {
        guard let range = self.range else {
            return ""
        }
        let count = range.ranges.reduce(0, {
            switch $1 {
            case .start(value: _):
                return $0
            case .tail(value: _):
                return $0
            case .within(start: let start, end: let end):
                return $0 - start + end
            }
        })
        return " [\(count.bytesHumanReadable) Range: \(range.serialize())]"
    }
}


extension TimeAmount {
    var prettyPrint: String {
        return (Double(nanoseconds) / 1_000_000_000).asSecondsPrettyPrint
    }
}

extension TimeInterval {
    var prettyPrint: String {
        return self.asSecondsPrettyPrint
    }
}

extension Date {
    static func hours(_ hours: Double) -> Date {
        return Date(timeIntervalSinceNow: hours * 3600)
    }
    static func minutes(_ minutes: Double) -> Date {
        return Date(timeIntervalSinceNow: minutes * 60)
    }
    static func seconds(_ seconds: Double) -> Date {
        return Date(timeIntervalSinceNow: seconds)
    }
}

extension String {
    // Expected formats:
    //   schema://host/path
    //   schema://user:pass@host/path
    //   schema://user@host/path
    // Username and password are percent-encoded and must be decoded.
    // If there is no schema (no "://"), return nil.
    // Replaces schema "s3://" with "https://". On 127.0.0.1 regular http is used
    public func extractSchemaUserNamePasswordCleanUrl() -> (schema: Substring, user: Substring?, password: Substring?, url: String)? {
        guard let schemeRange = self.range(of: "://") else {
            return nil
        }
        let schema = self[..<schemeRange.lowerBound]
        
        if schema == "file" {
            return (schema: schema, user: nil, password: nil, url: String(self[schemeRange.upperBound...]))
        }

        // Split credentials (if any) from host/path by looking for '@' before the first '/'
        let firstSlashIndex = self[schemeRange.upperBound...].firstIndex(of: "/") ?? self.endIndex
        let credsAndHost = self[schemeRange.upperBound..<firstSlashIndex]

        let user: Substring?
        let password: Substring?
        let atIndex = credsAndHost.firstIndex(of: "@")
        let hostPortAndPathStart = atIndex.map { credsAndHost.index(after: $0) } ?? schemeRange.upperBound

        if let atIndex {
            // Credentials are present before '@'
            let creds = self[schemeRange.upperBound..<atIndex]

            if let colonInCreds = creds.firstIndex(of: ":") {
                let u = creds[..<colonInCreds]
                let p = creds[creds.index(after: colonInCreds)..<creds.endIndex]
                user = u.firstIndex(of: "%") == nil ? u : u.removingPercentEncoding.map({Substring($0)}) ?? u
                password = p.firstIndex(of: "%") == nil ? p : p.removingPercentEncoding.map({Substring($0)}) ?? p
            } else {
                let u = creds
                user = u.firstIndex(of: "%") == nil ? u : u.removingPercentEncoding.map({Substring($0)}) ?? u
                password = nil
            }
        } else {
            user = nil
            password = nil
        }

        // Build the clean URL without credentials
        let hostAndPath = self[hostPortAndPathStart...]
        
        let url: String
        /// Hard coded overwrite to use S3 for certain URLs
        if schema == "s3" || hostAndPath.contains(".your-objectstorage.com") || hostAndPath.starts(with: "s3.open-meteo.com") || hostAndPath.starts(with: "127.0.0.1:7480") {
            /// If S3 is running on localhost, use http
            url = (hostAndPath.starts(with: "127.0.0.1") ? "http://" : "https://") + hostAndPath
            return (schema: "s3", user: user, password: password, url: url)
        } else {
            // If username and password are empty, the current string is already a clean URL
            url = (user == nil && password == nil) ? self : "\(schema)://\(hostAndPath)"
            return (schema: schema, user: user, password: password, url: url)
        }
    }
}
