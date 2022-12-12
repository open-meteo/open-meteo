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

/// Track the progress of some work
final class ProgressTracker {
    var done = 0
    var doneLastPrint = 0
    var total: Int
    
    let printDelta: Double = 20
    let startTime = Date()
    var lastPrint = Date()
    
    let logger: Logger
    let label: String
    
    public init(logger: Logger, total: Int, label: String) {
        self.logger = logger
        self.total = total
        self.label = label
    }
    
    /// Print status from time to time
    func add(_ work: Int) {
        done += work
        let deltaT = Date().timeIntervalSince(lastPrint)
        if deltaT > printDelta {
            let timeElapsed = Date().timeIntervalSince(startTime)
            let ratio = Int(Float(done) / (Float(total)) * 100)
            let rate = Double(done - doneLastPrint) / deltaT
            logger.info("[ \(label) ] Completed \(ratio)% \(work) / \(total) in \(Int(timeElapsed/60)):\((Int(timeElapsed) % 60).zeroPadded(len: 2)), \(rate.rounded()) per second")
            lastPrint = Date()
            doneLastPrint = done
        }
    }
}
