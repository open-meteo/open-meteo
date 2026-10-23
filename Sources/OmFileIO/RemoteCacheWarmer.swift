import Foundation

/// Bounded file-level warming queue. Each worker submits only one range download at a time.
public actor RemoteCacheWarmer {
    private struct Work {
        let id: UUID
        let key: String
        let operation: @Sendable () async -> Void
        var ready = false
    }
    private struct Running {
        let id: UUID
        let task: Task<Void, Never>
    }
    private var pending: [Work] = []
    private var running: [String: Running] = [:]
    private let concurrency: Int
    private let capacity: Int
    private var stopped = false

    public init(concurrency: Int = 4, capacity: Int = 256) {
        precondition(concurrency > 0 && capacity > 0)
        self.concurrency = concurrency
        self.capacity = capacity
    }

    /// Stage before publication, but do not start warming until the new payload is ready.
    public func stage(key: String, operation: @escaping @Sendable () async -> Void) -> UUID {
        cancel(key: key)
        let id = UUID()
        guard !stopped else { return id }
        if pending.count == capacity { pending.removeFirst() }
        pending.append(Work(id: id, key: key, operation: operation))
        return id
    }

    public func activate(_ id: UUID) {
        if let index = pending.firstIndex(where: { $0.id == id }) { pending[index].ready = true }
        drain()
    }

    public func cancel(key: String) {
        pending.removeAll { $0.key == key }
        running[key]?.task.cancel()
    }

    public func shutdown() async {
        stopped = true
        pending.removeAll()
        let tasks = running.values.map(\.task)
        for task in tasks { task.cancel() }
        for task in tasks { await task.value }
    }

    private func drain() {
        while !stopped && running.count < concurrency,
              let index = pending.firstIndex(where: { $0.ready && running[$0.key] == nil }) {
            let work = pending.remove(at: index)
            let task = Task {
                await work.operation()
                completed(key: work.key, id: work.id)
            }
            running[work.key] = Running(id: work.id, task: task)
        }
    }

    private func completed(key: String, id: UUID) {
        if running[key]?.id == id { running.removeValue(forKey: key) }
        drain()
    }
}
