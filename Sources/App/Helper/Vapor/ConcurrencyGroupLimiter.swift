import NIOConcurrencyHelpers

let apiConcurrencyLimiter = ConcurrencyGroupLimiter()

/**
 Limit concurrency in different slots
 
 See: https://forums.swift.org/t/semaphore-alternatives-for-structured-concurrency/59353/3
 */
final class ConcurrencyGroupLimiter {
    let lock = NIOLock()
    /// Number of running per slot
    private var counts: [Int: Int] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init() {}

    func wait(slot: Int) async throws {
        lock.lock()
        guard let count = self.counts[slot] else {
            self.counts[slot] = 1
            lock.unlock()
            //print("Single request slot \(slot)")
            return
        }
        guard count < 5 else {
            lock.unlock()
            throw RateLimitError.tooManyConcurrentRequests
        }
        counts[slot] = count + 1
        await withCheckedContinuation {
            //print("Queuing request slot \(slot)")
            waiters.append((slot, $0))
            lock.unlock()
        }
    }

    func release(slot: Int) {
        lock.lock()
        guard let count = self.counts[slot] else {
            return
        }
        guard count > 1 else {
            //print("All requests finished for slot \(slot)")
            self.counts.removeValue(forKey: slot)
            lock.unlock()
            return
        }
        self.counts[slot] = count - 1
        guard let index = waiters.firstIndex(where: {$0.0 == slot}) else {
            fatalError("Did not find waiting request")
        }
        //print("Running queued request at slot \(slot)")
        let cont = waiters[index].1
        waiters.remove(at: index)
        lock.unlock()
        cont.resume()
    }
}
