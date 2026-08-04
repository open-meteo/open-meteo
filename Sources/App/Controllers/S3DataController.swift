import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import NIOFileSystem

/**
 Expose database as S3 endpoint. This can be used to pull data from one server to another. It is used only internally to transfer data between Open-Meteo API nodes. Note: This is only a limited implementation and not fully compatible.
 
 List example:
 `http://127.0.0.1:8080/?list-type=2&delimiter=/&prefix=data/cmc_gem_gdps/shortwave_radiation/&apikey=123`
 
 Download exmaple
 `http://127.0.0.1:8080/data/cmc_gem_gdps/shortwave_radiation/chunk_1430.om?apikey=123`
 
 Nginx setting:
 ```
 location /data-internal {
 internal;
 alias /var/lib/openmeteo-api/data;
 }
 ```
 
 If `S3_READ_CREDENTIALS` is set to "key1:secret1,key2:secret2" the list and download endpoints accept AWS SigV4 signed GET requests in addition to API keys.
 
 If `S3_UPLOAD_CREDENTIALS` is set to "key1:secret1,key2:secret2" the endpoints accepts file uploads using S3 multi part uploads. The upload is non standard, meaning that additional headers for the final file size must be set. E.g. AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
 
 If `S3_UPLOAD_REPLICATION_SERVERS` is set to "s3://key1:secret1@server1.tld/,s3://key1:secret1@server2.tld/" all uploads are replicated to those servers. Servers are checked every couple of seconds. If offline, they are ignored. Also non standard S3 implementation. Used to replicate uploads to a fail-over server in realtime. If the server is available. This is a blocking operation.
 
 If `S3_UPLOAD_LAZY_SERVERS` is set to "s3://key1:secret1@server1.tld/,s3://key1:secret1@server2.tld/" all uploads are lazily replicated to those servers after the sync replication completed. Used to upload data to large S3 storage servers afterwards
 */
struct S3DataController: RouteCollection {
    static let syncApiKeys: [String.SubSequence] = Environment.get("API_SYNC_APIKEYS")?.split(separator: ",") ?? []
    static let nginxSendfilePrefix = Environment.get("NGINX_SENDFILE_PREFIX")
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
            routes.on(.HEAD, [], use: self.headRoot)
            routes.get("", use: self.list)
            routes.get("data", "**", use: self.get)
            routes.get("data_run", "**", use: self.get)
            routes.get("data_spatial", "**", use: self.get)
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
        /// in megabytes per second
        let rate: Int?
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
        try authorizeReadRequest(req: req, apikey: params.apikey)
        
        let path = params.prefix
        guard params.list_type == 2, params.delimiter == "/" else {
            throw S3ApiError.forbidden
        }
        guard let absoluteDirectoryPath = resolveListPath(path) else {
            throw S3ApiError.forbidden
        }
        
        let pathUrl = URL(fileURLWithPath: absoluteDirectoryPath, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            throw S3ApiError.forbidden
        }
        
        var files = [S3List.ListV2File]()
        var directories = [String]()
        /// Note: Maybe at some point a async version of the directory enumerator should be used.
        /// https://forums.swift.org/t/xcode-16-3-cant-use-makeiterator-via-filemanagers-enumerator-at-in-async-function/78976
        for case let fileURL as URL in AnySequence(directoryEnumerator) {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name,
                  !name.contains("~")
            else {
                continue
            }
            if isDirectory {
                directories.append(name)
            } else {
                guard let modificationTime = resourceValues.contentModificationDate,
                      let fileSize = resourceValues.fileSize
                else {
                    continue
                }
                files.append(S3List.ListV2File(name: name, modificationTime: modificationTime, fileSize: fileSize))
            }
        }
        
