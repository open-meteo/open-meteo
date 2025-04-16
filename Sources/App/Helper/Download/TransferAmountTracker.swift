import Vapor

/// Same as above, but not an actor
final class TransferAmountTracker {
    var transfered = 0
    var transferedLastPrint = 0
    let printDelta: Double = 20
    let startTime = Date()
    var lastPrint = Date()
    let logger: Logger
    let totalSize: Int?
    let name: String

    public init(logger: Logger, totalSize: Int?, name: String = "Transfer") {
        self.logger = logger
        self.totalSize = totalSize
        self.name = name
    }

    /// Print status from time to time
    func set(_ bytes: Int) {
        transfered = bytes
        let deltaT = Date().timeIntervalSince(lastPrint)
        if deltaT > printDelta {
            let timeElapsed = Date().timeIntervalSince(startTime).asSecondsPrettyPrint
            let rate = (transfered - transferedLastPrint) / Int(deltaT)
            if let totalSize {
                let percent = Int(round(Float(transfered) / Float(totalSize) * 100))
                let remainingTime = Double(totalSize - transfered) / (Double(transfered - transferedLastPrint) / deltaT)
                logger.info("\(name) \(percent)% \(transfered.bytesHumanReadable) / \(totalSize.bytesHumanReadable) in \(timeElapsed), \(rate.bytesHumanReadable)/s remaining \(remainingTime.asSecondsPrettyPrint)")
            } else {
                logger.info("\(name) \(transfered.bytesHumanReadable) in \(timeElapsed), \(rate.bytesHumanReadable)/s")
            }

            lastPrint = Date()
            transferedLastPrint = transfered
        }
    }

    /// Print status from time to time
    func add(_ bytes: Int) {
        set(bytes + transfered)
    }

    /// Print end statistics
    func finish() {
        guard transfered > 0 else {
            return
        }
        let timeElapsed = Date().timeIntervalSince(startTime)
        let rate = Int(Double(transfered) / timeElapsed)
        logger.info("\(name) completed \(transfered.bytesHumanReadable) in \(timeElapsed.asSecondsPrettyPrint). Average speed \(rate.bytesHumanReadable)/s")
    }
}
