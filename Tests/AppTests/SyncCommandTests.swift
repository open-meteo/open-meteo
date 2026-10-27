import Foundation
@testable import App
import Testing
import Vapor

@Suite struct SyncCommandTests {
    @Test func boxAndPolygonCannotBeCombined() async throws {
        let app = try await Application.make(.testing)
        var context = CommandContext(console: app.console, input: CommandInput(arguments: ["sync", "ecmwf_ifs025", "temperature_2m", "--bounding-box", "1,2,3,4", "--polygon", "POLYGON ((0 0, 1 0, 1 1, 0 0))"]))
        context.application = app
        await #expect(throws: ForecastApiError.self) { try await SyncCommand().run(using: &context) }
        try await app.asyncShutdown()
    }
}
