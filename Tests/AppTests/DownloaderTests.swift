@testable import App
import Foundation
import Testing
import AsyncHTTPClient
import NIOCore
import Logging
#if os(Linux)
import Glibc
#else
import Darwin
#endif

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
        var a = "s3://AKIAYawfawfawed5jdrh:FgseawfawfrVU8Dk1zTsesefsegsgW1I%2FWJ6@openmeteo.s3.amazonaws.com:8080/text.txt".extractSchemaUserNamePasswordCleanUrl()
        #expect(a?.schema == "s3")
        #expect(a?.user == "AKIAYawfawfawed5jdrh")
        #expect(a?.password == "FgseawfawfrVU8Dk1zTsesefsegsgW1I/WJ6")
        #expect(a?.url == "https://openmeteo.s3.amazonaws.com:8080/text.txt")
        
        a = "s3://AKIAYawfawfawed5jdrh@openmeteo.s3.amazonaws.com:8080/text.txt".extractSchemaUserNamePasswordCleanUrl()
        #expect(a?.schema == "s3")
        #expect(a?.user == "AKIAYawfawfawed5jdrh")
        #expect(a?.password == nil)
        #expect(a?.url == "https://openmeteo.s3.amazonaws.com:8080/text.txt")
        
        a = "s3://127.0.0.1/text.txt".extractSchemaUserNamePasswordCleanUrl()
        #expect(a?.schema == "s3")
        #expect(a?.user == nil)
        #expect(a?.password == nil)
        #expect(a?.url == "http://127.0.0.1/text.txt")
        
        a = "file:///user/home/text.txt".extractSchemaUserNamePasswordCleanUrl()
        #expect(a?.schema == "file")
        #expect(a?.user == nil)
        #expect(a?.password == nil)
        #expect(a?.url == "/user/home/text.txt")
        
        #expect("s3://AKIAYawfawfawed5jdrh:FgseawfawfrVU8Dk1zTsesefsegsgW1I%2FWJ6@openmeteo.s3.amazonaws.com:8080/text.txt".stripHttpPassword() == "s3://openmeteo.s3.amazonaws.com:8080/text.txt")
    }

    @Test func s3UploadPlanKeepsRegularDataForAwsProfile() throws {
        let targets = S3UploadPlan.targets(
            domain: .ncep_gfs025,
            endpoints: s3Endpoints("s3://aws-bucket/@aws"),
            localFile: "/tmp/chunk_1.om",
            remotePath: "data/ncep_gfs025/temperature_2m/chunk_1.om"
        )

        #expect(targets == [
            S3UploadTarget(
                bucketEndpoint: S3BucketEndpoint(rawEndpoint: "s3://aws-bucket/", profile: "aws"),
                localFile: "/tmp/chunk_1.om",
                remotePath: "data/ncep_gfs025/temperature_2m/chunk_1.om",
                contentType: "application/octet-stream"
            )
        ])
        #expect(targets.first?.uploadURL() == "s3://aws-bucket/data/ncep_gfs025/temperature_2m/chunk_1.om")
    }

    @Test func s3UploadPlanSkipsPreviousDayForAwsProfileAndDefaultOpenmeteo() throws {
        let targets = S3UploadPlan.targets(
            domain: .ncep_gfs025,
            endpoints: s3Endpoints("openmeteo,s3://aws-bucket/@aws,s3://ceph-bucket/@ceph"),
            localFile: "/tmp/chunk_1.om",
            remotePath: "data/ncep_gfs025/temperature_2m_previous_day1/chunk_1.om",
            kind: .previousDay
        )

        #expect(targets == [
            S3UploadTarget(
                bucketEndpoint: S3BucketEndpoint(rawEndpoint: "s3://ceph-bucket/", profile: "ceph"),
                localFile: "/tmp/chunk_1.om",
                remotePath: "data/ncep_gfs025/temperature_2m_previous_day1/chunk_1.om",
                contentType: "application/octet-stream"
            )
        ])
    }

    @Test func s3UploadPlanUsesDataRunPrefix() throws {
        let targets = S3UploadPlan.targets(
            domain: .ncep_gfs025,
            endpoints: s3Endpoints("openmeteo"),
            localFile: "/tmp/temperature_2m.om",
            remotePath: "data_run/ncep_gfs025/20260101/00/temperature_2m.om"
        )

        #expect(targets.first?.uploadURL() == "s3://openmeteo/data_run/ncep_gfs025/20260101/00/temperature_2m.om")
    }

    @Test func s3UploadPlanFormatsSpatialRealmSuffixes() throws {
        let run = Timestamp(2026, 1, 1, 0)
        let time = Timestamp(2026, 1, 1, 3)
        let data = ByteBuffer(string: "{}").readableBytesView

        let defaultFile = S3UploadPlan.targets(
            endpoints: s3Endpoints("openmeteo"),
            artifact: .spatialFile(
                domain: .ncep_gfs025,
                localFile: "/tmp/2026-01-01T0300.om",
                run: run,
                time: time,
                realm: nil
            )
        )
        #expect(defaultFile.first?.uploadURL() == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/2026-01-01T0300.om")

        let realmFile = S3UploadPlan.targets(
            endpoints: s3Endpoints("openmeteo"),
            artifact: .spatialFile(
                domain: .ncep_gfs025,
                localFile: "/tmp/2026-01-01T0300_model-level.om",
                run: run,
                time: time,
                realm: "model-level"
            )
        )
        #expect(realmFile.first?.uploadURL() == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/2026-01-01T0300_model-level.om")

        let defaultMeta = S3UploadPlan.targets(
            endpoints: s3Endpoints("openmeteo"),
            artifact: .spatialMeta(
                domain: .ncep_gfs025,
                localFile: "/tmp/meta.json",
                remote: .run(run: run, realm: nil),
                data: data
            )
        )
        #expect(defaultMeta.first?.uploadURL() == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/meta.json")

        let realmMeta = S3UploadPlan.targets(
            endpoints: s3Endpoints("openmeteo"),
            artifact: .spatialMeta(
                domain: .ncep_gfs025,
                localFile: "/tmp/meta_model-level.json",
                remote: .latest(realm: "model-level"),
                data: data
            )
        )
        #expect(realmMeta.first?.uploadURL() == "s3://openmeteo/data_spatial/ncep_gfs025/latest_model-level.json")
    }

    @Test func s3BucketEndpointParsesModelProfilesAndCredentialOverrides() throws {
        let endpoints = S3BucketEndpoint.parseList(
            "openmeteo,s3://MODEL/@ceph,https://user:pw@example.com/bucket/@aws",
            domain: .ncep_gfs025
        )

        #expect(endpoints == [
            S3BucketEndpoint(rawEndpoint: "openmeteo", profile: nil),
            S3BucketEndpoint(rawEndpoint: "s3://ncep-gfs025/", profile: "ceph"),
            S3BucketEndpoint(rawEndpoint: "https://user:pw@example.com/bucket/", profile: "aws")
        ])

        setenv("S3_CREDENTIALS_OPENMETEO_AWS", "s3://credential-bucket/", 1)
        defer { unsetenv("S3_CREDENTIALS_OPENMETEO_AWS") }

        #expect(S3BucketEndpoint.parseList("openmeteo@aws", domain: .ncep_gfs025) == [
            S3BucketEndpoint(rawEndpoint: "s3://credential-bucket/", profile: "aws")
        ])
    }

    @Test func s3BucketEndpointListRedactsMultipleCredentialedEndpoints() throws {
        let endpoints = S3BucketEndpointList(
            "s3://user1:pw1@bucket-a/@aws,https://user2:pw2@example.com/bucket/@ceph",
            domain: .ncep_gfs025
        )

        #expect(String(describing: endpoints) == "s3://bucket-a/,https://example.com/bucket/")
        #expect(!String(describing: endpoints).contains("user1"))
        #expect(!String(describing: endpoints).contains("pw1"))
        #expect(!String(describing: endpoints).contains("user2"))
        #expect(!String(describing: endpoints).contains("pw2"))
    }

    @Test func s3BucketEndpointListRedactsCredentialOverrides() throws {
        setenv("S3_CREDENTIALS_OPENMETEO_AWS", "s3://override-user:override-pw@credential-bucket/", 1)
        defer { unsetenv("S3_CREDENTIALS_OPENMETEO_AWS") }

        let endpoints = S3BucketEndpointList("openmeteo@aws", domain: .ncep_gfs025)

        #expect(String(describing: endpoints) == "s3://credential-bucket/")
        #expect(!String(describing: endpoints).contains("override-user"))
        #expect(!String(describing: endpoints).contains("override-pw"))
    }

    @Test func s3SyncManagerSerializesSyncsPerEndpointAndRunsEndpointsIndependently() async throws {
        let probe = S3SyncManagerProbe()
        let manager = S3SyncManager(
            logger: Logger(label: "DownloaderTests.S3SyncManager"),
            syncDirectory: { target in
                try await probe.sync(target: target)
            }
        )

        await manager.sync(s3UploadSyncTarget(endpoint: "s3://slow-bucket/", name: "slow-0"))
        await manager.sync(s3UploadSyncTarget(endpoint: "s3://slow-bucket/", name: "slow-1"))
        await manager.sync(s3UploadSyncTarget(endpoint: "s3://fast-bucket/", name: "fast-0"))
        await manager.shutdown()

        let events = await probe.events
        let slowSecondStart = try #require(events.firstIndex(of: "start:s3://slow-bucket/:data/slow-1"))
        let slowFirstEnd = try #require(events.firstIndex(of: "end:s3://slow-bucket/:data/slow-0"))
        #expect(slowSecondStart > slowFirstEnd)
        #expect(await probe.maxActiveByEndpoint == [
            "s3://slow-bucket/": 1,
            "s3://fast-bucket/": 1
        ])
        #expect(await probe.maxTotalActive > 1)
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

