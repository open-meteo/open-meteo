import AsyncHTTPClient
import Foundation
import Logging
import NIO
import NIOConcurrencyHelpers
import Vapor

/**
 Caches metadata for objects and directories of an S3 server
 It is used concurrently to get meta data from objects or return if a object does not exist.

 Performs S3 List operations on demand recursively.
 
 Each file can be bound to a "payload" type. E.g. an open OM-File which maintains meta data about timestamps and arrays available
 
 Data from object is read using HTTP `If-Unmodified-Since` and HTTP ranges. If a file got modified, perform a HEAD request to quickly get the new modification timestamp and restart execution
 
 TODO:
 - Serialise entries to disk for fast boot (option to store in KV cache? Need to prefix size)
 */

struct S3Inventory {
    let server: String
    let root = S3Directory()
    
    /// Find an object for a path
    func getObject(path: String, client: HTTPClient, logger: Logger) async throws -> S3File? {
        guard path.hasPrefix("/") == false, path.hasSuffix("/") == false else {
            fatalError()
        }
        let objectStart = path.lastIndex(of: "/").map { path.index(after: $0) } ?? path.startIndex
        let object = path[objectStart..<path.endIndex]

        var directory = root
        var componentStart = path.startIndex
        while componentStart < objectStart {
            let nextSlash = path[componentStart..<objectStart].firstIndex(of: "/") ?? objectStart
            let component = path[componentStart..<nextSlash]
            let prefix = path[..<componentStart]
            guard let next = try await directory.getDirectory(name: component, server: server, prefix: prefix, client: client, logger: logger) else {
                return nil
            }
            directory = next
            componentStart = path.index(after: nextSlash)
        }
        let prefix = path[path.startIndex..<objectStart]
        return try await directory.getFile(name: object, server: server, prefix: prefix, client: client, logger: logger)
    }
}

//struct S3FileMeta: Sendable {
//    let contentLength: Int
//    let lastModified: Timestamp
//}


