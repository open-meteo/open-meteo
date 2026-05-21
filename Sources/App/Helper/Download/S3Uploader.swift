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
        let _ = try await client.executeRetry(request, logger: logger, deadline: .minutes(10), timeoutPerRequest: .seconds(120))
    }

    /// Uploads files to S3 in 8 MB chunks
    /// Returns the `UploadId` which needs to be committed in a second step
    /// URL in form "https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/object"
    static func uploadMultipart<D: DataProtocol & Sendable>(client: HTTPClient, data: D, url: String, nConcurrent: Int = 8) async throws -> S3MultiPartUploadPrepared {
        let logger = Logger(label: "S3Uploader")
        let chunkSize = 8 * 1024 * 1024

        // Step 1: Initiate multipart upload
        let timeInitiateRequestStart = DispatchTime.now().uptimeNanoseconds
        var initiateRequest = HTTPClientRequest(url: url + "?uploads")
        initiateRequest.method = .POST
        initiateRequest.headers.add(name: "Content-Type", value: "application/octet-stream")
        initiateRequest.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
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
            abortRequest.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            let _ = try await client.executeRetry(abortRequest, logger: logger, deadline: .minutes(2), timeoutPerRequest: .seconds(30))
            throw error
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
