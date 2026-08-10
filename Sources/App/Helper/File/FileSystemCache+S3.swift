import AsyncHTTPClient
import Foundation
import Logging

/**
 Caches metadata for objects and directories of an S3 server
 It is used concurrently to get meta data from objects or return if a object does not exist.

 Performs S3 List operations on demand recursively.
 
 Data from object is read using HTTP `If-Unmodified-Since` and HTTP ranges. If a file got modified, perform a HEAD request to quickly get the new modification timestamp and restart execution
 
 TODO:
 - serialize entries to disk for fast boot (option to store in KV cache? Need to prefix size)
 - track last accessed for each directory
 - background task to revalidate directories. Rules: only revalidate directories accessed within 30 minutes, Q: Keep everything in memory or eject if not accessed?
 - force revalidation on access if not revalidated for more than 10 minutes
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
            guard let next = try await directory.getDirectory(name: component, server: server, prefix: prefix, client: client) else {
                return nil
            }
            directory = next
            componentStart = path.index(after: nextSlash)
        }
        let prefix = path[path.startIndex..<objectStart]
        return try await directory.getFile(name: object, server: server, prefix: prefix, client: client)
    }
}

protocol RemoteFilePayload: Sendable {
    init(client: HTTPClient, logger: Logger, server: String, objectKey: String, size: Int64, lastModified: Timestamp) async throws
    func remoteUpdated(new: Self) async throws
    func remoteDeleted() async throws
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
        case none
        case initialising([CheckedContinuation<any RemoteFilePayload, Error>])
        case updating(old: any RemoteFilePayload, [CheckedContinuation<any RemoteFilePayload, Error>])
        case ready(any RemoteFilePayload)
        case error(Error)
    }

    init(contentLength: Int, lastModified: Timestamp) {
        self.contentLength = contentLength
        self.lastModified = lastModified
        payload = .none
    }

    /// Called from directory listing updates or single file HEAD revalidation
    /// TODO inform payload about update -> discard cached blocks, maybe preload new file
    func update(contentLength: Int, lastModified: Timestamp) async throws {
        if self.contentLength == contentLength && self.lastModified == lastModified {
            return
        }
        // TODO correct state machine
        /*self.contentLength = contentLength
        self.lastModified = lastModified
        switch payload {
        case .ready(let p):
            payload = .updating(old: p, [])
            do {
                let p = try await T(client: client, logger: logger, server: server, objectKey: objectKey, size: Int64(contentLength), lastModified: lastModified)
                let new = try await p.remoteUpdated(size: Int64(contentLength), lastModified: lastModified)
            }

        case .error(_):
            payload = .none
        default:
            break
        }*/
    }

    func revalidate(client: HTTPClient, logger: Logger, server: String, objectKey: String) async throws {
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
        
        try await update(contentLength: newContentLength, lastModified: newLastModified)
    }

    /// Execute a closure on file metadata. If the file changed while reading, revalidate object metadata and retry once.
//    func with<R: Sendable>(client: HTTPClient, logger: Logger, fn: (_ file: S3FileMeta) async throws -> R) async throws -> R? {
//        let currentMeta = meta()
//
//        do {
//            return try await fn(currentMeta)
//        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
//            logger.debug("S3 object changed while reading, revalidating object '\(objectKey)'")
//            do {
//                _ = try await revalidate(client: client, logger: logger)
//            } catch CurlError.fileNotFound {
//                return nil
//            }
//            return try await fn(meta())
//        }
//    }
    
    func getPayload<T: RemoteFilePayload>(ofType: T.Type, client: HTTPClient, logger: Logger, server: String, objectKey: String, forceNew: Bool) async throws -> T? {
        // TODO correct state machine
        if forceNew {
            switch payload {
            case .ready(_), .error(_):
                payload = .none
            default:
                break
            }
        }
        switch payload {
        case .none:
            self.payload = .initialising([])
            do {
                if forceNew {
                    let _ = try await revalidate(client: client, logger: logger, server: server, objectKey: objectKey)
                }
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
            if forceNew {
                return try await withCheckedThrowingContinuation { continuation in
                    payload = .updating(old: old, queue + [continuation])
                } as? T
            }
            return old as? T
        case .ready(let payload):
            return payload as? T
        case .error(let error):
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

actor S3Directory {
    /// if nil, the directory has not been fetched from the remote server yet
    var lastValidated: Timestamp? = nil
    var files = [String: S3File]()
    var directories = [String: S3Directory]()
    
    /// TODO a state machine could be better, because this revalidation is only done once
    /// If set to an array, a revalidation is running in the background
    var revalidationQueue: [CheckedContinuation<Void, Error>]? = nil
    
    /// Revalidate the current directory using a S3 list operation. If a revalidation is already running, queue in.
    func revalidate(client: HTTPClient, server: String, prefix: Substring) async throws {
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
                    try await existing.update(contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp())
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

            for name in Array(files.keys) where listedFiles.contains(name) {
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
    
    func getDirectory(name: Substring, server: String, prefix: Substring, client: HTTPClient) async throws -> S3Directory? {
        if lastValidated == nil {
            try await revalidate(client: client, server: server, prefix: prefix)
        }
        return directories[String(name)]
    }

    func getFile(name: Substring, server: String, prefix: Substring, client: HTTPClient) async throws -> S3File? {
        if lastValidated == nil {
            try await revalidate(client: client, server: server, prefix: prefix)
        }
        return files[String(name)]
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

