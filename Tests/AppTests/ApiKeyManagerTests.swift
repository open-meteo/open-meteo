import Foundation
@testable import App
import Testing
import Vapor
import VaporTesting

@Suite struct ApiKeyManagerTests {
    @Test func quotaThreshold() throws {
        for usage in [1499.0, 1499.99] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageCurrentQuotaPeriod: usage, quotaResetTimestamp: nil)
            try key.checkQuota(quotaMultiplier: 15)
        }
        for usage in [1500.0, 1501, 2000] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageCurrentQuotaPeriod: usage, quotaResetTimestamp: nil)
            #expect(throws: ApiKeyManagerError.apiKeyOverQuota) {
                try key.checkQuota(quotaMultiplier: 15)
            }
        }
        #expect(ApiKeyManagerError.apiKeyOverQuota.status == .forbidden)
        #expect(ApiKeyManagerError.apiKeyOverQuota.reason == "Your API key is over quota.")
    }

    @Test func quotaBlockingIsOptional() throws {
        let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageCurrentQuotaPeriod: 2000, quotaResetTimestamp: nil)
        for multiplier: Double? in [nil, 0, -1, .nan, .infinity] {
            try key.checkQuota(quotaMultiplier: multiplier)
        }
        for usage: Double in [0, -1, .nan, .infinity] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageCurrentQuotaPeriod: usage, quotaResetTimestamp: nil)
            try key.checkQuota(quotaMultiplier: 15)
        }
        let unlimited = ApiKeyManager.KeyAndLimit(key: "key", limit: 0, id: nil, usageCurrentQuotaPeriod: 2000, quotaResetTimestamp: nil)
        try unlimited.checkQuota(quotaMultiplier: 15)
    }

    private struct TestResponder: ForecastapiResponder {
        func calculateQueryWeight() -> Float { 2.5 }

        func response(format: ForecastResultFormatWithOptions?, concurrencySlot: Int?, prefetch: Bool, logger: Logger) async throws -> Response {
            Response(status: .ok)
        }
    }

    @Test func customerResponseHeaders() async throws {
        let manager = ApiKeyManager.instance
        let previousKeys = await manager.apiKeys
        await manager.set(ApiKeyManager.KeyAndLimit.parseApiKeys("header-test;1000000;;25.5;1800000000"))
        do {
            try await withApp { app in
                for fail in [false, true] {
                    let request = Request(application: app, method: .GET, url: "/v1/forecast",
                                          headers: ["Host": "customer-api.open-meteo.com", "x-api-key": "header-test"],
                                          on: app.eventLoopGroup.next())
                    let response = try await request.withApiParameter("api.") { _, _ -> TestResponder in
                        if fail { throw Abort(.badRequest, reason: "Invalid request") }
                        return TestResponder()
                    }
                    #expect(response.status == (fail ? .badRequest : .ok))
                    #expect(response.headers.first(name: "X-RateLimit-Limit") == "1000000")
                    #expect(response.headers.first(name: "X-RateLimit-Remaining") == "999974.5")
                    #expect(response.headers.first(name: "X-RateLimit-Reset") == "1800000000")
                    #expect(response.headers.first(name: "X-RateLimit-Cost") == (fail ? nil : "2.5"))
                    #expect(response.headers.first(name: "X-RateLimit-Window") == nil)
                    if fail { #expect(response.body.string?.contains("Invalid request") == true) }
                }
            }
        } catch {
            await manager.set(previousKeys)
            throw error
        }
        await manager.set(previousKeys)
    }

    @Test func monthlyHeaders() throws {
        for (usage, remaining) in [(25.5, "74.5"), (120, "0.0")] {
            let key = try #require(ApiKeyManager.KeyAndLimit.parseApiKeys("key;100;customer;\(usage);1800000000").first)
            #expect(key.quotaResetTimestamp == 1800000000)
            var headers = HTTPHeaders()
            key.applyHeaders(to: &headers)
            #expect(headers.first(name: "X-RateLimit-Limit") == "100")
            #expect(headers.first(name: "X-RateLimit-Remaining") == remaining)
            #expect(headers.first(name: "X-RateLimit-Reset") == "1800000000")
            #expect(headers.first(name: "X-RateLimit-Window") == nil)
        }
        for reset in ["", ";", ";invalid", ";0", ";-1"] {
            let key = try #require(ApiKeyManager.KeyAndLimit.parseApiKeys("key;100;customer;25.5\(reset)").first)
            var headers = HTTPHeaders()
            key.applyHeaders(to: &headers)
            #expect(headers.first(name: "X-RateLimit-Remaining") == "74.5")
            #expect(headers.first(name: "X-RateLimit-Reset") == nil)
        }
        for entry in ["key", "key;0;customer;10;1800000000"] {
            let key = try #require(ApiKeyManager.KeyAndLimit.parseApiKeys(entry).first)
            var headers = HTTPHeaders()
            key.applyHeaders(to: &headers)
            #expect(headers.isEmpty)
        }
    }

    @Test func forgivingCsvParsing() {
        let keys = ApiKeyManager.KeyAndLimit.parseApiKeys(" legacy , old;100;customer, new;100;customer;115.5, empty;100;;120, missing;100;customer;, invalid;100;customer;unknown, ;;;, , whitespace; 100 ; customer ; 120 \n")
        #expect(keys.count == 7)
        #expect(keys.first(where: { $0.key == "legacy" })?.limit == 0)
        #expect(keys.first(where: { $0.key == "old" })?.usageCurrentQuotaPeriod == 0)
        #expect(keys.first(where: { $0.key == "new" })?.usageCurrentQuotaPeriod == 115.5)
        #expect(keys.first(where: { $0.key == "empty" })?.id == nil)
        #expect(keys.first(where: { $0.key == "empty" })?.usageCurrentQuotaPeriod == 120)
        #expect(keys.first(where: { $0.key == "missing" })?.usageCurrentQuotaPeriod == 0)
        #expect(keys.first(where: { $0.key == "invalid" })?.usageCurrentQuotaPeriod == 0)
        #expect(keys.first(where: { $0.key == "whitespace" })?.limit == 100)
        #expect(keys.first(where: { $0.key == "whitespace" })?.id == "customer")
        #expect(keys.first(where: { $0.key == "whitespace" })?.usageCurrentQuotaPeriod == 120)
        #expect(ApiKeyManager.KeyAndLimit.parseApiKeys(";;;,, \n").isEmpty)
    }
}
