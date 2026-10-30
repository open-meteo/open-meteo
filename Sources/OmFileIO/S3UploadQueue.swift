
import AsyncHTTPClient
import Logging
import Foundation
import NIOCore
import OmTime

public struct S3UploadQueue: Sendable {
    public let endpoint: S3BucketEndpoint
    /// Time-series upload policy, inherited by multipart sessions.
    public var excludeRollingFiles: Bool = true
    /// Skip spatial files and their associated metadata.
    public var excludeSpatialFiles: Bool = false
    let client: HTTPClient
    let logger: Logger
    let onError: @Sendable () -> Void
    
    let queue: ProcessingSerialQueue
    
    public init(endpoint: S3BucketEndpoint, client: HTTPClient, logger: Logger = Logger(label: "S3UploadQueue"), onError: @escaping @Sendable () -> Void = {}) {
        self.endpoint = endpoint
        self.client = client
        self.logger = logger
        self.onError = onError
        self.queue = ProcessingSerialQueue(onError: onError)
    }
    
    /// Start uploading multiple files in the background that are committed at a later stage
    public func startMultiPartUploads() -> S3MultiFileUploadQueue {
        S3MultiFileUploadQueue(endpoint: endpoint, client: client, onError: onError, maxConcurrentFiles: 4, maxConcurrentPartUploads: 16, excludeRollingFiles: excludeRollingFiles)
    }
    
    /// Enqueue completion of multi files
    public func finishMultiPartUploads(_ session: S3MultiFileUploadQueue) async {
        await queue.enqueueIgnoreError(logger: logger) {
            let prepared = await session.finishPreparations()
            try await prepared.foreachConcurrent(nConcurrent: 4, body: { prepared in
                try await prepared.commit(client: client)
            })
        }
    }

    /// Abort multipart uploads that were prepared before a conversion failure.
    public func abortMultiPartUploads(_ session: S3MultiFileUploadQueue) async {
        await queue.enqueueIgnoreError(logger: logger) {
            let prepared = await session.finishPreparations()
            try await prepared.foreachConcurrent(nConcurrent: 4, body: { prepared in
                try await prepared.abort(client: client)
            })
        }
    }
    
    public func upload<D: DataProtocol & Sendable>(data: D, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp) async {
        await queue.enqueueIgnoreError(logger: logger) {
            try await S3Uploader.upload(client: client, data: data, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType, lastModified: lastModified)
        }
    }
    
    public func upload(buffer: ByteBuffer, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp) async {
        await queue.enqueueIgnoreError(logger: logger) {
            try await S3Uploader.upload(client: client, buffer: buffer, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType, lastModified: lastModified)
        }
    }

    public func enqueueUpload(_ description: String, _ work: @escaping @Sendable (HTTPClient, S3BucketEndpoint) async throws -> ()) async {
        await queue.enqueue {
            do {
                try await work(client, endpoint)
            } catch {
                logger.error("Error during queued upload \(description) to \(endpoint): \(error)")
                onError()
            }
        }
    }

//    func uploadSync(localDirectory: String, basePath: String, exclude: [String] = [".*", "*~"]) async {
//        await queue.enqueueIgnoreError(logger: logger) {
//            try await S3Uploader.uploadSync(client: client, localDirectory: localDirectory, server: endpoint.uploadServer.s3UploadUrlPrefix, basePath: basePath, exclude: exclude)
//        }
//    }
    
    public func finish() async {
        await queue.finish()
    }
}


/// Upload multiple files in the background. Files can commit immediately or wait for session completion.
public struct S3MultiFileUploadQueue: Sendable {
    public let endpoint: S3BucketEndpoint
    public let excludeRollingFiles: Bool
    let client: HTTPClient
    let logger: Logger
    
    /// Max number of concurrent multipart uploads. 10 is a good number
    let partUploadExecutor: LimitedConcurrencyExecutor
    
    /// Max number of concurrent file uploads. 4 should be fine
    let queue: ProcessingParallelQueue<S3MultiPartUploadPrepared?>
    
    public init(endpoint: S3BucketEndpoint, client: HTTPClient, logger: Logger = Logger(label: "S3MultiFileUploadQueue"), onError: @escaping @Sendable () -> Void = {}, maxConcurrentFiles: Int, maxConcurrentPartUploads: Int, excludeRollingFiles: Bool = true) {
        self.excludeRollingFiles = excludeRollingFiles
        self.partUploadExecutor = .init(maxConcurrency: maxConcurrentPartUploads)
        self.queue = .init(executor: LimitedConcurrencyExecutor(maxConcurrency: maxConcurrentFiles), onError: onError)
        self.client = client
        self.logger = logger
        self.endpoint = endpoint
    }
    
    func uploadMultipart<Data: S3UploadAble & Sendable>(data: Data, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp) async {
        await queue.enqueueIgnoreError(logger: Logger(label: "Multipart Uploader")) {
            try await S3Uploader.uploadMultipart(client: client, data: data, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType, lastModified: lastModified, executor: partUploadExecutor)
        }
    }
    
    public func uploadMultipart(file: String, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp, commitImmediately: Bool = false) async {
        let url = endpoint.uploadURL(remotePath: objectName)
        let commit: (@Sendable (S3MultiPartUploadPrepared) async throws -> Void)?
        if commitImmediately {
            commit = { [client] prepared in try await prepared.commit(client: client) }
        } else {
            commit = nil
        }
        await enqueuePreparation(commit: commit) { [client, executor = partUploadExecutor] in
            try await S3Uploader.uploadMultipart(client: client, file: file, url: url, contentType: contentType, lastModified: lastModified, executor: executor)
        }
    }

    func enqueuePreparation(commit: (@Sendable (S3MultiPartUploadPrepared) async throws -> Void)? = nil, _ work: @escaping @Sendable () async throws -> S3MultiPartUploadPrepared) async {
        await queue.enqueueIgnoreError(logger: logger) { [client, logger] in
            let prepared = try await work()
            guard let commit else { return prepared }
            do {
                try await commit(prepared)
            } catch {
                // A failed immediate commit must not leave an unfinished multipart upload behind.
                do { try await prepared.abort(client: client) } catch {
                    logger.error("Error aborting multipart upload: \(error)")
                }
                throw error
            }
            // Already published; exclude it from later batch commit or abort.
            return nil
        }
    }

    func finishPreparations() async -> [S3MultiPartUploadPrepared] {
        await queue.collect().compactMap { $0 }
    }

}
