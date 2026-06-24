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

enum S3UploadFileKind: Sendable {
    case regular
    case previousDay
    case rolling
    case spatial
}

enum S3UploadOperation: Sendable {
    case multipart(S3UploadTarget)
    case metadataAfterCommits(S3UploadTarget, ByteBufferView)
}

enum S3UploadArtifact {
    case timeSeries(OmFileType)
    case fullRun(OmFileType)
    case modelMeta(ModelUpdateMetaFile, data: ByteBufferView)
    case fullRunMeta(FullRunMetaFile, data: ByteBufferView)
    case spatialFile(
        domain: DomainRegistry,
        localFile: String,
        run: Timestamp,
        time: Timestamp,
        realm: String?
    )
    case spatialMeta(
        domain: DomainRegistry,
        localFile: String,
        remote: S3SpatialMetaFile,
        data: ByteBufferView
    )
}

enum S3SpatialMetaFile {
    case run(run: Timestamp, realm: String?)
    case inProgress(realm: String?)
    case latest(realm: String?)
}

enum S3UploadPlan {
    static func operations(
        buckets: String,
        artifact: S3UploadArtifact
    ) -> [S3UploadOperation] {
        return targets(buckets: buckets, artifact: artifact).map { target in
            switch artifact {
            case .timeSeries, .fullRun, .spatialFile:
                return .multipart(target)
            case .modelMeta(_, let data), .fullRunMeta(_, let data), .spatialMeta(_, _, _, let data):
                return .metadataAfterCommits(target, data)
            }
        }
    }

    static func targets(buckets: String, artifact: S3UploadArtifact) -> [S3UploadTarget] {
        let plan = artifact.plan
        return targets(
            domain: plan.domain,
            buckets: buckets,
            localFile: plan.localFile,
            remotePath: plan.remotePath,
            kind: plan.kind,
            contentType: plan.contentType
        )
    }

    static func targets(
        domain: DomainRegistry,
        buckets: String,
        localFile: String,
        remotePath: String,
        kind: S3UploadFileKind = .regular,
        contentType: String = "application/octet-stream"
    ) -> [S3UploadTarget] {
        return domain.parseBucket(buckets).compactMap { bucket, profile in
            guard shouldUpload(domain: domain, bucket: bucket, profile: profile, kind: kind) else {
                return nil
            }
            return target(bucket: bucket, localFile: localFile, remotePath: remotePath, contentType: contentType)
        }
    }

    static func shouldUpload(domain: DomainRegistry, bucket: String, profile: String?, kind: S3UploadFileKind) -> Bool {
        switch kind {
        case .regular:
            return true
        case .previousDay:
            return !isDefaultOpenMeteoOrAws(bucket: bucket, profile: profile)
        case .rolling:
            return domain == .google_weathernext2_ensemble && !isDefaultOpenMeteoOrAws(bucket: bucket, profile: profile)
        case .spatial:
            return profile != "ceph"
        }
    }

    static func spatialSyncTargets(
        buckets: String,
        domain: DomainRegistry,
        localDirectory: String
    ) -> [S3UploadSyncTarget] {
        return domain.parseBucket(buckets).compactMap { bucket, profile in
            guard shouldUpload(domain: domain, bucket: bucket, profile: profile, kind: .spatial) else {
                return nil
            }
            return S3UploadSyncTarget(
                bucketEndpoint: bucket,
                localDirectory: localDirectory,
                server: bucket,
                basePath: "data_spatial/\(domain.rawValue)/"
            )
        }
    }

    private static func isDefaultOpenMeteoOrAws(bucket: String, profile: String?) -> Bool {
        return (bucket == "openmeteo" && profile == nil) || profile == "aws"
    }

    private static func target(bucket: String, localFile: String, remotePath: String, contentType: String) -> S3UploadTarget {
        return S3UploadTarget(
            bucketEndpoint: bucket,
            localFile: localFile,
            url: bucket.s3UploadUrlPrefix + remotePath,
            contentType: contentType
        )
    }
}

