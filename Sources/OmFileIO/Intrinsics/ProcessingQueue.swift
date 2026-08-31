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
    
    init() {
        let (stream, continuation) = AsyncStream<() async -> ()>.makeStream()
        self.continuation = continuation
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
        continuation.yield({
            do {
                try await work()
            } catch {
                logger.error("Error during queued work: \(error)")
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

/// Executes jobs in parallel in the background and return the result in `collect()`. Order is NOT preserved!
actor ProcessingParallelQueue<T: Sendable> {
    private var continuation: AsyncStream<@Sendable () async -> T?>.Continuation
    private var processingTask: Task<[T], Never>
    
    init(executor: LimitedConcurrencyExecutor) {
        let (stream, continuation) = AsyncStream<@Sendable () async -> T?>.makeStream()
        self.continuation = continuation
        self.processingTask = Task {
            var results = [T]()
            await withTaskGroup(of: T?.self) { group in
                var running = 0
                for await taskBlock in stream {
                    // If all worker slots are occupied, wait for one child task to finish
                    // before scheduling more work. This prevents unbounded child tasks from
                    // piling up inside the executor while preserving the stream backlog behavior.
                    if running >= executor.maxConcurrency, let result = await group.next() {
                        running -= 1
                        if let result {
                            results.append(result)
                        }
                    }
                    // Claim a task-group slot. The executor still enforces shared concurrency,
                    // but the queue no longer creates more children than it can actively run.
                    group.addTask {
                        await executor.execute {
                            await taskBlock()
                        }
                    }
                    running += 1
                }
                // On stream termination, drain all remaining child tasks and collect results.
                while let result = await group.next() {
                    if let result {
                        results.append(result)
                    }
                }
            }
            return results
        }
    }
    
    /// Enqueues work into the parallel queue
    func enqueue(_ work: @escaping @Sendable () async -> T) {
        continuation.yield(work)
    }
    
    /// Enqueues work into the parallel queue. Ignores errors
    func enqueueIgnoreError(logger: Logger, _ work: @escaping @Sendable () async throws -> T) {
        continuation.yield({
            do {
                return try await work()
            } catch {
                logger.error("Error during queued work: \(error)")
            }
            return nil
        })
    }
    
    /// Closes the queue, drains all remaining tasks in parallel, and collects results. Order is NOT preserved!
    func collect() async -> [T] {
        continuation.finish()
        return await processingTask.value
    }
    
    deinit {
        continuation.finish()
    }
}
