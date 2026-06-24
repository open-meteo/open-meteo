import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore

struct S3UploadTarget: Sendable, Equatable {
    let bucketEndpoint: String
    let localFile: String
    let url: String
    let contentType: String
}

enum S3UploadPlan {
    static func targets(
        domain: DomainRegistry,
        buckets: String,
        localFile: String,
        remotePath: String,
        isPreviousDay: Bool = false,
        isRolling: Bool = false,
        contentType: String = "application/octet-stream"
    ) -> [S3UploadTarget] {
        if isRolling, domain != .google_weathernext2_ensemble {
            return []
        }
        return domain.parseBucket(buckets).compactMap { bucket, profile in
            if isPreviousDay && ((bucket == "openmeteo" && profile == nil) || profile == "aws") {
                return nil
            }
            if isRolling && ((bucket == "openmeteo" && profile == nil) || profile == "aws") {
                return nil
            }
            return S3UploadTarget(
                bucketEndpoint: bucket,
                localFile: localFile,
                url: bucket.s3UploadUrlPrefix + remotePath,
                contentType: contentType
            )
        }
    }
}

struct S3UploadBatchError: Error, CustomStringConvertible {
    let failures: [String]

    var description: String {
        "S3 upload batch failed: \(failures.joined(separator: "; "))"
    }
}

actor S3UploadBatch {
    private struct PreparedUpload: Sendable {
        let target: S3UploadTarget
        let prepared: S3MultiPartUploadPrepared
    }

    private struct MetadataUpload: Sendable {
        let target: S3UploadTarget
        let data: ByteBufferView
    }

    private enum UploadResult: Sendable {
        case success(PreparedUpload)
        case failure(S3UploadTarget, String)
    }

    private let client: HTTPClient
    private let logger: Logger
    private var endpointQueues: [String: Task<Void, Never>] = [:]
    private var uploadTasks: [Task<UploadResult, Never>] = []
    private var metadataUploads: [MetadataUpload] = []

    init(client: HTTPClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    func uploadMultipart(_ target: S3UploadTarget) {
        let previous = endpointQueues[target.bucketEndpoint]
        let client = client
        let task = Task<UploadResult, Never> {
            await previous?.value
            do {
                let prepared = try await S3Uploader.uploadMultipart(
                    client: client,
                    file: target.localFile,
                    url: target.url,
                    contentType: target.contentType,
                    nConcurrent: 4
                )
                return .success(PreparedUpload(target: target, prepared: prepared))
            } catch {
                return .failure(target, error.localizedDescription)
            }
        }
        endpointQueues[target.bucketEndpoint] = Task<Void, Never> {
            _ = await task.value
        }
        uploadTasks.append(task)
    }

    func uploadMetadataAfterCommits(_ target: S3UploadTarget, data: ByteBufferView) {
        metadataUploads.append(MetadataUpload(target: target, data: data))
    }

    func finish() async throws {
        let prepared = try await collectPreparedUploads()
        guard prepared.isEmpty == false || metadataUploads.isEmpty == false else {
            return
        }

        let commitStart = DispatchTime.now()
        try await prepared.foreachConcurrent(nConcurrent: 8) { upload in
            try await upload.prepared.commit(client: self.client)
        }
        logger.info("S3 multipart commits completed in \(commitStart.timeElapsedPretty())")

        try await metadataUploads.foreachConcurrent(nConcurrent: 8) { upload in
            try await S3Uploader.upload(client: self.client, data: upload.data, url: upload.target.url, contentType: upload.target.contentType)
        }
    }

    private func collectPreparedUploads() async throws -> [PreparedUpload] {
        var prepared = [PreparedUpload]()
        var failures = [String]()
        for task in uploadTasks {
            switch await task.value {
            case .success(let upload):
                prepared.append(upload)
            case .failure(let target, let message):
                failures.append("\(target.url.asUrlGetQueryForLogging): \(message)")
            }
        }
        if !failures.isEmpty {
            logger.error("S3 multipart upload preparation failed: \(failures.joined(separator: "; "))")
            throw S3UploadBatchError(failures: failures)
        }
        return prepared
    }
}

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
        enqueue(endpoint: bucketEndpoint) {
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
        enqueue(endpoint: bucketEndpoint) {
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
        enqueue(endpoint: bucketEndpoint) {
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
}

private extension String {
    var s3UploadUrlPrefix: String {
        let withSlash = hasSuffix("/") ? self : self + "/"
        if withSlash.starts(with: "s3://") || withSlash.starts(with: "http://") || withSlash.starts(with: "https://") {
            return withSlash
        }
        return "s3://\(withSlash)"
    }

    var asUrlGetQueryForLogging: Substring {
        guard let schemaIndex = firstRange(of: "://"),
              let queryStart = self[schemaIndex.upperBound...].firstIndex(of: "/") else {
            return Substring(self)
        }
        return self[queryStart...]
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
