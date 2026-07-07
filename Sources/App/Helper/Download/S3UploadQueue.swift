
import AsyncHTTPClient
import Logging
import Foundation

struct S3UploadQueue {
    let endpoint: S3BucketEndpoint
    let client: HTTPClient
    let logger: Logger
    
    let queue = ProcessingSerialQueue()
    
    init(endpoint: S3BucketEndpoint, client: HTTPClient, logger: Logger = Logger(label: "S3UploadQueue")) {
        self.endpoint = endpoint
        self.client = client
        self.logger = logger
    }
    
    /// Start uploading multiple files in the background that are committed at a later stage
    func startMultiPartUploads() -> S3MultiFileUploadQueue {
        S3MultiFileUploadQueue(endpoint: endpoint, client: client, maxConcurrentFiles: 4, maxConcurrentPartUploads: 16)
    }
    
    /// Enqueue completion of multi files
    func finishMultiPartUploads(_ session: S3MultiFileUploadQueue) async {
        await queue.enqueueIgnoreError(logger: logger) {
            let prepared = try await session.queue.collect()
            try await prepared.foreachConcurrent(nConcurrent: 4, body: { prepared in
                try await prepared.commit(client: client)
            })
        }
    }

    /// Abort multipart uploads that were prepared before a conversion failure.
    func abortMultiPartUploads(_ session: S3MultiFileUploadQueue) async {
        await queue.enqueueIgnoreError(logger: logger) {
            let prepared = try await session.queue.collect()
            try await prepared.foreachConcurrent(nConcurrent: 4, body: { prepared in
                try await prepared.abort(client: client)
            })
        }
    }
    
    func upload<D: DataProtocol & Sendable>(data: D, objectName: String, contentType: String = "application/octet-stream") async {
        await queue.enqueueIgnoreError(logger: logger) {
            try await S3Uploader.upload(client: client, data: data, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType)
        }
    }

    func enqueueUpload(_ description: String, _ work: @escaping @Sendable (HTTPClient, S3BucketEndpoint) async throws -> ()) async {
        await queue.enqueue {
            do {
                try await work(client, endpoint)
            } catch {
                logger.error("Error during queued upload \(description) to \(endpoint): \(error)")
            }
        }
    }

    func uploadSync(localDirectory: String, basePath: String, exclude: [String] = [".*", "*~"]) async {
        await queue.enqueueIgnoreError(logger: logger) {
            try await S3Uploader.uploadSync(client: client, localDirectory: localDirectory, server: endpoint.uploadServer.s3UploadUrlPrefix, basePath: basePath, exclude: exclude)
        }
    }
    
    func finish() async {
        await queue.finish()
    }
}


/// Upload multiple files in the background, but do not commit them yet. Once all files have been uploaded, commit all of them
struct S3MultiFileUploadQueue {
    let endpoint: S3BucketEndpoint
    let client: HTTPClient
    let logger: Logger
    
    /// Max number of concurrent multipart uploads. 10 is a good number
    let partUploadExecutor: LimitedConcurrencyExecutor
    
    /// Max number of concurrent file uploads. 4 should be fine
    let queue: ProcessingParallelQueue<S3MultiPartUploadPrepared>
    
    init(endpoint: S3BucketEndpoint, client: HTTPClient, logger: Logger = Logger(label: "S3MultiFileUploadQueue"), maxConcurrentFiles: Int, maxConcurrentPartUploads: Int) {
        self.partUploadExecutor = .init(maxConcurrency: maxConcurrentPartUploads)
        self.queue = .init(executor: LimitedConcurrencyExecutor(maxConcurrency: maxConcurrentFiles))
        self.client = client
        self.logger = logger
        self.endpoint = endpoint
    }
    
    func uploadMultipart<Data: S3UploadAble & Sendable>(data: Data, objectName: String, contentType: String = "application/octet-stream") async {
        await queue.enqueueIgnoreError(logger: Logger(label: "Multipart Uploader")) {
            try await S3Uploader.uploadMultipart(client: client, data: data, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType, executor: partUploadExecutor)
        }
    }
    
    func uploadMultipart(file: String, objectName: String, contentType: String = "application/octet-stream") async {
        await queue.enqueueIgnoreError(logger: Logger(label: "Multipart Uploader")) {
            try await S3Uploader.uploadMultipart(client: client, file: file, url: endpoint.uploadURL(remotePath: objectName), contentType: contentType, executor: partUploadExecutor)
        }
    }
}
