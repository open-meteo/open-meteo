import Synchronization

struct ConcurrencyLimit: Sendable {
    let slot: Int
    let maxConcurrent: Int
    let maxConcurrentHard: Int
}

final class ConcurrencyPermit: @unchecked Sendable {
    private let limiter: ConcurrencyGroupLimiter
    private let slot: Int
    private let released = Atomic(false)

    init(limiter: ConcurrencyGroupLimiter, slot: Int) {
        self.limiter = limiter
        self.slot = slot
    }

    func release() async {
        guard released.exchange(true, ordering: .relaxed) == false else {
            return
        }
        await limiter.release(slot: slot)
    }

    func releaseSoon() {
        guard released.exchange(true, ordering: .relaxed) == false else {
            return
        }
        let limiter = limiter
        let slot = slot
        Task {
            await limiter.release(slot: slot)
        }
    }

    deinit {
        releaseSoon()
    }
}

/**
 Limit concurrency in different slots
 */
actor ConcurrencyGroupLimiter {
    static let instance = ConcurrencyGroupLimiter()

    private final class Waiter: @unchecked Sendable {
        let id: UInt64
        private let state = Atomic(0)
        var continuation: CheckedContinuation<ConcurrencyPermit, any Error>?

        init(id: UInt64) {
            self.id = id
        }

        var isQueued: Bool {
            state.load(ordering: .relaxed) == 0
        }

        func markCancelled() {
            _ = state.compareExchange(expected: 0, desired: 1, ordering: .relaxed)
        }

        @discardableResult
        func claimForResume() -> Bool {
            state.compareExchange(expected: 0, desired: 2, ordering: .relaxed).exchanged
        }

        func resume(returning permit: ConcurrencyPermit) {
            guard let continuation else {
                permit.releaseSoon()
                return
            }
            self.continuation = nil
            continuation.resume(returning: permit)
        }

        func resumeCancellation() {
            guard let continuation else {
                return
            }
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }

    private struct SlotState {
        var active: Int
        var waiters: [Waiter]
    }

    private var slots: [Int: SlotState] = [:]
    private var nextWaiterID: UInt64 = 0

    func stats() -> (monitored_ips: Int, total_running: Int, queued_requests: Int) {
        let trackedSlots = slots.values.filter { $0.active > 0 || liveWaiterCount($0) > 0 }
        return (
            trackedSlots.count,
            slots.reduce(0, { $0 + $1.value.active }),
            slots.reduce(0, { $0 + liveWaiterCount($1.value) })
        )
    }
    
    func numberOfTrackedSlots() -> Int {
        slots.values.filter { $0.active > 0 || liveWaiterCount($0) > 0 }.count
    }

    func acquire(_ limit: ConcurrencyLimit) async throws -> ConcurrencyPermit {
        var state = slots[limit.slot] ?? SlotState(active: 0, waiters: [])
        removeCancelledWaiters(&state)
        guard state.active + liveWaiterCount(state) < limit.maxConcurrentHard else {
            throw RateLimitError.tooManyConcurrentRequests
        }
        guard state.active < limit.maxConcurrent else {
            let id = nextWaiterID
            nextWaiterID &+= 1
            let waiter = Waiter(id: id)
            state.waiters.append(waiter)
            slots[limit.slot] = state
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ConcurrencyPermit, any Error>) in
                    waiter.continuation = continuation
                }
            } onCancel: {
                waiter.markCancelled()
                Task {
                    await self.cancelWaiter(slot: limit.slot, id: id)
                }
            }
        }
        state.active += 1
        slots[limit.slot] = state
        return ConcurrencyPermit(limiter: self, slot: limit.slot)
    }

    private func cancelWaiter(slot: Int, id: UInt64) {
        guard var state = slots[slot] else {
            return
        }
        if let index = state.waiters.firstIndex(where: { $0.id == id }) {
            let waiter = state.waiters.remove(at: index)
            waiter.markCancelled()
            waiter.resumeCancellation()
        }
        removeCancelledWaiters(&state)
        cleanup(slot: slot, state: state)
    }

    private func cleanup(slot: Int, state: SlotState) {
        if state.active == 0 && liveWaiterCount(state) == 0 {
            slots.removeValue(forKey: slot)
        } else {
            slots[slot] = state
        }
    }

    private func liveWaiterCount(_ state: SlotState) -> Int {
        state.waiters.reduce(0) { $0 + ($1.isQueued ? 1 : 0) }
    }

    private func removeCancelledWaiters(_ state: inout SlotState) {
        state.waiters.removeAll { waiter in
            guard !waiter.isQueued else {
                return false
            }
            waiter.resumeCancellation()
            return true
        }
    }

    func release(slot: Int) {
        guard var state = slots[slot] else {
            fatalError("Released slot \(slot) but it was not in use")
        }
        guard state.active > 0 else {
            fatalError("Released slot \(slot) but no permit was active")
        }
        while !state.waiters.isEmpty {
            let waiter = state.waiters.removeFirst()
            guard waiter.claimForResume() else {
                waiter.resumeCancellation()
                continue
            }
            let permit = ConcurrencyPermit(limiter: self, slot: slot)
            waiter.resume(returning: permit)
            cleanup(slot: slot, state: state)
            return
        }
        state.active -= 1
        cleanup(slot: slot, state: state)
    }
}
