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
 
 If S3_UPLOAD_CREDENTIALS is set to "key1:secret1,key2:secret2" the endpoints accepts file uploads using S3 multi part uploads. The upload is non standard, meaning that additional headers for the final file size must be set. E.g. AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
 
 If S3_UPLOAD_REPLICATION_SERVERS is set to "s3://key1:secret1@server1.tld/,s3://key1:secret1@server2.tld/," all uploads are replicated to those servers. Servers are checked every couple of seconds. If offline, they are ignored. Also non standard S3 implementation
 */
struct S3DataController: RouteCollection {
    static let syncApiKeys: [String.SubSequence] = Environment.get("API_SYNC_APIKEYS")?.split(separator: ",") ?? []
    static let nginxSendfilePrefix = Environment.get("NGINX_SENDFILE_PREFIX")
    static let uploadCredentials: [UploadCredential] = UploadCredential.loadFromEnvironment()
    static let multipartChunkSize = 8 * 1024 * 1024
    static let supportedRoots: [S3Root] = [.data, .dataRun, .dataSpatial]
    static let uploadIdRange = 1_000_000_000...Int.max
    static let uploadMaximumFileSize = 500 << 30 // 500GB

    func boot(routes: RoutesBuilder) throws {
        if Self.syncApiKeys.isEmpty && Self.uploadCredentials.isEmpty {
            return
        }

        if !Self.syncApiKeys.isEmpty {
            routes.get("", use: self.list)
            routes.get("data", "**", use: self.get)
            routes.get("data_run", "**", use: self.get)
            routes.get("data_spatial", "**", use: self.get)
        }

        if !Self.uploadCredentials.isEmpty {
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

    struct UploadCredential: Sendable, Hashable {
        let accessKey: String
        let secretKey: String

        static func loadFromEnvironment() -> [UploadCredential] {
            guard let raw = Environment.get("S3_UPLOAD_CREDENTIALS") else {
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
                let key = String(raw[..<split]).trimmingCharacters(in: .whitespaces)
                let secret = String(raw[raw.index(after: split)...]).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty, !secret.isEmpty else { return nil }
                return UploadCredential(accessKey: key, secretKey: secret)
            }
            return nil
        }
    }

    enum S3Root: String, CaseIterable {
        case data = "data"
        case dataRun = "data_run"
        case dataSpatial = "data_spatial"

        var pathPrefix: String {
            "/\(rawValue)/"
        }

        var listPrefix: String {
            "\(rawValue)/"
        }

        var directory: String {
            switch self {
            case .data:
                return OpenMeteo.dataDirectory
            case .dataRun:
                return OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_run")
            case .dataSpatial:
                return OpenMeteo.dataSpatialDirectory ?? OpenMeteo.dataDirectory.replacingLastPathComponent(with: "data_spatial")
            }
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
        guard let apikey = params.apikey, Self.syncApiKeys.contains(where: { $0 == apikey }) else {
            throw SyncError.invalidApiKey
        }

        let path = params.prefix
        guard params.list_type == 2, params.delimiter == "/" else {
            throw Abort(.forbidden)
        }
        guard !path.isEmpty,
              path.last == "/",
              !path.hasPrefix("/"),
              !path.contains("//"),
              !path.contains(".."),
              path.onlyContainsAlphanumericDashSlashDot else {
            throw Abort(.forbidden)
        }

        guard let resolved = resolveListPath(path) else {
            throw Abort(.forbidden)
        }

        let pathUrl = URL(fileURLWithPath: resolved.absoluteDirectoryPath, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])

        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            throw Abort(.forbidden)
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
                <Key>\(resolved.prefix)\($0.name)</Key>
                <LastModified>\(dateFormat.string(from: $0.modificationTime))</LastModified>
                <Size>\($0.fileSize)</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            """
        }.joined(separator: "\n")
        let directoriesXml = directories.map {
            """
            <CommonPrefixes>
            <Prefix>\(resolved.prefix)\($0)/</Prefix>
            </CommonPrefixes>
            """
        }.joined(separator: "\n")

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return Response(status: .ok, headers: headers, body: .init(string: """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Name>openmeteo</Name>
            <Prefix>\(resolved.prefix)</Prefix>
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
        guard let resolved = resolveObjectPath(path) else {
            throw Abort(.forbidden)
        }
        
        let isJson = resolved.relativePath.hasSuffix(".json")
        if !isJson {
            /// Only require API keys for non-json calls
            guard let apikey = params.apikey, Self.syncApiKeys.contains(where: { $0 == apikey }) else {
                throw SyncError.invalidApiKey
            }
        }

        guard let pathNoRoot = resolved.relativePath.split(separator: "/").dropFirst().joined(separator: "/").nilIfEmpty else {
            throw Abort(.forbidden)
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
          if resolved.root == .data,
              let remote = OpenMeteo.remoteDataDirectory,
              let modelStr = pathNoRoot.firstIndex(of: "/").map({ pathNoRoot[..<$0] }),
              let _ = DomainRegistry(rawValue: String(modelStr)) {
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
        let response = try await req.fileio.asyncStreamFile(at: resolved.absolutePath)
        return response
    }

    func putObject(_ req: Request) async throws -> Response {
        guard let body = req.body.data else {
            throw Abort(.badRequest, reason: "Expected body payload")
        }
        try verifyUploadSignature(req: req, body: body)
        struct Params: Codable {
            let uploadId: Int?
            let partNumber: Int?
        }
        let query = try req.query.decode(Params.self)
        if let uploadId = query.uploadId, let part = query.partNumber {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw Abort(.badRequest, reason: "Invalid uploadId")
            }
            guard part >= 1, part <= Self.uploadMaximumFileSize / Self.multipartChunkSize else {
                throw Abort(.badRequest, reason: "Invalid partNumber")
            }
            guard let resolved = resolveObjectPath(req.url.path) else {
                throw Abort(.forbidden)
            }
            try await writeMultipartPart(resolved: resolved, uploadId: uploadId, partNumber: part, body: body)
            try await replicateMultipartPart(req: req, resolved: resolved, uploadId: uploadId, partNumber: part, body: body)
            return makeUploadPartResponse(body: body)
        }

        try await uploadSinglePut(req: req, body: body)
        return Response(status: .ok)
    }

    func postObject(_ req: Request) async throws -> Response {
        let body = req.body.data
        try verifyUploadSignature(req: req, body: body ?? ByteBuffer())
        struct Params: Codable {
            let uploadId: Int?
            let partNumber: Int?
        }
        
        if req.url.query == "uploads" {
            let prepared = try await initiateMultipartUpload(req)
            try await replicateMultipartInitiate(req: req, resolved: prepared.resolved, uploadId: prepared.uploadId, fileSize: prepared.fileSize)
            return prepared.response
        }

        let query = try req.query.decode(Params.self)
        if let uploadId = query.uploadId, let part = query.partNumber {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw Abort(.badRequest, reason: "Invalid uploadId")
            }
            guard let body else {
                throw Abort(.badRequest, reason: "Expected body payload")
            }
            guard part >= 1, part <= Self.uploadMaximumFileSize / Self.multipartChunkSize else {
                throw Abort(.badRequest, reason: "Invalid partNumber")
            }
            guard let resolved = resolveObjectPath(req.url.path) else {
                throw Abort(.forbidden)
            }
            try await writeMultipartPart(resolved: resolved, uploadId: uploadId, partNumber: part, body: body)
            try await replicateMultipartPart(req: req, resolved: resolved, uploadId: uploadId, partNumber: part, body: body)
            return makeUploadPartResponse(body: body)
        }

        if let uploadId = query.uploadId {
            guard Self.uploadIdRange.contains(uploadId) else {
                throw Abort(.badRequest, reason: "Invalid uploadId")
            }
            guard let resolved = resolveObjectPath(req.url.path) else {
                throw Abort(.forbidden)
            }
            try await completeMultipartUpload(req: req, resolved: resolved, uploadId: uploadId)
            try await replicateMultipartComplete(req: req, resolved: resolved, uploadId: uploadId)
            return Response(status: .ok)
        }

        throw Abort(.badRequest, reason: "Unsupported POST operation")
    }

    func deleteObject(_ req: Request) async throws -> Response {
        try verifyUploadSignature(req: req, body: ByteBuffer())
        struct Params: Codable {
            let uploadId: Int
        }
        let query = try req.query.decode(Params.self)
        let uploadId = query.uploadId
        guard Self.uploadIdRange.contains(uploadId) else {
            throw Abort(.badRequest, reason: "Invalid uploadId")
        }
        guard let resolved = resolveObjectPath(req.url.path) else {
            throw Abort(.forbidden)
        }
        let tempPath = tempUploadPath(finalPath: resolved.absolutePath, uploadId: uploadId)
        _ = try await FileSystem.shared.removeItem(at: FilePath(tempPath))
        try await replicateAbort(req: req, resolved: resolved, uploadId: uploadId)
        return Response(status: .noContent)
    }

    private func uploadSinglePut(req: Request, body: ByteBuffer) async throws {
        guard let resolved = resolveObjectPath(req.url.path) else {
            print(req.url.path)
            throw Abort(.forbidden)
        }
        let uploadId = Int.random(in: Self.uploadIdRange)
        let tempPath = tempUploadPath(finalPath: resolved.absolutePath, uploadId: uploadId)

        try await ensureParentDirectoryExists(forFileAt: resolved.absolutePath)
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .newFile(replaceExisting: true)) { handle in
            try await handle.resize(to: .bytes(Int64(body.readableBytes)))
            try await handle.write(contentsOf: body, toAbsoluteOffset: 0)
        }
        try await FileSystem.shared.replaceItem(at: FilePath(resolved.absolutePath), withItemAt: FilePath(tempPath))
        try await applyLastModifiedIfProvided(header: req.headers.first(name: "x-last-modified"), filePath: resolved.absolutePath)
        try await replicateSinglePut(req: req, resolved: resolved, body: body)
    }

    private struct MultipartInitPrepared {
        let response: Response
        let resolved: (root: S3Root, relativePath: String, absolutePath: String)
        let uploadId: Int
        let fileSize: Int64
    }

    private func initiateMultipartUpload(_ req: Request) async throws -> MultipartInitPrepared {
        guard let resolved = resolveObjectPath(req.url.path) else {
            throw Abort(.forbidden)
        }
        guard let fileSizeRaw = req.headers.first(name: "x-file-size"),
              let fileSize = Int64(fileSizeRaw), fileSize >= 0, fileSize <= Self.uploadMaximumFileSize else {
            throw Abort(.badRequest, reason: "Missing or invalid x-file-size header")
        }

        let uploadId: Int
        if let customUploadId = req.headers.first(name: "x-upload-id") {
            guard let id = Int(customUploadId), Self.uploadIdRange.contains(id) else {
                throw Abort(.badRequest, reason: "Invalid uploadId")
            }
            uploadId = id
        } else {
            uploadId = Int.random(in: Self.uploadIdRange)
        }
        try await allocateMultipartTempFile(resolved: resolved, uploadId: uploadId, fileSize: fileSize)

        let responseBody = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <InitiateMultipartUploadResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">
            <Bucket>openmeteo</Bucket>
            <Key>\(resolved.relativePath)</Key>
            <UploadId>\(uploadId)</UploadId>
        </InitiateMultipartUploadResult>
        """
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return MultipartInitPrepared(
            response: Response(status: .ok, headers: headers, body: .init(string: responseBody)),
            resolved: resolved,
            uploadId: uploadId,
            fileSize: fileSize
        )
    }

    private func writeMultipartPart(resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int, partNumber: Int, body: ByteBuffer) async throws {
        guard body.readableBytes <= Self.multipartChunkSize else {
            throw Abort(.badRequest, reason: "Chunk size exceeds 8MB")
        }

        let tempPath = tempUploadPath(finalPath: resolved.absolutePath, uploadId: uploadId)
        let tempInfo = try await FileSystem.shared.info(forFileAt: FilePath(tempPath))
        guard let tempInfo else {
            throw Abort(.notFound, reason: "Multipart upload not found")
        }
        let offset = Int64(partNumber - 1) * Int64(Self.multipartChunkSize)
        guard offset + Int64(body.readableBytes) <= tempInfo.size else {
            throw Abort(.badRequest, reason: "Part exceeds allocated file size")
        }

        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .modifyFile(createIfNecessary: false)) { handle in
            try await handle.write(contentsOf: body, toAbsoluteOffset: offset)
        }
    }

    private func completeMultipartUpload(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int) async throws {
        let tempPath = tempUploadPath(finalPath: resolved.absolutePath, uploadId: uploadId)
        guard try await FileSystem.shared.info(forFileAt: FilePath(tempPath)) != nil else {
            throw Abort(.notFound, reason: "Multipart upload not found")
        }
        try await ensureParentDirectoryExists(forFileAt: resolved.absolutePath)
        try await FileSystem.shared.replaceItem(at: FilePath(resolved.absolutePath), withItemAt: FilePath(tempPath))
        try await applyLastModifiedIfProvided(header: req.headers.first(name: "x-last-modified"), filePath: resolved.absolutePath)
    }

    private func makeUploadPartResponse(body: ByteBuffer) -> Response {
        var headers = HTTPHeaders()
        headers.add(name: "ETag", value: "\"\(body.readableBytesView.sha256Hex)\"")
        return Response(status: .ok, headers: headers)
    }

    private func verifyUploadSignature(req: Request, body: ByteBuffer) throws {
        guard !Self.uploadCredentials.isEmpty else {
            throw Abort(.serviceUnavailable, reason: "No upload credentials configured")
        }
        let payloadHash = body.readableBytesView.sha256Hex
        let host = req.headers.first(name: .host) ?? req.headers.first(name: "Host")
        guard let host else {
            throw Abort(.unauthorized, reason: "Missing Host header")
        }
        let canonicalURL = "https://\(host)\(req.url.string)"

        var hasMatchingAccessKey = false
        for credentials in Self.uploadCredentials {
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

        let reason = hasMatchingAccessKey ? "Invalid request signature" : "Unknown access key"
        throw Abort(.unauthorized, reason: reason)
    }

    private func ensureParentDirectoryExists(forFileAt path: String) async throws {
        let parent = path.removeLastPathComponent()
        try await FileSystem.shared.createDirectory(at: FilePath(String(parent)), withIntermediateDirectories: true)
    }

    private func allocateMultipartTempFile(resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int, fileSize: Int64) async throws {
        let tempPath = tempUploadPath(finalPath: resolved.absolutePath, uploadId: uploadId)
        try await ensureParentDirectoryExists(forFileAt: resolved.absolutePath)
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: FilePath(tempPath), options: .newFile(replaceExisting: true)) { handle in
            try await handle.resize(to: .bytes(fileSize))
        }
    }

    private func activeReplicationServers(_ req: Request) async -> [S3ReplicationServer] {
        return await req.application.s3ServerHealth.activeServers()
    }

    private func replicateSinglePut(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), body: ByteBuffer) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        let lastModified = req.headers.first(name: "x-last-modified")
        let bodyHash = body.readableBytesView.sha256Hex
        let bodyLength = body.readableBytes
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.objectURL(relativePath: resolved.relativePath))
            request.method = .PUT
            request.body = .bytes(body)
            request.headers.add(name: "x-amz-content-sha256", value: bodyHash)
            request.headers.add(name: .contentLength, value: "\(bodyLength)")
            if let contentType = req.headers.first(name: .contentType) {
                request.headers.add(name: .contentType, value: contentType)
            }
            if let lastModified {
                request.headers.add(name: "x-last-modified", value: lastModified)
            }
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(5), timeoutPerRequest: .seconds(60))
        }
    }

    private func replicateMultipartInitiate(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int, fileSize: Int64) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.objectURL(relativePath: resolved.relativePath) + "?uploads")
            request.method = .POST
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            request.headers.add(name: "x-upload-id", value: "\(uploadId)")
            request.headers.add(name: "x-file-size", value: "\(fileSize)")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }

    private func replicateMultipartPart(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int, partNumber: Int, body: ByteBuffer) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        let bodyHash = body.readableBytesView.sha256Hex
        let bodyLength = body.readableBytes
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.objectURL(relativePath: resolved.relativePath) + "?partNumber=\(partNumber)&uploadId=\(uploadId)")
            request.method = .PUT
            request.body = .bytes(body)
            request.headers.add(name: "x-amz-content-sha256", value: bodyHash)
            request.headers.add(name: .contentLength, value: "\(bodyLength)")
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(5), timeoutPerRequest: .seconds(60))
        }
    }

    private func replicateMultipartComplete(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        let lastModified = req.headers.first(name: "x-last-modified")
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.objectURL(relativePath: resolved.relativePath) + "?uploadId=\(uploadId)")
            request.method = .POST
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            if let lastModified {
                request.headers.add(name: "x-last-modified", value: lastModified)
            }
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }

    private func replicateAbort(req: Request, resolved: (root: S3Root, relativePath: String, absolutePath: String), uploadId: Int) async throws {
        let servers = await activeReplicationServers(req)
        if servers.isEmpty { return }
        try await servers.foreachConcurrent(nConcurrent: 4) { server in
            var request = HTTPClientRequest(url: server.objectURL(relativePath: resolved.relativePath) + "?uploadId=\(uploadId)")
            request.method = .DELETE
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            _ = try await req.application.dedicatedHttpClient.executeRetry(request, logger: req.logger, deadline: .minutes(2), timeoutPerRequest: .seconds(5))
        }
    }

    private func tempUploadPath(finalPath: String, uploadId: Int) -> String {
        return "\(finalPath).\(uploadId)~"
    }

    private func resolveListPath(_ prefix: String) -> (prefix: String, absoluteDirectoryPath: String)? {
        for root in Self.supportedRoots {
            guard prefix.starts(with: root.listPrefix) else { continue }
            let relative = String(prefix.dropFirst(root.listPrefix.count))
            if relative.contains("..") || relative.contains("//") {
                return nil
            }
            return (prefix, root.directory + relative)
        }
        return nil
    }

    private func resolveObjectPath(_ path: String) -> (root: S3Root, relativePath: String, absolutePath: String)? {
        guard !path.isEmpty,
              path.first == "/",
              path.last != "/",
              !path.contains(".."),
              !path.contains("//"),
              path.onlyContainsAlphanumericDashSlashDot else {
            return nil
        }
        for root in Self.supportedRoots {
            guard path.starts(with: root.pathPrefix) else { continue }
            let relative = String(path.dropFirst(root.pathPrefix.count))
            guard !relative.isEmpty else { return nil }
            return (root, "\(root.rawValue)/\(relative)", root.directory + relative)
        }
        return nil
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

enum SyncError: AbortError {
    case invalidApiKey

    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .invalidApiKey:
            return .unauthorized
        }
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
