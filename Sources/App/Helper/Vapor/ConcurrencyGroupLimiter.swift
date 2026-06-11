/**
 Limit concurrency in different slots
 */
actor ConcurrencyGroupLimiter {
    static let instance = ConcurrencyGroupLimiter()
    
    /// Number of running per slot
    private var counts: [Int: Int] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, any Error>]] = [:]

    func stats() -> (monitored_ips: Int, total_running: Int, queued_requests: Int) {
        (counts.count, counts.reduce(0, { $0 + $1.value }), waiters.reduce(0, { $0 + $1.value.count }))
    }

    func wait(slot: Int, maxConcurrent: Int, maxConcurrentHard: Int) async throws {
        guard let count = counts[slot] else {
            counts[slot] = 1
            // print("Single request slot \(slot)")
            return
        }
        guard count < maxConcurrentHard else {
            throw RateLimitError.tooManyConcurrentRequests
        }
        counts[slot] = count + 1
        if count >= maxConcurrent {
            // print("Queuing request slot \(slot)")
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                    waiters[slot, default: []].append(cont)
                }
            } onCancel: {
                Task { await self.cancelWaiter(slot: slot) }
            }
        }
    }

    private func cancelWaiter(slot: Int) {
        guard var list = waiters[slot], !list.isEmpty else { return }
        let cont = list.removeFirst()
        waiters[slot] = list.isEmpty ? nil : list
        counts[slot] = (counts[slot] ?? 1) - 1
        cont.resume(throwing: CancellationError())
    }

    func release(slot: Int) {
        guard let count = counts[slot] else {
            fatalError("Released slot \(slot) but it was not in use")
        }
        guard count > 1 else {
            // print("All requests finished for slot \(slot)")
            counts.removeValue(forKey: slot)
            return
        }
        counts[slot] = count - 1
        guard let cont = waiters[slot]?.removeFirst() else {
            return // no other requests are queued
        }
        if waiters[slot]?.isEmpty == true {
            waiters.removeValue(forKey: slot)
        }
        // print("Running queued request at slot \(slot)")
        cont.resume()
    }
}
