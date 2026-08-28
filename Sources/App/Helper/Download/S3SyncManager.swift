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
        let queue = S3UploadQueue(endpoint: endpoint, client: client, logger: logger) { _ in
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
    
    func getQueues(bucketsOpt: String?) -> [S3UploadQueue]? {
        guard let bucketsOpt else {
            return nil
        }
        return getQueues(buckets: bucketsOpt)
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