actor S3File {
    private var contentLength: Int
    private var lastModified: Timestamp
    
    /// Reference to the open-meteo file or json file
    private var payload: RemotePayloadState
    
    /// If state is `updating`, a remote modification was detected and the old payload is now being updated
    /// The old payload is still available, because in many cases it can be reused
    private enum RemotePayloadState {
        /// Payload has not been requested yet by the application
        case none
        
        /// Payload is currently initialising. Consecutive requets are queued
        case initialising([CheckedContinuation<any FileSystemPayload, Error>])
        
        /// Payload got initialised and should be in sync with remote server
        case ready(any FileSystemPayload)
        
        /// The S3 directory listing detected a modification or a HTTP request threw a file modified error. Start reloading the new payload, but keep the old payload
        case updating(old: any FileSystemPayload, [CheckedContinuation<any FileSystemPayload, Error>])
        
        /// Received HTTP file not found error, while the directory did not yet update. Returns nil if payload is requested
        case deleted
        
        /// An error occurred while initialising the payload. This could also contains unrecoverable network errors, corrupted file errors, file not found, modified errors and others.
        /// Errors are cleared every 5 minutes
        case error(Error, Date)
    }

    init(contentLength: Int, lastModified: Timestamp) {
        self.contentLength = contentLength
        self.lastModified = lastModified
        payload = .none
    }

    /// Called from directory listing updates. Most of the times, content length and last modified did not change
    func updateFromDirectoryListing(client: HTTPClient, logger: Logger, server: String, objectKey: String, contentLength: Int, lastModified: Timestamp) async {
        if self.contentLength == contentLength && self.lastModified == lastModified {
            return
        }
        self.contentLength = contentLength
        self.lastModified = lastModified
        switch payload {
        case .ready(let old):
            payload = .updating(old: old, [])
            do {
                let new = try await old.remoteUpdated(client: client, logger: logger, server: server, objectKey: objectKey, size: Int64(contentLength), lastModified: lastModified)
                guard case .updating(_, let queued) = payload else {
                    fatalError("State was not .updating()")
                }
                self.payload = .ready(new)
                queued.forEach {
                    $0.resume(with: .success(new))
                }
            } catch {
                guard case .updating(_, let queued) = payload else {
                    fatalError("State was not .updating()")
                }
                if error is CancellationError {
                    self.payload = .none
                } else {
                    self.payload = .error(error, .now)
                }
                queued.forEach({
                    $0.resume(throwing: error)
                })
            }
        case .error(_, _), .deleted:
            /// Old payload had an error. Just reset state
            payload = .none
        case .none:
            break
        case .initialising(_):
            break
        case .updating(old: _, _):
            // most likely the new file is already being fetched
            break
        }
    }
    
    func receivedObjectDeletedError() {
        /// If this is called, we know for sure the file hast been deleted
        switch payload {
        case .none, .ready(_), .error(_, _):
            payload = .deleted
        case .initialising(_), .updating(old: _, _), .deleted:
            break // do not modify queued requests
        }
    }

    private static func fetchMeta(client: HTTPClient, logger: Logger, server: String, objectKey: String) async throws -> (contentLength: Int, lastModified: Timestamp) {
        var request = HTTPClientRequest(url: "\(server)\(objectKey.s3PathPercentEncoded)")
        request.method = .HEAD
        try request.applyS3Credentials()

        logger.debug("Revalidating S3 object '\(objectKey)' via HEAD")
        let response = try await client.executeRetry(request, logger: logger, deadline: .seconds(10), timeoutPerRequest: .seconds(2))
        guard let newContentLength = response.headers["Content-Length"].first.flatMap(Int.init) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }
        guard let newLastModified = response.headers["Last-Modified"]
            .first
            .flatMap(Self.lastModifiedDateFormat.date(from:))
            .map ({ Timestamp(Int($0.timeIntervalSince1970)) }) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }
        return (newContentLength, newLastModified)
    }
    
    /// Execute a closure with the resolved payload. May retries if file modified errors occur
    nonisolated func with<R, Payload: FileSystemPayload>(client: HTTPClient, logger: Logger, server: String, objectKey: String, fn: (_ value: Payload) async throws -> R) async throws -> R? {
        
        guard let payload = try await self.getPayload(ofType: Payload.self, client: client, logger: logger, server: server, objectKey: objectKey, receivedFileModifiedError: false) else {
            return nil
        }
        do {
            return try await fn(payload)
        } catch CurlError.fileNotFound {
            await self.receivedObjectDeletedError()
            return nil
        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
            guard let payload = try await self.getPayload(ofType: Payload.self, client: client, logger: logger, server: server, objectKey: objectKey, receivedFileModifiedError: true) else {
                return nil
            }
            /// Catch error again? If there would a file modified error again, this could indicate some remote server issues
            return try await fn(payload)
        }
    }
    
    /// Resolve payload
    func getPayload<T: FileSystemPayload>(ofType: T.Type, client: HTTPClient, logger: Logger, server: String, objectKey: String, receivedFileModifiedError: Bool) async throws -> T? {
        // Reset errors of they are older than 5 minutes
        if case .error(_, let issueDate) = payload, Date.now.timeIntervalSince(issueDate) > 5 * 60 {
            payload = .none
        }
        switch payload {
        case .none:
            self.payload = .initialising([])
            do {
                let p = try await T(client: client, logger: logger, server: server, objectKey: objectKey, size: Int64(contentLength), lastModified: lastModified)
                guard case .initialising(let queued) = payload else {
                    fatalError("State was not .initialising()")
                }
                self.payload = .ready(p)
                queued.forEach {
                    $0.resume(with: .success(p))
                }
                return p
            } catch {
                guard case .initialising(let queued) = payload else {
                    fatalError("State was not .initialising()")
                }
                // Do not cache the cancellation as terminal error.
                if error is CancellationError {
                    self.payload = .none
                } else {
                    self.payload = .error(error, .now)
                }
                queued.forEach({
                    $0.resume(throwing: error)
                })
                throw error
            }
        case .initialising(let queue):
            return try await withCheckedThrowingContinuation { continuation in
                payload = .initialising(queue + [continuation])
            } as? T
        case .updating(let old, let queue):
            // If the file is actively being updated, allow access to the old file, because cached responses still work
            if receivedFileModifiedError {
                // If the access fails, enqueue to get the new file
                let payload = try await withCheckedThrowingContinuation { continuation in
                    self.payload = .updating(old: old, queue + [continuation])
                }
                guard let payload = payload as? T else {
                    fatalError("Payload was not of correct type \(T.self)")
                }
                return payload
            }
            guard let old = old as? T else {
                fatalError("Payload was not of correct type \(T.self)")
            }
            return old
        case .ready(let payload):
            guard let payload = payload as? T else {
                fatalError("Payload was not of correct type \(T.self)")
            }
            guard receivedFileModifiedError else {
                return payload
            }
            // Old file got modified, we have to download it from the remote server again
            // At this stage there could be dozens of failing calls coming in
            self.payload = .updating(old: payload, [])
            do {
                let meta = try await Self.fetchMeta(client: client, logger: logger, server: server, objectKey: objectKey)
                self.contentLength = meta.contentLength
                self.lastModified = meta.lastModified
                let new = try await payload.remoteUpdated(client: client, logger: logger, server: server, objectKey: objectKey, size: Int64(contentLength), lastModified: lastModified)
                guard case .updating(old: _, let queued) = self.payload else {
                    fatalError("State was not .updating()")
                }
                self.payload = .ready(new)
                queued.forEach({
                    $0.resume(returning: new)
                })
                return new
            } catch {
                guard case .updating(old: _, let queued) = self.payload else {
                    fatalError("State was not .updating()")
                }
                if error is CancellationError {
                    self.payload = .none
                } else {
                    self.payload = .error(error, .now)
                }
                queued.forEach({
                    $0.resume(throwing: error)
                })
                throw error
            }
        case .deleted:
            return nil
        case .error(let error, _):
            throw error
        }
    }

    private static let lastModifiedDateFormat: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return fmt
    }()
}

