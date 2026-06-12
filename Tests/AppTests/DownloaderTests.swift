@testable import App
import Foundation
import Testing
import AsyncHTTPClient
import NIOCore
import Logging

@Suite struct DownloaderTests {
    @Test func testAwsSign() async throws {
        let url = "https://examplebucket.s3.amazonaws.com/test.txt"
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Range", value: "bytes=0-9")
        //request.headers.add(name: "Content-Type", value: "text/plain")
        //request.body = .bytes(ByteBuffer(string: "Hello AWS!"))

        let signer = AWSSigner(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", region: "us-east-1", service: "s3")

        let signingKey = signer.getSignatureKey(date: "20151229")
        #expect(signingKey.hex == "cbcef1ebeaefc82cce6530b9f0a9ae598846065f5c5bae0674bd5ebc4ba52d28")

        try signer.sign(request: &request, now: .init("2013-05-24T00:00:00Z", strategy: .iso8601))

        #expect(request.headers.first(name: "Authorization") == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")

        //let response = try await app!.http.client.shared.execute(request, timeout: .seconds(10))
        //print(response.status)
        //print(try await response.body.collect(upTo: 10000).readStringImmutable()!)
    }
    
    @Test func testAwsSignClientVerify() async throws {
        let url = "https://@examplebucket.s3.amazonaws.com/test.txt"
        var request = HTTPClientRequest(url: url)
        try request.applyS3Credentials()
        let signer = AWSSigner(accessKey: String("AKIAIOSFODNN7EXAMPLE"), secretKey: String("wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"), region: "us-west-2", service: "s3")
        try signer.sign(request: &request, now: Date(timeIntervalSince1970: 12345))
        #expect(request.headers["Authorization"].first == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/19700101/us-west-2/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=d88b4ffeba0ad306663853a7280ffeda745d25ead6c775ab59af84a272dc853a")
        
        try signer.verify(url: url, method: .GET, headers: request.headers, payloadHashSha256: Data().sha256Hex, now: Date(timeIntervalSince1970: 12345))
        
        request.headers.replaceOrAdd(name: "Authorization", value: "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/19700101/us-west-2/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=d88b4ffeba0ad306663853a7280ffeda745d25ead6c775ab59af84a272dc853b")
        #expect(throws: AWSSigner.SigningError.invalidSignature) {
            try signer.verify(url: url, method: .GET, headers: request.headers, payloadHashSha256: Data().sha256Hex, now: Date(timeIntervalSince1970: 12345))
        }
    }
    
    @Test func testAwsSignClient() async throws {
        // slash in password needs to be URL encoded
        let url = "https://AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI%2FK7MDENG%2FbPxRfiCYEXAMPLEKEY@examplebucket.s3.amazonaws.com/test.txt"
        var request = HTTPClientRequest(url: url)
        try request.applyS3Credentials()
        #expect(request.headers.contains(name: "Authorization"))
        #expect(request.url == "https://examplebucket.s3.amazonaws.com/test.txt")
    }
    
    @Test func testAwsSignClient2() throws {
        let url = "https://AKIAYawfawfawed5jdrh:FgseawfawfrVU8Dk1zTsesefsegsgW1I%2FWJ6@openmeteo.s3.amazonaws.com:8080/text.txt"
        var request = HTTPClientRequest(url: url)
        try request.applyS3Credentials()
        #expect(request.headers.contains(name: "Authorization"))
        #expect(request.url == "https://openmeteo.s3.amazonaws.com:8080/text.txt")
    }
    
    @Test func urlExtraction() throws {
        let a = "s3://AKIAYawfawfawed5jdrh:FgseawfawfrVU8Dk1zTsesefsegsgW1I%2FWJ6@openmeteo.s3.amazonaws.com:8080/text.txt".extractSchemaUserNamePasswordCleanUrl()
        #expect(a?.schema == "s3")
        #expect(a?.user == "AKIAYawfawfawed5jdrh")
        #expect(a?.password == "FgseawfawfrVU8Dk1zTsesefsegsgW1I/WJ6")
        #expect(a?.url == "https://openmeteo.s3.amazonaws.com:8080/text.txt")
    }

