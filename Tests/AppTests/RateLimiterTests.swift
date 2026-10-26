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
            #expect(success.headers.first(name: "X-RateLimit-Remaining") == "7.5")
            #expect(success.headers.first(name: "X-RateLimit-Limit") == "10.0")
            let reset = try #require(success.headers.first(name: "X-RateLimit-Reset").flatMap(Int.init))
            #expect(reset > started)
            #expect(reset <= Timestamp.now().timeIntervalSince1970 + 60)
            #expect(success.headers.first(name: "X-RateLimit-Window") == "60")
            #expect(success.headers.first(name: "Retry-After") == nil)
            let failure = try await request.withFreeApiRateLimiter(limiter: limiter) { _ in
                throw Abort(.badRequest, headers: ["X-Test-Error": "preserved"], reason: "Invalid request")
            }
            #expect(failure.status == .badRequest)
            #expect(failure.headers.first(name: "X-Test-Error") == "preserved")
            #expect(failure.headers.contentType == .json)
            #expect(failure.body.string?.contains("Invalid request") == true)
            #expect(failure.headers.first(name: "X-RateLimit-Cost") == "1.0")
            #expect(failure.headers.first(name: "X-RateLimit-Limit") == "10.0")
            #expect(failure.headers.first(name: "X-RateLimit-Remaining") == "6.5")
            #expect(failure.headers.first(name: "X-RateLimit-Reset") == success.headers.first(name: "X-RateLimit-Reset"))
            #expect(failure.headers.first(name: "X-RateLimit-Window") == "60")
            #expect(failure.headers.first(name: "Retry-After") == nil)
            #expect(await limiter.counter(address: address)?.increment(0, limits: limiter.limits)?.remaining == 6.5)
            await limiter.counter(address: address)?.increment(25, limits: limiter.limits)
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
        let counter = try #require(await limiter.counter(uint32: 1, now: 60))
        let minute = try #require(counter.increment(2.5, limits: limiter.limits, now: 100))
        #expect(minute == RateLimiter.Quota(limit: 10, remaining: 7.5, window: 60, reset: 120))
        try counter.check(limits: limiter.limits, now: 100)

        counter.increment(7, limits: limiter.limits, now: 100)
        try counter.check(limits: limiter.limits, now: 120)
        let hour = try #require(counter.increment(1, limits: limiter.limits, now: 120))
        #expect(hour == RateLimiter.Quota(limit: 12, remaining: 1.5, window: 3600, reset: 3600))

        let exhaustedHour = try #require(counter.increment(10, limits: limiter.limits, now: 120))
        #expect(exhaustedHour.remaining == 0)
        #expect(exhaustedHour.window == 3600)
        #expect(throws: RateLimitError.hourlyExceeded(quota: exhaustedHour, retryAfter: 3480)) {
            try counter.check(limits: limiter.limits, now: 120)
        }
        let exhaustedDay = try #require(counter.increment(20, limits: limiter.limits, now: 120))
        #expect(exhaustedDay.remaining == 0)
        #expect(exhaustedDay.window == 86400)
        #expect(throws: RateLimitError.dailyExceeded(quota: exhaustedDay, retryAfter: 86280)) {
            try counter.check(limits: limiter.limits, now: 120)
        }
    }

    @Test func periodicTaskResetsExpiredWindows() async throws {
        let limiter = RateLimiter(minute: 10, hour: 20, day: 30)
        let counter = try #require(await limiter.counter(uint32: 1, now: 3540))
        counter.increment(25, limits: limiter.limits)
        await limiter.minutelyCallback(now: 3600)
        let daily = try #require(counter.increment(0, limits: limiter.limits, now: 3600))
        try counter.check(limits: limiter.limits, now: 3600)
        #expect(daily.window == 86400)
        #expect(daily.remaining == 5)
        // A repeated callback in the same window must preserve new usage.
        let other = try #require(await limiter.counter(uint32: 2, now: 3600))
        other.increment(3, limits: limiter.limits)
        await limiter.minutelyCallback(now: 3600)
        #expect(other.increment(0, limits: limiter.limits, now: 3600)?.remaining == 7)
        await limiter.minutelyCallback(now: 86400)
        let reset = try #require(counter.increment(0, limits: limiter.limits, now: 86400))
        #expect(reset.window == 60)
        #expect(reset.remaining == 10)
        #expect(reset.reset == 86460)
    }

    @Test(arguments: [60, 3600, 86400])
    func clientsKeepIndependentResetOffsets(window: Int) async throws {
        let limiter = RateLimiter(minute: window == 60 ? 10 : 0, hour: window == 3600 ? 10 : 0,
                                  day: window == 86400 ? 10 : 0)
        let first = try #require(await limiter.counter(uint32: 1, now: window - 60 + 2))
        let second = try #require(await limiter.counter(int64: 2, now: window - 60 + 7))
        #expect(first.increment(10, limits: limiter.limits, now: window - 1)?.reset == window + 2)
        #expect(second.increment(10, limits: limiter.limits, now: window - 1)?.reset == window + 7)
        #expect(throws: RateLimitError.self) {
            try first.check(limits: limiter.limits, now: window + 1)
        }
        try first.check(limits: limiter.limits, now: window + 2)
        #expect(throws: RateLimitError.self) {
            try second.check(limits: limiter.limits, now: window + 2)
        }
        first.increment(1, limits: limiter.limits, now: window + 2)
        await limiter.minutelyCallback(now: window + 4)
        #expect(first.increment(0, limits: limiter.limits, now: window + 4)?.remaining == 9)
        #expect(second.increment(0, limits: limiter.limits, now: window + 4)?.remaining == 0)
        try second.check(limits: limiter.limits, now: window + 7)
        second.increment(2, limits: limiter.limits, now: window + 7)
        // A late periodic task must preserve both the offsets and the new usage.
        await limiter.minutelyCallback(now: window + 30)
        let firstQuota = try #require(first.increment(0, limits: limiter.limits, now: window + 30))
        let secondQuota = try #require(second.increment(0, limits: limiter.limits, now: window + 30))
        #expect(firstQuota.remaining == 9)
        #expect(secondQuota.remaining == 8)
        #expect(firstQuota.reset == 2 * window + 2)
        #expect(secondQuota.reset == 2 * window + 7)
        try first.check(limits: limiter.limits, now: window - 1)
        #expect(first.increment(0, limits: limiter.limits, now: window + 30)?.remaining == 9)
    }

    @Test func resetTimestampSupportsUnsignedRange() throws {
        let now = 2_200_000_007
        let counter = RateLimiter.ClientUsageCounter(lastReset: UInt32(now))
        let limits: (minute: Float, hour: Float, day: Float) = (10, 0, 0)
        #expect(counter.increment(10, limits: limits, now: now)?.reset == now + 60)
        #expect(throws: RateLimitError.self) {
            try counter.check(limits: limits, now: now + 59)
        }
        try counter.check(limits: limits, now: now + 60)
        #expect(counter.increment(0, limits: limits, now: now + 60)?.remaining == 10)
        #expect(counter.increment(0, limits: limits, now: now + 60)?.reset == now + 120)
    }

    @Test(arguments: [false, true], [false, true])
    func periodicCleanup(ipv6: Bool, keepActive: Bool) async throws {
        let limiter = RateLimiter(minute: 10, hour: 20, day: 30)
        let address = try SocketAddress(ipAddress: ipv6 ? "2001:db8::1" : "192.0.2.1", port: 80)
        var counter = await limiter.counter(address: address, now: 60)
        counter?.increment(2.5, limits: limiter.limits, now: 100)
        weak var reference = counter
        counter = nil
        await limiter.minutelyCallback(now: 120)
        #expect(reference != nil) // Hourly and daily usage still applies.
        await limiter.minutelyCallback(now: 3600)
        #expect(reference != nil) // Daily usage still applies.
        if keepActive {
            counter = await limiter.counter(address: address, now: 3600)
        }
        await limiter.minutelyCallback(now: 86400)
        if keepActive {
            #expect(counter?.increment(0, limits: limiter.limits, now: 86400)?.remaining == 10)
            #expect(await limiter.counter(address: address, now: 86400) === counter)
            counter = nil
            await limiter.minutelyCallback(now: 86460)
        }
        #expect(reference == nil)
    }

    @Test func disabledLimitsAndAllowlistedAddresses() async throws {
        let disabled = RateLimiter(minute: 0, hour: -1, day: 0)
        #expect(await disabled.counter(uint32: 1, now: 60) == nil)
        #expect(await disabled.counter(int64: 1, now: 60) == nil)
        let dailyOnly = RateLimiter(minute: 0, hour: 0, day: 100)
        let counter = try #require(await dailyOnly.counter(int64: 1, now: 60))
        let quota = try #require(counter.increment(2, limits: dailyOnly.limits, now: 100))
        #expect(quota.remaining == 98)
        #expect(quota.window == 86400)
        await dailyOnly.setAllowlistForTest(CIDR("127.0.0.1/32"))
        let address = try SocketAddress(ipAddress: "127.0.0.1", port: 1234)
        #expect(await dailyOnly.counter(address: address, now: 60) == nil)
        let ipv6 = try SocketAddress(ipAddress: "2001:db8::1", port: 1234)
        let ipv6Counter = try #require(await dailyOnly.counter(address: ipv6, now: 60))
        #expect(ipv6Counter.increment(2.5, limits: dailyOnly.limits, now: 100)?.remaining == 97.5)
    }

}

private extension RateLimiter {
    func setAllowlistForTest(_ allowlist: CIDR?) {
        allowlistedIPs = allowlist
    }
}
