import Foundation
import AsyncHTTPClient
import NIOCore
import Logging
import NIOFileSystem

/**
 Utility to upload files to S3. Supports simple file uploads, multipart uploads and syncing local directories.
 Uses NIOFileSystem for async file IO and AsyncHTTPClient for async HTTP.
 */
enum S3Uploader {
    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func upload<D: DataProtocol>(client: HTTPClient, data: D, url: String, contentType: String = "application/octet-stream") async throws {
        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.body = .bytes(ByteBuffer(bytes: data))
        request.headers.add(name: "Content-Type", value: contentType)
        request.headers.add(name: "x-amz-content-sha256", value: data.sha256Hex)
        // executeRetry extracts credentials from the URL, signs the request with
        // AWS4-HMAC-SHA256 on each attempt, and retries on transient errors.
        let logger = Logger(label: "S3Uploader")
        let _ = try await client.executeRetry(request, logger: logger, deadline: .minutes(60), timeoutPerRequest: .seconds(60))
    }
    
    static func uploadMultipart(client: HTTPClient, file: String, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        try await uploadMultipart(client: client, file: FilePath(file), url: url, contentType: contentType, nConcurrent: nConcurrent)
    }
    
    static func uploadMultipart(client: HTTPClient, file: FilePath, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        return try await FileSystem.shared.withFileHandle(forReadingAt: file) { fh in
            return try await uploadMultipart(client: client, data: fh, url: url, contentType: contentType, nConcurrent: nConcurrent)
        }
    }
    
    /// Uploads files to S3 in 8 MB chunks
    /// Returns the `UploadId` which needs to be committed in a second step
    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func uploadMultipart<Data: S3UploadAble>(client: HTTPClient, data: Data, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        let logger = Logger(label: "S3Uploader")

        // Step 1: Initiate multipart upload
        let timeInitiateRequestStart = DispatchTime.now().uptimeNanoseconds
        var initiateRequest = HTTPClientRequest(url: url + "?uploads")
        initiateRequest.method = .POST
        initiateRequest.headers.add(name: "Content-Type", value: contentType)
        // custom header to set the total expected upload file size. Might be used by a custom upload implementation in the future
        initiateRequest.headers.add(name: "x-file-size", value: "\(try await data.getFileSize())")
        let initiateResponse = try await client.executeRetry(initiateRequest, logger: logger, deadline: .minutes(60), timeoutPerRequest: .seconds(60))
        guard
            let initiateXml = try await initiateResponse.readStringImmutable(upTo: 1024*1024),
            let uploadId = initiateXml.xmlValue(tag: "UploadId") else {
            throw S3UploaderError.missingUploadId
        }
        let timeInitiateRequest = Double(DispatchTime.now().uptimeNanoseconds - timeInitiateRequestStart) / 1_000_000_000
        
        // uploadId may contain '+', '/' or '=' — percent-encode for use in query strings
        let encodedUploadId = uploadId.addingPercentEncoding(withAllowedCharacters: .awsUriAllowed) ?? uploadId

        // Step 2: Upload parts concurrently (up to 8 in parallel), abort on any error
        let timeChunkedRequestStart = DispatchTime.now().uptimeNanoseconds
        let chunks = data.readChunks(chunkLength: .megabytes(8))
        do {
            let uploaded: [(etag: String, size: Int)] = try await chunks.mapEnumeratedConcurrent(nConcurrent: nConcurrent) { (partNumber, chunk) in
                var req = HTTPClientRequest(url: url + "?partNumber=\(partNumber+1)&uploadId=\(encodedUploadId)")
                req.method = .PUT
                req.body = .bytes(chunk)
                req.headers.add(name: "x-amz-content-sha256", value: chunk.readableBytesView.sha256Hex)
                req.headers.add(name: .contentLength, value: "\(chunk.readableBytes)")
                let response = try await client.executeRetry(req, logger: logger, deadline: .minutes(60), timeoutPerRequest: .seconds(120))
                guard let etag = response.headers.first(name: "ETag") else {
                    throw S3UploaderError.missingETag(partNumber: partNumber)
                }
                return (etag, chunk.readableBytes)
            }
            let prepared = S3MultiPartUploadPrepared(
                etags: uploaded.map(\.etag),
                url: url,
                encodedUploadId: encodedUploadId
            )
            let size = uploaded.map(\.size).reduce(0, +)
            let timeChunkedRequest = Double(DispatchTime.now().uptimeNanoseconds - timeChunkedRequestStart) / 1_000_000_000
            let rate = Double(size) / timeChunkedRequest
            logger.info("Upload \(url.asUrlGetQuery) \(size.bytesHumanReadable). Initiate=\(timeInitiateRequest.asSecondsPrettyPrint), Upload=\(timeChunkedRequest.asSecondsPrettyPrint) Upload rate=\(rate.asRatePrettyPrint)")
            return prepared
        } catch {
            var abortRequest = HTTPClientRequest(url: url + "?uploadId=\(encodedUploadId)")
            abortRequest.method = .DELETE
            let _ = try await client.executeRetry(abortRequest, logger: logger, deadline: .minutes(60), timeoutPerRequest: .seconds(30))
            throw error
        }
    }
        
