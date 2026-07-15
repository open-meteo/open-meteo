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

    /// Claim one execution slot, suspending if the executor is already full.
    func acquire() async {
        if activeCount >= maxConcurrency {
            await withCheckedContinuation { continuation in
                suspensionQueue.append(continuation)
            }
        } else {
            // Resumed waiters inherit the slot from the releasing task.
            activeCount += 1
        }
    }

    /// Release one execution slot and wake the next waiter if present.
    func release() {
        if !suspensionQueue.isEmpty {
            suspensionQueue.removeFirst().resume()
        } else {
            activeCount -= 1
        }
    }

    /// Executes a single job, suspending inside the internal queue if the ceiling is reached
    func execute<T>(_ job: () async throws -> T) async rethrows -> T {
        await acquire()
        do {
            let result = try await job()
            release()
            return result
        } catch {
            release()
            throw error
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
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results = [(Int, T)]()
            var index = 0
            var running = 0
            var iterator = self.makeAsyncIterator()

            while true {
                // `acquire()` below already bounds element reads and active work.
                // This drain bounds unconsumed task-group children/results, so completed
                // results and part-upload errors do not pile up until the sequence ends.
                if running >= executor.maxConcurrency, let result = try await group.next() {
                    running -= 1
                    results.append(result)
                }

                await executor.acquire()

                let element: Element?
                do {
                    element = try await iterator.next()
                } catch {
                    await executor.release()
                    throw error
                }

                guard let element else {
                    await executor.release()
                    break
                }

                let i = index
                group.addTask {
                    do {
                        let result = try await body(i, element)
                        await executor.release()
                        return (i, result)
                    } catch {
                        await executor.release()
                        throw error
                    }
                }
                index += 1
                running += 1
            }
            while let result = try await group.next() {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}
