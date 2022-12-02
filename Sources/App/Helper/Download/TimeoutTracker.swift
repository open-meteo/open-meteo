import Foundation
import Logging

/// Helper to track timeouts and throw errors once a headline in reached
final class TimeoutTracker {
    let startTime = Date()
    private var lastPrint = Date(timeIntervalSince1970: 0)
    let logger: Logger
    let deadline: Date
    
    /// Wait time after each download
    let retryDelaySeconds = 5
    
    public init(logger: Logger, deadline: Date) {
        self.logger = logger
        self.deadline = deadline
    }
    
    /// Print statistics, throw if deadline reached, sleep backoff timer
    func check(error: Error) async throws {
        let timeElapsed = Date().timeIntervalSince(startTime)
        if Date().timeIntervalSince(lastPrint) > 60 {
            logger.info("Download failed, retry every \(retryDelaySeconds) seconds, (\(Int(timeElapsed/60)) minutes elapsed, curl error '\(error)'")
            lastPrint = Date()
        }
        if Date() > deadline {
            logger.error("Deadline reached. Last Error \(error)")
            throw CurlError.timeoutReached
        }
        try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * 1_000_000_000))
    }
}
