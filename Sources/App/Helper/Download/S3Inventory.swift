import AsyncHTTPClient
import Foundation
import Logging

/**
Caches metadata for objects and directories of an S3 server
 It is used heavily concurrently to get meta data from objects or return if a object does not exist.
 Data from object is read using HTTP `If-Unmodified-Since` and HTTP ranges. If a file got modified, the directory needs to be revalidated to get the new modification timestamp of an object. We do not revalidate single objects using HTTP HEAD.
 
 
 Notes:
 - If a remote file is read using HTTP If-modified-since and returns an error, the entire directory is revalidated
 - the KV value cache for files needs to keep the initialised reader instance in memory. The `OmFileReaderBackend`
 */



struct S3Inventory {
    let server: String
    let root = S3Directory()
    
    
    /// Find an object for a path
    func getObject(path: String, client: HTTPClient, logger: Logger) async throws -> S3File? {
        let fullPath = path

        let trimmedStart = fullPath.firstIndex(where: { $0 != "/" }) ?? fullPath.endIndex
        var trimmedEnd = fullPath.endIndex
        while trimmedEnd > trimmedStart {
            let previous = fullPath.index(before: trimmedEnd)
            guard fullPath[previous] == "/" else {
                break
            }
            trimmedEnd = previous
        }

        guard trimmedStart < trimmedEnd else {
            return nil
        }

        let relevantPath = fullPath[trimmedStart..<trimmedEnd]
        let objectStart = relevantPath.lastIndex(of: "/").map { relevantPath.index(after: $0) } ?? relevantPath.startIndex
        let object = relevantPath[objectStart..<relevantPath.endIndex]

        var directory = root
        var componentStart = relevantPath.startIndex
        while componentStart < objectStart {
            let nextSlash = relevantPath[componentStart..<objectStart].firstIndex(of: "/") ?? objectStart
            let component = relevantPath[componentStart..<nextSlash]
            let prefix = relevantPath[relevantPath.startIndex..<componentStart]

            guard let next = try await directory.getDirectory(name: component, server: server, prefix: prefix, client: client) else {
                return nil
            }

            directory = next
            componentStart = relevantPath.index(after: nextSlash)
        }

        let prefix = relevantPath[relevantPath.startIndex..<objectStart]
        return try await directory.getFile(name: object, server: server, prefix: prefix, client: client)
    }
}

struct S3FileMeta: Sendable {
    let contentLength: Int
    let lastModified: Timestamp
}

actor S3File {
    private let server: String
    private let objectKey: String

    private var contentLength: Int
    private var lastModified: Timestamp

    init(server: String, objectKey: String, contentLength: Int, lastModified: Timestamp) {
        self.server = server
        self.objectKey = objectKey
        self.contentLength = contentLength
        self.lastModified = lastModified
    }

    func meta() -> S3FileMeta {
        S3FileMeta(contentLength: contentLength, lastModified: lastModified)
    }

    func update(contentLength: Int, lastModified: Timestamp) {
        self.contentLength = contentLength
        self.lastModified = lastModified
    }

    func revalidate(client: HTTPClient, logger: Logger) async throws -> Bool {
        var request = HTTPClientRequest(url: "\(server)\(objectKey.s3PathPercentEncoded)")
        request.method = .HEAD
        try request.applyS3Credentials()

        logger.debug("Revalidating S3 object '\(objectKey)' via HEAD")
        let response = try await client.executeRetry(request, logger: logger, deadline: .seconds(10), timeoutPerRequest: .seconds(2))
        guard let newContentLength = response.headers["Content-Length"].first.flatMap(Int.init) else {
            throw OmHttpReaderBackendError.contentLengthMissing
        }

        let newLastModified = response.headers["Last-Modified"]
            .first
            .flatMap(Self.lastModifiedDateFormat.date(from:))
            .map { Timestamp(Int($0.timeIntervalSince1970)) }

        if let newLastModified, newContentLength == contentLength, newLastModified == lastModified {
            return false
        }

        contentLength = newContentLength
        if let newLastModified {
            lastModified = newLastModified
        }
        return true
    }

    /// Execute a closure on file metadata. If the file changed while reading, revalidate object metadata and retry once.
    func with<R: Sendable>(client: HTTPClient, logger: Logger, fn: (_ file: S3FileMeta) async throws -> R) async throws -> R? {
        let currentMeta = meta()

        do {
            return try await fn(currentMeta)
        } catch CurlErrorNonRetry.fileModifiedSinceLastDownload {
            logger.debug("S3 object changed while reading, revalidating object '\(objectKey)'")
            do {
                _ = try await revalidate(client: client, logger: logger)
            } catch CurlError.fileNotFound {
                return nil
            }
            return try await fn(meta())
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
    
    /// If set to an array, a revalidation is running in the background
    var revalidationQueue: [CheckedContinuation<Void, Error>]? = nil
    
    func revalidate(client: HTTPClient, server: String, prefix: String) async throws {
        guard revalidationQueue == nil else {
            try await withCheckedThrowingContinuation { continuation in
                revalidationQueue?.append(continuation)
            }
            return
        }

        revalidationQueue = []

        do {
            let listed = try await S3List.s3list(client: client, server: server, prefix: prefix, apikey: nil, deadLineHours: 3)

            var listedFiles = [String: (contentLength: Int, lastModified: Timestamp)]()
            for file in listed.files {
                let objectName = file.name.dropFirst(prefix.count)
                listedFiles[String(objectName)] = (contentLength: file.fileSize, lastModified: file.modificationTime.toTimestamp())
            }

            var listedDirectories = Set<String>()
            for directory in listed.directories {
                let directoryName = directory.dropFirst(prefix.count).dropLast()
                listedDirectories.insert(String(directoryName))
            }

            // Keep existing object actors and directory actors alive whenever possible.
            for (name, metadata) in listedFiles {
                if let existing = files[name] {
                    await existing.update(contentLength: metadata.contentLength, lastModified: metadata.lastModified)
                } else {
                    files[name] = S3File(server: server, objectKey: "\(prefix)\(name)", contentLength: metadata.contentLength, lastModified: metadata.lastModified)
                }
            }

            for name in Array(files.keys) where listedFiles[name] == nil {
                files.removeValue(forKey: name)
            }

            for name in listedDirectories where directories[name] == nil {
                directories[name] = S3Directory()
            }

            for name in Array(directories.keys) where !listedDirectories.contains(name) {
                directories.removeValue(forKey: name)
            }

            lastValidated = .now()

            let waiters = revalidationQueue ?? []
            revalidationQueue = nil
            for waiter in waiters {
                waiter.resume()
            }
        } catch {
            let waiters = revalidationQueue ?? []
            revalidationQueue = nil
            for waiter in waiters {
                waiter.resume(throwing: error)
            }
            throw error
        }
    }
    
    func getDirectory(name: Substring, server: String, prefix: Substring, client: HTTPClient) async throws -> S3Directory? {
        let prefixString = String(prefix)

        if lastValidated == nil {
            try await revalidate(client: client, server: server, prefix: prefixString)
        }
        return directories[String(name)]
    }

    func getFile(name: Substring, server: String, prefix: Substring, client: HTTPClient) async throws -> S3File? {
        let prefixString = String(prefix)

        if lastValidated == nil {
            try await revalidate(client: client, server: server, prefix: prefixString)
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

