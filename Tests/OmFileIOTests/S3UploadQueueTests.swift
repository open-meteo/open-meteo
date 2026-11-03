import Foundation
import NIOCore
import OmFileFormat
import AsyncHTTPClient
import Synchronization
import Testing
import Vapor
@testable import OmFileIO

@Suite(.timeLimit(.minutes(1)))
struct S3UploadQueueTests {
    enum Failure: Error { case injected }

    @Test(arguments: ["", "temporary forecast data"])
    func unlinkedTemporaryFileSupportsIndependentUploadReaders(contents: String) async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: "\(path)~") }
        let expected = Array(contents.utf8)
        func prepareChunks() throws -> FileHandle.ByteBufferSequence {
            let file = try FileHandle.createNewFile(file: path, temporary: true)
            if !file.wasDeleted() {
                try FileManager.default.removeItem(atPath: "\(path)~")
            }
            try file.write(contentsOf: Data(expected))
            #expect(file.wasDeleted())
            return file.readChunks(chunkLength: .bytes(3))
        }
        // Only the sequence now retains the file handle.
        let chunks = try prepareChunks()
        #expect(!FileManager.default.fileExists(atPath: path))
        #expect(!FileManager.default.fileExists(atPath: "\(path)~"))
        try await withThrowingTaskGroup(of: [UInt8].self) { group in
            for _ in 0..<2 {
                group.addTask {
                    var bytes: [UInt8] = []
                    for try await chunk in chunks {
                        #expect(chunk.readableBytes <= 3)
                        bytes.append(contentsOf: chunk.readableBytesView)
                    }
                    return bytes
                }
            }
            for try await bytes in group {
                #expect(bytes == expected)
            }
        }
    }

    @Test func reusedUploadBufferPreservesRetainedChunks() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: "\(path)~") }
        let file = try FileHandle.createNewFile(file: path, temporary: true)
        try file.write(contentsOf: Data("abcdefgh".utf8))
        var retained: [ByteBuffer] = []
        for try await chunk in file.readChunks(chunkLength: .bytes(3)) {
            retained.append(chunk)
        }
        #expect(retained.map { String(decoding: $0.readableBytesView, as: UTF8.self) } == ["abc", "def", "gh"])
    }

    @Test func uploadReaderReportsUnexpectedEndOfFile() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: "\(path)~") }
        let file = try FileHandle.createNewFile(file: path, temporary: true)
        try file.write(contentsOf: Data("forecast".utf8))
        let chunks = file.readChunks(chunkLength: .bytes(3))
        try file.truncate(atOffset: 2)
        await #expect(throws: S3UploaderError.self) {
            for try await _ in chunks {}
        }
    }

    @Test func immediateCommitDoesNotWaitForOtherFilesOrSessionCompletion() async throws {
        let committed = AsyncStream<Void>.makeStream()
        let app = try await Application.make(.testing)
        do {
            app.post("fast") { request -> String in
                if request.url.query == "uploads" {
                    return "<UploadId>fast</UploadId>"
                }
                committed.continuation.yield(())
                return "<CompleteMultipartUploadResult/>"
            }
            app.put("fast") { _ -> Response in
                Response(status: .ok, headers: ["ETag": "test-part"])
            }
            try await app.http.server.shared.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let failures = Atomic<Int>(0)
            let releaseSlowUpload = AsyncStream<Void>.makeStream()
            let session = S3MultiFileUploadQueue(
                endpoint: .init(rawEndpoint: "http://127.0.0.1:\(port)/", profile: nil), client: .shared,
                onError: { failures.wrappingAdd(1, ordering: .relaxed) },
                maxConcurrentFiles: 2, maxConcurrentPartUploads: 1
            )
            await session.queue.enqueueIgnoreError(logger: session.logger) {
                for await _ in releaseSlowUpload.stream { break }
                return S3MultiPartUploadPrepared(etags: [], url: "https://example.com/slow", encodedUploadId: "slow", lastModified: .init(0))
            }
            await session.uploadMultipart(data: ByteBuffer(string: "forecast"), objectName: "fast", lastModified: .init(0), commitImmediately: true)
            // Publication must happen before we release the other file or finish the session.
            var notifications = committed.stream.makeAsyncIterator()
            _ = await notifications.next()
            await session.queue.enqueueIgnoreError(logger: session.logger) { throw Failure.injected }
            releaseSlowUpload.continuation.yield(())
            releaseSlowUpload.continuation.finish()
            committed.continuation.finish()
            let prepared = await session.finishPreparations()
            // A later failure cannot cause the published file to be committed again or aborted.
            #expect(prepared.map(\.encodedUploadId) == ["slow"])
            #expect(failures.load(ordering: .relaxed) == 1)
        } catch {
            await app.http.server.shared.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.http.server.shared.shutdown()
        try await app.asyncShutdown()
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
            await session.queue.enqueueIgnoreError(logger: session.logger) {
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