    /// Single-part PUT upload.
    /// Set S3_TEST_SERVER to a URL of the form
    /// `https://ACCESS_KEY:SECRET_KEY@s3-host.tld/bucket/` to enable.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["S3_TEST_SERVER"] != nil))
    func testS3Upload() async throws {
        let server = try #require(ProcessInfo.processInfo.environment["S3_TEST_SERVER"])
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { let _ = client.shutdown() }

        let data = randomData(byteCount: 1 * 1024 * 1024)
        try await S3Uploader.upload(client: client, data: data, url: "\(server)test/s3uploader-single.bin")
    }

    /// Upload three files using single-part PUT uploads.
    /// Set S3_TEST_SERVER to a URL of the form
    /// `https://ACCESS_KEY:SECRET_KEY@s3-host.tld/bucket/` to enable.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["S3_TEST_SERVER"] != nil))
    func testS3UploadThreeFiles() async throws {
        let server = try #require(ProcessInfo.processInfo.environment["S3_TEST_SERVER"])
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { let _ = client.shutdown() }
        let manager = S3UploadManager(logger: Logger(label: "DownloaderTests.S3UploadManager"))

        let uploads: [(suffix: String, data: Data)] = [
            ("a", randomData(byteCount: 128 * 1024)),
            ("b", randomData(byteCount: 256 * 1024)),
            ("c", randomData(byteCount: 512 * 1024))
        ]

        for upload in uploads {
            await manager.upload(
                client: client,
                bucketEndpoint: server,
                data: upload.data,
                url: "\(server)test/s3uploader-three-\(upload.suffix).bin"
            )
        }

        // Ensure all queued uploads complete before ending the test.
        await manager.shutdown()
    }

    /// Multipart upload — 10 MB splits into two 8 MB / 2 MB parts.
    /// Set S3_TEST_SERVER to a URL of the form
    /// `https://ACCESS_KEY:SECRET_KEY@s3-host.tld/bucket/` to enable.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["S3_TEST_SERVER"] != nil))
    func testS3UploadMultipart() async throws {
        let server = try #require(ProcessInfo.processInfo.environment["S3_TEST_SERVER"])
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { let _ = client.shutdown() }

        let data = ByteBuffer(data: randomData(byteCount: 10 * 1024 * 1024))
        try await S3Uploader.uploadMultipart(client: client, data: data, url: "\(server)test/s3uploader-multipart.bin").commit(client: client)
    }
    
    /// Multipart upload — 10 MB splits into two 8 MB / 2 MB parts.
    /// Set S3_TEST_SERVER to a URL of the form
    /// `https://ACCESS_KEY:SECRET_KEY@s3-host.tld/bucket/` to enable.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["S3_TEST_SERVER"] != nil))
    func testS3SyncUpload() async throws {
        let server = try #require(ProcessInfo.processInfo.environment["S3_TEST_SERVER"])
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { let _ = client.shutdown() }

        try await S3Uploader.uploadSync(client: client, localDirectory: "/Users/patrick/Documents/open-meteo-data/data/ecmwf_ifs025_ensemble_mean/", server: server, basePath: "test/ecmwf_ifs025_ensemble_mean/")
    }
}

/// Fill a `Data` buffer with cryptographically random bytes.
private func randomData(byteCount: Int) -> Data {
    var data = Data(count: byteCount)
    data.withUnsafeMutableBytes { ptr in
        var rng = SystemRandomNumberGenerator()
        var i = ptr.startIndex
        while i < ptr.endIndex {
            let word = UInt64.random(in: .min ... .max, using: &rng)
            let end = min(i + 8, ptr.endIndex)
            withUnsafeBytes(of: word) { ptr[i..<end].copyBytes(from: $0.prefix(end - i)) }
            i += 8
        }
    }
    return data
}
