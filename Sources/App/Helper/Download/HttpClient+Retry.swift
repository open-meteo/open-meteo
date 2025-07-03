import Foundation
import AsyncHTTPClient
import NIOCore
import Logging

enum CurlErrorNonRetry: NonRetryError {
    case unauthorized
    case fileModifiedSinceLastDownload
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
    func throwOnError() throws {
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
        let baseWait = min(factor.nanoseconds * Int64(pow(2, Double(n - 1))), maximum.nanoseconds)
        let jitterRange = Int64(baseWait / 4)
        let jitter = Int64.random(in: -jitterRange...jitterRange)
        let jitteredWait = max(0, baseWait + jitter)
        return TimeAmount.nanoseconds(jitteredWait)
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
        var lastPrint = Date(timeIntervalSince1970: 0)
        let startTime = Date()
        var n = 0
        while true {
            do {
                n += 1
                let response = try await execute(request, timeout: timeoutPerRequest, logger: logger)
                logger.debug("Response for HTTP request #\(n) returned HTTP status code: \(response.status), from URL \(request.url)")
                try response.throwOnError()
                return response
            } catch CurlErrorNonRetry.unauthorized {
                logger.info("Download failed with 401 Unauthorized error, credentials rejected. Possibly outdated API key.")
                throw CurlErrorNonRetry.unauthorized
            } catch let error as CurlErrorNonRetry {
                logger.info("Download failed unrecoverable with \(error). Please make sure the API credentials are correct. Possibly outdated API key.")
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
                    logger.info("Download failed. Attempt \(n). Elapsed \(timeElapsed.prettyPrint). Retry in \(wait.prettyPrint). Error '\(error) [\(type(of: error))]'")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached. Attempt \(n). Elapsed \(timeElapsed.prettyPrint).  Error '\(error) [\(type(of: error))]'")
                    throw CurlError.timeoutReached
                }
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(wait.nanoseconds))
            }
        }
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
