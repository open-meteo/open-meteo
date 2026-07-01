import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore

struct S3UploadSessionError: Error, CustomStringConvertible {
    let failures: [String]

    var description: String {
        "S3 upload session failed: \(failures.joined(separator: "; "))"
    }
}

/// Transaction-like uploader for publishing converted files to their final S3 keys.
///
/// Multipart parts are uploaded while conversion is still running, but final S3
/// objects are not changed until `finish()` completes the multipart uploads. If
/// conversion fails, `cancel()` aborts prepared uploads and drops metadata work,
/// preserving the "no remote object changes before full conversion success"
/// contract.
actor S3UploadSession {
    private enum State {
        case open
        case finishing
        case finished
        case cancelling
        case cancelled
    }

    private struct PreparedUpload: Sendable {
        let target: S3UploadTarget
        let prepared: S3MultiPartUploadPrepared
    }

    private struct PendingUploadQueue {
        private var storage: [S3UploadTarget] = []
        private var headIndex = 0

        var isEmpty: Bool {
            headIndex >= storage.count
        }

        mutating func append(_ target: S3UploadTarget) {
            storage.append(target)
        }

        mutating func popFirst() -> S3UploadTarget? {
            guard headIndex < storage.count else {
                return nil
            }
            let target = storage[headIndex]
            headIndex += 1
            if headIndex > 64 && headIndex * 2 >= storage.count {
                storage.removeFirst(headIndex)
                headIndex = 0
            }
            return target
        }

        mutating func removeAll(keepingCapacity: Bool) {
            storage.removeAll(keepingCapacity: keepingCapacity)
            headIndex = 0
        }
    }

    private struct EndpointUploadQueue {
        var pendingUploads = PendingUploadQueue()
        var waitingWorkers: [CheckedContinuation<S3UploadTarget?, Never>] = []
        var workers: [Task<Void, Never>] = []
    }

    private struct MetadataUpload: Sendable {
        let target: S3UploadTarget
        let data: ByteBufferView
    }

    private struct UploadFailure: Sendable, CustomStringConvertible {
        let bucketEndpoint: String
        let phase: String
        let location: String
        let message: String

        var description: String {
            "\(phase) \(location): \(message)"
        }
    }

    typealias MultipartUploadPrepare = @Sendable (S3UploadTarget) async throws -> S3MultiPartUploadPrepared
    typealias MultipartUploadCommit = @Sendable (S3MultiPartUploadPrepared) async throws -> Void
    typealias MultipartUploadAbort = @Sendable (S3MultiPartUploadPrepared) async throws -> Void
    typealias DirectorySync = @Sendable (S3UploadSyncTarget) async throws -> Void
    typealias MetadataUploader = @Sendable (S3UploadTarget, ByteBufferView) async throws -> Void

    private let logger: Logger
    private let maxConcurrentFileUploads: Int
    private let prepareMultipartUpload: MultipartUploadPrepare
    private let commitMultipartUpload: MultipartUploadCommit
    private let abortMultipartUpload: MultipartUploadAbort
    private let syncDirectory: DirectorySync
    private let uploadMetadata: MetadataUploader
    private var endpointQueues: [String: EndpointUploadQueue] = [:]
    private var state: State = .open
    private var preparedUploads: [PreparedUpload] = []
    private var failures: [UploadFailure] = []
    private var syncsBeforeMetadata: [S3UploadSyncTarget] = []
    private var metadataUploads: [MetadataUpload] = []

    init(client: HTTPClient, logger: Logger, maxConcurrentFileUploads: Int = 4) {
        self.init(
            logger: logger,
            maxConcurrentFileUploads: maxConcurrentFileUploads,
            prepareMultipartUpload: Self.prepareMultipartUpload(client: client),
            commitMultipartUpload: Self.commitMultipartUpload(client: client),
            abortMultipartUpload: Self.abortMultipartUpload(client: client),
            syncDirectory: Self.syncDirectory(client: client),
            uploadMetadata: Self.uploadMetadata(client: client)
        )
    }

    init(
        logger: Logger,
        maxConcurrentFileUploads: Int = 4,
        prepareMultipartUpload: @escaping MultipartUploadPrepare,
        commitMultipartUpload: @escaping MultipartUploadCommit,
        abortMultipartUpload: @escaping MultipartUploadAbort = { _ in },
        syncDirectory: @escaping DirectorySync,
        uploadMetadata: @escaping MetadataUploader
    ) {
        self.logger = logger
        self.maxConcurrentFileUploads = max(1, maxConcurrentFileUploads)
        self.prepareMultipartUpload = prepareMultipartUpload
        self.commitMultipartUpload = commitMultipartUpload
        self.abortMultipartUpload = abortMultipartUpload
        self.syncDirectory = syncDirectory
        self.uploadMetadata = uploadMetadata
    }

    private static func prepareMultipartUpload(client: HTTPClient) -> MultipartUploadPrepare {
        return { target in
            try await S3Uploader.uploadMultipart(
                client: client,
                file: target.localFile,
                url: target.url,
                contentType: target.contentType,
                nConcurrent: 4
            )
        }
    }

    private static func commitMultipartUpload(client: HTTPClient) -> MultipartUploadCommit {
        return { prepared in
            try await prepared.commit(client: client)
        }
    }

    private static func abortMultipartUpload(client: HTTPClient) -> MultipartUploadAbort {
        return { prepared in
            try await prepared.abort(client: client)
        }
    }

    private static func syncDirectory(client: HTTPClient) -> DirectorySync {
        return { target in
            guard FileManager.default.fileExists(atPath: target.localDirectory) else {
                return
            }
            try await S3Uploader.uploadSync(
                client: client,
                localDirectory: target.localDirectory,
                server: target.server,
                basePath: target.basePath,
                exclude: target.exclude
            )
        }
    }

    private static func uploadMetadata(client: HTTPClient) -> MetadataUploader {
        return { target, data in
            try await S3Uploader.upload(client: client, data: data, url: target.url, contentType: target.contentType)
        }
    }

    func uploadMultipart(_ target: S3UploadTarget) {
        guard state == .open else {
            logger.warning("S3 upload session is closed. Rejecting multipart upload for: \(target.url.asUrlGetQueryForLogging)")
            return
        }
        enqueueUpload(target)
        startWorkersIfNeeded(endpoint: target.bucketEndpoint)
    }

    func uploadMetadataAfterCommits(_ target: S3UploadTarget, data: ByteBufferView) {
        guard state == .open else {
            logger.warning("S3 upload session is closed. Rejecting metadata upload for: \(target.url.asUrlGetQueryForLogging)")
            return
        }
        metadataUploads.append(MetadataUpload(target: target, data: data))
    }

    func syncBeforeMetadata(_ target: S3UploadSyncTarget) {
        guard state == .open else {
            logger.warning("S3 upload session is closed. Rejecting directory sync for: \(target.bucketEndpoint.stripHttpPassword())")
            return
        }
        syncsBeforeMetadata.append(target)
    }

    func upload(_ operation: S3UploadOperation) {
        switch operation {
        case .multipart(let target):
            uploadMultipart(target)
        case .syncBeforeMetadata(let target):
            syncBeforeMetadata(target)
        case .metadataAfterCommits(let target, let data):
            uploadMetadataAfterCommits(target, data: data)
        }
    }

    func upload(buckets: String, artifact: S3UploadArtifact) {
        for operation in S3UploadPlan.operations(buckets: buckets, artifact: artifact) {
            upload(operation)
        }
    }

    /// Close the intake queue, wait for all prepared multipart uploads, then
    /// publish in dependency order: data files first, directory syncs second,
    /// metadata last. Once this starts, rollback is no longer attempted because
    /// some final objects may already have been committed.
    func finish() async throws {
        switch state {
        case .open:
            state = .finishing
        case .finishing, .finished, .cancelling, .cancelled:
            return
        }

        closeUploadQueue(droppingPending: false)
        await waitForWorkers()

        let prepared = preparedUploads
        let syncs = syncsBeforeMetadata
        var failures = failures
        var failedEndpoints = Set(failures.map { $0.bucketEndpoint })

        guard prepared.isEmpty == false || syncs.isEmpty == false || metadataUploads.isEmpty == false || failures.isEmpty == false else {
            state = .finished
            return
        }

        let preparedUploadsToAbort = prepared.filter { failedEndpoints.contains($0.target.bucketEndpoint) }
        if !preparedUploadsToAbort.isEmpty {
            let abortFailures = await abortPreparedUploads(preparedUploadsToAbort)
            failures.append(contentsOf: abortFailures)
            failedEndpoints.formUnion(abortFailures.map { $0.bucketEndpoint })
        }

        let preparedUploadsToCommit = prepared.filter { !failedEndpoints.contains($0.target.bucketEndpoint) }
        if !preparedUploadsToCommit.isEmpty {
            let commitStart = DispatchTime.now()
            let commitResults = await preparedUploadsToCommit.mapConcurrent(nConcurrent: 8) { upload -> UploadFailure? in
                do {
                    try await self.commitMultipartUpload(upload.prepared)
                    return nil
                } catch {
                    return UploadFailure(
                        bucketEndpoint: upload.target.bucketEndpoint,
                        phase: "commit",
                        location: String(upload.target.url.asUrlGetQueryForLogging),
                        message: error.localizedDescription
                    )
                }
            }
            let commitFailures = commitResults.compactMap { $0 }
            failures.append(contentsOf: commitFailures)
            failedEndpoints.formUnion(commitFailures.map { $0.bucketEndpoint })
            logger.info("S3 multipart commits completed in \(commitStart.timeElapsedPretty())")
        }

        let syncTargets = syncs.filter { !failedEndpoints.contains($0.bucketEndpoint) }
        if !syncTargets.isEmpty {
            let syncResults = await syncTargets.mapConcurrent(nConcurrent: 4) { target -> UploadFailure? in
                do {
                    try await self.syncDirectory(target)
                    return nil
                } catch {
                    return UploadFailure(
                        bucketEndpoint: target.bucketEndpoint,
                        phase: "sync",
                        location: target.basePath,
                        message: error.localizedDescription
                    )
                }
            }
            let syncFailures = syncResults.compactMap { $0 }
            failures.append(contentsOf: syncFailures)
            failedEndpoints.formUnion(syncFailures.map { $0.bucketEndpoint })
        }

        let metadataTargets = metadataUploads.filter { !failedEndpoints.contains($0.target.bucketEndpoint) }
        if !metadataTargets.isEmpty {
            let metadataResults = await metadataTargets.mapConcurrent(nConcurrent: 8) { upload -> UploadFailure? in
                do {
                    try await self.uploadMetadata(upload.target, upload.data)
                    return nil
                } catch {
                    return UploadFailure(
                        bucketEndpoint: upload.target.bucketEndpoint,
                        phase: "metadata",
                        location: String(upload.target.url.asUrlGetQueryForLogging),
                        message: error.localizedDescription
                    )
                }
            }
            failures.append(contentsOf: metadataResults.compactMap { $0 })
        }

        state = .finished
        try throwIfNeeded(failures)
    }

    /// Abort unpublished work after a conversion failure.
    ///
    /// This intentionally does not throw: the conversion error that triggered
    /// cancellation should remain the caller-visible failure. Abort failures are
    /// logged because they may leave S3 multipart uploads for lifecycle cleanup.
    func cancel() async {
        switch state {
        case .open:
            state = .cancelling
        case .finishing, .cancelling, .cancelled, .finished:
            return
        }

        closeUploadQueue(droppingPending: true)
        syncsBeforeMetadata.removeAll(keepingCapacity: true)
        metadataUploads.removeAll(keepingCapacity: true)

        for worker in endpointQueues.values.flatMap({ $0.workers }) {
            worker.cancel()
        }
        await waitForWorkers()

        let prepared = preparedUploads
        preparedUploads.removeAll(keepingCapacity: true)
        failures.removeAll(keepingCapacity: true)

        let abortFailures = await abortPreparedUploads(prepared)
        if !abortFailures.isEmpty {
            logger.error("S3 upload session abort failed: \(abortFailures.map(\.description).joined(separator: "; "))")
        }

        state = .cancelled
    }

    private func abortPreparedUploads(_ prepared: [PreparedUpload]) async -> [UploadFailure] {
        guard !prepared.isEmpty else {
            return []
        }
        let abortResults = await prepared.mapConcurrent(nConcurrent: 8) { upload -> UploadFailure? in
            do {
                try await self.abortMultipartUpload(upload.prepared)
                return nil
            } catch {
                return UploadFailure(
                    bucketEndpoint: upload.target.bucketEndpoint,
                    phase: "abort",
                    location: String(upload.target.url.asUrlGetQueryForLogging),
                    message: error.localizedDescription
                )
            }
        }
        return abortResults.compactMap { $0 }
    }

    private func enqueueUpload(_ target: S3UploadTarget) {
        var queue = endpointQueues[target.bucketEndpoint] ?? EndpointUploadQueue()
        if queue.waitingWorkers.isEmpty {
            queue.pendingUploads.append(target)
        } else {
            queue.waitingWorkers.removeFirst().resume(returning: target)
        }
        endpointQueues[target.bucketEndpoint] = queue
    }

    private func startWorkersIfNeeded(endpoint: String) {
        var queue = endpointQueues[endpoint] ?? EndpointUploadQueue()
        guard queue.workers.isEmpty else {
            return
        }
        for _ in 0..<maxConcurrentFileUploads {
            queue.workers.append(Task { await self.runUploadWorker(endpoint: endpoint) })
        }
        endpointQueues[endpoint] = queue
    }

    private func runUploadWorker(endpoint: String) async {
        while let target = await nextUploadTarget(endpoint: endpoint) {
            do {
                let prepared = try await prepareMultipartUpload(target)
                preparedUploads.append(PreparedUpload(target: target, prepared: prepared))
            } catch {
                if state != .cancelling && state != .cancelled {
                    failures.append(UploadFailure(
                        bucketEndpoint: target.bucketEndpoint,
                        phase: "prepare",
                        location: String(target.url.asUrlGetQueryForLogging),
                        message: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func nextUploadTarget(endpoint: String) async -> S3UploadTarget? {
        var queue = endpointQueues[endpoint] ?? EndpointUploadQueue()
        if state == .cancelling || state == .cancelled {
            queue.pendingUploads.removeAll(keepingCapacity: true)
            endpointQueues[endpoint] = queue
            return nil
        }
        if let target = queue.pendingUploads.popFirst() {
            endpointQueues[endpoint] = queue
            return target
        }
        if state != .open {
            return nil
        }
        return await withCheckedContinuation { continuation in
            queue.waitingWorkers.append(continuation)
            endpointQueues[endpoint] = queue
        }
    }

    private func closeUploadQueue(droppingPending: Bool) {
        for endpoint in Array(endpointQueues.keys) {
            var queue = endpointQueues[endpoint] ?? EndpointUploadQueue()
            if droppingPending {
                queue.pendingUploads.removeAll(keepingCapacity: true)
            }
            let waiting = queue.waitingWorkers
            queue.waitingWorkers.removeAll(keepingCapacity: true)
            endpointQueues[endpoint] = queue
            for worker in waiting {
                worker.resume(returning: nil)
            }
        }
    }

    private func waitForWorkers() async {
        let workers = endpointQueues.values.flatMap { $0.workers }
        for worker in workers {
            await worker.value
        }
    }

    private func throwIfNeeded(_ failures: [UploadFailure]) throws {
        guard !failures.isEmpty else {
            return
        }
        let descriptions = failures.map { $0.description }
        logger.error("S3 upload session failed: \(descriptions.joined(separator: "; "))")
        throw S3UploadSessionError(failures: descriptions)
    }
}
