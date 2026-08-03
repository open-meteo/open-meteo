import Foundation
@testable import App
import Testing
import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore

@Suite(.serialized)
struct S3UploadTests {
    @Test func singlePutUpload() async throws {
        try await withApp { app in
            let credential = S3DataController.UploadCredential(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
            let controller = S3DataController(readCredentials: [credential], uploadCredentials: [credential])

            let objectName = "s3-upload-tests/single-\(UUID().uuidString).bin"
            let path = "/data/\(objectName)"
            let absolutePath = OpenMeteo.dataDirectory + objectName

            let payload = Data("single-put-upload".utf8)
            var body = ByteBufferAllocator().buffer(capacity: payload.count)
            body.writeData(payload)

            defer {
                try? FileManager.default.removeItem(atPath: absolutePath)
            }

            let request = try makeSignedRequest(
                app: app,
                method: .PUT,
                uri: path,
                body: body,
                credential: credential,
                additionalHeaders: [:]
            )

            let response = try await controller.putObject(request)
            #expect(response.status == .ok)

            let stored = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
            #expect(stored == payload)
        }
    }

    @Test func multipartUpload() async throws {
        try await withApp { app in
            let credential = S3DataController.UploadCredential(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
            let controller = S3DataController(readCredentials: [credential], uploadCredentials: [credential])

            let objectName = "s3-upload-tests/multipart-\(UUID().uuidString).bin"
            let path = "/data/\(objectName)"
            let absolutePath = OpenMeteo.dataDirectory + objectName

            let uploadId = "1234567891"
            let payload = Data("multipart-upload-body".utf8)

            defer {
                try? FileManager.default.removeItem(atPath: absolutePath)
                try? FileManager.default.removeItem(atPath: "\(absolutePath).\(uploadId)~")
            }

            // Step 1: initiate multipart upload
            let initiateRequest = try makeSignedRequest(
                app: app,
                method: .POST,
                uri: "\(path)?uploads",
                body: ByteBuffer(),
                credential: credential,
                additionalHeaders: [
                    "x-file-size": "\(payload.count)",
                    "x-upload-id": uploadId
                ]
            )
            let initiateResponse = try await controller.postObject(initiateRequest)
            #expect(initiateResponse.status == .ok)

            // Step 2: upload first part
            var partBody = ByteBufferAllocator().buffer(capacity: payload.count)
            partBody.writeData(payload)
            let partRequest = try makeSignedRequest(
                app: app,
                method: .PUT,
                uri: "\(path)?partNumber=1&uploadId=\(uploadId)",
                body: partBody,
                credential: credential,
                additionalHeaders: [:]
            )
            let partResponse = try await controller.putObject(partRequest)
            #expect(partResponse.status == .ok)

            // Step 3: complete multipart upload
            let completionXmlInvalidSHA = "<CompleteMultipartUpload><Part><PartNumber>1</PartNumber><ETag>\"WRONG_SHA256\"</ETag></Part></CompleteMultipartUpload>"
            let completeRequestInvalidSHA = try makeSignedRequest(
                app: app,
                method: .POST,
                uri: "\(path)?uploadId=\(uploadId)",
                body: ByteBuffer(string: completionXmlInvalidSHA),
                credential: credential,
                additionalHeaders: [:]
            )
            await #expect(throws: S3ApiError.multipartPartHashMismatch) {
                let _ = try await controller.postObject(completeRequestInvalidSHA)
            }
            
            let completionXml = "<CompleteMultipartUpload><Part><PartNumber>1</PartNumber><ETag>\"\(payload.sha256Hex)\"</ETag></Part></CompleteMultipartUpload>"
            let completeRequest = try makeSignedRequest(
                app: app,
                method: .POST,
                uri: "\(path)?uploadId=\(uploadId)",
                body: ByteBuffer(string: completionXml),
                credential: credential,
                additionalHeaders: [:]
            )
            let completeResponse = try await controller.postObject(completeRequest)
            #expect(completeResponse.status == .ok)

            let stored = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
            #expect(stored == payload)
        }
    }

    private func makeSignedRequest(
        app: Application,
        method: HTTPMethod,
        uri: String,
        body: ByteBuffer,
        credential: S3DataController.UploadCredential,
        additionalHeaders: [String: String]
    ) throws -> Request {
        var clientRequest = HTTPClientRequest(url: "https://localhost\(uri)")
        clientRequest.method = method

        for (name, value) in additionalHeaders {
            clientRequest.headers.add(name: name, value: value)
        }

        let payloadHash = body.readableBytesView.sha256Hex
        clientRequest.headers.replaceOrAdd(name: "x-amz-content-sha256", value: payloadHash)

        let signer = AWSSigner(
            accessKey: credential.accessKey,
            secretKey: credential.secretKey,
            region: "us-west-2",
            service: "s3"
        )
        try signer.sign(request: &clientRequest)

        return Request(
            application: app,
            method: method,
            url: URI(string: uri),
            headers: clientRequest.headers,
            collectedBody: .init(buffer: body),
            on: app.eventLoopGroup.next()
        )
    }
}
