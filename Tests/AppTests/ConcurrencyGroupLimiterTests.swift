import Foundation
@testable import App
import Testing
import Synchronization

@Suite struct ConcurrencyGroupLimiterTests {
    /// A request queued past maxConcurrent is unblocked when a slot is released
    @Test func queuedRequestIsUnblocked() async throws {
        let limiter = ConcurrencyGroupLimiter()
        // Fill up to the soft limit
        try await limiter.wait(slot: 7, maxConcurrent: 1, maxConcurrentHard: 3)

        // This request should queue because count (1) >= maxConcurrent (1)
        let waiterTask = Task<Void, any Error> {
            try await limiter.wait(slot: 7, maxConcurrent: 1, maxConcurrentHard: 3)
        }
        
        // This request should queue because count (1) >= maxConcurrent (1)
        let waiterTask2 = Task<Void, any Error> {
            try await limiter.wait(slot: 7, maxConcurrent: 1, maxConcurrentHard: 3)
        }
        
        // Give the waiter task time to enqueue
        try await Task.sleep(nanoseconds: 10_000_000)
        
        await #expect(throws: RateLimitError.tooManyConcurrentRequests) {
            try await limiter.wait(slot: 7, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        let s = await limiter.stats()
        #expect(s.total_running == 3)
        #expect(s.queued_requests == 2)

        // Releasing the first slot should unblock the waiter;
        // awaiting the task proves it actually ran.
        await limiter.release(slot: 7)
        
        let s2 = await limiter.stats()
        #expect(s2.queued_requests == 1)
        #expect(s2.total_running == 2)
        
        await limiter.release(slot: 7)
        let s3 = await limiter.stats()
        #expect(s3.queued_requests == 0)
        #expect(s3.total_running == 1)
        
        try await waiterTask.value
        try await waiterTask2.value
        
        await limiter.release(slot: 7)
        let s4 = await limiter.stats()
        #expect(s4.queued_requests == 0)
        #expect(s4.total_running == 0)
    }

    /// Different slots are tracked independently
    @Test func independentSlots() async throws {
        let limiter = ConcurrencyGroupLimiter()
        try await limiter.wait(slot: 1, maxConcurrent: 1, maxConcurrentHard: 2)
        try await limiter.wait(slot: 2, maxConcurrent: 1, maxConcurrentHard: 2)
        let s = await limiter.stats()
        #expect(s.monitored_ips == 2)
        #expect(s.total_running == 2)
        await limiter.release(slot: 1)
        let s2 = await limiter.stats()
        #expect(s2.monitored_ips == 1)
        #expect(s2.total_running == 1)
        await limiter.release(slot: 2)
    }
}
