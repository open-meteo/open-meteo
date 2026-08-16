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

struct OmFileSystemS3 {
    let server: String
    let root = Directory(prefix: "")
    
    /// Make initial root directory access given a HTTP client and logger. Refreshes root if required
    func getRoot(client: HTTPClient, logger: Logger) async throws -> DirectoryWithContext {
        let context = ServerContext(server: server, client: client, logger: logger)
        try await root.updateIfRequired(context: context)
        return DirectoryWithContext.init(directory: root, context: context)
    }

    func updateRecursivelyIfRequired(client: HTTPClient, logger: Logger) async {
        await self.root.updateRecursivelyIfRequired(
            context: .init(server: server, client: client, logger: logger),
            now: .now(),
            revalidateIntervalSeconds: 120,
            inactiveSkipSeconds: 30 * 60
        )
    }
    
    /// Server string with HTTP client and Logger
    struct ServerContext {
        let server: String
        let client: HTTPClient
        let logger: Logger
    }
    
    struct FileWithContext: OmFileSystemFile {
        let file: File
        let context: ServerContext
        
        /// Execute a closure with the resolved payload. May retries if file modified errors occur
        func with<R, Payload: OmRemotePayload>(fn: (_ value: Payload) async throws -> R) async throws -> R? {
            guard let payload = try await file.getPayload(ofType: Payload.self, context: context, receivedFileModifiedError: false) else {
                return nil
            }
            do {
                return try await fn(payload)
            } catch CurlError.fileNotFound {
                await file.receivedObjectDeletedError()
                return nil
            } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {
                guard let payload = try await file.getPayload(ofType: Payload.self, context: context, receivedFileModifiedError: true) else {
                    return nil
                }
                /// Catch error again? If there would a file modified error again, this could indicate some remote server issues
                return try await fn(payload)
            }
        }
    }

