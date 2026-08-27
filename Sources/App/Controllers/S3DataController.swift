import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import NIOFileSystem
@_spi(Testing) import NIOFileSystem

/**
 Expose database as S3 endpoint. This can be used to pull data from one server to another. It is used only internally to transfer data between Open-Meteo API nodes. Note: This is only a limited implementation and not fully compatible.
 After upload, the local cached file manager is updated as well to immediately reflect the file changes
 
 List example:
 `http://127.0.0.1:8080/?list-type=2&delimiter=/&prefix=data/cmc_gem_gdps/shortwave_radiation/&apikey=123`
 
 Download exmaple
 `http://127.0.0.1:8080/data/cmc_gem_gdps/shortwave_radiation/chunk_1430.om?apikey=123`
 
 If `S3_READ_CREDENTIALS` is set to "key1:secret1,key2:secret2" the list and download endpoints accept AWS SigV4 signed GET requests in addition to API keys.
 
 If `S3_UPLOAD_CREDENTIALS` is set to "key1:secret1,key2:secret2" the endpoints accepts file uploads using S3 multi part uploads. The upload is non standard, meaning that additional headers for the final file size must be set. E.g. AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
 
 If `S3_UPLOAD_REPLICATION_SERVERS` is set to "s3://key1:secret1@server1.tld/,s3://key1:secret1@server2.tld/" all uploads are replicated to those servers. Servers are checked every couple of seconds. If offline, they are ignored. Also non standard S3 implementation. Used to replicate uploads to a fail-over server in realtime. If the server is available. This is a blocking operation.
 
 If `S3_UPLOAD_LAZY_SERVERS` is set to "s3://key1:secret1@server1.tld/,s3://key1:secret1@server2.tld/" all uploads are lazily replicated to those servers after the sync replication completed. Used to upload data to large S3 storage servers afterwards
 
 TODO:
 - API key integration with accounting (1 call = 1KB traffic)
 */
struct S3DataController: RouteCollection {
    static let syncApiKeys: [String.SubSequence] = Environment.get("API_SYNC_APIKEYS")?.split(separator: ",") ?? []
    static let multipartChunkSize = 8 * 1024 * 1024
    static let uploadIdRange = 1_000_000_000...Int.max
    static let uploadMaximumFileSize = 500 << 30 // 500GB
    
    let readCredentials: [UploadCredential]
    let uploadCredentials: [UploadCredential]
    
    init(readCredentials: [UploadCredential]? = nil, uploadCredentials: [UploadCredential]? = nil) {
        self.uploadCredentials = uploadCredentials ?? UploadCredential.loadFromEnvironment(key: "S3_UPLOAD_CREDENTIALS")
        self.readCredentials = readCredentials ?? UploadCredential.loadFromEnvironment(key: "S3_READ_CREDENTIALS") + self.uploadCredentials
    }
    
    func boot(routes: RoutesBuilder) throws {
        if Self.syncApiKeys.isEmpty && readCredentials.isEmpty && uploadCredentials.isEmpty {
            return
        }
        
        if !Self.syncApiKeys.isEmpty || !self.readCredentials.isEmpty {
            routes.get("", use: self.list)
            routes.get("index.html", use: self.index)
            routes.get("openmeteo", use: self.list)
            routes.get("openmeteo-local", use: self.list)
            routes.on(.HEAD, [], use: self.headRoot)
            for root in ["data", "data_run", "data_spatial"] {
                routes.on(.HEAD, [PathComponent(stringLiteral: root), .catchall], use: self.get)
                routes.on(.HEAD, ["openmeteo", PathComponent(stringLiteral: root), .catchall], use: self.get)
                routes.on(.HEAD, ["openmeteo-local", PathComponent(stringLiteral: root), .catchall], use: self.get)
                routes.get(PathComponent(stringLiteral: root), "**", use: self.get)
                routes.get("openmeteo", PathComponent(stringLiteral: root), "**", use: self.get)
                routes.get("openmeteo-local", PathComponent(stringLiteral: root), "**", use: self.get)
            }
        }
        
        if !self.uploadCredentials.isEmpty {
            for root in ["data", "data_run", "data_spatial"] {
                routes.on(.PUT, [PathComponent(stringLiteral: root), .catchall], body: .collect(maxSize: "9mb"), use: self.putObject)
                routes.on(.POST, [PathComponent(stringLiteral: root), .catchall], body: .collect(maxSize: "9mb"), use: self.postObject)
                routes.on(.DELETE, [PathComponent(stringLiteral: root), .catchall], use: self.deleteObject)
            }
        }
    }
    
    struct DownloadParams: Codable {
        let apikey: String?
    }
    
    func headRoot(_ req: Request) throws -> HTTPStatus {
        try verifyRequestSignature(req: req, body: ByteBuffer(), isRead: true)
        return .ok
    }
    
    struct UploadCredential: Sendable, Hashable {
        let accessKey: String
        let secretKey: String
        
        init(accessKey: String, secretKey: String) {
            self.accessKey = accessKey
            self.secretKey = secretKey
        }
        
        static func loadFromEnvironment(key: String) -> [UploadCredential] {
            guard let raw = Environment.get(key) else {
                return []
            }
            return raw.split(separator: ",").map { entry in
                guard let parsed = parseCredential(String(entry)) else {
                    fatalError("Could not parse S3 credentials \(entry)")
                }
                return parsed
            }
        }
        
        private static func parseCredential(_ raw: String) -> UploadCredential? {
            if let split = raw.firstIndex(of: ":") {
                let key = String(raw[..<split])
                let secret = String(raw[raw.index(after: split)...])
                guard !key.isEmpty, !secret.isEmpty else { return nil }
                return UploadCredential(accessKey: key, secretKey: secret)
            }
            return nil
        }
    }
    
