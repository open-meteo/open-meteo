import Testing
import Vapor
import Synchronization
@testable import OmFileIO
import OmTime

private actor PrefetchGate {
    private(set) var deletions = 0

    func deleted() { deletions += 1 }

    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var completion: CheckedContinuation<Void, Never>?

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func run() async {
        await withCheckedContinuation { continuation in
            completion = continuation
            started = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}

private struct TestRemotePayload: OmRemotePayload {
    let version: String
    let gate: PrefetchGate

    init(file: OmHttpReaderBackend) {
        version = file.eTag
        gate = PrefetchGate()
    }

    func updateMetaData(file: OmHttpReaderBackend) async throws -> Self {
        Self(file: file)
    }

    func prefetchBackground(from previous: any OmRemotePayload) async throws {
        await gate.run()
        if version == "\"failure\"" { throw CancellationError() }
    }

    func remoteDeleted() async throws { await gate.deleted() }
}

struct RemotePayloadTests {
    @Test func modifiedBackendRejectsReadsWithoutContactingServer() async throws {
        // With no endpoints, attempting network access would fail with a server selection error.
        let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [], checksHealth: false)
        let backend = OmHttpReaderBackend(context: context, object: "test.om", count: 1, eTag: "\"old\"", lastModified: Timestamp(0))
        backend.markModified()

        for _ in 0..<2 {
            do {
                _ = try await backend.getData(offset: 0, count: 1)
                Issue.record("A modified backend must reject reads")
            } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {}
        }
        do {
            _ = try await backend.withData(offset: 0, count: 1) { $0.count }
            Issue.record("A modified backend must reject reads")
        } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {}
    }

    @Test(arguments: [false, true])
    func metadataAvailableBeforePrefetchFinishes(prefetchFails: Bool) async throws {
        let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [], checksHealth: false)
        let file = OmFileSystemS3.File(objectName: "test.om", contentLength: 1, lastModified: Timestamp(0), eTag: "\"old\"")
        _ = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false))
        let version = prefetchFails ? "\"failure\"" : "\"new\""
        await file.updateFromDirectoryListing(context: context, objectKey: "test.om", contentLength: 2, lastModified: Timestamp(1), eTag: version)
        let new = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: true))
        await new.gate.waitUntilStarted()

        // Cached requests keep using the old version while retries can use the new metadata.
        #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)?.version == "\"old\"")
        #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: true)?.version == version)
        await new.gate.finish()

        // Failed optional prefetch must also publish the new payload for on-demand reads.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)?.version != version {
            try #require(ContinuousClock.now < deadline)
            await Task.yield()
        }
    }

    @Test(arguments: [false, true])
    func deletionRetiresRetainedPayloads(prefetching: Bool) async throws {
        let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [], checksHealth: false)
        let file = OmFileSystemS3.File(objectName: "test.om", contentLength: 1, lastModified: Timestamp(0), eTag: "\"old\"")
        let old = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false))
        var new: TestRemotePayload?
        if prefetching {
            await file.updateFromDirectoryListing(context: context, objectKey: "test.om", contentLength: 2, lastModified: Timestamp(1), eTag: "\"new\"")
            new = try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: true)
            await new?.gate.waitUntilStarted()
        }
        let result: Int? = try await OmFileSystemS3.FileWithContext(file: file, context: context).with { (_: TestRemotePayload) in
            throw CurlError.fileNotFound
        }
        #expect(result == nil)
        await file.receivedObjectDeletedError(context: context)
        #expect(await old.gate.deletions == 1)
        if let new {
            #expect(await new.gate.deletions == 1)
            await new.gate.finish()
        }
        #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false) == nil)
    }

    @Test func inventoryRemovalNotifiesPayload() async throws {
        let app = try await Application.make(.testing)
        let deleted = Mutex(false)
        do {
            app.get { _ -> String in
                if deleted.withLock({ $0 }) { return "<ListBucketResult/>" }
                return """
                <ListBucketResult><Contents><Key>test.om</Key><Size>1</Size>
                <LastModified>2026-11-11T12:00:00.000Z</LastModified>
                <ETag>&quot;old&quot;</ETag></Contents></ListBucketResult>
                """
            }
            try await app.http.server.shared.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [
                .init(rawEndpoint: "http://127.0.0.1:\(port)/", profile: nil)
            ], checksHealth: false)
            let directory = OmFileSystemS3.Directory(prefix: "")
            try await directory.update(context: context)
            let file = try #require(await directory.getFile(name: "test.om"))
            let payload = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false))
            deleted.withLock { $0 = true }
            try await directory.update(context: context)
            #expect(await directory.getFile(name: "test.om") == nil)
            #expect(await payload.gate.deletions == 1)
            #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false) == nil)
        } catch {
            await app.http.server.shared.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.http.server.shared.shutdown()
        try await app.asyncShutdown()
    }

    @Test func retiredDirectoryDiscardsInFlightListing() async throws {
        let app = try await Application.make(.testing)
        let state = Mutex((removed: false, hold: false))
        let gate = PrefetchGate()
        do {
            app.get { request async -> String in
                let current = state.withLock { $0 }
                if request.query[String.self, at: "prefix"] == "child/" {
                    if current.hold { await gate.run() }
                    return """
                    <ListBucketResult><Contents><Key>child/test.om</Key><Size>1</Size>
                    <LastModified>2026-11-11T12:00:00.000Z</LastModified>
                    <ETag>&quot;old&quot;</ETag></Contents>
                    <CommonPrefixes><Prefix>child/nested/</Prefix></CommonPrefixes></ListBucketResult>
                    """
                }
                return current.removed ? "<ListBucketResult/>" : "<ListBucketResult><CommonPrefixes><Prefix>child/</Prefix></CommonPrefixes></ListBucketResult>"
            }
            try await app.http.server.shared.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [
                .init(rawEndpoint: "http://127.0.0.1:\(port)/", profile: nil)
            ], checksHealth: false)
            let parent = OmFileSystemS3.Directory(prefix: "")
            try await parent.update(context: context)
            let child = try #require(await parent.getDirectory(name: "child", context: context))
            let file = try #require(await child.getFile(name: "test.om"))
            let payload = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false))
            state.withLock { $0 = (removed: true, hold: true) }
            let updating = Task { try await child.update(context: context) }
            await gate.waitUntilStarted()
            try await parent.update(context: context)
            await gate.finish()
            try await updating.value
            #expect(await payload.gate.deletions == 1)
            #expect(await child.getFile(name: "test.om") == nil)
            #expect(try await child.getDirectory(name: "nested", context: context) == nil)
            // A retired actor must not issue another listing, which would block on the gate.
            try await child.update(context: context)
            #expect(await child.getFile(name: "test.om") == nil)
        } catch {
            await gate.finish()
            await app.http.server.shared.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.http.server.shared.shutdown()
        try await app.asyncShutdown()
    }

    @Test func staleReplacementRefreshesWhilePrefetchIsPending() async throws {
        let app = try await Application.make(.testing)
        do {
            app.on(.HEAD, "test.om") { _ -> Response in
                Response(status: .ok, headers: [
                    "Content-Length": "3", "ETag": "\"latest\"",
                    "Last-Modified": "Wed, 11 Nov 2026 12:00:00 GMT"
                ])
            }
            try await app.http.server.shared.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let context = S3ServerHealth(client: .shared, logger: .init(label: "test"), servers: [
                .init(rawEndpoint: "http://127.0.0.1:\(port)/", profile: nil)
            ], checksHealth: false)
            let file = OmFileSystemS3.File(objectName: "test.om", contentLength: 1, lastModified: Timestamp(0), eTag: "\"old\"")
            _ = try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)
            await file.updateFromDirectoryListing(context: context, objectKey: "test.om", contentLength: 2, lastModified: Timestamp(1), eTag: "\"new\"")
            let pending = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: true))
            await pending.gate.waitUntilStarted()

            let latest = try #require(await OmFileSystemS3.FileWithContext(file: file, context: context).with { (payload: TestRemotePayload) in
                guard payload.version == "\"latest\"" else {
                    throw CurlErrorNonRetry.fileModifiedOrPrevalidationFailed
                }
                return payload
            })
            await latest.gate.waitUntilStarted()
            #expect(latest.version == "\"latest\"")
            // Finishing the superseded task must not publish its stale replacement.
            await pending.gate.finish()
            await latest.gate.finish()
            let deadline = ContinuousClock.now.advanced(by: .seconds(60))
            while try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)?.version != latest.version {
                try #require(ContinuousClock.now < deadline)
                try await Task.sleep(for: .milliseconds(1))
            }
        } catch {
            await app.http.server.shared.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.http.server.shared.shutdown()
        try await app.asyncShutdown()
    }
}
