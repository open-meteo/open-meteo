import AsyncHTTPClient
import Foundation
import Synchronization
import Testing
import Vapor
import VaporTesting
@testable import App

struct CurlDownloadFilesTests {
    private struct ShutdownServer: LifecycleHandler {
        func shutdownAsync(_ application: Application) async {
            await application.server.shutdown()
        }
    }

    @Test(arguments: [1, 3]) func pipelinesFilesWithBoundedRequestsAndOffsetWrites(concurrent: Int) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payloads = [Data((0..<2_100_000).map { UInt8($0 % 251) }), Data(repeating: 42, count: 1_100_000), Data(), Data([7])]
        let observed = Mutex((active: 0, maximum: 0, firstFinished: false, overlapped: false))
        try await withApp { app in
            app.lifecycle.use(ShutdownServer())
            app.on(.HEAD, ":file") { request -> Response in
                let index = Int(request.parameters.get("file")!)!
                return Response(status: .ok, body: .init(data: payloads[index]))
            }
            app.get(":file") { request async throws -> Response in
                let index = Int(request.parameters.get("file")!)!
                let bounds = try #require(request.headers.first(name: "Range")).dropFirst(6).split(separator: "-")
                let start = try #require(Int(bounds[0]))
                let end = try #require(Int(bounds[1]))
                let range = start..<(end + 1)
                observed.withLock {
                    $0.active += 1
                    $0.maximum = max($0.maximum, $0.active)
                    if index == 1 && !$0.firstFinished { $0.overlapped = true }
                }
                defer { observed.withLock { $0.active -= 1 } }
                if index == 0 && range.lowerBound == 0 {
                    try await Task.sleep(for: .milliseconds(300))
                    // A partial file must not be published, even if later chunks finish.
                    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("0").path))
                    observed.withLock { $0.firstFinished = true }
                } else {
                    try await Task.sleep(for: .milliseconds(20))
                }
                return Response(status: .partialContent, headers: [
                    "Content-Range": "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(payloads[index].count)"
                ], body: .init(data: payloads[index].subdata(in: range)))
            }
            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let curl = Curl(logger: app.logger, client: HTTPClient.shared, chunkSizeMB: 1)
            let files = payloads.indices.map { (url: "http://127.0.0.1:\(port)/\($0)", path: directory.appendingPathComponent("\($0)").path) }
            var yieldedURLs = [String]()
            var yieldedBeforeFirstFinished = false
            for try await file in curl.downloadChunked(files: files, nConcurrent: concurrent) {
                let index = try #require(files.firstIndex(where: { $0.url == file.url }))
                #expect(try file.handle.offset() == 0)
                #expect(try (file.handle.readToEnd() ?? Data()) == payloads[index])
                try file.handle.close()
                if index == 1 && !observed.withLock({ $0.firstFinished }) {
                    yieldedBeforeFirstFinished = true
                }
                yieldedURLs.append(file.url)
            }
            #expect(yieldedURLs.count == files.count)
            #expect(Set(yieldedURLs) == Set(files.map(\.url)))
            if concurrent > 1 { #expect(yieldedBeforeFirstFinished) }
            let result = observed.withLock { $0 }
            #expect(result.maximum <= concurrent)
            if concurrent > 1 { #expect(result.overlapped) }
        }
    }

    @Test func truncatedChunkRetriesOverwritePartialWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data((0..<50_000).map { UInt8($0 % 251) })
        let attempts = Mutex(0)
        try await withApp { app in
            app.lifecycle.use(ShutdownServer())
            app.on(.HEAD, "file") { _ in Response(status: .ok, body: .init(data: payload)) }
            app.get("file") { _ -> Response in
                let attempt = attempts.withLock { $0 += 1; return $0 }
                return Response(status: .partialContent, headers: ["Content-Range": "bytes 0-49999/50000"], body: .init(managedAsyncStream: { writer in
                    if attempt == 1 {
                        // End early after writing incorrect bytes. A retry must replace them.
                        try await writer.write(.buffer(ByteBuffer(bytes: Array(repeating: UInt8(255), count: 1024))))
                    } else {
                        for offset in stride(from: 0, to: payload.count, by: 1024) {
                            let end = min(offset + 1024, payload.count)
                            try await writer.write(.buffer(ByteBuffer(data: payload.subdata(in: offset..<end))))
                        }
                    }
                }))
            }
            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let curl = Curl(logger: app.logger, client: HTTPClient.shared)
            var completed = 0
            for try await file in curl.downloadChunked(files: [(url: "http://127.0.0.1:\(port)/file", path: directory.appendingPathComponent("file").path)], nConcurrent: 2) {
                #expect(try file.handle.readToEnd() == payload)
                try file.handle.close()
                completed += 1
            }
            #expect(completed == 1)
            #expect(attempts.withLock { $0 } == 2)
        }
    }

}
