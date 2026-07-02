import Foundation
import Vapor
import AsyncHTTPClient

/// Queues best-effort S3 sync operations per endpoint so slow endpoints do not block faster ones.
actor S3SyncManager {
    typealias DirectorySync = @Sendable (S3UploadSyncTarget) async throws -> Void

    private let logger: Logger
    private let syncDirectory: DirectorySync
    private var endpointQueues: [S3BucketEndpoint: Task<Void, Never>] = [:]
    private var isShuttingDown = false

    init(client: HTTPClient, logger: Logger) {
        self.init(logger: logger) { target in
            try await S3Uploader.uploadSync(
                client: client,
                localDirectory: target.localDirectory,
                server: target.bucketEndpoint.uploadServer,
                basePath: target.basePath,
                exclude: target.exclude
            )
        }
    }

    init(logger: Logger, syncDirectory: @escaping DirectorySync) {
        self.logger = logger
        self.syncDirectory = syncDirectory
    }

    /// Enqueue a directory sync and return immediately.
    func sync(_ target: S3UploadSyncTarget) {
        let syncDirectory = self.syncDirectory
        enqueue(target) {
            try await syncDirectory(target)
        }
    }

    /// Stop accepting new work and wait for all queued syncs to finish.
    func shutdown() async {
        isShuttingDown = true
        let pending = Array(endpointQueues.values)
        for task in pending {
            await task.value
        }
    }

    private func enqueue(_ target: S3UploadSyncTarget, operation: @escaping @Sendable () async throws -> Void) {
        let endpoint = target.bucketEndpoint
        let description = "sync \(target.basePath)"
        guard !isShuttingDown else {
            logger.warning("S3 upload manager is shutting down. Rejecting \(description) for endpoint: \(endpoint)")
            return
        }

        let previous = endpointQueues[endpoint]
        let logger = self.logger
        let task = Task {
            await previous?.value
            let start = DispatchTime.now()
            logger.info("S3 background \(description) for \(endpoint) started")
            do {
                try await operation()
                logger.info("S3 background \(description) for \(endpoint) completed in \(start.timeElapsedPretty())")
            } catch {
                logger.error("S3 background \(description) for \(endpoint) failed: \(error.localizedDescription)")
            }
        }
        endpointQueues[endpoint] = task
    }
}

private final class S3SyncManagerLifecycle: LifecycleHandler {
    private let manager: S3SyncManager

    init(manager: S3SyncManager) {
        self.manager = manager
    }

    func shutdown(_ application: Application) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await manager.shutdown()
            semaphore.signal()
        }
        semaphore.wait()
    }
}

extension Application {
    fileprivate struct S3SyncManagerKey: StorageKey, LockKey {
        typealias Value = S3SyncManager
    }

    var s3SyncManager: S3SyncManager {
        let lock = self.locks.lock(for: S3SyncManagerKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3SyncManagerKey.self] {
            return existing
        }

        let manager = S3SyncManager(client: http1Client, logger: logger)
        self.lifecycle.use(S3SyncManagerLifecycle(manager: manager))
        self.storage[S3SyncManagerKey.self] = manager
        return manager
    }
}
