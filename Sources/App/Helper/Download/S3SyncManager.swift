import Foundation
import Vapor
import AsyncHTTPClient
import OmFileIO

/// Queues best-effort S3 sync operations per endpoint so slow endpoints do not block faster ones.
actor S3SyncManager: LifecycleHandler {
    private let logger: Logger
    private var queues: [S3UploadQueue] = []
    private let client: HTTPClient
    private let exitStatus: ProcessExitStatus

    init(client: HTTPClient, logger: Logger, exitStatus: ProcessExitStatus = .shared) {
        self.client = client
        self.logger = logger
        self.exitStatus = exitStatus
    }

    /// Get task queue for S3 Endpoint
    func getQueue(endpoint: S3BucketEndpoint) -> S3UploadQueue {
        if let queue = queues.first(where: {$0.endpoint == endpoint}) {
            return queue
        }
        let queue = S3UploadQueue(endpoint: endpoint, client: client, logger: logger) {
            self.exitStatus.markFailure()
        }
        queues.append(queue)
        return queue
    }

//    func sync(endpoint: S3BucketEndpoint, localDirectory: String, basePath: String, exclude: [String] = [".*", "*~"]) async {
//        await getQueue(endpoint: endpoint).uploadSync(localDirectory: localDirectory, basePath: basePath, exclude: exclude)
//    }
    
    /// Parse S3 bucket string and return queues
    func getQueues(buckets: String) -> [S3UploadQueue] {
        let endpoints = S3BucketEndpoint.parseList(buckets)
        return endpoints.map {
            self.getQueue(endpoint: $0)
        }
    }
    
    func getQueues(bucketsOpt: String?, rollingBucketsOpt: String? = nil) -> [S3UploadQueue]? {
        let standard = bucketsOpt.map(S3BucketEndpoint.parseList) ?? []
        let rolling = rollingBucketsOpt.map(S3BucketEndpoint.parseList) ?? []
        guard !standard.isEmpty || !rolling.isEmpty else { return nil }
        let rollingEndpoints = Set(rolling)
        var seen = Set<S3BucketEndpoint>()
        return (standard + rolling).filter { seen.insert($0).inserted }.map { endpoint in
            // Configure a value copy while sharing the endpoint's underlying task queue.
            var queue = getQueue(endpoint: endpoint)
            queue.excludeRollingFiles = !rollingEndpoints.contains(endpoint)
            return queue
        }
    }
    
    /// Wait for all queued syncs to finish.
    func finish() async {
        for queue in queues {
            await queue.finish()
        }
    }

    /// Called from lifecycle manager to shutdown application.
    func shutdownAsync(_ application: Application) async {
        await finish()
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
        self.lifecycle.use(manager)
        self.storage[S3SyncManagerKey.self] = manager
        return manager
    }
}
