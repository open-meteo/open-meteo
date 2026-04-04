import Foundation
@testable import App
import Testing
import AsyncHTTPClient
import Logging

@Suite struct StripeMeterTests {
    private struct TestEvent: StripeEventMetered {
        let stripeCustomerId: String
        let value: Int
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["STRIPE_API_KEY"] != nil))
    func getAuthenticationTokenAndSubmitEvents() async throws {
        let apikey = ProcessInfo.processInfo.environment["STRIPE_API_KEY"]!
        let logger = Logger(label: "stripe-test")
        let client = HTTPClient.shared

        let meter = StripeMeterEvents(apikey: apikey, client: client, logger: logger)
        let session = try await meter.getAuthenticationToken()
        #expect(!session.token.isEmpty)

        let events = [TestEvent(stripeCustomerId: "cus_UGQ70ABBqUB4pY", value: 1)]
        try await session.submitEvents(eventName: "api_calls", events: events)
    }
}
