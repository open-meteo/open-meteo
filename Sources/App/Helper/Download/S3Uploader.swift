import Foundation
import AsyncHTTPClient
import NIOCore
import Logging
import NIOFileSystem

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
        let _ = try await client.executeRetry(request, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
    }

    /// Uploads files to S3 in 8 MB chunks
    /// Returns the `UploadId` which needs to be committed in a second step
    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func uploadMultipart<D: DataProtocol & Sendable>(client: HTTPClient, data: D, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        let logger = Logger(label: "S3Uploader")
        let chunkSize = 8 * 1024 * 1024

        // Step 1: Initiate multipart upload
        let timeInitiateRequestStart = DispatchTime.now().uptimeNanoseconds
        var initiateRequest = HTTPClientRequest(url: url + "?uploads")
        initiateRequest.method = .POST
        initiateRequest.headers.add(name: "Content-Type", value: contentType)
        let initiateResponse = try await client.executeRetry(initiateRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
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
        let partCount = (data.count + chunkSize - 1) / chunkSize
        do {
            let prepared = S3MultiPartUploadPrepared(
                etags: try await (0..<partCount).mapConcurrent(nConcurrent: nConcurrent) { (partNumber: Int) -> String in
                    let offset = partNumber * chunkSize
                    let chunk = data[data.index(data.startIndex, offsetBy: offset)..<data.index(data.startIndex, offsetBy: min(offset + chunkSize, data.count))]
                    var req = HTTPClientRequest(url: url + "?partNumber=\(partNumber+1)&uploadId=\(encodedUploadId)")
                    req.method = .PUT
                    req.body = .bytes(ByteBuffer(bytes: chunk))
                    req.headers.add(name: "x-amz-content-sha256", value: chunk.sha256Hex)
                    req.headers.add(name: .contentLength, value: "\(chunk.count)")
                    let response = try await client.executeRetry(req, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
                    guard let etag = response.headers.first(name: "ETag") else {
                        throw S3UploaderError.missingETag(partNumber: partNumber)
                    }
                    return etag
                },
                url: url,
                encodedUploadId: encodedUploadId
            )
            let timeChunkedRequest = Double(DispatchTime.now().uptimeNanoseconds - timeChunkedRequestStart) / 1_000_000_000
            let rate = Double(data.count) / timeChunkedRequest
            logger.info("Upload \(url.asUrlGetQuery) \(data.count.bytesHumanReadable). Initiate=\(timeInitiateRequest.asSecondsPrettyPrint), Upload=\(timeChunkedRequest.asSecondsPrettyPrint) Upload rate=\(rate.asRatePrettyPrint)")
            return prepared
        } catch {
            var abortRequest = HTTPClientRequest(url: url + "?uploadId=\(encodedUploadId)")
            abortRequest.method = .DELETE
            let _ = try await client.executeRetry(abortRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
            throw error
        }
    }
    
    static func uploadMultipart(client: HTTPClient, file: String, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        try await uploadMultipart(client: client, file: FilePath(file), url: url, contentType: contentType, nConcurrent: nConcurrent)
    }
    
    static func uploadMultipart(client: HTTPClient, file: FilePath, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        let fh = try await FileSystem.shared.openFile(forReadingAt: file, options: .init())
        do {
            return try await uploadMultipart(client: client, file: fh, url: url, contentType: contentType, nConcurrent: nConcurrent)
        } catch {
            try await fh.close()
            throw error
        }
    }
    
    /// Multipart upload to S3. Read files using SwiftNIO Filesystem
    static func uploadMultipart(client: HTTPClient, file: ReadableFileHandleProtocol, url: String, contentType: String = "application/octet-stream", nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        let logger = Logger(label: "S3Uploader")

        // Step 1: Initiate multipart upload
        let timeInitiateRequestStart = DispatchTime.now().uptimeNanoseconds
        var initiateRequest = HTTPClientRequest(url: url + "?uploads")
        initiateRequest.method = .POST
        initiateRequest.headers.add(name: "Content-Type", value: contentType)
        let initiateResponse = try await client.executeRetry(initiateRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
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
        let chunks = file.readChunks(chunkLength: .megabytes(8))
        do {
            let uploaded: [(etag: String, size: Int)] = try await chunks.mapEnumeratedConcurrent(nConcurrent: nConcurrent) { (partNumber, chunk) in
                var req = HTTPClientRequest(url: url + "?partNumber=\(partNumber+1)&uploadId=\(encodedUploadId)")
                req.method = .PUT
                req.body = .bytes(chunk)
                req.headers.add(name: "x-amz-content-sha256", value: chunk.readableBytesView.sha256Hex)
                req.headers.add(name: .contentLength, value: "\(chunk.readableBytes)")
                let response = try await client.executeRetry(req, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
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
            let _ = try await client.executeRetry(abortRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
            throw error
        }
    }
    
    /// Sync a local directory to a remote S3 directory. Compares if size is different or local modification time is larger then remote modification time for each file
    static func uploadSync(client: HTTPClient, localDirectory: String, server: String, basePath: String) async throws {
        let logger = Logger(label: "S3Uploader")
        let remoteRoot = basePath.hasSuffix("/") ? basePath : basePath + "/"
        let serverBase = server.hasSuffix("/") ? String(server.dropLast()) : server

        struct LocalFile {
            let absolutePath: String
            let remoteKey: String
            let size: Int
            let modificationTime: Date
        }

        // Step 1: Traverse local directory tree and collect all files.
        // Accumulate the set of remote prefixes to list in parallel.
        var localFiles: [LocalFile] = []
        var remotePrefixes: [String] = [remoteRoot]

        func collectLocally(localPath: String, remotePrefix: String) async throws {
            let dir = try await FileSystem.shared.openDirectory(atPath: FilePath(localPath))
            var subdirs: [(String, String)] = []
            do {
                for try await entry in dir.listContents() {
                    guard let name = entry.path.lastComponent?.string else { continue }
                    if entry.type == .regular {
                        if let info = try await FileSystem.shared.info(forFileAt: entry.path) {
                            let modTime = Date(timeIntervalSince1970: Double(info.lastDataModificationTime.seconds) + Double(info.lastDataModificationTime.nanoseconds) / 1_000_000_000)
                            localFiles.append(LocalFile(
                                absolutePath: entry.path.string,
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
            } catch {
                try await dir.close()
                throw error
            }
            for (subPath, subPrefix) in subdirs {
                try await collectLocally(localPath: subPath, remotePrefix: subPrefix)
            }
        }

        try await collectLocally(localPath: localDirectory, remotePrefix: remoteRoot)

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

        let totalBytes = toUpload.reduce(0) { $0 + $1.size }
        logger.info("Uploading \(toUpload.count) of \(localFiles.count) files (\(totalBytes.bytesHumanReadable))")

        // Step 4: Upload 2 files concurrently.
        try await toUpload.foreachConcurrent(nConcurrent: 2) { file in
            let url = serverBase + "/" + file.remoteKey
            let prepared = try await uploadMultipart(client: client, file: file.absolutePath, url: url)
            try await prepared.commit(client: client)
        }
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
        let completeResponse = try await client.executeRetry(completeRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
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