        let dateFormat = DateFormatter.awsS3DateTime
        let filesXml = files.map {
            """
            <Contents>
                <Key>\(path)\($0.name)</Key>
                <LastModified>\(dateFormat.string(from: $0.modificationTime))</LastModified>
                <Size>\($0.fileSize)</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            """
        }.joined(separator: "\n")
        let directoriesXml = directories.map {
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
            <KeyCount>\(files.count + directories.count)</KeyCount>
            <MaxKeys>1000</MaxKeys>
            <Delimiter>/</Delimiter>
            <IsTruncated>false</IsTruncated>
            \(directoriesXml)
            \(filesXml)
        </ListBucketResult>
        """))
    }
    
    /// Serve file through nginx send file
    func get(_ req: Request) async throws -> Response {
        let params = try req.query.decode(DownloadParams.self)
        let path = req.url.path
        guard let absolutePath = resolveObjectPath(path) else {
            throw S3ApiError.forbidden
        }
        
        let isJson = path.hasSuffix(".json")
        if !isJson {
            try authorizeReadRequest(req: req, apikey: params.apikey)
        }
        
        guard let pathNoRoot = path.split(separator: "/").dropFirst().joined(separator: "/").nilIfEmpty else {
            throw S3ApiError.forbidden
        }
        
        if let nginxSendfilePrefix = Self.nginxSendfilePrefix {
            let response = Response()
            // let response = req.fileio.streamFile(at: abspath)
            response.headers.add(name: "X-Accel-Redirect", value: "/\(nginxSendfilePrefix)/\(pathNoRoot)")
            if let rate = params.rate {
                // Bytes per second download speed limit
                response.headers.add(name: "X-Accel-Limit-Rate", value: "\((rate) * 1024 * 1024)")
            }
            return response
        }
        /// TODO consider caching
        if let remote = OpenMeteo.remoteDataDirectory,
           let modelStr = pathNoRoot.firstIndex(of: "/").map({ pathNoRoot[..<$0] }),
           let _ = DomainRegistry(rawValue: String(modelStr))
        {
            var request = HTTPClientRequest(url: "\(remote)\(pathNoRoot)")
            try request.applyS3Credentials()
            let response = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger)
            let r = Response(status: response.status, body: .init(asyncStream: { writer in
                do {
                    for try await buffer in response.body {
                        try await writer.write(.buffer(buffer))
                    }
                    try await writer.write(.end)
                } catch {
                    try? await writer.write(.error(error))
                }
            }))
            r.headers.contentType = response.headers.contentType
            return r
        }
        let response = try await req.fileio.asyncStreamFile(at: absolutePath)
        return response
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
            try await validateMultipartCompletionBody(absolutePath: absolutePath, uploadId: uploadId, body: body)
            try await replicateMultipartComplete(req: req, uploadId: uploadId, body: body)
            try await finalizeMultipartUpload(req: req, absolutePath: absolutePath, uploadId: uploadId)
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
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .newFile(replaceExisting: true)) { handle in
            try await handle.resize(to: .bytes(Int64(body.readableBytes)))
            try await handle.write(contentsOf: body, toAbsoluteOffset: 0)
        }
        try await FileSystem.shared.replaceItem(at: FilePath(absolutePath), withItemAt: FilePath(tempPath))
        try await applyLastModifiedIfProvided(header: req.headers.first(name: "x-last-modified"), filePath: absolutePath)
        try await replicateSinglePut(req: req, body: body)
        
        for queue in await lazyReplicationQueues(req) {
            await queue.upload(buffer: body, objectName: String(req.url.path.dropFirst(1)), contentType: req.headers.first(name: "content-type") ?? "application/octet-stream")
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
        let tempInfo = try await FileSystem.shared.info(forFileAt: FilePath(tempPath))
        guard let tempInfo else {
            throw S3ApiError.multipartUploadNotFound
        }
        let offset = Int64(partNumber - 1) * Int64(Self.multipartChunkSize)
        print("S3ApiError.partExceedsAllocatedFileSize partNumber: \(partNumber), offset: \(offset), size: \(tempInfo.size), body: \(body.readableBytes), uploadId: \(uploadId) absolutePath: \(absolutePath)")
        guard offset + Int64(body.readableBytes) <= tempInfo.size else {
            throw S3ApiError.partExceedsAllocatedFileSize
        }
        
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .modifyFile(createIfNecessary: false)) { handle in
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
    
    private func finalizeMultipartUpload(req: Request, absolutePath: String, uploadId: Int) async throws {
        let tempPath = tempUploadPath(finalPath: absolutePath, uploadId: uploadId)
        try await FileSystem.shared.replaceItem(at: FilePath(absolutePath), withItemAt: FilePath(tempPath))
        try await applyLastModifiedIfProvided(header: req.headers.first(name: "x-last-modified"), filePath: absolutePath)
        
        for queue in await lazyReplicationQueues(req) {
            let session = queue.startMultiPartUploads()
            await session.uploadMultipart(file: absolutePath, objectName: String(req.url.path.dropFirst(1)))
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
    
    private func verifyRequestSignature(req: Request, body: ByteBuffer, isRead: Bool) throws {
        let credentials = isRead ? self.readCredentials : self.uploadCredentials
        guard !credentials.isEmpty else {
            throw isRead ? S3ApiError.missingReadCredentials : S3ApiError.missingUploadCredentials
        }
        let payloadHash = body.readableBytesView.sha256Hex
        let host = req.headers.first(name: .host) ?? req.headers.first(name: "Host")
        guard let host else {
            throw S3ApiError.missingHostHeader
        }
        let canonicalURL = "\(req.scheme)://\(host)\(req.url.string)"
        
        var hasMatchingAccessKey = false
        for credentials in credentials {
            let signer = AWSSigner(accessKey: credentials.accessKey, secretKey: credentials.secretKey, region: "us-west-2", service: "s3")
            do {
                try signer.verify(url: canonicalURL, method: req.method, headers: req.headers, payloadHashSha256: payloadHash)
                return
            } catch AWSSigner.SigningError.invalidAccessKey {
                continue
            } catch {
                hasMatchingAccessKey = true
            }
        }
        
        if hasMatchingAccessKey {
            throw S3ApiError.invalidRequestSignature
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
    
    private func replicateSinglePut(req: Request, body: ByteBuffer) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        let lastModified = req.headers.first(name: "x-last-modified")
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
            if let lastModified {
                request.headers.add(name: "x-last-modified", value: lastModified)
            }
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
    
    private func replicateMultipartComplete(req: Request, uploadId: Int, body: ByteBuffer) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        let lastModified = req.headers.first(name: "x-last-modified")
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
            if let lastModified {
                request.headers.add(name: "x-last-modified", value: lastModified)
            }
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
    
    private func resolveListPath(_ path: String) -> String? {
        guard !path.isEmpty,
              path.last == "/",
              !path.hasPrefix("/"),
              !path.contains("//"),
              !path.contains(".."),
              path.onlyContainsAlphanumericDashSlashDot else {
            return nil
        }
        let directory: Substring
        if path.starts(with: "data/") {
            directory = OpenMeteo.dataDirectory.dropLast("/data/".count)
        } else if path.starts(with: "data_run/") {
            directory = (OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_run")).dropLast("/data_run/".count)
        } else if path.starts(with: "data_spatial/") {
            directory = (OpenMeteo.dataSpatialDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_spatial")).dropLast("/data_spatial/".count)
        } else {
            return nil
        }
        return "\(directory)/\(path)"
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
    
    private func applyLastModifiedIfProvided(header: String?, filePath: String) async throws {
        guard let header, let date = Self.parseLastModifiedDate(header) else {
            return
        }
        let seconds = Int(date.timeIntervalSince1970)
        let nanoseconds = Int((date.timeIntervalSince1970 - Double(seconds)) * 1_000_000_000)
        let ts = FileInfo.Timespec(seconds: seconds, nanoseconds: max(0, nanoseconds))
        try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(filePath), options: .modifyFile(createIfNecessary: false)) { handle in
            try await handle.setLastDataModificationTime(to: ts)
        }
    }
    
    private static func parseLastModifiedDate(_ value: String) -> Date? {
        if let unix = Double(value) {
            return Date(timeIntervalSince1970: unix)
        }
        
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            return date
        }
        
        let rfc1123 = DateFormatter()
        rfc1123.locale = Locale(identifier: "en_US_POSIX")
        rfc1123.timeZone = TimeZone(secondsFromGMT: 0)
        rfc1123.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return rfc1123.date(from: value)
    }
}

enum S3ApiError: AbortError, Equatable {
    case invalidApiKey
    case forbidden
    case expectedBodyPayload
    case invalidUploadId
    case invalidPartNumber
    case expectedCompletionXMLBody
    case unsupportedPostOperation
    case missingOrInvalidFileSizeHeader
    case chunkSizeExceeds8MB
    case multipartUploadNotFound
    case partExceedsAllocatedFileSize
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
    
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .invalidApiKey:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .multipartUploadNotFound:
            return .notFound
        case .missingReadCredentials, .missingUploadCredentials:
            return .serviceUnavailable
        case .missingHostHeader, .invalidRequestSignature, .unknownAccessKey:
            return .unauthorized
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
        case .multipartUploadNotFound:
            return "Multipart upload not found"
        case .partExceedsAllocatedFileSize:
            return "Part exceeds allocated file size"
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

extension DateFormatter {
    /// Format dates like `2023-11-14T04:32:17.000Z`
    static let awsS3DateTime = {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "y-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormat
    }()
}
