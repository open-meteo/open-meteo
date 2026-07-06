import Synchronization

/**
 Limit concurrency in different slots
 */
actor ConcurrencyGroupLimiter {
    static let instance = ConcurrencyGroupLimiter()
    
    private var slots: [Int: ConcurrencySlot] = [:]

    func stats() -> (monitored_ips: Int, total_running: Int, queued_requests: Int) {
        let slotStats = slots.values.map { $0.stats() }
        return (
            slots.count,
            slotStats.reduce(0, { $0 + $1.inUse }),
            slotStats.reduce(0, { $0 + $1.queued })
        )
    }
    
    func numberOfTrackedSlots() -> Int {
        slots.count
    }

    func wait(slot: Int, maxConcurrent: Int, maxConcurrentHard: Int) async throws {
        try Task.checkCancellation()

        let concurrencySlot = slots[slot] ?? {
            let new = ConcurrencySlot()
            slots[slot] = new
            return new
        }()

        switch concurrencySlot.enter(maxConcurrent: maxConcurrent, maxConcurrentHard: maxConcurrentHard) {
        case .admitted:
            return

        case .rejected:
            pruneSlot(slot, concurrencySlot)
            throw RateLimitError.tooManyConcurrentRequests

        case .queued(let waiter):
            do {
                try await waiter.wait(in: concurrencySlot)
            } catch {
                pruneSlot(slot, concurrencySlot)
                throw error
            }
        }
    }

    private func pruneSlot(_ slot: Int, _ concurrencySlot: ConcurrencySlot) {
        if concurrencySlot.isIdle {
            slots.removeValue(forKey: slot)
        }
    }

    func release(slot: Int) {
        guard let concurrencySlot = slots[slot] else {
            fatalError("Released slot \(slot) but it was not in use")
        }

        let continuation = concurrencySlot.release()
        pruneSlot(slot, concurrencySlot)
        continuation?.resume()
    }
}

private final class ConcurrencySlot: Sendable {
    private struct State {
        var inUse = 0
        var waiters: [Waiter] = []
        var nextWaiterID: UInt64 = 0
    }

    private let state = Mutex(State())

    enum EnterResult {
        case admitted
        case queued(Waiter)
        case rejected
    }

    var isIdle: Bool {
        state.withLock { state in
            state.inUse == 0 && state.waiters.isEmpty
        }
    }

    func stats() -> (inUse: Int, queued: Int) {
        state.withLock { state in
            (state.inUse, state.waiters.reduce(0, { $0 + ($1.isQueued ? 1 : 0) }))
        }
    }

    func enter(maxConcurrent: Int, maxConcurrentHard: Int) -> EnterResult {
        state.withLock { state in
            guard state.inUse < maxConcurrentHard else {
                return .rejected
            }

            state.inUse += 1
            guard state.inUse > maxConcurrent else {
                return .admitted
            }

            let waiter = Waiter(id: state.nextWaiterID)
            state.nextWaiterID &+= 1
            state.waiters.append(waiter)
            return .queued(waiter)
        }
    }

    func cancel(waiter: Waiter) {
        let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            guard let index = state.waiters.firstIndex(where: { $0 === waiter }) else {
                return nil
            }
            guard let result = waiter.cancelQueued() else {
                return nil
            }
            state.waiters.remove(at: index)
            state.inUse -= 1
            return result
        }
        continuation?.resume(throwing: CancellationError())
    }

    func release() -> CheckedContinuation<Void, any Error>? {
        state.withLock { state in
            guard state.inUse > 0 else {
                fatalError("Released slot but it was not in use")
            }

            state.inUse -= 1

            while !state.waiters.isEmpty {
                let waiter = state.waiters.removeFirst()
                switch waiter.admit() {
                case .admitted(let continuation):
                    return continuation
                case .skip:
                    continue
                }
            }

            return nil
        }
    }
}

private final class Waiter: Sendable {
    private enum State: Int {
        case created = 0
        case waiting = 1
        case admitted = 2
        case cancelled = 3
        case completed = 4
    }

    enum AdmitResult {
        case admitted(CheckedContinuation<Void, any Error>?)
        case skip
    }

    let id: UInt64
    private let currentState = Atomic(State.created.rawValue)
    private let continuation = Mutex<CheckedContinuation<Void, any Error>?>(nil)

    init(id: UInt64) {
        self.id = id
    }

    var isQueued: Bool {
        switch State(rawValue: currentState.load(ordering: .relaxed)) {
        case .created, .waiting:
            return true
        case .admitted, .cancelled, .completed, nil:
            return false
        }
    }

    func wait(in slot: ConcurrencySlot) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                switch install(continuation) {
                case .none:
                    break
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            slot.cancel(waiter: self)
        }
    }

    func cancelQueued() -> CheckedContinuation<Void, any Error>? {
        continuation.withLock { continuation in
            while true {
                guard let state = State(rawValue: currentState.load(ordering: .relaxed)) else {
                    fatalError("Invalid waiter state")
                }

                switch state {
                case .created, .waiting:
                    guard currentState.compareExchange(
                        expected: state.rawValue,
                        desired: State.cancelled.rawValue,
                        ordering: .relaxed
                    ).exchanged else {
                        continue
                    }
                    let continuationToResume = continuation
                    continuation = nil
                    if continuationToResume != nil {
                        currentState.store(State.completed.rawValue, ordering: .relaxed)
                    }
                    return continuationToResume

                case .admitted, .cancelled, .completed:
                    return nil
                }
            }
        }
    }

    func admit() -> AdmitResult {
        continuation.withLock { continuation in
            while true {
                guard let state = State(rawValue: currentState.load(ordering: .relaxed)) else {
                    fatalError("Invalid waiter state")
                }

                switch state {
                case .created, .waiting:
                    guard currentState.compareExchange(
                        expected: state.rawValue,
                        desired: State.admitted.rawValue,
                        ordering: .relaxed
                    ).exchanged else {
                        continue
                    }
                    let continuationToResume = continuation
                    continuation = nil
                    if continuationToResume != nil {
                        currentState.store(State.completed.rawValue, ordering: .relaxed)
                    }
                    return .admitted(continuationToResume)

                case .cancelled, .completed:
                    return .skip

                case .admitted:
                    return .admitted(nil)
                }
            }
        }
    }

    private func install(_ newContinuation: CheckedContinuation<Void, any Error>) -> Result<Void, any Error>? {
        continuation.withLock { continuation in
            while true {
                guard let state = State(rawValue: currentState.load(ordering: .relaxed)) else {
                    fatalError("Invalid waiter state")
                }

                switch state {
                case .created:
                    guard currentState.compareExchange(
                        expected: State.created.rawValue,
                        desired: State.waiting.rawValue,
                        ordering: .relaxed
                    ).exchanged else {
                        continue
                    }
                    continuation = newContinuation
                    return nil

                case .waiting:
                    fatalError("Continuation was installed twice")

                case .admitted:
                    currentState.store(State.completed.rawValue, ordering: .relaxed)
                    return .success(())

                case .cancelled:
                    currentState.store(State.completed.rawValue, ordering: .relaxed)
                    return .failure(CancellationError())

                case .completed:
                    return .failure(CancellationError())
                }
            }
        }
    }
}