/// Represents the content of a remote S3 directory with files and sub directories.
/// At initialisation the directory does not fetch contents, but waits until the first request arrives
actor S3Directory {
    var files = [String: S3File]()
    var directories = [String: S3Directory]()
    var lastValidated = Date(timeIntervalSince1970: 0)
    var lastAccess = Date(timeIntervalSince1970: 0)
    
    /// If set to an array, a revalidation is running in the background
    var revalidationQueue: [CheckedContinuation<Void, Error>]? = nil
    
    /// Revalidate the current directory using a S3 list operation. If a revalidation is already running, queue in.
    func revalidate(client: HTTPClient, logger: Logger, server: String, prefix: Substring) async throws {
        guard revalidationQueue == nil else {
            try await withCheckedThrowingContinuation { continuation in
                revalidationQueue?.append(continuation)
            }
            return
        }
        revalidationQueue = []
        do {
            let listed = try await S3List.s3list(client: client, server: server, prefix: String(prefix), apikey: nil, deadLineHours: 3)
            var listedFiles = Set<String>()
            for file in listed.files {
                let name = String(file.name.dropFirst(prefix.count))
                listedFiles.insert(name)
                // Keep existing object actors and directory actors alive whenever possible.
                if let existing = files[name] {
                    await existing.updateFromDirectoryListing(client: client, logger: logger, server: server, objectKey: file.name, contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp())
                } else {
                    files[name] = S3File(contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp())
                }
            }

            var listedDirectories = Set<String>()
            for directory in listed.directories {
                let name = String(directory.dropFirst(prefix.count).dropLast())
                listedDirectories.insert(name)
                if directories[name] == nil {
                    directories[name] = S3Directory()
                }
            }

            for name in Array(files.keys) where !listedFiles.contains(name) {
                files.removeValue(forKey: name)
            }

            for name in Array(directories.keys) where !listedDirectories.contains(name) {
                directories.removeValue(forKey: name)
            }

            lastValidated = .now
            let waiters = revalidationQueue
            revalidationQueue = nil
            waiters?.forEach({
                $0.resume()
            })
        } catch {
            let waiters = revalidationQueue
            revalidationQueue = nil
            waiters?.forEach({
                $0.resume(throwing: error)
            })
            throw error
        }
    }

    /// Periodic lifecycle callback.
    /// - Revalidates directories every `revalidateIntervalSeconds` if they were revalidated at least once before.
    /// - Skips revalidation for directories that were not accessed for more than `inactiveSkipSeconds`.
    nonisolated func lifecycleTick(
        client: HTTPClient,
        logger: Logger,
        server: String,
        prefix: String,
        now: Date,
        revalidateIntervalSeconds: Int,
        inactiveSkipSeconds: Int
    ) async {
        if now.timeIntervalSince(await lastAccess) > Double(inactiveSkipSeconds) {
            return
        }
        /// Skip directories that have never been validated
        guard await revalidationQueue != nil else {
            return
        }

        if now.timeIntervalSince(await lastValidated) > Double(revalidateIntervalSeconds) {
            do {
                try await revalidate(client: client, logger: logger, server: server, prefix: prefix[...])
                OmMetrics.fileCacheRemoteRevalidated.add(1, ordering: .relaxed)
            } catch {
                logger.warning("S3Inventory lifecycle revalidation failed for prefix '\(prefix)': \(error)")
            }
        }

        for (name, directory) in await directories {
            await directory.lifecycleTick(
                client: client,
                logger: logger,
                server: server,
                prefix: "\(prefix)\(name)/",
                now: now,
                revalidateIntervalSeconds: revalidateIntervalSeconds,
                inactiveSkipSeconds: inactiveSkipSeconds
            )
        }
    }
    
    func getDirectory(name: Substring, server: String, prefix: Substring, client: HTTPClient, logger: Logger) async throws -> S3Directory? {
        if revalidationQueue == nil || Date.now.timeIntervalSince(lastValidated) > 10*60 {
            try await revalidate(client: client, logger: logger, server: server, prefix: prefix)
        }
        lastAccess = .now
        return directories[String(name)]
    }

    func getFile(name: Substring, server: String, prefix: Substring, client: HTTPClient, logger: Logger) async throws -> S3File? {
        if revalidationQueue == nil || Date.now.timeIntervalSince(lastValidated) > 10*60 {
            try await revalidate(client: client, logger: logger, server: server, prefix: prefix)
        }
        lastAccess = .now
        return files[String(name)]
    }
}

