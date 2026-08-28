import Foundation
@testable import App
import Testing
import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore

@Suite(.serialized)
struct S3ApiServerTests {
    @Test func rejectsIncompleteRequestBody() async throws {
        try await withApp { app in
            let credential = S3DataController.UploadCredential(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
            let controller = S3DataController(readCredentials: [credential], uploadCredentials: [credential])
            let body = ByteBuffer(string: "truncated")
            let request = try makeSignedRequest(
                app: app,
                method: .PUT,
                uri: "/data/s3-upload-tests/incomplete.bin",
                body: body,
                credential: credential,
                additionalHeaders: [:]
            )
            request.headers.replaceOrAdd(name: .contentLength, value: "100")

            await #expect(throws: S3ApiError.incompleteBodyPayload(expected: 100, actual: body.readableBytes)) {
                _ = try await controller.putObject(request)
            }
        }
    }

    @Test func singlePutUpload() async throws {
        try await withApp { app in
            let credential = S3DataController.UploadCredential(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
            let controller = S3DataController(readCredentials: [credential], uploadCredentials: [credential])
            let file = "single-\(UUID().uuidString).bin"
            let objectName = "s3-upload-tests/\(file)"
            let path = "/data/\(objectName)"
            let absolutePath = OpenMeteo.dataDirectory + objectName
            try? FileManager.default.removeItemIfExists(at: absolutePath)
            try FileManager.default.createDirectory(atPath: "\(OpenMeteo.dataDirectory)s3-upload-tests/", withIntermediateDirectories: true)
            let dir = await OmFileSystemManager.instance.localFileSystem.getDirectory(fullPath: "data/s3-upload-tests/")
            #expect(dir != nil)
            #expect(await dir?.getFile(name: file) == nil)

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
            
            /// Check that the cached local directory got updated and now contains the new file
            let storedFile = await dir?.getFile(name: file)
            #expect(storedFile != nil)

            let stored = try await storedFile?.fd.readToEnd()
            #expect(stored == payload)
        }
    }

    @Test func multipartUpload() async throws {
        try await withApp { app in
            let credential = S3DataController.UploadCredential(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
            let controller = S3DataController(readCredentials: [credential], uploadCredentials: [credential])

            let file = "multipart-\(UUID().uuidString).bin"
            let objectName = "s3-upload-tests/\(file)"
            let path = "/data/\(objectName)"
            let absolutePath = OpenMeteo.dataDirectory + objectName
            
            try? FileManager.default.removeItemIfExists(at: absolutePath)
            try FileManager.default.createDirectory(atPath: "\(OpenMeteo.dataDirectory)s3-upload-tests/", withIntermediateDirectories: true)
            let dir = await OmFileSystemManager.instance.localFileSystem.getDirectory(fullPath: "data/s3-upload-tests/")
            
            #expect(dir != nil)
            #expect(await dir?.getFile(name: file) == nil)

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
            #expect(initiateResponse.body.buffer!.string == """
                <?xml version="1.0" encoding="UTF-8"?>
                <InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                    <Bucket>openmeteo</Bucket>
                    <Key>\(path)</Key>
                    <UploadId>\(uploadId)</UploadId>
                </InitiateMultipartUploadResult>
                """)

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
            #expect(partResponse.headers["ETag"].first == payload.sha256Hex)
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

            // A retried completion validates the already-moved destination and returns successfully.
            let duplicateCompleteRequest = try makeSignedRequest(
                app: app,
                method: .POST,
                uri: "\(path)?uploadId=\(uploadId)",
                body: ByteBuffer(string: completionXml),
                credential: credential,
                additionalHeaders: [:]
            )
            let duplicateCompleteResponse = try await controller.postObject(duplicateCompleteRequest)
            #expect(duplicateCompleteResponse.status == .ok)
            
            /// Check that the cached local directory got updated and now contains the new file
            let storedFile = await dir?.getFile(name: file)
            #expect(storedFile != nil)

            let stored = try await storedFile?.fd.readToEnd()
            #expect(stored == payload)
            
            let listRequest = try makeSignedRequest(
                app: app,
                method: .GET,
                uri: "/?list-type=2&delimiter=/&prefix=data/s3-upload-tests/",
                body: ByteBuffer(),
                credential: credential,
                additionalHeaders: [:]
            )
            let listResponse = try await controller.list(listRequest)
            #expect(listResponse.status == .ok)
            #expect(listResponse.body.buffer!.string.contains("<Key>data/\(objectName)</Key>"))
            
            let getRequest = try makeSignedRequest(
                app: app,
                method: .GET,
                uri: path,
                body: ByteBuffer(),
                credential: credential,
                additionalHeaders: [:]
            )
            let getResponse = try await controller.get(getRequest)
            #expect(getResponse.status == .ok)
            #expect(try await getResponse.body.collect(on: app.eventLoopGroup.next()).get()?.string == "multipart-upload-body")
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
