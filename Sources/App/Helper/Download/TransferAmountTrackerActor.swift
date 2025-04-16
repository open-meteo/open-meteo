import Vapor

extension AsyncSequence where Element == ByteBuffer {
    /// Get tracker to print and track transfer rates
    func tracker(_ tracker: TransferAmountTrackerActor) -> TransferAmountTrackerStream<Self> {
        return TransferAmountTrackerStream(sequence: self, tracker: tracker)
    }
}

final actor TransferAmountTrackerActor {
    private let tracker: TransferAmountTracker

    var transfered: Int {
        tracker.transfered
    }

    public init(logger: Logger, totalSize: Int?, name: String = "Transfer") {
        self.tracker = TransferAmountTracker(logger: logger, totalSize: totalSize, name: name)
    }

    /// Print status from time to time
    func set(_ bytes: Int) {
        tracker.set(bytes)
    }

    /// Print status from time to time
    func add(_ bytes: Int) {
        tracker.add(bytes)
    }

    /// Print end statistics
    func finish() {
        tracker.finish()
    }
}

/// Sum up transfered amount and print statistics every couple of seconds
struct TransferAmountTrackerStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element

    let sequence: T
    let tracker: TransferAmountTrackerActor

    public init(sequence: T, tracker: TransferAmountTrackerActor) {
        self.sequence = sequence
        self.tracker = tracker
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var tracker: TransferAmountTrackerActor
        private var iterator: T.AsyncIterator

        fileprivate init(tracker: TransferAmountTrackerActor, iterator: T.AsyncIterator) {
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
        if self > 5 * 1024 * 1024 * 1024 {
            return "\((Double(self) / 1024 / 1024 / 1024).round(digits: 1)) GB"
        }
        if self > 1 * 1024 * 1024 * 1024 {
            return "\((Double(self) / 1024 / 1024 / 1024).round(digits: 2)) GB"
        }
        if self > 5 * 1024 * 1024 {
            return "\((Double(self) / 1024 / 1024).round(digits: 1)) MB"
        }
        if self > 1 * 1024 * 1024 {
            return "\((Double(self) / 1024 / 1024).round(digits: 2)) MB"
        }
        if self > 5 * 1024 {
            return "\((Double(self) / 1024).round(digits: 1)) KB"
        }
        if self > 1 * 1024 {
            return "\((Double(self) / 1024).round(digits: 2)) KB"
        }
        return "\(self) bytes"
    }
}
