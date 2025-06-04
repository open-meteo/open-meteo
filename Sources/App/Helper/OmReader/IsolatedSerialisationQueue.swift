/**
 Ensure that only a single task is running to return a resource
 */
final actor IsolatedSerialisationQueue<Key: Hashable, Value: Sendable> {
    private var queue: [Key: [CheckedContinuation<Value, any Error>]] = [:]
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get(key: Key, provider: () async throws -> Value) async throws -> Value {
        guard queue[key] == nil else {
            let value = try await withCheckedThrowingContinuation { continuation in
                queue[key, default: []].append(continuation)
            }
            return value
        }
        queue[key] = []
        do {
            let data = try await provider()
            queue.removeValue(forKey: key)?.forEach({
                $0.resume(with: .success(data))
            })
            return data
        } catch {
            queue.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}

/**
 KV cache, but a resource is resolved not in parallel
 */
/*final actor IsolatedSerialisationCache<Key: Hashable & Sendable, Value: Sendable> {
    enum State {
        case cached(Value)
        case running([CheckedContinuation<Value, any Error>])
        
        var isCached: Bool {
            switch self {
            case .cached:
                return true
            case .running:
                return false
            }
        }
    }
    
    var cache = [Key: State]()
    
    /**
     Get a resource identified by a key. If the request is currently being requested, enqueue the request
     */
    func get(key: Key, forceNew: Bool, provider: () async throws -> Value) async throws -> Value {
        guard let state = cache[key], !(forceNew == true && state.isCached) else {
            // Value not cached or needs to be refreshed
            cache[key] = .running([])
            do {
                let data = try await provider()
                guard case .running(let queued) = cache.updateValue(.cached(data), forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach {
                    $0.resume(with: .success(data))
                }
                return data
            } catch {
                guard case .running(let queued) = cache.removeValue(forKey: key) else {
                    fatalError("State was not .running()")
                }
                queued.forEach({
                    $0.resume(with: .failure(error))
                })
                throw error
            }
        }
        switch state {
        case .cached(let value):
            return value
        case .running(let running):
            let value = try await withCheckedThrowingContinuation { continuation in
                cache[key] = .running(running + [continuation])
            }
            return value
        }
    }
}
*/
