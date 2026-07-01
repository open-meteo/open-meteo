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
            buckets: "s3://aws-bucket/@aws",
            localFile: "/tmp/chunk_1.om",
            remotePath: "data/ncep_gfs025/temperature_2m/chunk_1.om"
        )

        #expect(targets == [
            S3UploadTarget(
                bucketEndpoint: "s3://aws-bucket/",
                localFile: "/tmp/chunk_1.om",
                url: "s3://aws-bucket/data/ncep_gfs025/temperature_2m/chunk_1.om",
                contentType: "application/octet-stream"
            )
        ])
    }

    @Test func s3UploadPlanSkipsPreviousDayForAwsProfileAndDefaultOpenmeteo() throws {
        let targets = S3UploadPlan.targets(
            domain: .ncep_gfs025,
            buckets: "openmeteo,s3://aws-bucket/@aws,s3://ceph-bucket/@ceph",
            localFile: "/tmp/chunk_1.om",
            remotePath: "data/ncep_gfs025/temperature_2m_previous_day1/chunk_1.om",
            kind: .previousDay
        )

        #expect(targets == [
            S3UploadTarget(
                bucketEndpoint: "s3://ceph-bucket/",
                localFile: "/tmp/chunk_1.om",
                url: "s3://ceph-bucket/data/ncep_gfs025/temperature_2m_previous_day1/chunk_1.om",
                contentType: "application/octet-stream"
            )
        ])
    }

    @Test func s3UploadPlanUsesDataRunPrefix() throws {
        let targets = S3UploadPlan.targets(
            domain: .ncep_gfs025,
            buckets: "openmeteo",
            localFile: "/tmp/temperature_2m.om",
            remotePath: "data_run/ncep_gfs025/20260101/00/temperature_2m.om"
        )

        #expect(targets.first?.url == "s3://openmeteo/data_run/ncep_gfs025/20260101/00/temperature_2m.om")
    }

    @Test func s3UploadPlanBuildsStaticSyncTargetsWithoutMetaJson() throws {
        let targets = S3UploadPlan.staticSyncTargets(
            buckets: "openmeteo,s3://ceph-bucket/@ceph",
            domain: .ncep_gfs025
        )

        #expect(targets == [
            S3UploadSyncTarget(
                bucketEndpoint: "openmeteo",
                localDirectory: "\(DomainRegistry.ncep_gfs025.directory)static",
                server: "openmeteo",
                basePath: "data/ncep_gfs025/static",
                exclude: [".*", "*~", "meta.json"]
            ),
            S3UploadSyncTarget(
                bucketEndpoint: "s3://ceph-bucket/",
                localDirectory: "\(DomainRegistry.ncep_gfs025.directory)static",
                server: "s3://ceph-bucket/",
                basePath: "data/ncep_gfs025/static",
                exclude: [".*", "*~", "meta.json"]
            )
        ])
    }

    @Test func s3UploadPlanFormatsSpatialRealmSuffixes() throws {
        let run = Timestamp(2026, 1, 1, 0)
        let time = Timestamp(2026, 1, 1, 3)
        let data = ByteBuffer(string: "{}").readableBytesView

        let defaultFile = S3UploadPlan.targets(
            buckets: "openmeteo",
            artifact: .spatialFile(
                domain: .ncep_gfs025,
                localFile: "/tmp/2026-01-01T0300.om",
                run: run,
                time: time,
                realm: nil
            )
        )
        #expect(defaultFile.first?.url == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/2026-01-01T0300.om")

        let realmFile = S3UploadPlan.targets(
            buckets: "openmeteo",
            artifact: .spatialFile(
                domain: .ncep_gfs025,
                localFile: "/tmp/2026-01-01T0300_model-level.om",
                run: run,
                time: time,
                realm: "model-level"
            )
        )
        #expect(realmFile.first?.url == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/2026-01-01T0300_model-level.om")

        let defaultMeta = S3UploadPlan.targets(
            buckets: "openmeteo",
            artifact: .spatialMeta(
                domain: .ncep_gfs025,
                localFile: "/tmp/meta.json",
                remote: .run(run: run, realm: nil),
                data: data
            )
        )
        #expect(defaultMeta.first?.url == "s3://openmeteo/data_spatial/ncep_gfs025/2026/01/01/0000Z/meta.json")

        let realmMeta = S3UploadPlan.targets(
            buckets: "openmeteo",
            artifact: .spatialMeta(
                domain: .ncep_gfs025,
                localFile: "/tmp/meta_model-level.json",
                remote: .latest(realm: "model-level"),
                data: data
            )
        )
        #expect(realmMeta.first?.url == "s3://openmeteo/data_spatial/ncep_gfs025/latest_model-level.json")
    }

    @Test func s3BucketEndpointParsesModelProfilesAndCredentialOverrides() throws {
        let endpoints = S3BucketEndpoint.parseList(
            "openmeteo,s3://MODEL/@ceph,https://user:pw@example.com/bucket/@aws",
            domain: .ncep_gfs025
        )

        #expect(endpoints == [
            S3BucketEndpoint(bucket: "openmeteo", profile: nil),
            S3BucketEndpoint(bucket: "s3://ncep-gfs025/", profile: "ceph"),
            S3BucketEndpoint(bucket: "https://user:pw@example.com/bucket/", profile: "aws")
        ])

        setenv("S3_CREDENTIALS_OPENMETEO_AWS", "s3://credential-bucket/", 1)
        defer { unsetenv("S3_CREDENTIALS_OPENMETEO_AWS") }

        #expect(S3BucketEndpoint.parseList("openmeteo@aws", domain: .ncep_gfs025) == [
            S3BucketEndpoint(bucket: "s3://credential-bucket/", profile: "aws")
        ])
    }

    @Test func s3UploadSessionLimitsFileUploadsPerEndpoint() async throws {
        let slowEndpoint = "s3://slow-bucket/"
        let fastEndpoint = "s3://fast-bucket/"
        let probe = S3UploadSessionSchedulerProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            maxConcurrentFileUploads: 2,
            prepareMultipartUpload: { target in
                await probe.prepare(target: target)
            },
            commitMultipartUpload: { _ in },
            syncDirectory: { _ in },
            uploadMetadata: { _, _ in }
        )

        do {
            for index in 0..<4 {
                await session.uploadMultipart(s3UploadTarget(endpoint: slowEndpoint, name: "slow-\(index)"))
            }
            try await waitForStarted(probe: probe, endpoint: slowEndpoint, count: 2, timeoutSeconds: 2)

            for index in 0..<2 {
                await session.uploadMultipart(s3UploadTarget(endpoint: fastEndpoint, name: "fast-\(index)"))
            }
            try await waitForStarted(probe: probe, endpoint: fastEndpoint, count: 2, timeoutSeconds: 2)

            let maxActiveByEndpoint = await probe.getMaxActiveByEndpoint()
            #expect(maxActiveByEndpoint[slowEndpoint] == 2)
            #expect(maxActiveByEndpoint[fastEndpoint] == 2)
            #expect(await probe.getMaxTotalActive() == 4)

            await probe.release()
            try await session.finish()
        } catch {
            await probe.release()
            try? await session.finish()
            throw error
        }
    }

    @Test func s3UploadSessionSyncsStaticBeforeMetadata() async throws {
        let probe = S3UploadSessionOrderProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            prepareMultipartUpload: { target in
                await probe.record("prepare:\(target.url)")
                return S3MultiPartUploadPrepared(etags: ["etag"], url: target.url, encodedUploadId: "upload-id")
            },
            commitMultipartUpload: { prepared in
                await probe.record("commit:\(prepared.url)")
            },
            syncDirectory: { target in
                await probe.record("sync:\(target.basePath)")
            },
            uploadMetadata: { target, _ in
                await probe.record("metadata:\(target.url)")
            }
        )

        await session.uploadMultipart(s3UploadTarget(endpoint: "s3://bucket/", name: "chunk"))
        await session.upload(.syncBeforeMetadata(S3UploadSyncTarget(
            bucketEndpoint: "s3://bucket/",
            localDirectory: "/tmp/static",
            server: "s3://bucket/",
            basePath: "data/ncep_gfs025/static",
            exclude: [".*", "*~", "meta.json"]
        )))
        await session.uploadMetadataAfterCommits(
            S3UploadTarget(
                bucketEndpoint: "s3://bucket/",
                localFile: "/tmp/meta.json",
                url: "s3://bucket/data/ncep_gfs025/static/meta.json",
                contentType: "application/json"
            ),
            data: ByteBuffer(string: "{}").readableBytesView
        )

        try await session.finish()

        #expect(await probe.events == [
            "prepare:s3://bucket/data/chunk.om",
            "commit:s3://bucket/data/chunk.om",
            "sync:data/ncep_gfs025/static",
            "metadata:s3://bucket/data/ncep_gfs025/static/meta.json"
        ])
    }

    @Test func s3UploadSessionCommitsHealthyEndpointAfterPrepareFailure() async throws {
        let goodEndpoint = "s3://good-bucket/"
        let badEndpoint = "s3://bad-bucket/"
        let probe = S3UploadSessionOrderProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            prepareMultipartUpload: { target in
                await probe.record("prepare:\(target.url)")
                if target.bucketEndpoint == badEndpoint {
                    throw TestS3UploadError.failed
                }
                return S3MultiPartUploadPrepared(etags: ["etag"], url: target.url, encodedUploadId: "upload-id")
            },
            commitMultipartUpload: { prepared in
                await probe.record("commit:\(prepared.url)")
            },
            syncDirectory: { target in
                await probe.record("sync:\(target.basePath)")
            },
            uploadMetadata: { target, _ in
                await probe.record("metadata:\(target.url)")
            }
        )

        await session.uploadMultipart(s3UploadTarget(endpoint: badEndpoint, name: "bad"))
        await session.uploadMultipart(s3UploadTarget(endpoint: goodEndpoint, name: "good"))
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: badEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: goodEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )

        do {
            try await session.finish()
            Issue.record("Expected S3UploadSessionError")
        } catch let error as S3UploadSessionError {
            #expect(error.failures.count == 1)
            #expect(error.failures.first?.contains("prepare") == true)
        }

        let events = await probe.events
        #expect(events.contains("commit:s3://good-bucket/data/good.om"))
        #expect(events.contains("metadata:s3://good-bucket/data/meta.om"))
        #expect(!events.contains("metadata:s3://bad-bucket/data/meta.om"))
    }

    @Test func s3UploadSessionAbortsPreparedUploadsForEndpointAfterPrepareFailure() async throws {
        let goodEndpoint = "s3://good-bucket/"
        let badEndpoint = "s3://bad-bucket/"
        let probe = S3UploadSessionOrderProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            maxConcurrentFileUploads: 1,
            prepareMultipartUpload: { target in
                await probe.record("prepare:\(target.url)")
                if target.url.hasSuffix("/data/fails.om") {
                    throw TestS3UploadError.failed
                }
                return S3MultiPartUploadPrepared(etags: ["etag"], url: target.url, encodedUploadId: "upload-id")
            },
            commitMultipartUpload: { prepared in
                await probe.record("commit:\(prepared.url)")
            },
            abortMultipartUpload: { prepared in
                await probe.record("abort:\(prepared.url)")
            },
            syncDirectory: { target in
                await probe.record("sync:\(target.basePath)")
            },
            uploadMetadata: { target, _ in
                await probe.record("metadata:\(target.url)")
            }
        )

        await session.uploadMultipart(s3UploadTarget(endpoint: badEndpoint, name: "prepared"))
        await session.uploadMultipart(s3UploadTarget(endpoint: badEndpoint, name: "fails"))
        await session.uploadMultipart(s3UploadTarget(endpoint: goodEndpoint, name: "good"))
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: badEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: goodEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )

        do {
            try await session.finish()
            Issue.record("Expected S3UploadSessionError")
        } catch let error as S3UploadSessionError {
            #expect(error.failures.count == 1)
            #expect(error.failures.first?.contains("prepare") == true)
        }

        let events = await probe.events
        #expect(events.contains("abort:s3://bad-bucket/data/prepared.om"))
        #expect(!events.contains("commit:s3://bad-bucket/data/prepared.om"))
        #expect(!events.contains("metadata:s3://bad-bucket/data/meta.om"))
        #expect(events.contains("commit:s3://good-bucket/data/good.om"))
        #expect(events.contains("metadata:s3://good-bucket/data/meta.om"))
    }

    @Test func s3UploadSessionContinuesCommitsAfterCommitFailure() async throws {
        let goodEndpoint = "s3://good-bucket/"
        let badEndpoint = "s3://bad-bucket/"
        let probe = S3UploadSessionOrderProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            prepareMultipartUpload: { target in
                await probe.record("prepare:\(target.url)")
                return S3MultiPartUploadPrepared(etags: ["etag"], url: target.url, encodedUploadId: "upload-id")
            },
            commitMultipartUpload: { prepared in
                await probe.record("commit:\(prepared.url)")
                if prepared.url.hasPrefix(badEndpoint) {
                    throw TestS3UploadError.failed
                }
            },
            syncDirectory: { target in
                await probe.record("sync:\(target.basePath)")
            },
            uploadMetadata: { target, _ in
                await probe.record("metadata:\(target.url)")
            }
        )

        await session.uploadMultipart(s3UploadTarget(endpoint: badEndpoint, name: "bad"))
        await session.uploadMultipart(s3UploadTarget(endpoint: goodEndpoint, name: "good"))
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: badEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: goodEndpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )

        do {
            try await session.finish()
            Issue.record("Expected S3UploadSessionError")
        } catch let error as S3UploadSessionError {
            #expect(error.failures.count == 1)
            #expect(error.failures.first?.contains("commit") == true)
        }

        let events = await probe.events
        #expect(events.contains("commit:s3://bad-bucket/data/bad.om"))
        #expect(events.contains("commit:s3://good-bucket/data/good.om"))
        #expect(events.contains("metadata:s3://good-bucket/data/meta.om"))
        #expect(!events.contains("metadata:s3://bad-bucket/data/meta.om"))
    }

    @Test func s3UploadSessionCancelAbortsPreparedUploadsAndSkipsPublishSteps() async throws {
        let endpoint = "s3://bucket/"
        let scheduler = S3UploadSessionSchedulerProbe()
        let order = S3UploadSessionOrderProbe()
        let session = S3UploadSession(
            logger: Logger(label: "DownloaderTests.S3UploadSession"),
            maxConcurrentFileUploads: 1,
            prepareMultipartUpload: { target in
                await order.record("prepare:\(target.url)")
                return await scheduler.prepare(target: target)
            },
            commitMultipartUpload: { prepared in
                await order.record("commit:\(prepared.url)")
            },
            abortMultipartUpload: { prepared in
                await order.record("abort:\(prepared.url)")
            },
            syncDirectory: { target in
                await order.record("sync:\(target.basePath)")
            },
            uploadMetadata: { target, _ in
                await order.record("metadata:\(target.url)")
            }
        )

        await session.uploadMultipart(s3UploadTarget(endpoint: endpoint, name: "started"))
        await session.uploadMultipart(s3UploadTarget(endpoint: endpoint, name: "queued"))
        await session.upload(.syncBeforeMetadata(S3UploadSyncTarget(
            bucketEndpoint: endpoint,
            localDirectory: "/tmp/static",
            server: endpoint,
            basePath: "data/ncep_gfs025/static"
        )))
        await session.uploadMetadataAfterCommits(
            s3UploadTarget(endpoint: endpoint, name: "meta"),
            data: ByteBuffer(string: "{}").readableBytesView
        )
        try await waitForStarted(probe: scheduler, endpoint: endpoint, count: 1, timeoutSeconds: 2)

        let cancelTask = Task {
            await session.cancel()
        }
        await scheduler.release()
        await cancelTask.value

        await session.cancel()
        try await session.finish()

        #expect(await order.events == [
            "prepare:s3://bucket/data/started.om",
            "abort:s3://bucket/data/started.om"
        ])
    }

    @Test func s3UploadManagerSerializesSyncsPerEndpointAndRunsEndpointsIndependently() async throws {
        let probe = S3UploadManagerProbe()
        let manager = S3UploadManager(
            logger: Logger(label: "DownloaderTests.S3UploadManager"),
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

private func s3UploadTarget(endpoint: String, name: String) -> S3UploadTarget {
    S3UploadTarget(
        bucketEndpoint: endpoint,
        localFile: "/tmp/\(name).om",
        url: "\(endpoint)data/\(name).om",
        contentType: "application/octet-stream"
    )
}

private func s3UploadSyncTarget(endpoint: String, name: String) -> S3UploadSyncTarget {
    S3UploadSyncTarget(
        bucketEndpoint: endpoint,
        localDirectory: "/tmp/\(name)",
        server: endpoint,
        basePath: "data/\(name)"
    )
}

private enum TestTimeoutError: Error {
    case timedOut
}

private enum TestS3UploadError: Error {
    case failed
}

private func waitForStarted(probe: S3UploadSessionSchedulerProbe, endpoint: String, count: Int, timeoutSeconds: Double) async throws {
    let stepNanoseconds: UInt64 = 10_000_000
    let maxAttempts = Int(timeoutSeconds * 1_000_000_000 / Double(stepNanoseconds))
    for _ in 0..<maxAttempts {
        if await probe.getStarted(endpoint: endpoint) >= count {
            return
        }
        try await Task.sleep(nanoseconds: stepNanoseconds)
    }
    throw TestTimeoutError.timedOut
}

private actor S3UploadSessionSchedulerProbe {
    private var startedByEndpoint: [String: Int] = [:]
    private var activeByEndpoint: [String: Int] = [:]
    private var maxActiveByEndpoint: [String: Int] = [:]
    private var maxTotalActive = 0
    private var isReleased = false
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func prepare(target: S3UploadTarget) async -> S3MultiPartUploadPrepared {
        let endpoint = target.bucketEndpoint
        startedByEndpoint[endpoint, default: 0] += 1
        activeByEndpoint[endpoint, default: 0] += 1
        maxActiveByEndpoint[endpoint] = max(maxActiveByEndpoint[endpoint, default: 0], activeByEndpoint[endpoint, default: 0])
        maxTotalActive = max(maxTotalActive, activeByEndpoint.values.reduce(0, +))

        if !isReleased {
            await withCheckedContinuation { continuation in
                releaseContinuations.append(continuation)
            }
        }

        activeByEndpoint[endpoint, default: 0] -= 1
        return S3MultiPartUploadPrepared(etags: ["etag"], url: target.url, encodedUploadId: "upload-id")
    }

    func release() {
        isReleased = true
        let continuations = releaseContinuations
        releaseContinuations.removeAll(keepingCapacity: true)
        for continuation in continuations {
            continuation.resume()
        }
    }

    func getMaxActiveByEndpoint() -> [String: Int] {
        maxActiveByEndpoint
    }

    func getMaxTotalActive() -> Int {
        maxTotalActive
    }

    func getStarted(endpoint: String) -> Int {
        startedByEndpoint[endpoint, default: 0]
    }
}

private actor S3UploadSessionOrderProbe {
    private var recordedEvents: [String] = []

    var events: [String] {
        recordedEvents
    }

    func record(_ event: String) {
        recordedEvents.append(event)
    }
}

private actor S3UploadManagerProbe {
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
        let endpoint = target.bucketEndpoint
        activeByEndpoint[endpoint, default: 0] += 1
        maxActive[endpoint] = max(maxActive[endpoint, default: 0], activeByEndpoint[endpoint, default: 0])
        maxTotal = max(maxTotal, activeByEndpoint.values.reduce(0, +))
        recordedEvents.append("start:\(endpoint):\(target.basePath)")
        try await Task.sleep(nanoseconds: 50_000_000)
        recordedEvents.append("end:\(endpoint):\(target.basePath)")
        activeByEndpoint[endpoint, default: 0] -= 1
    }
}