extension Application {
    /// Create S3 inventory instance and start background watcher to get modifications
    func makeS3Inventory(server: String) async throws -> S3Inventory {
        let inventory = S3Inventory(server: server)
        let manager = S3InventoryLifecycleManager(inventory: inventory)
        try manager.didBoot(self)
        self.lifecycle.use(manager)
        return inventory
    }
}

/// Lifecycle manager for S3 inventory caches. Revalidate active directories in the background.
/// Runs every 2 minutes and revalidates active directories.
/// Directories that were not accessed for >30 minutes are skipped but kept in memory.
final class S3InventoryLifecycleManager: LifecycleHandler {
    private let inventory: S3Inventory
    private let backgroundWatcher: NIOLockedValueBox<RepeatedTask?>

    init(inventory: S3Inventory) {
        self.inventory = inventory
        self.backgroundWatcher = .init(nil)
    }

    func didBoot(_ application: Application) throws {
        let eventLoop = application.eventLoopGroup.next()
        backgroundWatcher.withLockedValue {
            $0 = eventLoop.scheduleRepeatedAsyncTask(
                initialDelay: .seconds(120),
                delay: .seconds(120)
            ) { _ in
                application.eventLoopGroup.makeFutureWithTask {
                    await self.inventory.root.lifecycleTick(
                        client: application.dedicatedHttpClient,
                        logger: application.logger,
                        server: self.inventory.server,
                        prefix: "",
                        now: .now,
                        revalidateIntervalSeconds: 120,
                        inactiveSkipSeconds: 30 * 60
                    )
                }
            }
        }
    }

    func shutdown(_ application: Application) {
        backgroundWatcher.withLockedValue {
            $0?.cancel()
        }
    }
}

private extension String {
    /// Percent-encode each path segment but keep directory separators.
    var s3PathPercentEncoded: String {
        split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).awsPercentEncoded }
            .joined(separator: "/")
    }
}

