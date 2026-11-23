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
                let range = try #require(CurlMemoryDownloadError.singleRange(String(request.headers.first(name: "Range")!.dropFirst(6))))
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
            var yieldedPaths = [String]()
            var yieldedBeforeFirstFinished = false
            for try await file in curl.download(files: files, nConcurrent: concurrent) {
                let index = try #require(files.firstIndex(where: { $0.path == file.path }))
                #expect(file.url == files[index].url)
                #expect(try Data(contentsOf: URL(fileURLWithPath: file.path)) == payloads[index])
                if index == 1 && !observed.withLock({ $0.firstFinished }) {
                    yieldedBeforeFirstFinished = true
                }
                yieldedPaths.append(file.path)
            }
            #expect(yieldedPaths.count == files.count)
            #expect(Set(yieldedPaths) == Set(files.map(\.path)))
            if concurrent > 1 { #expect(yieldedBeforeFirstFinished) }
            let result = observed.withLock { $0 }
            #expect(result.maximum <= concurrent)
            if concurrent > 1 { #expect(result.overlapped) }
        }
    }
}