    /// Sync a local directory to a remote S3 directory. Compares if size is different or local modification time is larger then remote modification time for each file
    /// local directory in form `/home/user/some-bucket/some-path/`
    /// `server` in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/"
    /// `basePath` offsets the object names relative to the local directory .e.g. `some-path/` in this example
    /// `exclude` can be used to exclude file names. Supports "*" and "?" wildcards
    static func uploadSync(client: HTTPClient, localDirectory: String, server: String, basePath: String, exclude: [String] = [".*", "*~"]) async throws {
        let logger = Logger(label: "S3Uploader")
        let remoteRoot = basePath.hasSuffix("/") ? basePath : basePath + "/"
        let serverBase = server.hasSuffix("/") ? String(server.dropLast()) : server

        struct LocalFile {
            let absolutePath: FilePath
            let remoteKey: String
            let size: Int
            let modificationTime: Date
        }

        // Step 1: Traverse local directory tree and collect all files.
        // Accumulate the set of remote prefixes to list in parallel.
        var localFiles: [LocalFile] = []
        var remotePrefixes: [String] = [remoteRoot]

        func collectLocally(localPath: String, remotePrefix: String) async throws {
            let subdirs = try await FileSystem.shared.withDirectoryHandle(atPath: FilePath(localPath)) { dir in
                var subdirs: [(String, String)] = []
                for try await entry in dir.listContents() {
                    guard let name = entry.path.lastComponent?.string else { continue }
                    if !exclude.isEmpty && exclude.contains(where: { name.matchesGlob($0) }) { continue }
                    if entry.type == .regular {
                        if let info = try await FileSystem.shared.info(forFileAt: entry.path) {
                            let modTime = Date(timeIntervalSince1970: Double(info.lastDataModificationTime.seconds) + Double(info.lastDataModificationTime.nanoseconds) / 1_000_000_000)
                            localFiles.append(LocalFile(
                                absolutePath: entry.path,
                                remoteKey: remotePrefix + name,
                                size: Int(info.size),
                                modificationTime: modTime
                            ))
                        }
                    } else if entry.type == .directory {
                        let subPrefix = remotePrefix + name + "/"
                        remotePrefixes.append(subPrefix)
                        subdirs.append((entry.path.string, subPrefix))
                    }
                }
                return subdirs
            }
            for (subPath, subPrefix) in subdirs {
                try await collectLocally(localPath: subPath, remotePrefix: subPrefix)
            }
        }
        
        logger.info("Collecting local files in \(localDirectory)")
        let startLocal = DispatchTime.now()

        try await collectLocally(localPath: localDirectory, remotePrefix: remoteRoot)
        
        logger.info("Checked local files in \(startLocal.timeElapsedPretty()). Collecting remote files now.")
        let startRemote = DispatchTime.now()

        // Step 2: Fetch remote directory listings concurrently, max 4 S3 list operations at a time.
        let remoteListings = try await remotePrefixes.mapConcurrent(nConcurrent: 4) { prefix in
            try await S3List.s3list(client: client, server: server, prefix: prefix, apikey: nil, deadLineHours: 1).files
        }
        var remoteFiles: [String: S3List.ListV2File] = [:]
        for files in remoteListings {
            for file in files { remoteFiles[file.name] = file }
        }

        // Step 3: Determine which files need uploading:
        // missing remotely, different size, or local is newer than remote.
        let toUpload = localFiles.filter { local in
            guard let remote = remoteFiles[local.remoteKey] else { return true }
            return remote.fileSize != local.size || local.modificationTime > remote.modificationTime
        }
        
        guard toUpload.count > 0 else {
            logger.info("No files to upload. Exiting.")
            return
        }

        let totalBytes = toUpload.reduce(0) { $0 + $1.size }
        let uploadStart = DispatchTime.now()
        logger.info("Collected remote files in \(startRemote.timeElapsedPretty()). Uploading \(toUpload.count) of \(localFiles.count) files (\(totalBytes.bytesHumanReadable))")

        // Step 4: Upload 2 files concurrently.
        let prepared = try await toUpload.mapConcurrent(nConcurrent: 4) { file in
            let url = serverBase + "/" + file.remoteKey
            return try await uploadMultipart(client: client, file: file.absolutePath, url: url, nConcurrent: 4)
        }
        let uploadTime = Double(DispatchTime.now().uptimeNanoseconds - uploadStart.uptimeNanoseconds) / 1_000_000_000
        let rate = Double(totalBytes) / uploadTime
        logger.info("Upload completed in \(uploadTime.asSecondsPrettyPrint) \(rate.asRatePrettyPrint). Commit changes now")
        let commitStart = DispatchTime.now()
        
        // Commit all OM file changes
        try await prepared.foreachConcurrent(nConcurrent: 8) { prepared in
            if prepared.url.hasSuffix(".json") {
                return
            }
            try await prepared.commit(client: client)
        }
        // Commit all json files. E.g. meta.json which should be committed last
        try await prepared.foreachConcurrent(nConcurrent: 8) { prepared in
            if prepared.url.hasSuffix(".json") == false {
                return
            }
            try await prepared.commit(client: client)
        }
        
        logger.info("Commit completed in \(commitStart.timeElapsedPretty())")
    }
}

