import Foundation
@testable import App
import Testing
import Vapor

@Suite(.serialized) struct SyncCommandTests {
    /// The listing offers one file whose download fails at once, because its size is too small to fetch in chunks.
    /// The sync must still mark the process as failed, so that a scheduler notices the model did not update
    @Test func failedModelFailsTheCommand() async throws {
        let app = try await Application.make(.testing)
        app.get { req -> Response in
            let prefix = try req.query.get(String.self, at: "prefix")
            let entry = prefix.hasSuffix("synctest_variable/")
                ? "<Contents><Key>\(prefix)master_0.om</Key><LastModified>2026-09-01T00:00:00.000Z</LastModified><ETag>&quot;a&quot;</ETag><Size>3</Size></Contents>"
                : "<CommonPrefixes><Prefix>\(prefix)synctest_variable/</Prefix></CommonPrefixes>"
            return Response(body: .init(string: "<ListBucketResult>\(entry)</ListBucketResult>"))
        }
        app.get("data", "**") { _ in "abc" }
        /// A variable no real sync produces, so only files of this test are written
        let output = "\(OpenMeteo.dataDirectory)dwd_icon/synctest_variable"
        try #require(!FileManager.default.fileExists(atPath: output), "Remove the leftover test directory first")
        defer { try? FileManager.default.removeItem(atPath: output) }
        let exitStatus = ProcessExitStatus()
        do {
            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            var context = CommandContext(console: app.console, input: CommandInput(arguments: ["sync", "dwd_icon", "synctest_variable", "--server", "http://127.0.0.1:\(port)/", "--past-days", "100000"]))
            context.application = app
            try await SyncCommand(exitStatus: exitStatus).run(using: &context)
            #expect(exitStatus.hasFailed)
        } catch {
            await app.http.server.shared.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.http.server.shared.shutdown()
        try await app.asyncShutdown()
    }
}