struct S3UploadSyncTarget: Sendable {
    let bucketEndpoint: String
    let localDirectory: String
    let server: String
    let basePath: String
}

private extension S3UploadArtifact {
    var plan: (domain: DomainRegistry, localFile: String, remotePath: String, kind: S3UploadFileKind, contentType: String) {
        switch self {
        case .timeSeries(let file):
            return (
                file.domainRegistry,
                file.getFilePath(),
                "data/\(file.getRelativeFilePath())",
                file.s3UploadKind,
                "application/octet-stream"
            )
        case .fullRun(let file):
            return (
                file.domainRegistry,
                file.getFilePath(),
                "data_run/\(file.getRelativeFilePath())",
                .regular,
                "application/octet-stream"
            )
        case .modelMeta(let file, _):
            return (
                file.domain,
                file.getFilePath(),
                "data/\(file.domain.rawValue)/static/meta.json",
                .regular,
                "application/json"
            )
        case .fullRunMeta(let file, _):
            let remotePath: String
            let domain: DomainRegistry
            switch file {
            case .run(let fileDomain, let run):
                domain = fileDomain
                remotePath = "data_run/\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/meta.json"
            case .latest(let fileDomain):
                domain = fileDomain
                remotePath = "data_run/\(domain.rawValue)/latest.json"
            }
            return (domain, file.getFilePath(), remotePath, .regular, "application/json")
        case .spatialFile(let domain, let localFile, let run, let time, let realm):
            let remotePath = "data_spatial/\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/\(time.iso8601_YYYY_MM_dd_HHmm)\(realm.s3UploadSuffix).om"
            return (
                domain,
                localFile,
                remotePath,
                .spatial,
                "application/octet-stream"
            )
        case .spatialMeta(let domain, let localFile, let remote, _):
            return (
                domain,
                localFile,
                "data_spatial/\(domain.rawValue)/\(remote.relativePath)",
                .spatial,
                "application/json"
            )
        }
    }
}

private extension S3SpatialMetaFile {
    var relativePath: String {
        switch self {
        case .run(let run, let realm):
            return "\(run.format_directoriesYYYYMMddhhmm)/meta\(realm.s3UploadSuffix).json"
        case .inProgress(let realm):
            return "in-progress\(realm.s3UploadSuffix).json"
        case .latest(let realm):
            return "latest\(realm.s3UploadSuffix).json"
        }
    }
}

private extension Optional where Wrapped == String {
    var s3UploadSuffix: String {
        return map { "_\($0)" } ?? ""
    }
}

private extension OmFileType {
    var domainRegistry: DomainRegistry {
        switch self {
        case .domainChunk(let domain, _, _, _, _, _),
                .staticFile(let domain, _, _),
                .run(let domain, _, _):
            return domain
        }
    }

    var s3UploadKind: S3UploadFileKind {
        switch self {
        case .domainChunk(_, _, .rolling, _, _, _):
            return .rolling
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return .previousDay
        case .domainChunk, .staticFile, .run:
            return .regular
        }
    }
}

struct S3UploadSessionError: Error, CustomStringConvertible {
    let failures: [String]

    var description: String {
        "S3 upload session failed: \(failures.joined(separator: "; "))"
    }
}

actor S3UploadSession {
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

    func upload(_ operation: S3UploadOperation) {
        switch operation {
        case .multipart(let target):
            uploadMultipart(target)
        case .metadataAfterCommits(let target, let data):
            uploadMetadataAfterCommits(target, data: data)
        }
    }

    func upload(buckets: String, artifact: S3UploadArtifact) {
        for operation in S3UploadPlan.operations(buckets: buckets, artifact: artifact) {
            upload(operation)
        }
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
            throw S3UploadSessionError(failures: failures)
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
