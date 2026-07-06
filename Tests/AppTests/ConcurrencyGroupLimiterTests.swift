import Foundation
@testable import App
import Testing
import Synchronization

@Suite struct ConcurrencyGroupLimiterTests {
    private func waitForStats(
        _ limiter: ConcurrencyGroupLimiter,
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        _ predicate: ((monitored_ips: Int, total_running: Int, queued_requests: Int)) -> Bool
    ) async throws -> (monitored_ips: Int, total_running: Int, queued_requests: Int) {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let stats = await limiter.stats()
            if predicate(stats) {
                return stats
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        return await limiter.stats()
    }

    private func expectCancellation(_ task: Task<Void, any Error>) async {
        do {
            try await task.value
            Issue.record("Expected task cancellation")
        } catch is CancellationError {
            return
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }

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
        
        _ = try await waitForStats(limiter) {
            $0.total_running == 3 && $0.queued_requests == 2
        }
        
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

    @Test func cancellingSecondQueuedRequestDoesNotCancelFirst() async throws {
        let limiter = ConcurrencyGroupLimiter()
        try await limiter.wait(slot: 11, maxConcurrent: 1, maxConcurrentHard: 3)

        let firstWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 11, maxConcurrent: 1, maxConcurrentHard: 3)
        }
        let secondWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 11, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        _ = try await waitForStats(limiter) {
            $0.total_running == 3 && $0.queued_requests == 2
        }

        secondWaiter.cancel()
        await expectCancellation(secondWaiter)

        let afterCancel = try await waitForStats(limiter) {
            $0.total_running == 2 && $0.queued_requests == 1
        }
        #expect(afterCancel.total_running == 2)
        #expect(afterCancel.queued_requests == 1)

        await limiter.release(slot: 11)
        try await firstWaiter.value

        let afterRelease = await limiter.stats()
        #expect(afterRelease.total_running == 1)
        #expect(afterRelease.queued_requests == 0)

        await limiter.release(slot: 11)
        let final = await limiter.stats()
        #expect(final.total_running == 0)
        #expect(final.queued_requests == 0)
    }

    @Test func cancellingFirstQueuedRequestLetsSecondRun() async throws {
        let limiter = ConcurrencyGroupLimiter()
        try await limiter.wait(slot: 12, maxConcurrent: 1, maxConcurrentHard: 3)

        let firstWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 12, maxConcurrent: 1, maxConcurrentHard: 3)
        }
        let secondWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 12, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        _ = try await waitForStats(limiter) {
            $0.total_running == 3 && $0.queued_requests == 2
        }

        firstWaiter.cancel()
        await expectCancellation(firstWaiter)

        let afterCancel = try await waitForStats(limiter) {
            $0.total_running == 2 && $0.queued_requests == 1
        }
        #expect(afterCancel.total_running == 2)
        #expect(afterCancel.queued_requests == 1)

        await limiter.release(slot: 12)
        try await secondWaiter.value

        let afterRelease = await limiter.stats()
        #expect(afterRelease.total_running == 1)
        #expect(afterRelease.queued_requests == 0)

        await limiter.release(slot: 12)
        let final = await limiter.stats()
        #expect(final.total_running == 0)
        #expect(final.queued_requests == 0)
    }

    @Test func queuedCancellationFreesHardLimitCapacity() async throws {
        let limiter = ConcurrencyGroupLimiter()
        try await limiter.wait(slot: 13, maxConcurrent: 1, maxConcurrentHard: 3)

        let firstWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 13, maxConcurrent: 1, maxConcurrentHard: 3)
        }
        let secondWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 13, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        _ = try await waitForStats(limiter) {
            $0.total_running == 3 && $0.queued_requests == 2
        }

        await #expect(throws: RateLimitError.tooManyConcurrentRequests) {
            try await limiter.wait(slot: 13, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        secondWaiter.cancel()
        await expectCancellation(secondWaiter)

        _ = try await waitForStats(limiter) {
            $0.total_running == 2 && $0.queued_requests == 1
        }

        let replacementWaiter = Task<Void, any Error> {
            try await limiter.wait(slot: 13, maxConcurrent: 1, maxConcurrentHard: 3)
        }

        _ = try await waitForStats(limiter) {
            $0.total_running == 3 && $0.queued_requests == 2
        }

        await limiter.release(slot: 13)
        try await firstWaiter.value
        await limiter.release(slot: 13)
        try await replacementWaiter.value
        await limiter.release(slot: 13)

        let final = await limiter.stats()
        #expect(final.total_running == 0)
        #expect(final.queued_requests == 0)
    }

    @Test func cancellingQueuedRequestsInDifferentSlotsIsIndependent() async throws {
        let limiter = ConcurrencyGroupLimiter()
        try await limiter.wait(slot: 21, maxConcurrent: 1, maxConcurrentHard: 2)
        try await limiter.wait(slot: 22, maxConcurrent: 1, maxConcurrentHard: 2)

        let waiter21 = Task<Void, any Error> {
            try await limiter.wait(slot: 21, maxConcurrent: 1, maxConcurrentHard: 2)
        }
        let waiter22 = Task<Void, any Error> {
            try await limiter.wait(slot: 22, maxConcurrent: 1, maxConcurrentHard: 2)
        }

        _ = try await waitForStats(limiter) {
            $0.monitored_ips == 2 && $0.total_running == 4 && $0.queued_requests == 2
        }

        waiter21.cancel()
        await expectCancellation(waiter21)

        let afterCancel = try await waitForStats(limiter) {
            $0.monitored_ips == 2 && $0.total_running == 3 && $0.queued_requests == 1
        }
        #expect(afterCancel.total_running == 3)
        #expect(afterCancel.queued_requests == 1)

        await limiter.release(slot: 22)
        try await waiter22.value

        await limiter.release(slot: 21)
        await limiter.release(slot: 22)

        let final = await limiter.stats()
        #expect(final.total_running == 0)
        #expect(final.queued_requests == 0)
    }

    @Test func releaseCancelRaceDoesNotLeakAcceptedRequest() async throws {
        for slot in 100..<150 {
            let limiter = ConcurrencyGroupLimiter()
            try await limiter.wait(slot: slot, maxConcurrent: 1, maxConcurrentHard: 2)

            let waiter = Task<Void, any Error> {
                try await limiter.wait(slot: slot, maxConcurrent: 1, maxConcurrentHard: 2)
            }

            _ = try await waitForStats(limiter) {
                $0.total_running == 2 && $0.queued_requests == 1
            }

            let releaseTask = Task {
                await limiter.release(slot: slot)
            }
            waiter.cancel()
            await releaseTask.value

            do {
                try await waiter.value
                await limiter.release(slot: slot)
            } catch is CancellationError {
                // Cancellation won before the waiter was admitted.
            } catch {
                Issue.record("Expected success or CancellationError, got \(error)")
            }

            let final = try await waitForStats(limiter) {
                $0.total_running == 0 && $0.queued_requests == 0
            }
            #expect(final.total_running == 0)
            #expect(final.queued_requests == 0)
        }
    }
}
