import Collections


/// Limits the number of concurrently executed tasks. More incoming tasks are queued
actor LimitedConcurrencyExecutor {
    public let maxConcurrency: Int
    
    private var activeCount = 0
    
    /// Hold suspended tasks waiting for an opening
    private var suspensionQueue = Deque<CheckedContinuation<Void, Never>>()
    
    init(maxConcurrency: Int) {
        precondition(maxConcurrency > 0)
        self.maxConcurrency = maxConcurrency
    }
    
    /// Executes a single job, suspending inside the internal queue if the ceiling is reached
    func execute<T>(_ job: () async throws -> T) async rethrows -> T {
        // If we are at capacity, wait for a slot to clear up
        if activeCount >= maxConcurrency {
            await withCheckedContinuation { continuation in
                suspensionQueue.append(continuation)
            }
        }
        
        // Claim the execution slot
        activeCount += 1
        
        defer {
            // On exit (success or failure), relinquish slot and wake up next in line
            activeCount -= 1
            if !suspensionQueue.isEmpty {
                // Execute next task
                suspensionQueue.removeFirst().resume()
            }
        }
        
        // 3. Execute the payload
        return try await job()
    }
    
    /// Wait for whatever tasks are currently executed or queued
    func awaitCurrentTasks() async throws {
        guard activeCount > 0 else {
            return
        }
        await withCheckedContinuation { continuation in
            suspensionQueue.append(continuation)
        }
    }
    
//    nonisolated func execute<T: Sendable>(stream: AsyncStream<@Sendable () async throws -> T>) async throws -> [T] {
//        let results = BoxedArray<T>()
//        await withThrowingTaskGroup { group in
//            for await taskBlock in stream {
//                group.addTask {
//                    let result = try await self.execute(taskBlock)
//                    await results.append(result)
//                }
//            }
//        }
//        return await results.array
//    }
}

extension AsyncSequence where Element: Sendable {
    func mapEnumeratedConcurrent<T: Sendable>(
        executor: LimitedConcurrencyExecutor,
        body: @escaping @Sendable (Int, Element) async throws -> T
    ) async rethrows -> [T] {
        let results = BoxedArray<(Int, T)>()
        try await withThrowingTaskGroup() { group in
            //var results = [(Int, T)]()
            var index = 0
            for try await element in self {
                let i = index
                group.addTask {
                    let result: (Int, T) = try await executor.execute {
                        return (i, try await body(i, element))
                    }
                    await results.append(result)
                }
                index += 1
            }
            return
        }
        return await results.array.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
}



actor BoxedArray<T>: Sendable {
    var array: Array<T>
    
    init(array: [T] = .init()) {
        self.array = array
    }
    
    func append(_ element: T) {
        array.append(element)
    }
}
