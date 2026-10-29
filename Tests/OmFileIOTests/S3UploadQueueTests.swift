import AsyncHTTPClient
import Synchronization
import Testing
@testable import OmFileIO

@Suite(.timeLimit(.minutes(1)))
struct S3UploadQueueTests {
    enum Failure: Error { case injected }

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
