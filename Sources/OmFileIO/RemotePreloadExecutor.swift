import Foundation
import Synchronization

/// Stops future preload I/O without cancelling a download already in progress.
public final class RemotePreloadSession: Sendable {
    private let stopped = Atomic(false)
    let id = UUID()
    let admission: RemoteHTTPAdmission?
    let concurrency: Int
    let background: Bool
    public init() {
        admission = nil
        concurrency = 1
        background = false
    }
    init(admission: RemoteHTTPAdmission, concurrency: Int, background: Bool = false) {
        self.admission = admission
        self.concurrency = concurrency
        self.background = background
    }
    public var isStopped: Bool { stopped.load(ordering: .relaxed) }
    public func stop() {
        guard !stopped.exchange(true, ordering: .relaxed), let admission else { return }
        Task { await admission.stop(self) }
    }
    public func checkActive() throws {
        if isStopped { throw CancellationError() }
    }
    @TaskLocal public static var current: RemotePreloadSession?
}

/// Owns independent request traversal and bounded rotation workers.
/// Only payload HTTP attempts share global admission.
public actor RemotePreloadExecutor {
    public nonisolated let admission: RemoteHTTPAdmission
    private var sessions: [UUID: RemotePreloadSession] = [:]
    private struct Warmup {
        let id: UUID
        let key: String
        let session: RemotePreloadSession
        var next: () -> (@Sendable () async -> Void)?
        var ready = false
        var active = false
    }
    public struct Snapshot: Sendable {
        public let activeRequests: Int
        public let activeWarmups: Int
        public let queuedRequests: Int
        public let queuedWarmups: Int
        public let stoppedRequests: Int
        public let stoppedWarmups: Int
    }
    private var warmups: [Warmup] = []
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var activeWarmups = 0
    private var stoppedRequests = 0
    private var stoppedWarmups = 0
    private var stopped = false
    private let warmingConcurrency: Int
    private let warmingCapacity: Int

    public init(concurrency: Int, warmingConcurrency: Int = 4, warmingCapacity: Int = 256) {
        precondition(concurrency > 0 && warmingConcurrency > 0 && warmingCapacity > 0)
        self.admission = RemoteHTTPAdmission(concurrency: concurrency, warmingConcurrency: warmingConcurrency)
        self.warmingConcurrency = min(warmingConcurrency, concurrency)
        self.warmingCapacity = warmingCapacity
    }

    public var snapshot: Snapshot {
        get async {
            let http = await admission.snapshot
            return Snapshot(activeRequests: http.activeRequests, activeWarmups: http.activeWarmups,
                            queuedRequests: http.queuedRequests, queuedWarmups: http.queuedWarmups,
                            stoppedRequests: stoppedRequests, stoppedWarmups: stoppedWarmups)
        }
    }

    /// Stage a lazy sequence of bounded chunks. Publication must precede activation.
    public func stage<S: Sequence & Sendable>(key: String, jobs: S,
        operation: @escaping @Sendable (S.Element) async -> Void
    ) -> UUID where S.Element: Sendable {
        cancel(key: key)
        let id = UUID()
        guard !stopped else { return id }
        if warmups.filter({ !$0.active }).count >= warmingCapacity,
           let oldest = warmups.first(where: { !$0.active }) {
            cancel(key: oldest.key)
        }
        var iterator = jobs.makeIterator()
        warmups.append(Warmup(id: id, key: key, session: RemotePreloadSession(admission: admission, concurrency: 1, background: true), next: {
            guard let job = iterator.next() else { return nil }
            return { await operation(job) }
        }))
        return id
    }

    public func activate(_ id: UUID) {
        if let index = warmups.firstIndex(where: { $0.id == id }) { warmups[index].ready = true }
        drain()
    }

    public func cancel(key: String) {
        for work in warmups where work.key == key {
            if !work.session.isStopped { stoppedWarmups += 1 }
            work.session.stop()
            tasks[work.id]?.cancel()
        }
        warmups.removeAll { !$0.active && $0.session.isStopped }
    }

    public func shutdown() async {
        stopped = true
        for session in sessions.values { session.stop() }
        for work in warmups { work.session.stop() }
        let running = Array(tasks.values)
        for task in running { task.cancel() }
        drain()
        for task in running { await task.value }
    }

    public nonisolated func makeSession(concurrency: Int) -> RemotePreloadSession {
        RemotePreloadSession(admission: admission, concurrency: concurrency)
    }

    public func run(count: Int, concurrency: Int, operation: @escaping @Sendable (Int) async -> Void) async throws {
        precondition(count >= 0 && concurrency > 0)
        guard !stopped else { throw CancellationError() }
        let session = RemotePreloadSession.current ?? makeSession(concurrency: concurrency)
        sessions[session.id] = session
        defer {
            tasks.removeValue(forKey: session.id)
            sessions.removeValue(forKey: session.id)
            if session.isStopped { stoppedRequests += 1 }
        }
        let traversal = Task {
            await Self.traverse(count: count, concurrency: concurrency, session: session, operation: operation)
        }
        tasks[session.id] = traversal
        await withTaskCancellationHandler {
            await traversal.value
        } onCancel: {
            session.stop()
            traversal.cancel()
        }
        try Task.checkCancellation()
        try session.checkActive()
    }

    /// Task-group completion and refill do not run on the shared lifecycle actor.
    @concurrent
    private nonisolated static func traverse(
        count: Int, 
        concurrency: Int, 
        session: RemotePreloadSession,                                         
        operation: @escaping @Sendable (Int) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var next = 0
            func submit(_ index: Int) {
                group.addTask {
                    await RemotePreloadSession.$current.withValue(session) {
                        if !session.isStopped && !Task.isCancelled { await operation(index) }
                    }
                }
            }
            while next < min(count, concurrency) {
                submit(next)
                next += 1
            }
            while await group.next() != nil {
                if next < count && !session.isStopped && !Task.isCancelled {
                    submit(next)
                    next += 1
                }
            }
        }
    }

    private func drain() {
        warmups.removeAll { !$0.active && $0.session.isStopped }
        guard !stopped else { return }
        // Rotation traversal is bounded separately; HTTP admission gives API work priority.
        while activeWarmups < warmingConcurrency,
              let index = warmups.firstIndex(where: { $0.ready && !$0.active }) {
            var work = warmups.remove(at: index)
            guard let operation = work.next() else { continue }
            work.active = true
            warmups.append(work)
            activeWarmups += 1
            let id = work.id
            let session = work.session
            let task = id
            tasks[task] = Task {
                await RemotePreloadSession.$current.withValue(session) {
                    if !session.isStopped { await operation() }
                }
                tasks.removeValue(forKey: task)
                activeWarmups -= 1
                if let index = warmups.firstIndex(where: { $0.id == id }) {
                    // Move the completed file behind other files for chunk-level fairness.
                    var work = warmups.remove(at: index)
                    work.active = false
                    warmups.append(work)
                }
                drain()
            }
        }
    }
}
