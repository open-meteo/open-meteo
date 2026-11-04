import Collections
import Foundation
import Synchronization

/// One shared payload download. Demand promotion survives retry backoff.
final class RemotePayloadDownload: Sendable {
    let id = UUID()
    let owner: RemotePreloadSession
    private let demand = Atomic(false)
    // Admission and last-waiter cancellation must agree before the first HTTP attempt starts.
    // 0 = not started, 1 = started, 2 = abandoned before admission.
    private let startState = Atomic<UInt8>(0)
    func markStarted() -> Bool {
        let result = startState.compareExchange(expected: 0, desired: 1, ordering: .acquiringAndReleasing)
        return result.exchanged || result.original == 1
    }
    func abandonBeforeStart() -> Bool {
        startState.compareExchange(expected: 0, desired: 2, ordering: .acquiringAndReleasing).exchanged
    }
    var isDemand: Bool { demand.load(ordering: .acquiring) }

    init(owner: RemotePreloadSession) { self.owner = owner }

    /// Only the first demand waiter needs to notify admission.
    func markDemand() -> Bool {
        demand.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing).exchanged
    }

    func promote() async {
        guard markDemand() else { return }
        await owner.admission?.promote(self)
    }

    @TaskLocal static var current: RemotePayloadDownload?
}

/// Admission only for speculative payload HTTP attempts. No cache or metadata work runs here.
public actor RemoteHTTPAdmission {
    private final class Group {
        let owner: RemotePreloadSession
        var pending: Deque<UUID> = []
        var active = 0
        var queued = false
        init(owner: RemotePreloadSession) { self.owner = owner }
    }
    private struct Pending {
        let job: RemotePayloadDownload
        let continuation: CheckedContinuation<Bool, Error>
    }
    private var groups: [UUID: Group] = [:]
    private var requests: Deque<UUID> = []
    private var rotations: Deque<UUID> = []
    private var pending: [UUID: Pending] = [:]
    private var active: [UUID: RemotePreloadSession] = [:]
    private var activeRotations = 0
    private let limit: Int
    private let rotationLimit: Int

    public init(concurrency: Int, warmingConcurrency: Int) {
        precondition(concurrency > 0 && warmingConcurrency > 0)
        limit = concurrency
        rotationLimit = min(concurrency, warmingConcurrency)
    }

    public struct Snapshot: Sendable {
        public let activeRequests: Int
        public let activeWarmups: Int
        public let queuedRequests: Int
        public let queuedWarmups: Int
    }

    public var snapshot: Snapshot {
        Snapshot(activeRequests: active.count - activeRotations, activeWarmups: activeRotations,
                 queuedRequests: Set(pending.values.filter { !$0.job.owner.background }.map { $0.job.owner.id }).count,
                 queuedWarmups: Set(pending.values.filter { $0.job.owner.background }.map { $0.job.owner.id }).count)
    }

    /// Returns whether this attempt owns a speculative permit. Demand owns none.
    func acquire(_ job: RemotePayloadDownload) async throws -> Bool {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            if job.isDemand {
                guard job.markStarted() else { throw CancellationError() }
                return false
            }
            try job.owner.checkActive()
            return try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                let owner = job.owner
                if groups[owner.id] == nil { groups[owner.id] = Group(owner: owner) }
                pending[job.id] = Pending(job: job, continuation: continuation)
                groups[owner.id]!.pending.append(job.id)
                enqueue(owner.id)
                drain()
            }
        } onCancel: {
            Task { await self.cancel(job.id) }
        }
    }

    func stop(_ owner: RemotePreloadSession) {
        guard let group = groups[owner.id] else { return }
        for id in group.pending {
            guard let entry = pending[id], !entry.job.isDemand else { continue }
            pending.removeValue(forKey: id)
            entry.continuation.resume(throwing: CancellationError())
        }
        enqueue(owner.id)
        drain()
    }

    func release(_ job: RemotePayloadDownload) {
        guard let owner = active.removeValue(forKey: job.id) else { return }
        if owner.background { activeRotations -= 1 }
        groups[owner.id]!.active -= 1
        enqueue(owner.id)
        drain()
    }

    func promote(_ job: RemotePayloadDownload) {
        if let entry = pending.removeValue(forKey: job.id) {
            if entry.job.markStarted() { entry.continuation.resume(returning: false) }
            else { entry.continuation.resume(throwing: CancellationError()) }
            drain()
        }
    }

    /// A caller abandoning a queued download must not leave an admission waiter behind.
    private func cancel(_ id: UUID) {
        if let entry = pending.removeValue(forKey: id) {
            entry.continuation.resume(throwing: CancellationError())
            drain()
        }
    }

    private func enqueue(_ id: UUID) {
        guard let group = groups[id] else { return }
        while let first = group.pending.first, pending[first] == nil { group.pending.removeFirst() }
        if group.pending.isEmpty && group.active == 0 && !group.queued {
            groups.removeValue(forKey: id)
            return
        }
        if !group.queued && !group.pending.isEmpty && group.active < group.owner.concurrency {
            group.queued = true
            if group.owner.background { rotations.append(id) } else { requests.append(id) }
        }
    }

    private func drain() {
        while active.count < limit {
            let id: UUID
            if let next = requests.popFirst() { id = next }
            else if activeRotations < rotationLimit, let next = rotations.popFirst() { id = next }
            else { return }
            guard let group = groups[id] else { continue }
            group.queued = false
            while let first = group.pending.first, pending[first] == nil { group.pending.removeFirst() }
            guard let next = group.pending.popFirst(), let entry = pending.removeValue(forKey: next) else {
                enqueue(id)
                continue
            }
            if (!entry.job.isDemand && entry.job.owner.isStopped) || !entry.job.markStarted() {
                entry.continuation.resume(throwing: CancellationError())
            } else if entry.job.isDemand {
                entry.continuation.resume(returning: false)
            } else {
                group.active += 1
                active[next] = group.owner
                if group.owner.background { activeRotations += 1 }
                entry.continuation.resume(returning: true)
            }
            enqueue(id)
        }
    }
}