    /// List all files in a specified directory
    func list(_ req: Request) async throws -> Response {
        OmMetrics.requestsS3ApiTotal.add(1, ordering: .relaxed)
        guard OmMetrics.requestsRunning.load(ordering: .relaxed) <= RateLimiter.concurrencyLimitTotal else {
            OmMetrics.requestsServiceOverloadedTotal.add(1, ordering: .relaxed)
            throw RateLimitError.serviceOverloaded
        }
        let params = try req.query.decode(S3List.ListV2Query.self)
        let localOnly = req.url.path == "/openmeteo-local" || req.url.path == "/openmeteo-local/"
        if params.apikey != nil || req.headers.first(name: .authorization) != nil {
            try authorizeReadRequest(req: req, apikey: params.apikey)
            return try await params.makeResponse(client: req.application.dedicatedHttpClient, logger: req.logger, localOnly: localOnly)
        } else {
            return try await req.withFreeApiRateLimiter() { _ in
                try validateAllowedReferer(req)
                return (1, try await params.makeResponse(client: req.application.dedicatedHttpClient, logger: req.logger, localOnly: localOnly))
            }
        }
    }
    
    /// Serve static files
    func get(_ req: Request) async throws -> Response {
        OmMetrics.requestsS3ApiTotal.add(1, ordering: .relaxed)
        guard OmMetrics.requestsRunning.load(ordering: .relaxed) <= RateLimiter.concurrencyLimitTotal else {
            OmMetrics.requestsServiceOverloadedTotal.add(1, ordering: .relaxed)
            throw RateLimitError.serviceOverloaded
        }
        guard req.url.path.hasPrefix("/"), req.url.path.hasSuffix("/") == false, req.url.path.onlyContainsAlphanumericDashSlashDot else {
            throw S3ApiError.forbidden
        }
        let isJson = req.url.path.hasSuffix(".json")
        let localOnly = req.url.path.hasPrefix("/openmeteo-local/")
        
        let mediaType = isJson ? HTTPMediaType.json : .binary
        if req.headers.first(name: .host) == "data-spatial.open-meteo.com" {
            return try await req.withFreeApiRateLimiter(fn: { _ in
                try validateAllowedReferer(req)
                let path = String(req.url.path.dropFirst(1))
                guard path.hasPrefix("data_spatial/") else {
                    throw S3ApiError.forbidden
                }
                guard let file = try await OmFileSystemManager.instance.getFile(path: path, client: req.application.dedicatedHttpClient, logger: req.logger, localOnly: localOnly) else {
                    throw CurlError.fileNotFound
                }
                return (1, try await req.asyncStreamFile(file: file, mediaType: mediaType))
            })
        }
        let params = try req.query.decode(DownloadParams.self)
        let path = String(req.url.path.dropFirst(1).dropPrefix("openmeteo/").dropPrefix("openmeteo-local/"))
        
        if !isJson {
            try authorizeReadRequest(req: req, apikey: params.apikey)
        }
        
        guard let file = try await OmFileSystemManager.instance.getFile(path: path, client: req.application.dedicatedHttpClient, logger: req.logger, localOnly: localOnly) else {
            throw CurlError.fileNotFound
        }
        return try await req.asyncStreamFile(file: file, mediaType: mediaType)
    }
    
    func putObject(_ req: Request) async throws -> Response {
        guard let body = req.body.data else {
            throw S3ApiError.expectedBodyPayload
        }
        try verifyRequestSignature(req: req, body: body, isRead: false)
        struct Params: Codable {
            let uploadId: Int?
            let partNumber: Int?
        }
        let query = try req.query.decode(Params.self)
        if let uploadId = query.uploadId, let part = query.partNumber {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw S3ApiError.invalidUploadId
            }
            guard part >= 1, part <= Self.uploadMaximumFileSize / Self.multipartChunkSize else {
                throw S3ApiError.invalidPartNumber
            }
            guard let absolutePath = resolveObjectPath(req.url.path) else {
                throw S3ApiError.forbidden
            }
            try await writeMultipartPart(absolutePath: absolutePath, uploadId: uploadId, partNumber: part, body: body)
            try await replicateMultipartPart(req: req, uploadId: uploadId, partNumber: part, body: body)
            return makeUploadPartResponse(body: body)
        }
        
