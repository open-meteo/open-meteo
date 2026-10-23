import Foundation
import Synchronization

public enum RemoteReadPriority: Sendable {
    case foreground
    case background
}

/// Shared by all cache blocks in one download, allowing overlapping reads to promote it.
public final class RemoteDownloadJob: Sendable {
    struct State {
        var priority: RemoteReadPriority
        var scheduler: RemoteDownloadScheduler?
    }
    let id = UUID()
    private let state: Mutex<State>
    public init(priority: RemoteReadPriority) {
        state = Mutex(State(priority: priority))
    }
    var priority: RemoteReadPriority { state.withLock { $0.priority } }
    func attach(_ scheduler: RemoteDownloadScheduler?) {
        state.withLock { $0.scheduler = scheduler }
    }
    public func promote() async {
        let scheduler = state.withLock { state -> RemoteDownloadScheduler? in
            guard state.priority == .background else { return nil }
            state.priority = .foreground
            return state.scheduler
        }
        await scheduler?.promote(id)
    }
    @TaskLocal public static var current: RemoteDownloadJob?
}

public enum RemoteDownloadSchedulerError: Error {
    case backgroundQueueFull
}

/// Admission control before HTTP requests enter the client's connection/stream queues.
public actor RemoteDownloadScheduler {
    struct Entry {
        let job: RemoteDownloadJob
        var priority: RemoteReadPriority
        let queuedAt: ContinuousClock.Instant
        let continuation: CheckedContinuation<Void, Error>
    }
    public struct Snapshot: Sendable {
        public let activeForeground: Int
        public let activeBackground: Int
        public let queuedForeground: Int
        public let queuedBackground: Int
        public let promotions: Int
        public let foregroundWaitSeconds: Double
        public let backgroundWaitSeconds: Double
    }
    let limit: Int
    let backgroundLimit: Int
    let backgroundQueueLimit: Int
    private var pending: [Entry] = []
    private var active: [UUID: RemoteReadPriority] = [:]
    private var promotions = 0
    private var foregroundWaitSeconds = 0.0
    private var backgroundWaitSeconds = 0.0

    public init(limit: Int = 32, backgroundLimit: Int = 4, backgroundQueueLimit: Int = 256) {
        precondition(limit > 0 && backgroundLimit > 0 && backgroundLimit <= limit && backgroundQueueLimit > 0)
        self.limit = limit
        self.backgroundLimit = backgroundLimit
        self.backgroundQueueLimit = backgroundQueueLimit
    }

    public var snapshot: Snapshot {
        Snapshot(activeForeground: active.values.filter { $0 == .foreground }.count,
                 activeBackground: active.values.filter { $0 == .background }.count,
                 queuedForeground: pending.filter { $0.priority == .foreground }.count,
                 queuedBackground: pending.filter { $0.priority == .background }.count,
                 promotions: promotions, foregroundWaitSeconds: foregroundWaitSeconds,
                 backgroundWaitSeconds: backgroundWaitSeconds)
    }

    public func execute<T: Sendable>(job: RemoteDownloadJob, operation: @Sendable () async throws -> T) async throws -> T {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if job.priority == .background && pending.filter({ $0.priority == .background }).count >= backgroundQueueLimit {
                    continuation.resume(throwing: RemoteDownloadSchedulerError.backgroundQueueFull)
                    return
                }
                job.attach(self)
                pending.append(Entry(job: job, priority: job.priority, queuedAt: .now, continuation: continuation))
                drain()
            }
        } onCancel: {
            Task { await self.cancel(job.id) }
        }
        do {
            try Task.checkCancellation()
            let result = try await operation()
            release(job)
            return result
        } catch {
            release(job)
            throw error
        }
    }

    func promote(_ id: UUID) {
        if active[id] == .background {
            active[id] = .foreground
            promotions += 1
        } else if let index = pending.firstIndex(where: { $0.job.id == id && $0.priority == .background }) {
            var entry = pending.remove(at: index)
            entry.priority = .foreground
            pending.append(entry)
            promotions += 1
        }
        drain()
    }

    private func cancel(_ id: UUID) {
        guard let index = pending.firstIndex(where: { $0.job.id == id }) else { return }
        let entry = pending.remove(at: index)
        entry.job.attach(nil)
        entry.continuation.resume(throwing: CancellationError())
        drain()
    }

    private func release(_ job: RemoteDownloadJob) {
        active.removeValue(forKey: job.id)
        job.attach(nil)
        drain()
    }

    private func drain() {
        while active.count < limit {
            let foreground = pending.firstIndex { $0.priority == .foreground }
            guard let index = foreground ?? (active.values.filter { $0 == .background }.count < backgroundLimit ? pending.indices.first : nil) else { return }
            let entry = pending.remove(at: index)
            let priority = entry.priority
            active[entry.job.id] = priority
            let elapsed = entry.queuedAt.duration(to: .now).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            if priority == .foreground { foregroundWaitSeconds += seconds } else { backgroundWaitSeconds += seconds }
            entry.continuation.resume()
        }
    }
}
