import Logging

/// Execute jobs in serial in the background and return the result with `collect()`
//actor ProcessingSerialQueue<T: Sendable> {
//    private var continuation: AsyncStream<() async -> T>.Continuation
//    private var processingTask: Task<[T], Never>
//    
//    init() {
//        let (stream, continuation) = AsyncStream<() async -> T>.makeStream()
//        self.continuation = continuation
//        
//        // Store the task reference
//        self.processingTask = Task {
//            var results = [T]()
//            for await taskBlock in stream {
//                results.append(await taskBlock())
//            }
//            return results
//        }
//    }
//    
//    /// Enqueues work into the serial queue
//    func enqueue(_ work: @escaping @Sendable () async -> T) {
//        continuation.yield(work)
//    }
//    
//    /// Closes the queue, drains all remaining tasks, and terminates the background loop.
//    func collect() async -> [T] {
//        continuation.finish()
//        return await processingTask.value
//    }
//    
//    deinit {
//        continuation.finish()
//    }
//}

/// Execute jobs in serial in the background and return the result with `collect()`
actor ProcessingSerialQueue {
    private var continuation: AsyncStream<() async -> ()>.Continuation
    private var processingTask: Task<Void, Never>
    private let onError: @Sendable () -> Void
    
    init(onError: @escaping @Sendable () -> Void = {}) {
        let (stream, continuation) = AsyncStream<() async -> ()>.makeStream()
        self.continuation = continuation
        self.onError = onError
        self.processingTask = Task {
            for await taskBlock in stream {
                await taskBlock()
            }
        }
    }
    
    /// Enqueues work into the serial queue
    func enqueue(_ work: @escaping @Sendable () async -> ()) {
        continuation.yield(work)
    }
    
    func enqueueIgnoreError(logger: Logger, _ work: @escaping @Sendable () async throws -> ()) {
        let onError = onError
        continuation.yield({
            do {
                try await work()
            } catch {
                logger.error("Error during queued work: \(error)")
                onError()
            }
        })
    }
    
    /// Closes the queue, drains all remaining tasks, and terminates the background loop.
    func finish() async {
        continuation.finish()
        return await processingTask.value
    }
    
    deinit {
        continuation.finish()
    }
}
