import Foundation
@testable import App
import Testing
import Synchronization
import Vapor

private struct TestStreamWriter: AsyncBodyStreamWriter {
    func write(_ result: BodyStreamResult) async throws {
    }
}

@Suite struct ConcurrencyGroupLimiterTests {
    private func waitForStats(_ limiter: ConcurrencyGroupLimiter, predicate: ((monitored_ips: Int, total_running: Int, queued_requests: Int)) -> Bool) async throws {
        for _ in 0..<20 {
            let stats = await limiter.stats()
            if predicate(stats) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(Bool(false), "Timed out waiting for limiter stats")
    }

    /// A request queued past maxConcurrent is unblocked when a slot is released
    @Test func queuedRequestIsUnblocked() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let limit = ConcurrencyLimit(slot: 7, maxConcurrent: 1, maxConcurrentHard: 3)
        // Fill up to the soft limit
        let firstPermit = try await limiter.acquire(limit)

        // This request should queue because count (1) >= maxConcurrent (1)
        let waiterTask = Task<ConcurrencyPermit, any Error> {
            try await limiter.acquire(limit)
        }
        
        // This request should queue because count (1) >= maxConcurrent (1)
        let waiterTask2 = Task<ConcurrencyPermit, any Error> {
            try await limiter.acquire(limit)
        }
        
        // Give the waiter task time to enqueue
        try await Task.sleep(nanoseconds: 10_000_000)
        
        await #expect(throws: RateLimitError.tooManyConcurrentRequests) {
            _ = try await limiter.acquire(limit)
        }

        let s = await limiter.stats()
        #expect(s.total_running == 1)
        #expect(s.queued_requests == 2)

        // Releasing the first slot should unblock the waiter;
        // awaiting the task proves it actually ran.
        await firstPermit.release()
        
        let s2 = await limiter.stats()
        #expect(s2.queued_requests == 1)
        #expect(s2.total_running == 1)
        
        let secondPermit = try await waiterTask.value
        await secondPermit.release()
        let s3 = await limiter.stats()
        #expect(s3.queued_requests == 0)
        #expect(s3.total_running == 1)
        
        let thirdPermit = try await waiterTask2.value
        await thirdPermit.release()
        let s4 = await limiter.stats()
        #expect(s4.queued_requests == 0)
        #expect(s4.total_running == 0)
    }

    /// Different slots are tracked independently
    @Test func independentSlots() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let permit1 = try await limiter.acquire(.init(slot: 1, maxConcurrent: 1, maxConcurrentHard: 2))
        let permit2 = try await limiter.acquire(.init(slot: 2, maxConcurrent: 1, maxConcurrentHard: 2))
        let s = await limiter.stats()
        #expect(s.monitored_ips == 2)
        #expect(s.total_running == 2)
        await permit1.release()
        let s2 = await limiter.stats()
        #expect(s2.monitored_ips == 1)
        #expect(s2.total_running == 1)
        await permit2.release()
    }

    /// Cancelling a queued acquire removes it from the queue and does not consume capacity
    @Test func queuedAcquireCancellationDoesNotLeak() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let limit = ConcurrencyLimit(slot: 8, maxConcurrent: 1, maxConcurrentHard: 3)
        let permit = try await limiter.acquire(limit)
        let waiterTask = Task<ConcurrencyPermit, any Error> {
            try await limiter.acquire(limit)
        }

        try await waitForStats(limiter) { $0.total_running == 1 && $0.queued_requests == 1 }
        waiterTask.cancel()
        do {
            _ = try await waiterTask.value
            Issue.record("Expected queued acquire to be cancelled")
        } catch is CancellationError {
            // expected
        }

        try await waitForStats(limiter) { $0.total_running == 1 && $0.queued_requests == 0 }
        await permit.release()
        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }
    }

    /// Cancellation and release can arrive in either order without leaking the transferred slot
    @Test func queuedAcquireCancellationRacingReleaseDoesNotLeak() async throws {
        for slot in 100..<150 {
            let limiter = ConcurrencyGroupLimiter()
            let limit = ConcurrencyLimit(slot: slot, maxConcurrent: 1, maxConcurrentHard: 2)
            let permit = try await limiter.acquire(limit)
            let waiterTask = Task<ConcurrencyPermit, any Error> {
                try await limiter.acquire(limit)
            }

            try await waitForStats(limiter) { $0.total_running == 1 && $0.queued_requests == 1 }
            waiterTask.cancel()
            await permit.release()

            do {
                let transferredPermit = try await waiterTask.value
                await transferredPermit.release()
            } catch is CancellationError {
                // Cancellation won the race.
            }

            try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }
        }
    }

    /// Permit release is idempotent and deinit also releases if callers forget
    @Test func permitReleaseIsIdempotentAndDeinitReleases() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let limit = ConcurrencyLimit(slot: 9, maxConcurrent: 1, maxConcurrentHard: 2)
        let permit = try await limiter.acquire(limit)
        await permit.release()
        await permit.release()
        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }

        do {
            let forgotten = try await limiter.acquire(limit)
            _ = forgotten
            let s = await limiter.stats()
            #expect(s.total_running == 1)
        }
        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }
    }

    /// The streaming helper releases its owned permit after the body task completes or throws
    @Test func streamSubmitReleasesPermit() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let limit = ConcurrencyLimit(slot: 10, maxConcurrent: 1, maxConcurrentHard: 2)
        let writer = TestStreamWriter()
        let logger = Logger(label: "ConcurrencyGroupLimiterTests")

        let successPermit = try await limiter.acquire(limit)
        try await writer.submit(concurrencyPermit: successPermit, logger: logger) {}
        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }

        struct TestError: Error {}
        let errorPermit = try await limiter.acquire(limit)
        try await writer.submit(concurrencyPermit: errorPermit, logger: logger) {
            throw TestError()
        }
        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }
    }

    /// If Vapor/NIO drops a response before invoking the async body, the captured permit is released by deinit
    @Test func droppedStreamingResponseReleasesPermit() async throws {
        let limiter = ConcurrencyGroupLimiter()
        let limit = ConcurrencyLimit(slot: 11, maxConcurrent: 1, maxConcurrentHard: 2)
        let logger = Logger(label: "ConcurrencyGroupLimiterTests")

        do {
            let permit = try await limiter.acquire(limit)
            _ = Response(body: .init(asyncStream: { writer in
                try await writer.submit(concurrencyPermit: permit, logger: logger) {}
            }))
            let stats = await limiter.stats()
            #expect(stats.total_running == 1)
        }

        try await waitForStats(limiter) { $0.total_running == 0 && $0.queued_requests == 0 }
    }
}
