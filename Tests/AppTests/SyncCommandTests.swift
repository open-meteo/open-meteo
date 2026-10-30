import Foundation
@testable import App
import Testing
import Vapor

@Suite struct SyncCommandTests {
    @Test func boxAndPolygonCannotBeCombined() async throws {
        let app = try await Application.make(.testing)
        var context = CommandContext(console: app.console, input: CommandInput(arguments: ["sync", "ecmwf_ifs025", "temperature_2m", "--bounding-box", "1,2,3,4", "--polygon", "[[[[0,0], [1,0], [1,1], [0,0]]]]"]))
        context.application = app
        await #expect(throws: ForecastApiError.self) { try await SyncCommand().run(using: &context) }
        try await app.asyncShutdown()
    }

    @Test func regionalReadOptionsParse() throws {
        var input = CommandInput(arguments: ["sync", "ecmwf_ifs025", "temperature_2m", "--max-merge-gap-bytes", "1MB", "--max-concurrent-reads", "10"])
        let signature = try SyncCommand.Signature(from: &input)
        #expect(try ByteSizeParser.parseSizeStringToBytes(#require(signature.maxMergeGapBytes)) == 1024 * 1024)
        #expect(signature.maxConcurrentReads == 10)
        #expect(input.arguments.isEmpty)
    }

    @Test(arguments: [
        ["--max-merge-gap-bytes", "2MB"], ["--max-merge-gap-bytes", "\\-1KB"],
        ["--max-merge-gap-bytes", "nanMB"], ["--max-merge-gap-bytes", "1e100MB"],
        ["--max-concurrent-reads", "0"], ["--max-concurrent-reads", "33"],
        ["--concurrent", "0"], ["--concurrent", "33"],
        ["--concurrent", "13", "--max-concurrent-reads", "10"]
    ])
    func invalidReadOptionsFailBeforeDownloading(options: [String]) async throws {
        let app = try await Application.make(.testing)
        var context = CommandContext(console: app.console, input: CommandInput(arguments: ["sync", "ecmwf_ifs025", "temperature_2m"] + options))
        context.application = app
        await #expect(throws: (any Error).self) { try await SyncCommand().run(using: &context) }
        try await app.asyncShutdown()
    }
}
