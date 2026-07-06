import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import AsyncAlgorithms

struct S3UploadSessionError: Error, CustomStringConvertible {
    let failures: [String]

    var description: String {
        "S3 upload session failed: \(failures.joined(separator: "; "))"
    }
}

private struct S3UploadFailure: Sendable, CustomStringConvertible {
    let phase: String
    let location: String
    let message: String

    var description: String {
        "\(phase) \(location): \(message)"
    }
}

/// Transaction-like uploader for publishing converted files to their final S3 keys.
///
/// Multipart parts are uploaded while conversion is still running, but final S3
/// objects are not changed until `finish()` completes the multipart uploads. Each
/// bucket endpoint publishes independently, so a slow endpoint does not block a
/// healthy endpoint's commits and metadata upload.
actor S3UploadSession {
    private enum State {
        case open
        case finishing
        case finished
        case cancelling
        case cancelled
    }

    private let client: HTTPClient
    private let logger: Logger
    private let maxConcurrentFileUploads: Int
    private var state: State = .open
    private var endpoints: [S3BucketEndpoint: S3EndpointUploadSession] = [:]

    init(client: HTTPClient, logger: Logger, maxConcurrentFileUploads: Int = 4) {
        self.client = client
        self.logger = logger
        self.maxConcurrentFileUploads = max(1, maxConcurrentFileUploads)
    }

    func uploadMultipart(_ target: S3UploadTarget) async {
        guard state == .open else {
            logger.warning("S3 upload session is closed. Rejecting multipart upload for: \(target.logLocation)")
            return
        }
        await endpoint(for: target.bucketEndpoint).uploadMultipart(target)
    }

    func uploadMetadataAfterCommits(_ target: S3UploadTarget, data: ByteBufferView) async {
        guard state == .open else {
            logger.warning("S3 upload session is closed. Rejecting metadata upload for: \(target.logLocation)")
            return
        }
        await endpoint(for: target.bucketEndpoint).uploadMetadataAfterCommits(target, data: data)
    }

    func upload(_ operation: S3UploadOperation) async {
        switch operation {
        case .multipart(let target):
            await uploadMultipart(target)
        case .metadataAfterCommits(let target, let data):
            await uploadMetadataAfterCommits(target, data: data)
        }
    }

    func upload(endpoints: S3BucketEndpointList, artifact: S3UploadArtifact) async {
        for operation in S3UploadPlan.operations(endpoints: endpoints, artifact: artifact) {
            await upload(operation)
        }
    }

    /// Close the intake queue and publish each endpoint independently.
    func finish() async throws {
        switch state {
        case .open:
            state = .finishing
        case .finishing, .finished, .cancelling, .cancelled:
            return
        }

        let endpointSessions = Array(endpoints.values)
        guard endpointSessions.isEmpty == false else {
            state = .finished
            return
        }

        let failures = await withTaskGroup(of: [S3UploadFailure].self, returning: [S3UploadFailure].self) { group in
            for endpoint in endpointSessions {
                group.addTask {
                    await endpoint.finish()
                }
            }

            var failures: [S3UploadFailure] = []
            for await endpointFailures in group {
                failures.append(contentsOf: endpointFailures)
            }
            return failures
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

        let endpointSessions = Array(endpoints.values)
        await withTaskGroup(of: Void.self) { group in
            for endpoint in endpointSessions {
                group.addTask {
                    await endpoint.cancel()
                }
            }
        }

        state = .cancelled
    }

    private func endpoint(for bucketEndpoint: S3BucketEndpoint) -> S3EndpointUploadSession {
        if let endpoint = endpoints[bucketEndpoint] {
            return endpoint
        }
        let endpoint = S3EndpointUploadSession(
            client: client,
            logger: logger,
            bucketEndpoint: bucketEndpoint,
            maxConcurrentFileUploads: maxConcurrentFileUploads
        )
        endpoints[bucketEndpoint] = endpoint
        return endpoint
    }

    private func throwIfNeeded(_ failures: [S3UploadFailure]) throws {
        guard !failures.isEmpty else {
            return
        }
        let descriptions = failures.map { $0.description }
        logger.error("S3 upload session failed: \(descriptions.joined(separator: "; "))")
        throw S3UploadSessionError(failures: descriptions)
    }
}

private actor S3EndpointUploadSession {
    private struct PreparedUpload: Sendable {
        let target: S3UploadTarget
        let prepared: S3MultiPartUploadPrepared
    }

    private struct MetadataUpload: Sendable {
        let target: S3UploadTarget
        let data: ByteBufferView
    }

    private let client: HTTPClient
    private let logger: Logger
    private let bucketEndpoint: S3BucketEndpoint
    private let maxConcurrentFileUploads: Int
    private let uploads = AsyncChannel<S3UploadTarget>()
    private var isClosed = false
    private var workers: [Task<Void, Never>] = []
    private var preparedUploads: [PreparedUpload] = []
    private var failures: [S3UploadFailure] = []
    private var metadataUploads: [MetadataUpload] = []

    init(client: HTTPClient, logger: Logger, bucketEndpoint: S3BucketEndpoint, maxConcurrentFileUploads: Int) {
        self.client = client
        self.logger = logger
        self.bucketEndpoint = bucketEndpoint
        self.maxConcurrentFileUploads = maxConcurrentFileUploads
    }

    func uploadMultipart(_ target: S3UploadTarget) async {
        guard !isClosed else {
            return
        }
        startWorkersIfNeeded()
        await uploads.send(target)
    }

    func uploadMetadataAfterCommits(_ target: S3UploadTarget, data: ByteBufferView) {
        guard !isClosed else {
            return
        }
        metadataUploads.append(MetadataUpload(target: target, data: data))
    }

    func finish() async -> [S3UploadFailure] {
        guard !isClosed else {
            return []
        }
        isClosed = true

        uploads.finish()
        await waitForWorkers()

        var failures = failures
        if failures.isEmpty == false {
            failures.append(contentsOf: await abortPreparedUploads(preparedUploads))
            preparedUploads.removeAll(keepingCapacity: true)
            return failures
        }

        if preparedUploads.isEmpty == false {
            let commitStart = DispatchTime.now()
            let commitFailures = await commitPreparedUploads(preparedUploads)
            failures.append(contentsOf: commitFailures)
            logger.info("S3 multipart commits for \(bucketEndpoint) completed in \(commitStart.timeElapsedPretty())")
        }

        if failures.isEmpty {
            failures.append(contentsOf: await uploadMetadata())
        }

        preparedUploads.removeAll(keepingCapacity: true)
        metadataUploads.removeAll(keepingCapacity: true)
        return failures
    }

    func cancel() async {
        guard !isClosed else {
            return
        }
        isClosed = true

        uploads.finish()
        metadataUploads.removeAll(keepingCapacity: true)

        for worker in workers {
            worker.cancel()
        }
        await waitForWorkers()

        let abortFailures = await abortPreparedUploads(preparedUploads)
        if !abortFailures.isEmpty {
            logger.error("S3 upload session abort failed for \(bucketEndpoint): \(abortFailures.map { $0.description }.joined(separator: "; "))")
        }

        preparedUploads.removeAll(keepingCapacity: true)
        failures.removeAll(keepingCapacity: true)
    }

    private func startWorkersIfNeeded() {
        guard workers.isEmpty else {
            return
        }
        for _ in 0..<maxConcurrentFileUploads {
            workers.append(Task { await self.runUploadWorker() })
        }
    }

    private func runUploadWorker() async {
        for await target in uploads {
            do {
                let prepared = try await S3Uploader.uploadMultipart(
                    client: client,
                    file: target.localFile,
                    url: target.uploadURL(),
                    contentType: target.contentType,
                    executor: LimitedConcurrencyExecutor(maxConcurrency: 4)
                )
                preparedUploads.append(PreparedUpload(target: target, prepared: prepared))
            } catch {
                if !Task.isCancelled {
                    failures.append(S3UploadFailure(
                        phase: "prepare",
                        location: String(target.logLocation),
                        message: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func waitForWorkers() async {
        for worker in workers {
            await worker.value
        }
    }

    private func commitPreparedUploads(_ prepared: [PreparedUpload]) async -> [S3UploadFailure] {
        let commitResults = await prepared.mapConcurrent(nConcurrent: 8) { upload -> S3UploadFailure? in
            do {
                try await upload.prepared.commit(client: self.client)
                return nil
            } catch {
                return S3UploadFailure(
                    phase: "commit",
                    location: String(upload.target.logLocation),
                    message: error.localizedDescription
                )
            }
        }
        return commitResults.compactMap { $0 }
    }

    private func abortPreparedUploads(_ prepared: [PreparedUpload]) async -> [S3UploadFailure] {
        guard !prepared.isEmpty else {
            return []
        }
        let abortResults = await prepared.mapConcurrent(nConcurrent: 8) { upload -> S3UploadFailure? in
            do {
                try await upload.prepared.abort(client: self.client)
                return nil
            } catch {
                return S3UploadFailure(
                    phase: "abort",
                    location: String(upload.target.logLocation),
                    message: error.localizedDescription
                )
            }
        }
        return abortResults.compactMap { $0 }
    }

    private func uploadMetadata() async -> [S3UploadFailure] {
        let metadataResults = await metadataUploads.mapConcurrent(nConcurrent: 8) { upload -> S3UploadFailure? in
            do {
                try await S3Uploader.upload(client: self.client, data: upload.data, url: upload.target.uploadURL(), contentType: upload.target.contentType)
                return nil
            } catch {
                return S3UploadFailure(
                    phase: "metadata",
                    location: String(upload.target.logLocation),
                    message: error.localizedDescription
                )
            }
        }
        return metadataResults.compactMap { $0 }
    }
}
