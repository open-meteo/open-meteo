import Foundation
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
}

enum CurlErrorRetry: Error {
    case requestTimeout
    case tooManyRequests
    case internalServerError
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
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
     Retry HTTP requests on error
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
        
        // URL might contain password, strip them from logging
        guard var urlComponents = URLComponents(string: request.url) else {
            throw HTTPClientError.invalidURL
        }
        let password = urlComponents.password
        let user = urlComponents.user
        let schema = urlComponents.scheme
        if schema == "s3" {
            /// If S3 is running on localhost, use http
            urlComponents.scheme = request.url.contains("127.0.0.1") ? "http" : "https"
        }
        urlComponents.password = nil
        urlComponents.user = nil
        var request = request
        // Set URL without username and password
        request.url = urlComponents.url!.absoluteString
        
        while true {
            do {
                n += 1
                var request = request
                if let user, let password {
                    // Request need to be signed in the retry loop because the signature expires after 15 minutes
                    if schema == "s3" {
                        let signer = AWSSigner(accessKey: user, secretKey: password, region: "us-west-2", service: "s3")
                        try signer.sign(request: &request)
                    } else {
                        request.setBasicAuth(username: user, password: password)
                    }
                }
                
                let response = try await execute(request, timeout: timeoutPerRequest, logger: logger)
                logger.debug("Response for HTTP request #\(n) returned HTTP status code: \(response.status). URL \(request.url)\(request.rangePrettyPrint)")
                //print(try await response.readStringImmutable())
                try await response.throwOnError()
                return try await body(response)
            } catch CurlErrorNonRetry.unauthorized {
                logger.info("Download failed with 401 Unauthorized error, credentials rejected. Possibly outdated API key. URL \(request.url)\(request.rangePrettyPrint)")
                throw CurlErrorNonRetry.unauthorized
            } catch let error as CurlErrorNonRetry {
                
                logger.info("Download failed unrecoverable with \(error). URL \(request.url)\(request.rangePrettyPrint)")
                throw error
            } catch let error as CancellationError {
                logger.debug("Download failed with cancellation. URL \(request.url)\(request.rangePrettyPrint)")
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
                    logger.info("Download failed. Attempt \(n). Elapsed \(timeElapsed.prettyPrint). Retry in \(wait.prettyPrint). Error '\(error) [\(type(of: error))]' URL \(request.url)\(request.rangePrettyPrint)")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached. Attempt \(n). Elapsed \(timeElapsed.prettyPrint).  Error '\(error) [\(type(of: error))]' URL \(request.url)\(request.rangePrettyPrint)")
                    throw CurlError.timeoutReached
                }
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(wait.nanoseconds))
            }
        }
    }
    
    func executeRetryAndCollect(_ request: HTTPClientRequest,
                      logger: Logger,
                      upTo maxBytes: Int,
                      deadline: Date = .minutes(60),
                      timeoutPerRequest: TimeAmount = .seconds(30),
                      backOffSettings: ExponentialBackOff = .init(),
                      error404WaitTime: TimeAmount? = nil) async throws -> ByteBuffer {
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
}

fileprivate extension HTTPClientRequest {
    var rangePrettyPrint: String {
        guard let range = headers.range else {
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
