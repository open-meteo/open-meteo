import AsyncHTTPClient
import Foundation
import Logging
import NIO
import NIOConcurrencyHelpers
import Vapor
import OmFileFormat

enum S3InventoryError: Error {
    case invalidObjectName
}

/**
 Caches metadata for objects and directories of an S3 server
 It is used concurrently to get meta data from objects or return if a object does not exist.

 Performs S3 List operations on demand recursively.
 
 Each file can be bound to a "payload" type. E.g. an open OM-File which maintains meta data about timestamps and arrays available
 
 Data from object is read using HTTP `If-Unmodified-Since` and `If-Match` (eTag) and HTTP ranges. If a file got modified, perform a HEAD request to quickly get the new modification timestamp and restart execution
 
 TODO:
 - Serialise entries to disk for fast boot (option to store in KV cache? Need to prefix size)
 - Use different update times per directory. E.g. recent data_run needs to be validated more often
 - Consider back propagation of file-updated to directory. E.g. flag "should_do_background_update" for directory
 - Consider dynamic update strategy using meta JSON files... or implement some sort of WAL or transaction log
 
 Transaction log:
 - Log each individual model update operation to data, data_run, data_spatial... data spatial might be updated every couple of seconds
 - S3 path: logs/2026/09/14/dwd_icon_eps-00z-spatial.json  logs/2026/09/14/dwd_icon_eps-00z.json logs/2026/09/14/dwd_icon_eps-00z-data-run.json
 - could also do data/log/YYYYMMDD/dwd_icon_eps-00zjson
 - could also do data/log/YYYYMMDD/dwd_icon_eps-00zjson
 - Each contains a list of modified files
 */

struct S3Inventory {
    let server: String
    let root = S3Directory(prefix: "")

    /// Find a directory for a path
    func getDirectory(path: String, client: HTTPClient, logger: Logger) async throws -> S3Directory? {
        guard path.hasPrefix("/") == false, path.hasSuffix("/") else {
            throw S3InventoryError.invalidObjectName
        }
        let trimmedPath = path.dropLast()
        var directory = root
        var componentStart = trimmedPath.startIndex
        while componentStart < trimmedPath.endIndex {
            let nextSlash = trimmedPath[componentStart..<trimmedPath.endIndex].firstIndex(of: "/") ?? trimmedPath.endIndex
            let component = trimmedPath[componentStart..<nextSlash]
            guard let next = try await directory.getDirectory(name: String(component), server: server, client: client, logger: logger) else {
                return nil
            }
            directory = next

            guard nextSlash < trimmedPath.endIndex else {
                break
            }
            componentStart = trimmedPath.index(after: nextSlash)
        }
        return directory
    }
    
    /// Find an object for a path
    func getObject(path: String, client: HTTPClient, logger: Logger) async throws -> S3File? {
        guard path.hasPrefix("/") == false, path.hasSuffix("/") == false else {
            throw S3InventoryError.invalidObjectName
        }
        let objectStart = path.lastIndex(of: "/").map { path.index(after: $0) } ?? path.startIndex
        let object = path[objectStart..<path.endIndex]

        var directory = root
        var componentStart = path.startIndex
        while componentStart < objectStart {
            let nextSlash = path[componentStart..<objectStart].firstIndex(of: "/") ?? objectStart
            let component = path[componentStart..<nextSlash]
            guard let next = try await directory.getDirectory(name: String(component), server: server, client: client, logger: logger) else {
                return nil
            }
            directory = next
            componentStart = path.index(after: nextSlash)
        }
        return try await directory.getFile(name: String(object), server: server, client: client, logger: logger)
    }
    
    func updateRecursivelyIfRequired(client: HTTPClient, logger: Logger) async {
        await self.root.updateRecursivelyIfRequired(
            client: client,
            logger: logger,
            server: server,
            now: .now(),
            revalidateIntervalSeconds: 120,
            inactiveSkipSeconds: 30 * 60
        )
    }
}

protocol RemotePayload: Sendable {
    /// Initialise from remote source
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Self
    func remoteDeleted() async throws
}

