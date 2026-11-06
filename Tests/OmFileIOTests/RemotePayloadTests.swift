import Testing
@testable import OmFileIO
import OmTime

private actor PrefetchGate {
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

    private init(version: String, gate: PrefetchGate) {
        self.version = version
        self.gate = gate
    }

    func updateMetaData(file: OmHttpReaderBackend) async throws -> Self {
        Self(version: file.eTag, gate: gate)
    }

    func prefetchBackground(from previous: any OmRemotePayload) async throws {
        await gate.run()
        if version == "\"failure\"" { throw CancellationError() }
    }

    func remoteDeleted() async throws {}
}

struct RemotePayloadTests {
    @Test func modifiedBackendRejectsReadsWithoutContactingServer() async throws {
        // With no endpoints, attempting network access would fail with a server selection error.
        let context = S3ServerHealth(logger: .init(label: "test"), servers: [], checksHealth: false)
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
        let context = S3ServerHealth(logger: .init(label: "test"), servers: [], checksHealth: false)
        let file = OmFileSystemS3.File(objectName: "test.om", contentLength: 1, lastModified: Timestamp(0), eTag: "\"old\"")
        let old = try #require(await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false))
        let version = prefetchFails ? "\"failure\"" : "\"new\""
        await file.updateFromDirectoryListing(context: context, objectKey: "test.om", contentLength: 2, lastModified: Timestamp(1), eTag: version)
        await old.gate.waitUntilStarted()

        // Cached requests keep using the old version while retries can use the new metadata.
        #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)?.version == "\"old\"")
        #expect(try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: true)?.version == version)
        await old.gate.finish()

        // Failed optional prefetch must also publish the new payload for on-demand reads.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while try await file.getPayload(ofType: TestRemotePayload.self, context: context, receivedFileModifiedError: false)?.version != version {
            try #require(ContinuousClock.now < deadline)
            await Task.yield()
        }
    }
}
