import Vapor

extension AsyncSequence where Element == ByteBuffer {
    /// Get tracker to print and track transfer rates
    func tracker(_ tracker: TransferAmountTracker) -> TransferAmountTrackerStream<Self> {
        return TransferAmountTrackerStream(sequence: self, tracker: tracker)
    }
}

final actor TransferAmountTracker {
    var transfered = 0
    var transferedLastPrint = 0
    let printDelta: Double = 20
    let startTime = Date()
    var lastPrint = Date()
    let logger: Logger
    let totalSize: Int?
    let name: String
    
    public init(logger: Logger, totalSize: Int?, name: String = "Transferred") {
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
        logger.info("Completed in \(timeElapsed.asSecondsPrettyPrint). Average speed \(rate.bytesHumanReadable)/s")
    }
}

/// Sum up transfered amount and print statistics every couple of seconds
struct TransferAmountTrackerStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element
    
    let sequence: T
    let tracker: TransferAmountTracker
    
    public init(sequence: T, tracker: TransferAmountTracker) {
        self.sequence = sequence
        self.tracker = tracker
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var tracker: TransferAmountTracker
        private var iterator: T.AsyncIterator

        fileprivate init(tracker: TransferAmountTracker, iterator: T.AsyncIterator) {
            self.tracker = tracker
            self.iterator = iterator
        }

        public func next() async throws -> ByteBuffer? {
            guard let data = try await self.iterator.next() else {
                return nil
            }
            await tracker.add(data.readableBytes)
            return data
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(tracker: tracker, iterator: sequence.makeAsyncIterator())
    }
}

extension Int {
    /// Format number of bytes to a human readable format like `5.5 MB`
    var bytesHumanReadable: String {
        if self > 5 * 1024*1024*1024 {
            return "\((Double(self)/1024/1024/1024).round(digits: 1)) GB"
        }
        if self > 1 * 1024*1024*1024 {
            return "\((Double(self)/1024/1024/1024).round(digits: 2)) GB"
        }
        if self > 5 * 1024*1024 {
            return "\((Double(self)/1024/1024).round(digits: 1)) MB"
        }
        if self > 1 * 1024*1024 {
            return "\((Double(self)/1024/1024).round(digits: 2)) MB"
        }
        if self > 5 * 1024 {
            return "\((Double(self)/1024).round(digits: 1)) KB"
        }
        if self > 1 * 1024 {
            return "\((Double(self)/1024).round(digits: 2)) KB"
        }
        return "\(self) bytes"
    }
}
