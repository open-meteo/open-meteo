import Vapor


extension AsyncSequence where Element == ByteBuffer {
    /// Get tracker to print and track transfer rates
    func tracker(_ tracker: TransferAmountTracker) -> TransferAmountTrackerStream<Self> {
        return TransferAmountTrackerStream(sequence: self, tracker: tracker)
    }
}

final class TransferAmountTracker {
    var transfered = 0
    var transferedLastPrint = 0
    let printDelta: Double = 20
    let startTime = Date()
    var lastPrint = Date()
    let logger: Logger
    let totalSize: Int?
    
    public init(logger: Logger, totalSize: Int?) {
        self.logger = logger
        self.totalSize = totalSize
    }
    
    /// Print status from time to time
    func add(_ bytes: Int) {
        transfered += bytes
        let deltaT = Date().timeIntervalSince(lastPrint)
        if deltaT > printDelta {
            let timeElapsed = Date().timeIntervalSince(startTime)
            let rate = (transfered - transferedLastPrint) / Int(deltaT)
            logger.info("Transferred \(transfered.bytesHumanReadable) / \(totalSize?.bytesHumanReadable ?? "-") in \(Int(timeElapsed/60)):\((Int(timeElapsed) % 60).zeroPadded(len: 2)), \(rate.bytesHumanReadable)/s")
            lastPrint = Date()
            transferedLastPrint = transfered
        }
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
            tracker.add(data.readableBytes)
            return data
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(tracker: tracker, iterator: sequence.makeAsyncIterator())
    }
}