actor S3File {
    /// Full object name e.g. `data/dwd_icon/temperature_2m/chunk_1234.om`
    let objectName: String
    var contentLength: Int
    var lastModified: Timestamp
    var eTag: String
    
    /// Reference to the open-meteo file or json file
    private var payload: RemotePayloadState
    
    /// If state is `updating`, a remote modification was detected and the old payload is now being updated
    /// The old payload is still available, because in many cases it can be reused
    private enum RemotePayloadState {
        /// Payload has not been requested yet by the application
        case none
        
        /// Payload is currently initialising. Consecutive requets are queued
        case initialising([CheckedContinuation<any RemotePayload, Error>])
        
        /// Payload got initialised and should be in sync with remote server
        case ready(any RemotePayload)
        
        /// The S3 directory listing detected a modification or a HTTP request threw a file modified error. Start reloading the new payload, but keep the old payload
        case updating(old: any RemotePayload, [CheckedContinuation<any RemotePayload, Error>])
        
        /// Received HTTP file not found error, while the directory did not yet update. Returns nil if payload is requested
        case deleted
        
        /// An error occurred while initialising the payload. This could also contains unrecoverable network errors, corrupted file errors, file not found, modified errors and others.
        /// Errors are cleared every 5 minutes
        case error(Error, Date)
    }

    init(objectName: String, contentLength: Int, lastModified: Timestamp, eTag: String) {
        self.objectName = objectName
        self.contentLength = contentLength
        self.lastModified = lastModified
        self.eTag = eTag
        payload = .none
    }
    
    /// Initiate cached HTTP reader
    func makeCachedClient(client: HTTPClient, logger: Logger, server: String) -> OmReaderBlockCache<OmHttpReaderBackend, MmapFile> {
        let backend = OmHttpReaderBackend(client: client, logger: logger, url: "\(server)\(objectName)", count: contentLength, lastModified: lastModified, eTag: eTag)
        return OmReaderBlockCache<OmHttpReaderBackend, MmapFile>(backend: backend, cache: OpenMeteo.dataBlockCache, cacheKey: backend.cacheKey)
    }

    /// Called from directory listing updates. Most of the times, content length and last modified did not change
    func updateFromDirectoryListing(client: HTTPClient, logger: Logger, server: String, objectKey: String, contentLength: Int, lastModified: Timestamp, eTag: String) async {
        if self.contentLength == contentLength && self.lastModified == lastModified && eTag == self.eTag {
            return
        }
        self.contentLength = contentLength
        self.lastModified = lastModified
        self.eTag = eTag
        switch payload {
        case .ready(let old):
            payload = .updating(old: old, [])
            do {
                let file = makeCachedClient(client: client, logger: logger, server: server)
                let new = try await old.remoteUpdated(file: file)
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
    
    /// Execute a closure with the resolved payload. May retries if file modified errors occur
    nonisolated func with<R, Payload: RemotePayload>(client: HTTPClient, logger: Logger, server: String, fn: (_ value: Payload) async throws -> R) async throws -> R? {
        
        guard let payload = try await self.getPayload(ofType: Payload.self, client: client, logger: logger, server: server, receivedFileModifiedError: false) else {
            return nil
        }
        do {
            return try await fn(payload)
        } catch CurlError.fileNotFound {
            await self.receivedObjectDeletedError()
            return nil
        } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {
            guard let payload = try await self.getPayload(ofType: Payload.self, client: client, logger: logger, server: server, receivedFileModifiedError: true) else {
                return nil
            }
            /// Catch error again? If there would a file modified error again, this could indicate some remote server issues
            return try await fn(payload)
        }
    }
    
    /// Resolve payload
    func getPayload<T: RemotePayload>(ofType: T.Type, client: HTTPClient, logger: Logger, server: String, receivedFileModifiedError: Bool) async throws -> T? {
        // Reset errors of they are older than 5 minutes
        if case .error(_, let issueDate) = payload, Date.now.timeIntervalSince(issueDate) > 5 * 60 {
            payload = .none
        }
        switch payload {
        case .none:
            self.payload = .initialising([])
            do {
                let p = try await T(file: makeCachedClient(client: client, logger: logger, server: server))
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
                let newReader = try await OmHttpReaderBackend(client: client, logger: logger, url: "\(server)\(objectName)")
                self.contentLength = newReader.count
                self.lastModified = newReader.lastModifiedTimestamp
                self.eTag = newReader.eTag
                let new = try await payload.remoteUpdated(file: OmReaderBlockCache(backend: newReader, cache: OpenMeteo.dataBlockCache, cacheKey: newReader.cacheKey))
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
    let prefix: String
    var files = [String: S3File]()
    var directories = [String: S3Directory]()
    var lastValidated = Timestamp(0)
    var lastAccessed = Timestamp(0)
    
    /// If set to an array, a revalidation is running in the background
    var revalidationQueue: [CheckedContinuation<Void, Error>]? = nil
    
    init(prefix: String) {
        self.prefix = prefix
    }
    
    /// Revalidate the current directory using a S3 list operation. If a revalidation is already running, queue in.
    func update(client: HTTPClient, logger: Logger, server: String) async throws {
        guard revalidationQueue == nil else {
            try await withCheckedThrowingContinuation { continuation in
                revalidationQueue?.append(continuation)
            }
            return
        }
        logger.debug("Revalidating remote directory: \(prefix)")
        revalidationQueue = []
        do {
            let listed = try await S3List.s3list(client: client, server: server, prefix: prefix, apikey: nil, deadLineHours: 3)
            var listedFiles = Set<String>()
            for file in listed.files {
                let name = String(file.name.dropFirst(prefix.count))
                listedFiles.insert(name)
                // Keep existing object actors and directory actors alive whenever possible.
                if let existing = files[name] {
                    await existing.updateFromDirectoryListing(client: client, logger: logger, server: server, objectKey: file.name, contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp(), eTag: file.eTag)
                } else {
                    files[name] = S3File(objectName: "\(prefix)\(name)", contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp(), eTag: file.eTag)
                }
            }

            var listedDirectories = Set<String>()
            for directory in listed.directories {
                let name = String(directory.dropFirst(prefix.count).dropLast())
                listedDirectories.insert(name)
                if directories[name] == nil {
                    directories[name] = S3Directory(prefix: "\(prefix)\(name)/")
                }
            }

            for name in Array(files.keys) where !listedFiles.contains(name) {
                files.removeValue(forKey: name)
            }

            for name in Array(directories.keys) where !listedDirectories.contains(name) {
                directories.removeValue(forKey: name)
            }

            lastValidated = .now()
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
    nonisolated func updateRecursivelyIfRequired(
        client: HTTPClient,
        logger: Logger,
        server: String,
        now: Timestamp,
        revalidateIntervalSeconds: Int,
        inactiveSkipSeconds: Int
    ) async {
        if await lastAccessed.olderThan(seconds: inactiveSkipSeconds, now: now) {
            return
        }
        if await lastValidated.olderThan(seconds: revalidateIntervalSeconds, now: now) {
            do {
                try await update(client: client, logger: logger, server: server)
                OmMetrics.fileCacheRemoteRevalidated.add(1, ordering: .relaxed)
            } catch {
                logger.warning("S3Inventory lifecycle revalidation failed for prefix '\(prefix)': \(error)")
            }
        }

        for directory in await directories.values {
            await directory.updateRecursivelyIfRequired(
                client: client,
                logger: logger,
                server: server,
                now: now,
                revalidateIntervalSeconds: revalidateIntervalSeconds,
                inactiveSkipSeconds: inactiveSkipSeconds
            )
        }
    }
    
    private func updateIfRequired(client: HTTPClient, logger: Logger, server: String) async throws {
        let now = Timestamp.now()
        if lastValidated.olderThan(seconds: 10*60, now: now) {
            try await update(client: client, logger: logger, server: server)
        }
        lastAccessed = now
    }
    
    func exportDirectories(directories: inout Set<String>, files: inout [String: (lastModified: Date, size: Int64, eTag: String?)], server: String, client: HTTPClient, logger: Logger) async throws {
        try await updateIfRequired(client: client, logger: logger, server: server)
        for name in self.directories.keys {
            directories.insert(name)
        }
        for (name, attr) in self.files {
            guard files[name] == nil else {
                continue
            }
            files[name] = await (attr.lastModified.toDate(), Int64(attr.contentLength), attr.eTag)
        }
    }
    
    func getDirectory(name: String, server: String, client: HTTPClient, logger: Logger) async throws -> S3Directory? {
        try await updateIfRequired(client: client, logger: logger, server: server)
        return directories[name]
    }

    func getFile(name: String, server: String, client: HTTPClient, logger: Logger) async throws -> S3File? {
        try await updateIfRequired(client: client, logger: logger, server: server)
        return files[name]
    }
    
    func getContents(server: String, client: HTTPClient, logger: Logger) async throws -> DirectoryContents {
        try await updateIfRequired(client: client, logger: logger, server: server)
        return DirectoryContents(files: files, directories: directories, server: server, client: client, logger: logger)
    }
    
    /// Temporary view of the contents of a directory
    struct DirectoryContents {
        let files: [String: S3File]
        let directories: [String: S3Directory]
        let server: String
        let client: HTTPClient
        let logger: Logger
    }
}