/// Protocol of how a file can be chunked into 8 MB parts and upload as individual ByteBuffers. Unfortunately, `AsyncHTTPClient` only accepts ByteBuffers so a memory copy can not be avoided.
protocol S3UploadAble {
    associatedtype ByteBufferSequence: AsyncSequence where ByteBufferSequence.Element == ByteBuffer, ByteBufferSequence: Sendable
    func readChunks(chunkLength: ByteCount) -> ByteBufferSequence
    
    func getFileSize() async throws -> Int64
}

extension ReadFileHandle: S3UploadAble {
    func getFileSize() async throws -> Int64 {
        return try await self.info().size
    }
}

extension ByteBuffer: S3UploadAble {
    func getFileSize() async throws -> Int64 {
        return Int64(self.readableBytes)
    }
    
    func readChunks(chunkLength: ByteCount) -> AsyncStream<ByteBuffer> {
        let chunkSize = Int(chunkLength.bytes)
        var copy = self
        return AsyncStream { continuation in
            while copy.readableBytes > 0 {
                let slice = copy.readSlice(length: min(chunkSize, copy.readableBytes))!
                continuation.yield(slice)
            }
            continuation.finish()
        }
    }
}

//extension Foundation.FileHandle: S3UploadAble {
//    /// Note: Blocking implementation
//    public func readChunks(chunkLength: ByteCount) -> AsyncStream<ByteBuffer> {
//        let chunkSize = Int(chunkLength.bytes)
//        return AsyncStream { continuation in
//            while true {
//                let data = self.readData(ofLength: chunkSize)
//                if data.isEmpty { break }
//                continuation.yield(ByteBuffer(bytes: data))
//            }
//            continuation.finish()
//        }
//    }
//}

