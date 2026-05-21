import Foundation
import AsyncHTTPClient
import NIOCore
import Logging

enum S3Uploader {
    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func upload<D: DataProtocol & Sendable>(client: HTTPClient, data: D, url: String) async throws {
        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.body = .bytes(ByteBuffer(bytes: data))
        request.headers.add(name: "Content-Type", value: "application/octet-stream")
        request.headers.add(name: "x-amz-content-sha256", value: data.sha256Hex)
        // executeRetry extracts credentials from the URL, signs the request with
        // AWS4-HMAC-SHA256 on each attempt, and retries on transient errors.
        let logger = Logger(label: "S3Uploader")
        let response = try await client.executeRetry(request, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
        _ = try await response.body.collect(upTo: 1024 * 1024)
    }

    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func uploadMultipart<D: DataProtocol & Sendable>(client: HTTPClient, data: D, url: String) async throws {
        let logger = Logger(label: "S3Uploader")
        let chunkSize = 8 * 1024 * 1024

        // Step 1: Initiate multipart upload
        var initiateRequest = HTTPClientRequest(url: url + "?uploads")
        initiateRequest.method = .POST
        initiateRequest.headers.add(name: "Content-Type", value: "application/octet-stream")
        initiateRequest.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
        let initiateResponse = try await client.executeRetry(initiateRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
        let initiateBody = try await initiateResponse.body.collect(upTo: 1024 * 1024)
        let initiateXml = String(buffer: initiateBody)
        guard let uploadId = initiateXml.xmlValue(tag: "UploadId") else {
            throw S3UploaderError.missingUploadId
        }
        // uploadId may contain '+', '/' or '=' — percent-encode for use in query strings
        let encodedUploadId = uploadId.addingPercentEncoding(withAllowedCharacters: .awsUriAllowed) ?? uploadId

        // Step 2: Upload parts concurrently (up to 8 in parallel), abort on any error
        let partCount = (data.count + chunkSize - 1) / chunkSize
        let etags: [(partNumber: Int, etag: String)]
        do {
            etags = try await stride(from: 1, through: partCount, by: 1).mapConcurrent(nConcurrent: 8) { (partNumber: Int) -> (Int, String) in
                let offset = (partNumber - 1) * chunkSize
                let chunk = data.dropFirst(offset).prefix(chunkSize)
                var req = HTTPClientRequest(url: url + "?partNumber=\(partNumber)&uploadId=\(encodedUploadId)")
                req.method = .PUT
                req.body = .bytes(ByteBuffer(bytes: chunk))
                req.headers.add(name: "x-amz-content-sha256", value: chunk.sha256Hex)
                let response = try await client.executeRetry(req, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
                _ = try await response.body.collect(upTo: 1024 * 1024)
                guard let etag = response.headers.first(name: "ETag") else {
                    throw S3UploaderError.missingETag(partNumber: partNumber)
                }
                return (partNumber, etag)
            }
        } catch {
            var abortRequest = HTTPClientRequest(url: url + "?uploadId=\(encodedUploadId)")
            abortRequest.method = .DELETE
            abortRequest.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            let _ = try await client.executeRetry(abortRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
            throw error
        }

        // Step 3: Complete multipart upload
        let completionXml = "<CompleteMultipartUpload>" + etags.map {
            "<Part><PartNumber>\($0.partNumber)</PartNumber><ETag>\($0.etag)</ETag></Part>"
        }.joined() + "</CompleteMultipartUpload>"
        let completionData = Data(completionXml.utf8)
        var completeRequest = HTTPClientRequest(url: url + "?uploadId=\(encodedUploadId)")
        completeRequest.method = .POST
        completeRequest.body = .bytes(ByteBuffer(data: completionData))
        completeRequest.headers.add(name: "Content-Type", value: "application/xml")
        completeRequest.headers.add(name: "x-amz-content-sha256", value: completionData.sha256Hex)
        let completeResponse = try await client.executeRetry(completeRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
        _ = try await completeResponse.body.collect(upTo: 1024 * 1024)
    }
}

enum S3UploaderError: Error {
    case missingUploadId
    case missingETag(partNumber: Int)
}

private extension String {
    /// Extract the text content of the first occurrence of `<tag>…</tag>` in an XML string.
    func xmlValue(tag: String) -> String? {
        guard let start = range(of: "<\(tag)>"),
              let end = range(of: "</\(tag)>") else { return nil }
        return String(self[start.upperBound..<end.lowerBound])
    }
}
