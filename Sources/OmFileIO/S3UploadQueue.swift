
import AsyncHTTPClient
import Logging
import Foundation
import NIOCore
import OmTime

public struct S3UploadQueue: Sendable {
    public let endpoint: S3BucketEndpoint
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
        S3MultiFileUploadQueue(endpoint: endpoint, client: client, onError: onError, maxConcurrentFiles: 4, maxConcurrentPartUploads: 16)
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


/// Upload multiple files in the background, but do not commit them yet. Once all files have been uploaded, commit all of them
public struct S3MultiFileUploadQueue: Sendable {
    public let endpoint: S3BucketEndpoint
    let client: HTTPClient
    let logger: Logger
    
    /// Max number of concurrent multipart uploads. 10 is a good number
    let partUploadExecutor: LimitedConcurrencyExecutor
    
    /// Max number of concurrent file uploads. 4 should be fine
    private let queue: ProcessingParallelQueue<S3MultiPartUploadPrepared?>
    private let preparations: Task<[S3MultiPartUploadPrepared], Never>
    private let onError: @Sendable () -> Void
    
    public init(endpoint: S3BucketEndpoint, client: HTTPClient, logger: Logger = Logger(label: "S3MultiFileUploadQueue"), onError: @escaping @Sendable () -> Void = {}, maxConcurrentFiles: Int, maxConcurrentPartUploads: Int) {
        self.partUploadExecutor = .init(maxConcurrency: maxConcurrentPartUploads)
        let queue = ProcessingParallelQueue<S3MultiPartUploadPrepared?>(concurrent: maxConcurrentFiles)
        self.queue = queue
        self.onError = onError
        // Drain throughout conversion so completed uploads never block admission of later files.
        // Only preparation metadata is retained until the caller chooses commit or abort.
        self.preparations = Task { [results = queue.results, logger, onError] in
            var prepared = [S3MultiPartUploadPrepared]()
            do {
                for try await result in results {
                    if let result { prepared.append(result) }
                }
            } catch {
                logger.error("Error receiving prepared uploads: \(error)")
                onError()
            }
            return prepared
        }
        self.client = client
        self.logger = logger
        self.endpoint = endpoint
    }
    
    func uploadMultipart<Data: S3UploadAble & Sendable>(data: Data, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp) async {
        let url = endpoint.uploadURL(remotePath: objectName)
        await enqueuePreparation { [client, executor = partUploadExecutor] in
            try await S3Uploader.uploadMultipart(client: client, data: data, url: url, contentType: contentType, lastModified: lastModified, executor: executor)
        }
    }
    
    public func uploadMultipart(file: String, objectName: String, contentType: String = "application/octet-stream", lastModified: Timestamp) async {
        let url = endpoint.uploadURL(remotePath: objectName)
        await enqueuePreparation { [client, executor = partUploadExecutor] in
            try await S3Uploader.uploadMultipart(client: client, file: file, url: url, contentType: contentType, lastModified: lastModified, executor: executor)
        }
    }

    func enqueuePreparation(_ work: @escaping @Sendable () async throws -> S3MultiPartUploadPrepared) async {
        do {
            try await queue.enqueue { [logger, onError] in
                do { return try await work() } catch {
                    logger.error("Error preparing multipart upload: \(error)")
                    onError()
                    return nil
                }
            }
        } catch {
            logger.error("Error enqueueing multipart upload: \(error)")
            onError()
        }
    }

    func finishPreparations() async -> [S3MultiPartUploadPrepared] {
        queue.finish()
        let prepared = await preparations.value
        await queue.waitForCompletion()
        return prepared
    }

}
