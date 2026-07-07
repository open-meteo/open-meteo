import Collections

/// Limits the number of concurrently executed tasks. More incoming tasks are queued
actor LimitedConcurrencyExecutor {
    public nonisolated let maxConcurrency: Int
    
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
        } else {
            // Claim the execution slot. Resumed waiters inherit the slot from the releasing task.
            activeCount += 1
        }
        
        defer {
            // On exit (success or failure), relinquish slot and wake up next in line
            if !suspensionQueue.isEmpty {
                suspensionQueue.removeFirst().resume()
            } else {
                activeCount -= 1
            }
        }
        
        // 3. Execute the payload
        return try await job()
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
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results = [(Int, T)]()
            var index = 0
            for try await element in self {
                // `for try await` has already read `element` before this check runs.
                // Retaining at most one element over `maxConcurrency` is acceptable here
                // but we need to prevent unbounded scheduling.
                if index >= executor.maxConcurrency, let result = try await group.next() {
                    results.append(result)
                }
                let i = index
                group.addTask {
                    return try await executor.execute {
                        return (i, try await body(i, element))
                    }
                }
                index += 1
            }
            while let result = try await group.next() {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}
