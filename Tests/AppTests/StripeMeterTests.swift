import Foundation
@testable import App
import Testing
import AsyncHTTPClient
import Logging

@Suite struct StripeMeterTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STRIPE_API_KEY"] != nil))
    func getAuthenticationTokenAndSubmitEvents() async throws {
        let apiKey = ProcessInfo.processInfo.environment["STRIPE_API_KEY"]!
        let logger = Logger(label: "stripe-test")
        let client = HTTPClient.shared

        let meter = StripeMeterEvents(apiKey: apiKey, client: client, logger: logger)
        let session = try await meter.getAuthenticationToken()
        #expect(!session.token.isEmpty)

        try await session.submit(events: ["cus_UGQ70ABBqUB4pY": (1, 23)])
    }
}