        try await uploadSinglePut(req: req, body: body)
        return Response(status: .ok)
    }
    
    func postObject(_ req: Request) async throws -> Response {
        let body = req.body.data
        try verifyRequestSignature(req: req, body: body ?? ByteBuffer(), isRead: false)
        struct Params: Codable {
            let uploadId: Int?
            let partNumber: Int?
        }
        
        if req.url.query == "uploads" {
            let prepared = try await initiateMultipartUpload(req)
            try await replicateMultipartInitiate(req: req, uploadId: prepared.uploadId, fileSize: prepared.fileSize)
            return prepared.response
        }
        
        let query = try req.query.decode(Params.self)
        if let uploadId = query.uploadId, let part = query.partNumber {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw S3ApiError.invalidUploadId
            }
            guard let body else {
                throw S3ApiError.expectedBodyPayload
            }
            guard part >= 1, part <= Self.uploadMaximumFileSize / Self.multipartChunkSize else {
                throw S3ApiError.invalidPartNumber
            }
            guard let absolutePath = resolveObjectPath(req.url.path) else {
                throw S3ApiError.forbidden
            }
            try await writeMultipartPart(absolutePath: absolutePath, uploadId: uploadId, partNumber: part, body: body)
            try await replicateMultipartPart(req: req, uploadId: uploadId, partNumber: part, body: body)
            return makeUploadPartResponse(body: body)
        }
        
        if let uploadId = query.uploadId {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw S3ApiError.invalidUploadId
            }
            guard let absolutePath = resolveObjectPath(req.url.path) else {
                throw S3ApiError.forbidden
            }
            guard let body else {
                throw S3ApiError.expectedCompletionXMLBody
            }
            let modifiedDate = try req.headers.getXAmzMetaMtime() ?? req.headers.first(name: "x-last-modified")?.parseLastModifiedDate() ?? .now()
            try await validateMultipartCompletionBody(absolutePath: absolutePath, uploadId: uploadId, body: body)
            try await replicateMultipartComplete(req: req, uploadId: uploadId, body: body, lastModified: modifiedDate)
            try await finalizeMultipartUpload(req: req, absolutePath: absolutePath, uploadId: uploadId, lastModified: modifiedDate)
            return Response(status: .ok)
        }
        
        throw S3ApiError.unsupportedPostOperation
    }
    
    func deleteObject(_ req: Request) async throws -> Response {
        try verifyRequestSignature(req: req, body: ByteBuffer(), isRead: false)
        struct Params: Codable {
            let uploadId: Int
        }
        let query = try req.query.decode(Params.self)
        let uploadId = query.uploadId
        guard Self.uploadIdRange.contains(uploadId) else {
            throw S3ApiError.invalidUploadId
        }
        guard let absolutePath = resolveObjectPath(req.url.path) else {
            throw S3ApiError.forbidden
        }
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        _ = try await FileSystem.shared.removeItem(at: FilePath(tempPath))
        try await replicateAbort(req: req, uploadId: uploadId)
        return Response(status: .noContent)
    }
    
    private func uploadSinglePut(req: Request, body: ByteBuffer) async throws {
        guard let absolutePath = resolveObjectPath(req.url.path) else {
            throw S3ApiError.forbidden
        }
        let uploadId = Int.random(in: Self.uploadIdRange)
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        
        try await ensureParentDirectoryExists(forFileAt: absolutePath)
        let modifiedDate = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .newFile(replaceExisting: true)) { handle in
            try await handle.resize(to: .bytes(Int64(body.readableBytes)))
            try await handle.write(contentsOf: body, toAbsoluteOffset: 0)
            
            let modifiedDate = try req.headers.getXAmzMetaMtime() ?? req.headers.first(name: "x-last-modified")?.parseLastModifiedDate() ?? .now()
            let ts = FileInfo.Timespec(seconds: Int(modifiedDate.timeIntervalSince1970), nanoseconds: 0)
            try await handle.setLastDataModificationTime(to: ts)
            return modifiedDate
        }
        try await replicateSinglePut(req: req, body: body, lastModified: modifiedDate)
        try await FileSystem.shared.moveItem(at: FilePath(tempPath), to: FilePath(absolutePath))
        
        /// Full path `/somedir/object.ext`
        let path = req.url.path
        /// Object directory `somedir/`
        let objectDirectory = path.lastIndex(of: "/").map { String(path[path.index(after: path.startIndex) ... $0]) } ?? ""
        await OmFileSystemManager.instance.updateLocalDirectory(path: objectDirectory)
        
        for queue in await lazyReplicationQueues(req) {
            await queue.upload(buffer: body, objectName: String(path.dropFirst(1)), contentType: req.headers.first(name: "content-type") ?? "application/octet-stream", lastModified: modifiedDate)
        }
    }
    
    private struct MultipartInitPrepared {
        let response: Response
        let absolutePath: String
        let uploadId: Int
        let fileSize: Int64
    }
    
    private func initiateMultipartUpload(_ req: Request) async throws -> MultipartInitPrepared {
        guard let absolutePath = resolveObjectPath(req.url.path) else {
            throw S3ApiError.forbidden
        }
        guard let fileSizeRaw = req.headers.first(name: "x-file-size"),
              let fileSize = Int64(fileSizeRaw), fileSize >= 0, fileSize <= Self.uploadMaximumFileSize else {
            throw S3ApiError.missingOrInvalidFileSizeHeader
        }
        let uploadId: Int
        if let customUploadId = req.headers.first(name: "x-upload-id") {
            guard let id = Int(customUploadId), Self.uploadIdRange.contains(id) else {
                throw S3ApiError.invalidUploadId
            }
            uploadId = id
        } else {
            uploadId = Int.random(in: Self.uploadIdRange)
        }
        
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        try await ensureParentDirectoryExists(forFileAt: absolutePath)
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .newFile(replaceExisting: true)) { handle in
            try await handle.resize(to: .bytes(fileSize))
        }
        
        let responseBody = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <InitiateMultipartUploadResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">
            <Bucket>openmeteo</Bucket>
            <Key>\(req.url.path)</Key>
            <UploadId>\(uploadId)</UploadId>
        </InitiateMultipartUploadResult>
        """
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return MultipartInitPrepared(
            response: Response(status: .ok, headers: headers, body: .init(string: responseBody)),
            absolutePath: absolutePath,
            uploadId: uploadId,
            fileSize: fileSize
        )
    }
    
    private func writeMultipartPart(absolutePath: String, uploadId: Int, partNumber: Int, body: ByteBuffer) async throws {
        guard body.readableBytes <= Self.multipartChunkSize else {
            throw S3ApiError.chunkSizeExceeds8MB
        }
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .modifyFile(createIfNecessary: false)) { handle in
            let tempInfo = try await handle.fileHandle.info()
            
            let offset = Int64(partNumber - 1) * Int64(Self.multipartChunkSize)
            let numParts = (Int(tempInfo.size) + Self.multipartChunkSize - 1) / Self.multipartChunkSize
            let isLastPart = partNumber == numParts
            guard isLastPart || body.readableBytes == Self.multipartChunkSize else {
                throw S3ApiError.partSizeNotChunkSize
            }
            guard offset + Int64(body.readableBytes) <= tempInfo.size else {
                throw S3ApiError.partExceedsAllocatedFileSize
            }
            try await handle.write(contentsOf: body, toAbsoluteOffset: offset)
        }
    }
    
    private func validateMultipartCompletionBody(absolutePath: String, uploadId: Int, body: ByteBuffer) async throws {
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        guard let completionXML = body.getString(at: body.readerIndex, length: body.readableBytes) else {
            throw S3ApiError.couldNotDecodeCompletionXML
        }
        let parts = try parseMultipartCompleteXML(completionXML)
        
        _ = try await FileSystem.shared.withFileHandle(forReadingAt: FilePath(tempPath)) { handle in
            let fileSize = try await handle.getFileSize()
            guard fileSize > 0 else {
                return
            }
            var partIndex = 0
            for try await chunk in handle.readChunks(chunkLength: .bytes(Int64(Self.multipartChunkSize))) {
                guard partIndex < parts.count else {
                    throw S3ApiError.invalidNumberOfParts
                }
                let part = parts[partIndex]
                guard part.partNumber == partIndex + 1 else {
                    throw S3ApiError.nonContiguousPartNumbers
                }
                let actualHash = chunk.readableBytesView.sha256Hex
                guard part.etagSha256.caseInsensitiveCompare(actualHash) == .orderedSame else {
                    throw S3ApiError.multipartPartHashMismatch
                }
                partIndex += 1
            }
            
            guard partIndex == parts.count else {
                throw S3ApiError.invalidNumberOfParts
            }
        }
    }
    
    private func finalizeMultipartUpload(req: Request, absolutePath: String, uploadId: Int, lastModified: Timestamp) async throws {
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        try await FileSystem.shared.moveItem(at: FilePath(tempPath), to: FilePath(absolutePath))
        try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(absolutePath), options: .modifyFile(createIfNecessary: false)) { handle in
            let ts = FileInfo.Timespec(seconds: Int(lastModified.timeIntervalSince1970), nanoseconds: 0)
            try await handle.setLastDataModificationTime(to: ts)
        }
        /// Full path `/somedir/object.ext`
        let path = req.url.path
        /// Object directory `somedir/`
        let objectDirectory = path.lastIndex(of: "/").map { String(path[path.index(after: path.startIndex) ... $0]) } ?? ""
        await OmFileSystemManager.instance.updateLocalDirectory(path: objectDirectory)
        
        for queue in await lazyReplicationQueues(req) {
            let session = queue.startMultiPartUploads()
            await session.uploadMultipart(file: absolutePath, objectName: String(path.dropFirst(1)), lastModified: lastModified)
            await queue.finishMultiPartUploads(session)
        }
    }
    
    private func parseMultipartCompleteXML(_ xml: String) throws -> [(partNumber: Int, etagSha256: Substring)] {
        guard let root = xml.xmlFirst("CompleteMultipartUpload") else {
            throw S3ApiError.invalidCompletionXML
        }
        return try root.xmlSection("Part").map { partSection in
            guard let partNumberString = partSection.xmlFirst("PartNumber"),
                  let etag = partSection.xmlFirst("ETag"),
                  let partNumber = Int(partNumberString), partNumber >= 1,
                  !etag.isEmpty else {
                throw S3ApiError.invalidCompletionXMLPart
            }
            return (partNumber, etag.trimmingQuotes())
        }
    }
    
    private func makeUploadPartResponse(body: ByteBuffer) -> Response {
        var headers = HTTPHeaders()
        headers.add(name: "ETag", value: "\(body.readableBytesView.sha256Hex)")
        return Response(status: .ok, headers: headers)
    }
    
    private func authorizeReadRequest(req: Request, apikey: String?) throws {
        if let apikey, Self.syncApiKeys.contains(where: { $0 == apikey }) {
            return
        }
        guard !self.readCredentials.isEmpty else {
            throw S3ApiError.invalidApiKey
        }
        try verifyRequestSignature(req: req, body: ByteBuffer(), isRead: true)
    }

    private func validateAllowedReferer(_ req: Request) throws {
        guard let host = req.getRefererHost() else {
            throw S3ApiError.forbidden
        }
        guard host == "localhost" || host == "open-meteo.com" || host.hasSuffix(".open-meteo.com") || host == "drizz.li" || host.hasSuffix(".maps-5aj.pages.dev") else {
            throw S3ApiError.forbidden
        }
    }
    
    private func verifyRequestSignature(req: Request, body: ByteBuffer, isRead: Bool) throws {
        let credentials = isRead ? self.readCredentials : self.uploadCredentials
        guard !credentials.isEmpty else {
            throw isRead ? S3ApiError.missingReadCredentials : S3ApiError.missingUploadCredentials
        }
        if let contentLength = req.headers.first(name: .contentLength) {
            guard let expectedBodySize = Int(contentLength), expectedBodySize == body.readableBytes else {
                throw S3ApiError.incompleteBodyPayload(expected: Int(contentLength), actual: body.readableBytes)
            }
        }
        let payloadHash = body.readableBytesView.sha256Hex
        let host = req.headers.first(name: .host) ?? req.headers.first(name: "Host")
        guard let host else {
            throw S3ApiError.missingHostHeader
        }
        let canonicalURL = "\(req.scheme)://\(host)\(req.url.string)"
        
        for credentials in credentials {
            let signer = AWSSigner(accessKey: credentials.accessKey, secretKey: credentials.secretKey, region: "us-west-2", service: "s3")
            do {
                try signer.verify(url: canonicalURL, method: req.method, headers: req.headers, payloadHashSha256: payloadHash)
                return
            } catch AWSSigner.SigningError.invalidAccessKey {
                continue
            }
        }
        throw S3ApiError.unknownAccessKey
    }
    
    private func ensureParentDirectoryExists(forFileAt path: String) async throws {
        let parent = path.removeLastPathComponent()
        try await FileSystem.shared.createDirectory(at: FilePath(String(parent)), withIntermediateDirectories: true)
    }
    
    private func activeReplicationServers(_ req: Request) async -> [S3BucketEndpoint] {
        if req.headers.first(name: "x-replication") == "false" {
            return []
        }
        return await req.application.s3UploadReplicationServer.activeServers()
    }
    
    private func lazyReplicationQueues(_ req: Request) async -> [S3UploadQueue] {
        /// Do not lazy replicate data_spatial to backend storage
        guard req.url.path.hasPrefix("/data_spatial") == false else {
            return []
        }
        if req.headers.first(name: "x-replication") == "false" {
            return []
        }
        guard let servers = Environment.get("S3_UPLOAD_LAZY_SERVERS") else {
            return []
        }
        return await req.application.s3SyncManager.getQueues(buckets: servers)
    }
    
    private func replicateSinglePut(req: Request, body: ByteBuffer, lastModified: Timestamp) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        guard let bodyHash = req.headers.first(name: "x-amz-content-sha256") else {
            throw S3ApiError.missingSha256HashHeader
        }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.uploadURL(remotePath: "\(req.url.path.dropFirst(1))"))
            request.method = .PUT
            request.body = .bytes(body)
            request.headers.add(name: "x-amz-content-sha256", value: bodyHash)
            request.headers.add(name: "x-replication", value: "false")
            if let contentType = req.headers.first(name: .contentType) {
                request.headers.add(name: .contentType, value: contentType)
            }
            request.headers.add(name: "x-amz-meta-mtime", value: "\(lastModified.timeIntervalSince1970)")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(5), timeoutPerRequest: .seconds(60))
        }
    }
    
    private func replicateMultipartInitiate(req: Request, uploadId: Int, fileSize: Int64) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.uploadURL(remotePath: "\(req.url.path.dropFirst(1))?uploads"))
            request.method = .POST
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            request.headers.add(name: "x-replication", value: "false")
            request.headers.add(name: "x-upload-id", value: "\(uploadId)")
            request.headers.add(name: "x-file-size", value: "\(fileSize)")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }
    
    private func replicateMultipartPart(req: Request, uploadId: Int, partNumber: Int, body: ByteBuffer) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        guard let bodyHash = req.headers.first(name: "x-amz-content-sha256") else {
            throw S3ApiError.missingSha256HashHeader
        }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.uploadURL(remotePath: "\(req.url.path.dropFirst(1))?partNumber=\(partNumber)&uploadId=\(uploadId)"))
            request.method = .PUT
            request.body = .bytes(body)
            request.headers.add(name: "x-amz-content-sha256", value: bodyHash)
            request.headers.add(name: "x-replication", value: "false")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(5), timeoutPerRequest: .seconds(60))
        }
    }
    
    private func replicateMultipartComplete(req: Request, uploadId: Int, body: ByteBuffer, lastModified: Timestamp) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        guard let bodyHash = req.headers.first(name: "x-amz-content-sha256") else {
            throw S3ApiError.missingSha256HashHeader
        }
        //let bodyLength = body.readableBytes
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.uploadURL(remotePath: "\(req.url.path.dropFirst(1))?uploadId=\(uploadId)"))
            request.method = .POST
            request.body = .bytes(body)
            request.headers.add(name: "x-amz-content-sha256", value: bodyHash)
            request.headers.add(name: "x-replication", value: "false")
            request.headers.add(name: .contentType, value: "application/xml")
            request.headers.add(name: "x-amz-meta-mtime", value: "\(lastModified.timeIntervalSince1970)")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }
    
    private func replicateAbort(req: Request, uploadId: Int) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.uploadURL(remotePath: "\(req.url.path.dropFirst(1))?uploadId=\(uploadId)"))
            request.method = .DELETE
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            request.headers.add(name: "x-replication", value: "false")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }
    
    private func tempUploadPath(finalPath: String, uploadId: Int) -> String {
        return "\(finalPath).\(uploadId)~"
    }
    
    /// Get absolute object path for local storage
    private func resolveObjectPath(_ path: String) -> String? {
        guard !path.isEmpty,
              path.first == "/",
              path.last != "/",
              !path.contains(".."),
              !path.contains("//"),
              path.onlyContainsAlphanumericDashSlashDot else {
            return nil
        }
        let directory: Substring
        if path.starts(with: "/data/") {
            directory = OpenMeteo.dataDirectory.dropLast("/data/".count)
        } else if path.starts(with: "/data_run/") {
            directory = (OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_run")).dropLast("/data_run/".count)
        } else if path.starts(with: "/data_spatial/") {
            directory = (OpenMeteo.dataSpatialDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_spatial")).dropLast("/data_spatial/".count)
        } else {
            return nil
        }
        return "\(directory)\(path)"
    }
}

extension Request {
    /// Get the `Referer` header and extract the hostname if available
    func getRefererHost() -> Substring? {
        guard let referer = headers.first(name: .referer) else {
            return nil
        }
        guard let schemeRange = referer.range(of: "http://") ?? referer.range(of: "https://") else {
            return nil
        }
        let hostStart = schemeRange.upperBound
        guard hostStart < referer.endIndex else {
            return nil
        }
        let hostEnd = referer[hostStart...].firstIndex(where: { $0 == "/" || $0 == ":" }) ?? referer.endIndex
        guard hostStart < hostEnd else {
            return nil
        }
        return referer[hostStart..<hostEnd]
    }
}

extension S3List.ListV2Query {
    func makeResponse(client: HTTPClient, logger: Logger, localOnly: Bool) async throws -> Response {
        let path = self.prefix
        guard self.list_type == 2, self.delimiter == "/", path.hasPrefix("/") == false, (path == "" || path.hasSuffix("/") == true), path.onlyContainsAlphanumericDashSlashDot else {
            throw S3ApiError.forbidden
        }
        guard let directory = try await OmFileSystemManager.instance.getDirectoryContents(path: path, client: client, logger: logger, localOnly: localOnly) else {
            throw S3ApiError.forbidden
        }
        // eTag uses "timestamp-filesize" for local files
        let filesXml = directory.files.map { (name, attr) in
            let eTag = "\(Int(attr.0.timeIntervalSince1970))-\(attr.1)"
            return """
            <Contents>
                <Key>\(path)\(name)</Key>
                <LastModified>\(attr.0.s3ListXmlDateFormat)</LastModified>
                <Size>\(attr.1)</Size>
                <ETag>&quot;\(eTag)&quot;</ETag>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            """
        }.joined(separator: "\n")
        
        let directoriesXml = directory.directories.map {
            """
            <CommonPrefixes>
            <Prefix>\(path)\($0)/</Prefix>
            </CommonPrefixes>
            """
        }.joined(separator: "\n")
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return Response(status: .ok, headers: headers, body: .init(string: """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Name>openmeteo</Name>
            <Prefix>\(path)</Prefix>
            <KeyCount>\(directory.directories.count + directory.files.count)</KeyCount>
            <MaxKeys>1000</MaxKeys>
            <Delimiter>/</Delimiter>
            <IsTruncated>false</IsTruncated>
            \(directoriesXml)
            \(filesXml)
        </ListBucketResult>
        """))
    }
}

extension StringProtocol {
    /// Formats from: "EEE, dd MMM yyyy HH:mm:ss GMT".. like `Wed, 19 Aug 2026 09:38:00 GMT`
    func parseLastModifiedDate() throws -> Timestamp {
        guard self.count == 29 else {
            throw TimeError.InvalidDateFromat
        }
        guard let day = Int(self[5..<7]), day >= 1, day <= 31 else {
            throw TimeError.InvalidDate
        }
        let month: Int
        switch self[8..<11] {
        case "Jan": month = 1
        case "Feb": month = 2
        case "Mar": month = 3
        case "Apr": month = 4
        case "May": month = 5
        case "Jun": month = 6
        case "Jul": month = 7
        case "Aug": month = 8
        case "Sep": month = 9
        case "Oct": month = 10
        case "Nov": month = 11
        case "Dec": month = 12
        default: throw TimeError.InvalidDate
        }
        guard let year = Int(self[12..<16]), year >= 1900, year <= 2200 else {
            throw TimeError.InvalidDate
        }
        guard let hour = Int(self[17..<19]), hour >= 0, hour <= 23 else {
            throw TimeError.InvalidDate
        }
        guard let minute = Int(self[20..<22]), minute >= 0, minute <= 59 else {
            throw TimeError.InvalidDate
        }
        guard let second = Int(self[23..<25]), second >= 0, second <= 59 else {
            throw TimeError.InvalidDate
        }
        guard self[25..<29] == " GMT" else {
            throw TimeError.InvalidDate
        }
        return Timestamp(year, month, day, hour, minute, second)
    }
    
    /// Formats from: "EEE, dd MMM yyyy HH:mm:ss GMT".. like `2026-08-19T09:38:00.000Z`
    func parseXmlS3Date() throws -> Timestamp {
        let str = self
        guard str.count == 24 else {
            throw TimeError.InvalidDateFromat
        }
        guard let year = Int(str[0..<4]), year >= 1900, year <= 2200 else {
            throw TimeError.InvalidDate
        }
        guard let month = Int(str[5..<7]), month >= 1, month <= 12 else {
            throw TimeError.InvalidDate
        }
        guard let day = Int(str[8..<10]), day >= 1, day <= 31 else {
            throw TimeError.InvalidDate
        }
        guard let hour = Int(str[11..<13]), hour >= 0, hour <= 23 else {
            throw TimeError.InvalidDate
        }
        guard let minute = Int(str[14..<16]), minute >= 0, minute <= 59 else {
            throw TimeError.InvalidDate
        }
        guard let second = Int(str[17..<19]), second >= 0, second <= 59 else {
            throw TimeError.InvalidDate
        }
        return Timestamp(year, month, day, hour, minute, second)
    }
}

extension Timestamp {
    var lastModifiedHttpDateFormat: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        
        // HTTP days of the week (0 = Sunday)
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let wdayStr = days[Int(t.tm_wday)]
        
        // HTTP months (0 = January)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthStr = months[Int(t.tm_mon)]
        
        let day = Int(t.tm_mday).zeroPadded(len: 2)
        let year = Int(t.tm_year + 1900)
        let hour = Int(t.tm_hour).zeroPadded(len: 2)
        let minute = Int(t.tm_min).zeroPadded(len: 2)
        let second = Int(t.tm_sec).zeroPadded(len: 2)
        
        // Formats to: "EEE, dd MMM yyyy HH:mm:ss GMT"
        return "\(wdayStr), \(day) \(monthStr) \(year) \(hour):\(minute):\(second) GMT"
    }
    
    /// Format dates like `2023-11-14T04:32:17.000Z`
    var s3ListXmlDateFormat: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year + 1900)
        let month = Int(t.tm_mon + 1)
        let day = Int(t.tm_mday)
        let hour = Int(t.tm_hour)
        let minute = Int(t.tm_min)
        let second = Int(t.tm_sec)
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2)):\(second.zeroPadded(len: 2)).000Z"
    }
}

enum S3ApiError: AbortError, Equatable {
    case invalidApiKey
    case forbidden
    case expectedBodyPayload
    case incompleteBodyPayload(expected: Int?, actual: Int)
    case invalidUploadId
    case invalidPartNumber
    case expectedCompletionXMLBody
    case unsupportedPostOperation
    case missingOrInvalidFileSizeHeader
    case chunkSizeExceeds8MB
    case partExceedsAllocatedFileSize
    case partSizeNotChunkSize
    case couldNotDecodeCompletionXML
    case invalidNumberOfParts
    case nonContiguousPartNumbers
    case multipartPartHashMismatch
    case invalidCompletionXML
    case invalidCompletionXMLPart
    case missingReadCredentials
    case missingUploadCredentials
    case missingHostHeader
    case missingSha256HashHeader
    case invalidRequestSignature
    case unknownAccessKey
    case invalidXAmzMetaMtimeHeaderValue
    
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .invalidApiKey:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .missingReadCredentials, .missingUploadCredentials:
            return .serviceUnavailable
        case .missingHostHeader, .invalidRequestSignature, .unknownAccessKey:
            return .unauthorized
        case .incompleteBodyPayload:
            return .requestTimeout
        default:
            return .badRequest
        }
    }
    
    var reason: String {
        switch self {
        case .invalidApiKey:
            return "Invalid API key"
        case .forbidden:
            return "Forbidden"
        case .expectedBodyPayload:
            return "Expected body payload"
        case .incompleteBodyPayload(let expected, let actual):
            let expectedDescription = expected.map(String.init) ?? "a valid Content-Length"
            return "Incomplete body payload: expected \(expectedDescription) bytes, received \(actual)"
        case .invalidUploadId:
            return "Invalid uploadId"
        case .invalidPartNumber:
            return "Invalid partNumber"
        case .expectedCompletionXMLBody:
            return "Expected completion XML body"
        case .unsupportedPostOperation:
            return "Unsupported POST operation"
        case .missingOrInvalidFileSizeHeader:
            return "Missing or invalid x-file-size header"
        case .chunkSizeExceeds8MB:
            return "Chunk size exceeds 8MB"
        case .partExceedsAllocatedFileSize:
            return "Part exceeds allocated file size"
        case .partSizeNotChunkSize:
            return "Part size must be equal to chunk size"
        case .couldNotDecodeCompletionXML:
            return "Could not decode completion XML"
        case .invalidNumberOfParts:
            return "Invalid number of parts"
        case .nonContiguousPartNumbers:
            return "Part numbers must be contiguous and start at 1"
        case .multipartPartHashMismatch:
            return "Multipart part hash mismatch"
        case .invalidCompletionXML:
            return "Invalid completion XML"
        case .invalidCompletionXMLPart:
            return "Invalid completion XML part"
        case .missingReadCredentials:
            return "No read credentials configured"
        case .missingUploadCredentials:
            return "No upload credentials configured"
        case .missingHostHeader:
            return "Missing Host header"
        case .missingSha256HashHeader:
            return "Missing SHA256 hash header"
        case .invalidRequestSignature:
            return "Invalid request signature"
        case .unknownAccessKey:
            return "Unknown access key"
        case .invalidXAmzMetaMtimeHeaderValue:
            return "Invalid x-amz-meta-mtime header value"
        }
    }
}

extension StringProtocol {
    func trimmingWhitespace() -> Self.SubSequence {
        var start = startIndex
        while start < endIndex && self[start].isWhitespace {
            formIndex(after: &start)
        }
        var end = endIndex
        while end > start {
            let before = index(before: end)
            if !self[before].isWhitespace {
                break
            }
            end = before
        }
        return self[start..<end]
    }
    
    func trimmingQuotes() -> Self.SubSequence {
        var start = startIndex
        while start < endIndex && self[start] == "\"" {
            formIndex(after: &start)
        }
        var end = endIndex
        while end > start {
            let before = index(before: end)
            if self[before] != "\"" {
                break
            }
            end = before
        }
        return self[start..<end]
    }
}

extension String {
    /// Only contains A-Z, a-z, 0-9, _, and -
    var onlyContainsAlphanumericAndDash: Bool {
        for byte in self.utf8 {
            let isUpperAZ = byte >= 65 && byte <= 90
            let isLowerAZ = byte >= 97 && byte <= 122
            let isDigit = byte >= 48 && byte <= 57
            let isAllowedSymbol = byte == 95 || byte == 45 // _ or -
            guard isUpperAZ || isLowerAZ || isDigit || isAllowedSymbol else {
                return false
            }
        }
        return true
    }
    
    /// Only contains A-Z, a-z, 0-9, _, -  / and .
    var onlyContainsAlphanumericDashSlashDot: Bool {
        for byte in self.utf8 {
            let isUpperAZ = byte >= 65 && byte <= 90
            let isLowerAZ = byte >= 97 && byte <= 122
            let isDigit = byte >= 48 && byte <= 57
            let isAllowedSymbol = byte == 95 || byte == 45 || byte == 47 || byte == 46 // _ or - or / or .
            guard isUpperAZ || isLowerAZ || isDigit || isAllowedSymbol else {
                return false
            }
        }
        return true
    }
    
    func removeLastPathComponent() -> Substring {
        let baseEnd = self.hasSuffix("/") ? self.index(before: self.endIndex) : self.endIndex
        guard let slashPos = self[..<baseEnd].lastIndex(of: "/") else {
            return Substring(self)
        }
        return self[..<slashPos]
    }
    
    func replacingLastPathComponent(with component: String) -> String {
        return "\(self.removeLastPathComponent())/\(component)/"
    }
    
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension StringProtocol {
    func dropPrefix(_ prefix: String) -> some StringProtocol {
        if self.starts(with: prefix) {
            return self.dropFirst(prefix.count)
        }
        return self[...]
    }
}

extension Request {
    func asyncStreamFile(
        file: OmFileSystemManager.FileType,
        chunkSize: Int = NonBlockingFileIO.defaultChunkSize,
        mediaType: HTTPMediaType,
        onCompleted: @escaping @Sendable (Result<Void, Error>) async throws -> () = { _ in }
    ) async throws -> Response {
        let request = self
        // Get file attributes for this file.
//        guard let fileInfo = try await FileSystem.shared.info(forFileAt: .init(path)) else {
//            throw Abort(.internalServerError)
//        }

        let contentRange: HTTPHeaders.Range?
        if let rangeFromHeaders = request.headers.range {
            if rangeFromHeaders.unit == .bytes && rangeFromHeaders.ranges.count == 1 {
                contentRange = rangeFromHeaders
            } else {
                contentRange = nil
            }
        } else if request.headers.contains(name: .range) {
            // Range header was supplied but could not be parsed i.e. it was invalid
            request.logger.debug("Range header was provided in request but was invalid")
            throw Abort(.badRequest)
        } else {
            contentRange = nil
        }

        // Generate ETag value, "last modified date in epoch time" + "-" + "file size"
        let eTag = "\"\(file.modificationTimestamp.timeIntervalSince1970)-\(file.size)\""
        
        // Create empty headers array.
        var headers: HTTPHeaders = [:]

        // Respond with lastModified header
        headers.replaceOrAdd(name: .lastModified, value: file.modificationTimestamp.lastModifiedHttpDateFormat)

        headers.replaceOrAdd(name: .eTag, value: eTag)
        headers.contentType = mediaType
        
        /// Disable response compression for HEAD requests, content range and non JSON request
        if self.method == .HEAD || contentRange != nil || mediaType != .json {
            headers.responseCompression = .disable
        }

        // Check if file has been cached already and return NotModified response if the etags match
        if eTag == request.headers.first(name: .ifNoneMatch) {
            // Per RFC 9110 here: https://www.rfc-editor.org/rfc/rfc9110.html#status.304
            // and here: https://www.rfc-editor.org/rfc/rfc9110.html#name-content-encoding
            // A 304 response MUST include the ETag header and a Content-Length header matching what the original resource's content length would have been were this a 200 response.
            headers.replaceOrAdd(name: .contentLength, value: file.size.description)
            return Response(status: .notModified, version: .http1_1, headersNoUpdate: headers, body: .empty)
        }
        
        // Ensure that file has NOT been modified
        if let ifMatch = request.headers.first(name: .ifMatch), eTag != ifMatch {
            headers.replaceOrAdd(name: .contentLength, value: file.size.description)
            headers.replaceOrAdd(name: .eTag, value: eTag)
            return Response(status: .preconditionFailed, version: .http1_1, headersNoUpdate: headers, body: .empty)
        }
        
        // Check `If-Unmodified-Since` header and return precondition failed if modified
        if let ifUnmodifiedSince = try request.headers.first(name: .ifUnmodifiedSince)?.parseLastModifiedDate() {
            guard ifUnmodifiedSince >= file.modificationTimestamp else {
                return Response(status: .preconditionFailed, version: .http1_1, headersNoUpdate: headers, body: .empty)
            }
        }

        // Create the HTTP response.
        let response = Response(status: .ok, headers: headers)
        let offset: Int64
        let byteCount: Int
        if let contentRange = contentRange {
            response.status = .partialContent
            response.headers.add(name: .accept, value: contentRange.unit.serialize())
            if let firstRange = contentRange.ranges.first {
                do {
                    let range = try firstRange.asResponseContentRange(limit: Int(file.size))
                    response.headers.contentRange = HTTPHeaders.ContentRange(unit: contentRange.unit, range: range)
                    (offset, byteCount) = try firstRange.asByteBufferBounds(withMaxSize: Int(file.size), logger: request.logger)
                } catch {
                    throw Abort(.badRequest)
                }
            } else {
                offset = 0
                byteCount = Int(file.size)
            }
        } else {
            offset = 0
            byteCount = Int(file.size)
        }
                
        switch file {
        case .local(let fileEntry):
            // Read file from disk using the open file handle and SwiftNIO async reader
            response.body = .init(asyncStream: { stream in
                // TODO: `SystemFileHandle(takingOwnershipOf:` is used from testing SPI. Maybe not ideal
                let handle = SystemFileHandle(takingOwnershipOf: FileDescriptor(rawValue: fileEntry.fd.fileDescriptor), path: "", materialization: nil, threadPool: .singleton)
                let chunks = handle.readChunks(in: offset..<(offset+Int64(byteCount)), chunkLength: .bytes(Int64(chunkSize)))
                do {
                    for try await chunk in chunks {
                        try await stream.writeBuffer(chunk)
                    }
                    let _ = try handle.detachUnsafeFileDescriptor()
                    try await stream.write(.end)
                    try await onCompleted(.success(()))
                } catch {
                    let _ = try? handle.detachUnsafeFileDescriptor()
                    try? await stream.write(.error(error))
                    try await onCompleted(.failure(error))
                }
            }, count: byteCount, byteBufferAllocator: request.byteBufferAllocator)
        case .remote(let cached):
            // Return cached data or stream from network
            response.body = .init(asyncStream: { stream in
                do {
                    let end = offset + Int64(byteCount)
                    for block in offset / Int64(chunkSize) ..< (offset + Int64(byteCount)).divideRoundedUp(divisor: Int64(chunkSize)) {
                        let blockStart = block * Int64(chunkSize)
                        let blockEnd = min(file.size, (block+1)*Int64(chunkSize))
                        let readOffset = max(offset, blockStart)
                        let readEnd = min(end, blockEnd)
                        let chunk = try await cached.getByteBuffer(offset: Int(readOffset), count: Int(readEnd - readOffset))
                        try await stream.writeBuffer(chunk)
                    }
                    try await stream.write(.end)
                    try await onCompleted(.success(()))
                } catch {
                    try? await stream.write(.error(error))
                    try await onCompleted(.failure(error))
                }
            }, count: byteCount, byteBufferAllocator: request.byteBufferAllocator)
        }
        return response
    }
}

extension HTTPHeaders {
    /// rclone encodes modification time in `x-amz-meta-mtime` as a floating point seconds past epoch
    /// Nil is header is not set, throws is malformated
    func  getXAmzMetaMtime() throws -> Timestamp? {
        guard let seconds = self.first(name: "x-amz-meta-mtime") else {
            return nil
        }
        guard let seconds = Double(seconds) else {
            throw S3ApiError.invalidXAmzMetaMtimeHeaderValue
        }
        return Timestamp(Int(seconds))
    }
}

extension HTTPHeaders.Range.Value {
    
    fileprivate func asByteBufferBounds(withMaxSize size: Int, logger: Logger) throws -> (offset: Int64, byteCount: Int) {
        switch self {
            case .start(let value):
                guard value <= size, value >= 0 else {
                    logger.debug("Requested range start was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(value), byteCount: size - value)
            case .tail(let value):
                guard value <= size, value >= 0 else {
                    logger.debug("Requested range end was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(size - value), byteCount: value)
            case .within(let start, let end):
                guard start >= 0, end >= 0, start <= end, start <= size, end <= size else {
                    logger.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                let (byteCount, overflow) =  (end - start).addingReportingOverflow(1)
                guard !overflow else {
                    logger.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(start), byteCount: byteCount)
        }
    }
}