extension String {
    /// Match a filename against a glob pattern supporting `*` (any sequence) and `?` (single character).
    /// E.g. `".*"`, `"*~"`, `"*_previous_day*"`
    func matchesGlob(_ pattern: String) -> Bool {
        var p = pattern.startIndex
        var s = self.startIndex
        var starP: String.Index? = nil
        var starS: String.Index? = nil
        while s < self.endIndex {
            if p < pattern.endIndex && (pattern[p] == "?" || pattern[p] == self[s]) {
                p = pattern.index(after: p)
                s = self.index(after: s)
            } else if p < pattern.endIndex && pattern[p] == "*" {
                starP = p
                starS = s
                p = pattern.index(after: p)
            } else if let sp = starP {
                p = pattern.index(after: sp)
                starS = self.index(after: starS!)
                s = starS!
            } else {
                return false
            }
        }
        while p < pattern.endIndex && pattern[p] == "*" { p = pattern.index(after: p) }
        return p == pattern.endIndex
    }
}

/// Intermediate representation
struct S3MultiPartUploadPrepared {
    let etags: [String]
    let url: String
    let encodedUploadId: String

    /// complete multipart upload. This may take longer than expected
    func commit(client: HTTPClient) async throws {
        // Step 3: Complete multipart upload
        let logger = Logger(label: "S3Uploader")
        let timeCommitRequestStart = DispatchTime.now().uptimeNanoseconds
        let completionXml = "<CompleteMultipartUpload>" + etags.enumerated().map {
            "<Part><PartNumber>\($0.0 + 1)</PartNumber><ETag>\($0.1)</ETag></Part>"
        }.joined() + "</CompleteMultipartUpload>"
        let completionData = Data(completionXml.utf8)
        var completeRequest = HTTPClientRequest(url: url + "?uploadId=\(encodedUploadId)")
        completeRequest.method = .POST
        completeRequest.body = .bytes(ByteBuffer(data: completionData))
        completeRequest.headers.add(name: "Content-Type", value: "application/xml")
        completeRequest.headers.add(name: "x-amz-content-sha256", value: completionData.sha256Hex)
        let completeResponse = try await client.executeRetry(completeRequest, logger: logger, deadline: .minutes(60), timeoutPerRequest: .seconds(30))
        _ = try await completeResponse.body.collect(upTo: 1024 * 1024)
        let timeCommitRequest = Double(DispatchTime.now().uptimeNanoseconds - timeCommitRequestStart) / 1_000_000_000
        logger.info("Upload \(url.asUrlGetQuery) committed in \(timeCommitRequest.asSecondsPrettyPrint)")
    }
}

enum S3UploaderError: Error {
    case missingUploadId
    case missingETag(partNumber: Int)
}

fileprivate extension String {
    /// Extract the text content of the first occurrence of `<tag>…</tag>` in an XML string.
    func xmlValue(tag: String) -> String? {
        guard let start = range(of: "<\(tag)>"),
              let end = range(of: "</\(tag)>") else { return nil }
        return String(self[start.upperBound..<end.lowerBound])
    }
    
    /// Assume self is a URL, return the query part
    var asUrlGetQuery: Substring {
        guard let schemaIndex = self.firstRange(of: "://"),
                let queryStart = self[schemaIndex.upperBound...].firstIndex(of: "/") else {
            return Substring(self)
        }
        return self[queryStart...]
    }
}