private func s3UploadSyncTarget(endpoint: String, name: String) -> S3UploadSyncTarget {
    S3UploadSyncTarget(
        bucketEndpoint: S3BucketEndpoint(rawEndpoint: endpoint, profile: nil),
        localDirectory: "/tmp/\(name)",
        basePath: "data/\(name)"
    )
}

private func s3Endpoints(_ buckets: String, domain: DomainRegistry = .ncep_gfs025) -> S3BucketEndpointList {
    return S3BucketEndpointList(buckets, domain: domain)
}

private actor S3SyncManagerProbe {
    private var recordedEvents: [String] = []
    private var activeByEndpoint: [String: Int] = [:]
    private var maxActive: [String: Int] = [:]
    private var maxTotal = 0

    var events: [String] {
        recordedEvents
    }

    var maxActiveByEndpoint: [String: Int] {
        maxActive
    }

    var maxTotalActive: Int {
        maxTotal
    }

    func sync(target: S3UploadSyncTarget) async throws {
        let endpoint = target.bucketEndpoint.description
        activeByEndpoint[endpoint, default: 0] += 1
        maxActive[endpoint] = max(maxActive[endpoint, default: 0], activeByEndpoint[endpoint, default: 0])
        maxTotal = max(maxTotal, activeByEndpoint.values.reduce(0, +))
        recordedEvents.append("start:\(endpoint):\(target.basePath)")
        try await Task.sleep(nanoseconds: 50_000_000)
        recordedEvents.append("end:\(endpoint):\(target.basePath)")
        activeByEndpoint[endpoint, default: 0] -= 1
    }
}
