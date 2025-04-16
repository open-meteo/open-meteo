import Foundation
import AsyncHTTPClient
import NIOCore
import Logging

extension HTTPClientResponse {
    /// Throw if a transient error occurred. A retry could be successful
    func throwOnTransientError() throws {
        if isTransientError {
            throw CurlError.downloadFailed(code: status)
        }
    }

    /// True is status code contains an error that is retirable. E.g. Gateway timeout or too many requests
    var isTransientError: Bool {
        return [
            .requestTimeout,
            .tooManyRequests,
            .internalServerError,
            .badGateway,
            .serviceUnavailable,
            .gatewayTimeout
        ].contains(status)
    }

    func throwOnFatalError() throws {
        if status == .unauthorized {
            throw CurlErrorNonRetry.unauthorized
        }
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
                      backoffFactor: TimeAmount = .milliseconds(1000),
                      backoffMaximum: TimeAmount = .seconds(30),
                      error404WaitTime: TimeAmount? = nil) async throws -> HTTPClientResponse {
        var lastPrint = Date(timeIntervalSince1970: 0)
        let startTime = Date()
        var n = 0
        while true {
            do {
                n += 1
                let response = try await execute(request, timeout: timeoutPerRequest, logger: logger)
                logger.debug("Response for HTTP request #\(n) returned HTTP status code: \(response.status), from URL \(request.url)")
                try response.throwOnTransientError()
                try response.throwOnFatalError()
                if error404WaitTime != nil && response.status == .notFound {
                    throw CurlError.fileNotFound
                }
                return response
            } catch CurlErrorNonRetry.unauthorized {
                logger.info("Download failed with 401 Unauthorized error, credentials rejected. Possibly outdated API key.")
                throw CurlErrorNonRetry.unauthorized
            } catch {
                var wait = TimeAmount.nanoseconds(min(backoffFactor.nanoseconds * Int64(pow(2, Double(n - 1))), backoffMaximum.nanoseconds))

                if let ioerror = error as? IOError, [104, 54].contains(ioerror.errnoCode), n <= 2 {
                    /// MeteoFrance API resets the connection very frequently causing large delays in downloading
                    /// Immediately retry twice
                    wait = .zero
                }
                if let error404WaitTime, case CurlError.fileNotFound = error {
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
