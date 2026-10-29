import AsyncHTTPClient
import Synchronization
import Testing
@testable import OmFileIO

@Suite(.timeLimit(.minutes(1)))
struct S3UploadQueueTests {
    enum Failure: Error { case injected }

    @Test func immediateCommitDoesNotWaitForOtherFilesOrSessionCompletion() async {
        let failures = Atomic<Int>(0)
        let committed = AsyncStream<Void>.makeStream()
        let releaseSlowUpload = AsyncStream<Void>.makeStream()
        let session = S3MultiFileUploadQueue(
            endpoint: .init(rawEndpoint: "s3://test/", profile: nil), client: .shared,
            onError: { failures.wrappingAdd(1, ordering: .relaxed) },
            maxConcurrentFiles: 2, maxConcurrentPartUploads: 1
        )
        await session.enqueuePreparation {
            for await _ in releaseSlowUpload.stream { break }
            return S3MultiPartUploadPrepared(etags: [], url: "https://example.com/slow", encodedUploadId: "slow", lastModified: .init(0))
        }
        await session.enqueuePreparation(commit: { prepared in
            #expect(prepared.encodedUploadId == "fast")
            committed.continuation.yield(())
        }) {
            S3MultiPartUploadPrepared(etags: [], url: "https://example.com/fast", encodedUploadId: "fast", lastModified: .init(0))
        }
        // Publication must happen before we release the other file or finish the session.
        var notifications = committed.stream.makeAsyncIterator()
        _ = await notifications.next()
        await session.enqueuePreparation { throw Failure.injected }
        releaseSlowUpload.continuation.yield(())
        releaseSlowUpload.continuation.finish()
        committed.continuation.finish()
        let prepared = await session.finishPreparations()
        // A later failure cannot cause the published file to be committed again or aborted.
        #expect(prepared.map(\.encodedUploadId) == ["slow"])
        #expect(failures.load(ordering: .relaxed) == 1)
    }

    @Test(arguments: [false, true])
    func drainsPreparationsDuringProduction(ignoreFailure: Bool) async {
        let failures = Atomic<Int>(0)
        let session = S3MultiFileUploadQueue(
            endpoint: .init(rawEndpoint: "s3://test/", profile: nil), client: .shared,
            onError: { failures.wrappingAdd(1, ordering: .relaxed) },
            maxConcurrentFiles: 1, maxConcurrentPartUploads: 1
        )
        // More results than queue capacity must drain before finish is called.
        // A failed preparation must not discard successful uploads needed for commit or abort.
        for index in 0..<8 {
            await session.enqueuePreparation {
                if ignoreFailure && index == 3 { throw Failure.injected }
                return S3MultiPartUploadPrepared(
                    etags: [], url: "https://example.com/\(index)",
                    encodedUploadId: "\(index)", lastModified: .init(0)
                )
            }
        }
        let prepared = await session.finishPreparations()
        let expected = (0..<8).filter { !ignoreFailure || $0 != 3 }.map { "\($0)" }
        #expect(prepared.map(\.encodedUploadId).sorted() == expected)
        #expect(failures.load(ordering: .relaxed) == (ignoreFailure ? 1 : 0))
    }
}
