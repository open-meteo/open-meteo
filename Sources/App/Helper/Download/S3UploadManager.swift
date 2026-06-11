import Foundation
import Vapor
import AsyncHTTPClient

/// Queues S3 operations per endpoint so slow endpoints do not block faster ones.
actor S3UploadManager {
    private let logger: Logger
    private var endpointQueues: [String: Task<Void, Never>] = [:]
    private var isShuttingDown = false

    init(logger: Logger) {
        self.logger = logger
    }

    /// Enqueue a single-part upload and return immediately.
    func upload<D: DataProtocol & Sendable>(
        client: HTTPClient,
        bucketEndpoint: String,
        data: D,
        url: String,
        contentType: String = "application/octet-stream"
    ) {
        enqueue(endpoint: normalizeEndpoint(bucketEndpoint)) {
            try await S3Uploader.upload(client: client, data: data, url: url, contentType: contentType)
        }
    }
    
    
    /// Enqueue a single-part upload and return immediately.
    func uploadMultipart(
        client: HTTPClient,
        bucketEndpoint: String,
        file: String,
        url: String,
        contentType: String = "application/octet-stream"
    ) {
        enqueue(endpoint: normalizeEndpoint(bucketEndpoint)) {
            try await S3Uploader.uploadMultipart(client: client, file: file, url: url, contentType: contentType).commit(client: client)
        }
    }


    /// Enqueue a directory sync and return immediately.
    func sync(
        client: HTTPClient,
        bucketEndpoint: String,
        localDirectory: String,
        server: String,
        basePath: String,
        exclude: [String] = [".*", "*~"]
    ) {
        enqueue(endpoint: normalizeEndpoint(bucketEndpoint)) {
            try await S3Uploader.uploadSync(
                client: client,
                localDirectory: localDirectory,
                server: server,
                basePath: basePath,
                exclude: exclude
            )
        }
    }

    /// Stop accepting new work and wait for all queued uploads to finish.
    func shutdown() async {
        isShuttingDown = true
        let pending = Array(endpointQueues.values)
        for task in pending {
            await task.value
        }
    }

    private func enqueue(endpoint: String, operation: @escaping @Sendable () async throws -> Void) {
        guard !isShuttingDown else {
            logger.warning("S3 upload manager is shutting down. Rejecting new operation for endpoint: \(endpoint)")
            return
        }

        let previous = endpointQueues[endpoint]
        let logger = self.logger
        let task = Task {
            await previous?.value
            do {
                try await operation()
            } catch {
                logger.error("S3 queued operation failed for endpoint \(endpoint): \(error.localizedDescription)")
            }
        }
        endpointQueues[endpoint] = task
    }

    private func normalizeEndpoint(_ raw: String) -> String {
        if let components = URLComponents(string: raw), let host = components.host {
            let scheme = components.scheme ?? "https"
            let port = components.port.map { ":\($0)" } ?? ""
            return "\(scheme)://\(host)\(port)"
        }
        return raw
    }
}

private final class S3UploadManagerLifecycle: LifecycleHandler {
    private let manager: S3UploadManager

    init(manager: S3UploadManager) {
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
    fileprivate struct S3UploadManagerKey: StorageKey, LockKey {
        typealias Value = S3UploadManager
    }

    var s3UploadManager: S3UploadManager {
        let lock = self.locks.lock(for: S3UploadManagerKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3UploadManagerKey.self] {
            return existing
        }

        let manager = S3UploadManager(logger: logger)
        self.lifecycle.use(S3UploadManagerLifecycle(manager: manager))
        self.storage[S3UploadManagerKey.self] = manager
        return manager
    }
}
