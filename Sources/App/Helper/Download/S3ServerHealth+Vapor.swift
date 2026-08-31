import Vapor

extension Application {
    fileprivate struct S3ServerHealthKey: StorageKey, LockKey {
        typealias Value = S3ServerHealth
    }

    /// Monitored S3 hosts to replicate upload S3 files
    var s3UploadReplicationServer: S3ServerHealth {
        let lock = self.locks.lock(for: S3ServerHealthKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3ServerHealthKey.self] {
            return existing
        }
        let servers = S3BucketEndpoint.loadFromEnvironment(variable: "S3_UPLOAD_REPLICATION_SERVERS")
        let manager = S3ServerHealth(logger: logger, servers: servers)
        self.storage[S3ServerHealthKey.self] = manager
        return manager
    }
}
