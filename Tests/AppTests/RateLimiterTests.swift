@testable import App
import Testing
import Vapor
import VaporTesting
import NIO

@Suite struct RateLimiterTests {
    @Test func freeApiQuotaResponseHeaders() async throws {
        let limiter = RateLimiter(minute: 10, hour: 20, day: 100)
        let address = try SocketAddress(ipAddress: "192.0.2.1", port: 1234)
        try await withApp { app in
            let request = Request(application: app, method: .GET, url: "/quota",
                                  remoteAddress: address, on: app.eventLoopGroup.next())
            let started = Timestamp.now().timeIntervalSince1970
            let success = try await request.withFreeApiRateLimiter(limiter: limiter) { _ in
                (2.5, Response(status: .ok))
            }
            let reset = try #require(success.headers.first(name: "X-RateLimit-Reset").flatMap(Int.init))
            #expect(reset > started)
            #expect(reset <= Timestamp.now().timeIntervalSince1970 + 60)
            let failure = try await request.withFreeApiRateLimiter(limiter: limiter) { _ in
                throw Abort(.badRequest, headers: ["X-Test-Error": "preserved"], reason: "Invalid request")
            }
            #expect(failure.status == .badRequest)
            #expect(failure.headers.first(name: "X-Test-Error") == "preserved")
            #expect(failure.headers.contentType == .json)
            #expect(failure.body.string?.contains("Invalid request") == true)
            for (response, remaining, cost) in [(success, "7.5", "2.5"), (failure, "6.5", "1.0")] {
                #expect(response.headers.first(name: "X-RateLimit-Cost") == cost)
                #expect(response.headers.first(name: "X-RateLimit-Limit") == "10.0")
                #expect(response.headers.first(name: "X-RateLimit-Remaining") == remaining)
                #expect(response.headers.first(name: "X-RateLimit-Reset") == String(reset))
                #expect(response.headers.first(name: "X-RateLimit-Window") == "60")
                #expect(response.headers.first(name: "Retry-After") == nil)
            }
            await limiter.increment(25, for: limiter.clientKey(for: address))
            await #expect(throws: RateLimitError.self) {
                _ = try await request.withFreeApiRateLimiter(limiter: limiter) { _ in
                    Issue.record("An exhausted quota must reject before running the handler")
                    return (1, Response(status: .ok))
                }
            }
            // Exercise error rendering with deterministic quota data.
            let exhausted = RateLimiter.Quota(limit: 20, remaining: 0, window: 3600, reset: 3600)
            app.middleware.use(ErrorMiddleware.custom(environment: .testing))
            app.get("quota") { _ async throws -> Response in
                throw RateLimitError.hourlyExceeded(quota: exhausted, retryAfter: 3500)
            }
            try await app.testing().test(.GET, "quota", headers: ["X-Forwarded-For": "192.0.2.1"], afterResponse: { response async in
                #expect(response.status == .tooManyRequests)
                #expect(response.headers.first(name: "X-RateLimit-Limit") == "20.0")
                #expect(response.headers.first(name: "X-RateLimit-Remaining") == "0.0")
                #expect(response.headers.first(name: "X-RateLimit-Reset") == "3600")
                #expect(response.headers.first(name: "X-RateLimit-Window") == "3600")
                #expect(response.headers.first(name: "Retry-After") == "3500")
                #expect(response.body.string.contains("Hourly API request limit exceeded"))
            })
        }
    }

    @Test func weightedQuotaSelectionAndExhaustion() async throws {
        let limiter = RateLimiter(minute: 10, hour: 12, day: 30)
        let client = 1
        try await limiter.check(client, now: 60)
        #expect(await limiter.increment(2.5, for: client, now: 100) ==
                RateLimiter.Quota(limit: 10, remaining: 7.5, window: 60, reset: 120))
        try await limiter.check(client, now: 100)
        await limiter.increment(7, for: client, now: 100)
        try await limiter.check(client, now: 120)
        #expect(await limiter.increment(1, for: client, now: 120) ==
                RateLimiter.Quota(limit: 12, remaining: 1.5, window: 3600, reset: 3600))
        let exhaustedHour = try #require(await limiter.increment(10, for: client, now: 120))
        #expect(exhaustedHour.remaining == 0)
        #expect(exhaustedHour.window == 3600)
        await #expect(throws: RateLimitError.hourlyExceeded(quota: exhaustedHour, retryAfter: 3480)) {
            try await limiter.check(client, now: 120)
        }
        let exhaustedDay = try #require(await limiter.increment(20, for: client, now: 120))
        #expect(exhaustedDay.remaining == 0)
        #expect(exhaustedDay.window == 86400)
        await #expect(throws: RateLimitError.dailyExceeded(quota: exhaustedDay, retryAfter: 86280)) {
            try await limiter.check(client, now: 120)
        }
    }

    @Test func periodicResetsPreserveUnexpiredUsage() async throws {
        let limiter = RateLimiter(minute: 10, hour: 20, day: 30)
        let client = 1
        await limiter.increment(25, for: client, now: 3540)
        await limiter.minutelyCallback(now: 3600)
        try await limiter.check(client, now: 3600)
        #expect(await limiter.increment(0, for: client, now: 3600) ==
                RateLimiter.Quota(limit: 30, remaining: 5, window: 86400, reset: 86400))
        let other = -2
        await limiter.increment(3, for: other, now: 3600)
        await limiter.minutelyCallback(now: 3600)
        #expect(await limiter.increment(0, for: other, now: 3600)?.remaining == 7)
        await limiter.minutelyCallback(now: 86400)
        #expect(await limiter.increment(0, for: client, now: 86400) ==
                RateLimiter.Quota(limit: 10, remaining: 10, window: 60, reset: 86460))
    }

    @Test(arguments: [60, 3600, 86400])
    func clientsKeepIndependentResetOffsets(window: Int) async throws {
        let limiter = RateLimiter(minute: window == 60 ? 10 : 0, hour: window == 3600 ? 10 : 0,
                                  day: window == 86400 ? 10 : 0)
        let first = 1
        let second = -2
        try await limiter.check(first, now: window - 60 + 2)
        try await limiter.check(second, now: window - 60 + 7)
        #expect(await limiter.increment(10, for: first, now: window - 1)?.reset == window + 2)
        #expect(await limiter.increment(10, for: second, now: window - 1)?.reset == window + 7)
        await #expect(throws: RateLimitError.self) {
            try await limiter.check(first, now: window + 1)
        }
        try await limiter.check(first, now: window + 2)
        await #expect(throws: RateLimitError.self) {
            try await limiter.check(second, now: window + 2)
        }
        await limiter.increment(1, for: first, now: window + 2)
        await limiter.minutelyCallback(now: window + 4)
        #expect(await limiter.increment(0, for: first, now: window + 4)?.remaining == 9)
        #expect(await limiter.increment(0, for: second, now: window + 4)?.remaining == 0)
        try await limiter.check(second, now: window + 7)
        await limiter.increment(2, for: second, now: window + 7)
        await limiter.minutelyCallback(now: window + 30)
        #expect(await limiter.increment(0, for: first, now: window + 30) ==
                RateLimiter.Quota(limit: 10, remaining: 9, window: window, reset: 2 * window + 2))
        #expect(await limiter.increment(0, for: second, now: window + 30) ==
                RateLimiter.Quota(limit: 10, remaining: 8, window: window, reset: 2 * window + 7))
        try await limiter.check(first, now: window - 1)
        #expect(await limiter.increment(0, for: first, now: window + 30)?.remaining == 9)
    }

    @Test func resetTimestampSupportsUnsignedRange() async throws {
        let now = 2_200_000_007
        let limiter = RateLimiter(minute: 10, hour: 0, day: 0)
        let client = 1
        #expect(await limiter.increment(10, for: client, now: now)?.reset == now + 60)
        await #expect(throws: RateLimitError.self) {
            try await limiter.check(client, now: now + 59)
        }
        try await limiter.check(client, now: now + 60)
        #expect(await limiter.increment(0, for: client, now: now + 60) ==
                RateLimiter.Quota(limit: 10, remaining: 10, window: 60, reset: now + 120))
    }

    @Test func cleanupPreservesUsageAndAllowsLateCompletion() async throws {
        let limiter = RateLimiter(minute: 10, hour: 20, day: 30)
        let expired = 1
        let retained = -1
        // This request completes after cleanup has removed its empty entry.
        try await limiter.check(expired, now: 60)
        await limiter.increment(25, for: retained, now: 67)
        await limiter.minutelyCallback(now: 120)
        await limiter.minutelyCallback(now: 120)
        #expect(await limiter.increment(2, for: expired, now: 125) ==
                RateLimiter.Quota(limit: 10, remaining: 8, window: 60, reset: 185))
        // Repeated cleanup must not affect other clients.
        let other = 2
        #expect(await limiter.increment(3, for: other, now: 125)?.remaining == 7)
        #expect(await limiter.increment(0, for: expired, now: 125)?.remaining == 8)
        // The retained client's usage and reset offset survive cleanup.
        await #expect(throws: RateLimitError.self) {
            try await limiter.check(retained, now: 125)
        }
        #expect(await limiter.increment(0, for: retained, now: 3607)?.remaining == 5)
        await limiter.minutelyCallback(now: 86407)
        #expect(await limiter.increment(1, for: retained, now: 86427) ==
                RateLimiter.Quota(limit: 10, remaining: 9, window: 60, reset: 86487))
        // A request crossing a minute boundary is charged to its completion window,
        // even when the periodic task has not run yet.
        try await limiter.check(expired, now: 86430)
        #expect(await limiter.increment(10, for: expired, now: 86430)?.remaining == 0)
        #expect(await limiter.increment(2, for: expired, now: 86490)?.remaining == 8)
    }

    @Test func disabledLimitsAndAllowlistedAddresses() async throws {
        let disabled = RateLimiter(minute: 0, hour: -1, day: 0)
        try await disabled.check(1, now: 60)
        #expect(await disabled.increment(1, for: 1, now: 60) == nil)
        #expect(await disabled.increment(1, for: -1, now: 60) == nil)
        let dailyOnly = RateLimiter(minute: 0, hour: 0, day: 100)
        let quota = try #require(await dailyOnly.increment(2, for: -1, now: 100))
        #expect(quota.remaining == 98)
        #expect(quota.window == 86400)
        await dailyOnly.setAllowlistForTest(CIDR("127.0.0.1/32"))
        let address = try SocketAddress(ipAddress: "127.0.0.1", port: 1234)
        #expect(await dailyOnly.clientKey(for: address) == nil)
        try await dailyOnly.check(nil, now: 60)
        #expect(await dailyOnly.increment(2, for: nil, now: 60) == nil)
        let ipv6 = try SocketAddress(ipAddress: "2001:db8::1", port: 1234)
        let client = try #require(await dailyOnly.clientKey(for: ipv6))
        #expect(await dailyOnly.increment(2.5, for: client, now: 100)?.remaining == 97.5)
    }
}

private extension RateLimiter {
    func setAllowlistForTest(_ allowlist: CIDR?) {
        allowlistedIPs = allowlist
    }
}