    actor File {
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
            case initialising([CheckedContinuation<any OmRemotePayload, Error>])
            
            /// Payload got initialised and should be in sync with remote server
            case ready(any OmRemotePayload)
            
            /// The S3 directory listing detected a modification or a HTTP request threw a file modified error. Start reloading the new payload, but keep the old payload
            case updating(old: any OmRemotePayload, [CheckedContinuation<any OmRemotePayload, Error>])
            
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
        func makeCachedClient(context: ServerContext) -> OmReaderBlockCache<OmHttpReaderBackend, MmapFile> {
            let backend = OmHttpReaderBackend(client: context.client, logger: context.logger, url: "\(context.server)\(objectName)", count: contentLength, lastModified: lastModified, eTag: eTag)
            return OmReaderBlockCache<OmHttpReaderBackend, MmapFile>(backend: backend, cache: OpenMeteo.dataBlockCache, cacheKey: backend.cacheKey)
        }

        /// Called from directory listing updates. Most of the times, content length and last modified did not change
        func updateFromDirectoryListing(context: ServerContext, objectKey: String, contentLength: Int, lastModified: Timestamp, eTag: String) async {
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
                    let file = makeCachedClient(context: context)
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
        
        /// Resolve payload
        func getPayload<T: OmRemotePayload>(ofType: T.Type, context: ServerContext, receivedFileModifiedError: Bool) async throws -> T? {
            // Reset errors of they are older than 5 minutes
            if case .error(_, let issueDate) = payload, Date.now.timeIntervalSince(issueDate) > 5 * 60 {
                payload = .none
            }
            switch payload {
            case .none:
                self.payload = .initialising([])
                do {
                    let p = try await T(file: makeCachedClient(context: context))
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
                    let newReader = try await OmHttpReaderBackend(client: context.client, logger: context.logger, url: "\(context.server)\(objectName)")
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


    struct DirectoryWithContext: OmFileSystemDirectory {
        let directory: Directory
        let context: ServerContext
        
        /// Find a directory for a path
        func getDirectory(fullPath: String) async throws -> DirectoryWithContext? {
            guard fullPath.hasPrefix("/") == false, fullPath.hasSuffix("/") else {
                throw S3InventoryError.invalidObjectName
            }
            let trimmedPath = fullPath.dropLast()
            var directory = directory
            var componentStart = trimmedPath.startIndex
            while componentStart < trimmedPath.endIndex {
                let nextSlash = trimmedPath[componentStart..<trimmedPath.endIndex].firstIndex(of: "/") ?? trimmedPath.endIndex
                let component = trimmedPath[componentStart..<nextSlash]
                guard let next = try await directory.getDirectory(name: String(component), context: context) else {
                    return nil
                }
                directory = next

                guard nextSlash < trimmedPath.endIndex else {
                    break
                }
                componentStart = trimmedPath.index(after: nextSlash)
            }
            return .init(directory: directory, context: context)
        }
        
        /// Find an object for a path
        func getFile(fullPath: String) async throws -> FileWithContext? {
            guard fullPath.hasPrefix("/") == false, fullPath.hasSuffix("/") == false else {
                throw S3InventoryError.invalidObjectName
            }
            let objectStart = fullPath.lastIndex(of: "/").map { fullPath.index(after: $0) } ?? fullPath.startIndex
            let object = fullPath[objectStart..<fullPath.endIndex]

            var directory = directory
            var componentStart = fullPath.startIndex
            while componentStart < objectStart {
                let nextSlash = fullPath[componentStart..<objectStart].firstIndex(of: "/") ?? objectStart
                let component = fullPath[componentStart..<nextSlash]
                guard let next = try await directory.getDirectory(name: String(component), context: context) else {
                    return nil
                }
                directory = next
                componentStart = fullPath.index(after: nextSlash)
            }
            guard let f = await directory.getFile(name: String(object)) else {
                return nil
            }
            return .init(file: f, context: context)
        }
        
        func getDirectory(name: String) async throws -> DirectoryWithContext? {
            guard let directory = try await directory.getDirectory(name: name, context: context) else {
                return nil
            }
            return .init(directory: directory, context: context)
        }
        
        func getFile(name: String) async -> FileWithContext? {
            guard let file = await directory.getFile(name: name) else {
                return nil
            }
            return .init(file: file, context: context)
        }
    }

    /// Represents the content of a remote S3 directory with files and sub directories.
    /// At initialisation the directory does not fetch contents, but waits until the first request arrives
    actor Directory {
        let prefix: String
        private var files = [String: File]()
        private var directories = [String: Directory]()
        private var lastValidated = Timestamp(0)
        private var lastAccessed = Timestamp(0)
        
        /// If set to an array, a revalidation is running in the background
        var revalidationQueue: [CheckedContinuation<Void, Error>]? = nil
        
        init(prefix: String) {
            self.prefix = prefix
        }
        
        /// Revalidate the current directory using a S3 list operation. If a revalidation is already running, queue in.
        func update(context: ServerContext) async throws {
            let logger = context.logger
            guard revalidationQueue == nil else {
                try await withCheckedThrowingContinuation { continuation in
                    revalidationQueue?.append(continuation)
                }
                return
            }
            logger.debug("Revalidating remote directory: \(prefix)")
            revalidationQueue = []
            do {
                let listed = try await S3List.s3list(context: context, prefix: prefix, apikey: nil, deadLineHours: 3)
                var listedFiles = Set<String>()
                for file in listed.files {
                    let name = String(file.name.dropFirst(prefix.count))
                    listedFiles.insert(name)
                    // Keep existing object actors and directory actors alive whenever possible.
                    if let existing = files[name] {
                        await existing.updateFromDirectoryListing(context: context, objectKey: file.name, contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp(), eTag: file.eTag)
                    } else {
                        files[name] = File(objectName: "\(prefix)\(name)", contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp(), eTag: file.eTag)
                    }
                }

                var listedDirectories = Set<String>()
                for directory in listed.directories {
                    let name = String(directory.dropFirst(prefix.count).dropLast())
                    listedDirectories.insert(name)
                    if directories[name] == nil {
                        directories[name] = Directory(prefix: "\(prefix)\(name)/")
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
        func updateRecursivelyIfRequired(
            context: ServerContext,
            now: Timestamp,
            revalidateIntervalSeconds: Int,
            inactiveSkipSeconds: Int
        ) async {
            if lastAccessed.olderThan(seconds: inactiveSkipSeconds, now: now) {
                return
            }
            if lastValidated.olderThan(seconds: revalidateIntervalSeconds, now: now) {
                do {
                    try await update(context: context)
                    OmMetrics.fileCacheRemoteRevalidated.add(1, ordering: .relaxed)
                } catch {
                    context.logger.warning("S3Inventory lifecycle revalidation failed for prefix '\(prefix)': \(error)")
                }
            }

            for directory in directories.values {
                await directory.updateRecursivelyIfRequired(
                    context: context,
                    now: now,
                    revalidateIntervalSeconds: revalidateIntervalSeconds,
                    inactiveSkipSeconds: inactiveSkipSeconds
                )
            }
        }
        
        func updateIfRequired(context: ServerContext) async throws {
            let now = Timestamp.now()
            if lastValidated.olderThan(seconds: 10*60, now: now) {
                try await update(context: context)
            }
            lastAccessed = now
        }
        
        func exportDirectories(directories: inout Set<String>, files: inout [String: (lastModified: Date, size: Int64, eTag: String?)]) async {
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
        
        /// Get directory inside this directory and update its contents
        func getDirectory(name: String, context: ServerContext) async throws -> Directory? {
            let directory = directories[name]
            try await directory?.updateIfRequired(context: context)
            return directory
        }

        /// Get a file from this directory. Does not update its contents, because directory access already refreshed it
        func getFile(name: String) -> File? {
            return files[name]
        }
    }

}

