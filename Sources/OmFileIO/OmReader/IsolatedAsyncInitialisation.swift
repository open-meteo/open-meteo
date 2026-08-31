/**
 Ensure that a value is only initialised once.
 While the value is being initialised, queue other requests to wait until the resource has been resolved
 */
/*protocol IsolatedAsyncInitialisation: Actor {
    associatedtype Value: Sendable
    func fetchFromBackend() async throws -> Value
    var state: IsolatedAsyncInitialisationState<Value> { get set }
}

enum IsolatedAsyncInitialisationState<Value> {
    case none
    case initialising([Int: CheckedContinuation<Value, any Error>])
    case fetched(Value)
    case error(Error)
}

extension IsolatedAsyncInitialisation {
    func get() async throws -> Value {
        switch state {
        case .none:
            self.state = .initialising([:])
            do {
                let value = try await fetchFromBackend()
                guard case .initialising(let waiters) = state else {
                    // State may have changed if task cancellation raced in; keep fetched value.
                    self.state = .fetched(value)
                    return value
                }
                self.state = .fetched(value)
                waiters.values.forEach {
                    $0.resume(with: .success(value))
                }
                return value
            } catch {
                guard case .initialising(let waiters) = state else {
                    throw error
                }

                // If the leader task was cancelled, do not cache the cancellation as terminal error.
                if error is CancellationError {
                    self.state = .none
                } else {
                    self.state = .error(error)
                }

                waiters.values.forEach {
                    $0.resume(throwing: error)
                }
                throw error
            }
        case .initialising(var waiters):
            let id = Int.random(in: Int.min...Int.max)
            return try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { continuation in
                    waiters[id] = continuation
                    state = .initialising(waiters)
                }
            }, onCancel: {
                Task {
                    await self.cancelWaitingTasks(id: id)
                }
            }
            )
        case .fetched(let value):
            return value
        case .error(let error):
            throw error
        }
    }
    
    func cancelWaitingTasks(id: Int) {
        guard case .initialising(var waiters) = state,
              let continuation = waiters.removeValue(forKey: id) else {
            return
        }
        state = .initialising(waiters)
        continuation.resume(throwing: CancellationError())
    }
}*/
