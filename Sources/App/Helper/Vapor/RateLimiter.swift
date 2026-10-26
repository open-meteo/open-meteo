import Foundation
import Vapor
import NIO
import Synchronization

/**
 Limit API request rate for the free API.
 Count how many calls have been made by a given IP address.
 */
final actor RateLimiter {
    private static let limitDaily = Float(Environment.get("CALL_LIMIT_DAILY").flatMap(Int.init) ?? 10_000)

    static let limitHourly = Float(Environment.get("CALL_LIMIT_HOURLY").flatMap(Int.init) ?? 5_000)

    private static let limitMinutely = Float(Environment.get("CALL_LIMIT_MINUTELY").flatMap(Int.init) ?? 600)
    
    static let concurrencyLimit = Environment.get("CONCURRENCY_LIMIT").flatMap(Int.init) ?? 1
    
    static let concurrencyLimitHard = Environment.get("CONCURRENCY_LIMIT_HARD").flatMap(Int.init) ?? 5
    
    static let concurrencyLimitTotal = Environment.get("CONCURRENCY_LIMIT_TOTAL").flatMap(Int.init) ?? 4096

    private var perIPv4 = [UInt32: ClientUsageCounter]()
    private var perIPv6 = [Int: ClientUsageCounter]()

    /// List of IP addresses / networks to disable rate limited
    var allowlistedIPs: CIDR?
    
    /// See https://www.cloudflare.com/en-gb/ips/
    /// Last updated 2026-02-19
    nonisolated(unsafe) static let cloudFlareWorkerIPs = CIDR("173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0/14,172.64.0.0/13,131.0.72.0/22,2400:cb00::/32,2606:4700::/32,2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32")

    public static let instance = RateLimiter()

    nonisolated let limits: (minute: Float, hour: Float, day: Float)

    init(minute: Float = limitMinutely, hour: Float = limitHourly, day: Float = limitDaily) {
        self.limits = (minute, hour, day)
        if let ipAllowlistPath = Environment.get("IP_ALLOWLIST_PATH") {
            do {
                let cidr = try CIDR(filename: ipAllowlistPath)
                allowlistedIPs = cidr
                print("IP allow list loaded \(cidr.ips.count) address ranges")
            } catch {
                print("Failed to load allowlisted IPs from \(ipAllowlistPath): \(error)")
            }
        } else {
            allowlistedIPs = nil
        }
    }

    /// Called every minute from a life cycle handler
    func minutelyCallback(now: Int? = nil) {
        let now = now ?? Timestamp.now().timeIntervalSince1970
        resetExpiredWindows(now: now)
        if (now % 3600) < 60 {
            if let path = Environment.get("IP_ALLOWLIST_PATH") {
                do {
                    let allowlistedIPs = try CIDR(filename: path)
                    if self.allowlistedIPs != allowlistedIPs {
                        self.allowlistedIPs = allowlistedIPs
                    }
                } catch {
                    print("Failed to load allowlisted IPs from \(path): \(error)")
                }
            }
        }
    }

    /// Periodic cleanup also resets idle clients. Active clients can reset on checks;
    /// concurrent resets of the same expired window are allowed.
    private func resetExpiredWindows(now: Int) {
        // Copy just the keys, so dictionary iteration does not retain the counter objects.
        for ip in Array(perIPv4.keys) {
            perIPv4[ip]?.resetIfNeeded(now: now)
            if isKnownUniquelyReferenced(&perIPv4[ip]), perIPv4[ip]?.isUnused == true {
                perIPv4.removeValue(forKey: ip)
            }
        }
        for ip in Array(perIPv6.keys) {
            perIPv6[ip]?.resetIfNeeded(now: now)
            if isKnownUniquelyReferenced(&perIPv6[ip]), perIPv6[ip]?.isUnused == true {
                perIPv6.removeValue(forKey: ip)
            }
        }
    }

    struct Quota: Sendable, Equatable {
        let limit: Float
        let remaining: Float
        let window: Int
        let reset: Int

        func applyHeaders(to headers: inout HTTPHeaders) {
            headers.replaceOrAdd(name: "X-RateLimit-Limit", value: String(limit))
            headers.replaceOrAdd(name: "X-RateLimit-Remaining", value: String(remaining))
            headers.replaceOrAdd(name: "X-RateLimit-Reset", value: String(reset))
            headers.replaceOrAdd(name: "X-RateLimit-Window", value: String(window))
        }
    }

    /// Shared usage for one client. Requests retain this object while executing;
    /// increments and periodic resets can safely run on different executors.
    final class ClientUsageCounter: Sendable {
        private let minuteUsed = Atomic<Float>(0)
        private let hourUsed = Atomic<Float>(0)
        private let dayUsed = Atomic<Float>(0)
        private let lastReset: Atomic<UInt32>

        init(lastReset: UInt32 = UInt32(Timestamp.now().timeIntervalSince1970)) {
            self.lastReset = Atomic(lastReset)
        }

        fileprivate var isUnused: Bool {
            minuteUsed.load(ordering: .relaxed) == 0 && hourUsed.load(ordering: .relaxed) == 0 && dayUsed.load(ordering: .relaxed) == 0
        }

        fileprivate func resetIfNeeded(now: Int) {
            let previous = Int(lastReset.load(ordering: .acquiring))
            guard now >= previous + 60 else { return }
            // Advance whole minutes, preserving this client's original seconds offset.
            let updated = previous + (now - previous) / 60 * 60
            let offset = previous % 60
            // Concurrent resets may clear the same counters more than once.
            minuteUsed.store(0, ordering: .relaxed)
            if (updated - offset) / 3600 > (previous - offset) / 3600 { hourUsed.store(0, ordering: .relaxed) }
            if (updated - offset) / 86400 > (previous - offset) / 86400 { dayUsed.store(0, ordering: .relaxed) }
            lastReset.store(UInt32(updated), ordering: .releasing)
        }

        /// Reset expired windows before comparing usage. Construct quota metadata only
        /// when a limit is exceeded.
        func check(limits: (minute: Float, hour: Float, day: Float), now: Int? = nil) throws {
            let now = now ?? Timestamp.now().timeIntervalSince1970
            resetIfNeeded(now: now)
            let minute = limits.minute > 0 ? minuteUsed.load(ordering: .relaxed) : 0
            let hour = limits.hour > 0 ? hourUsed.load(ordering: .relaxed) : 0
            let day = limits.day > 0 ? dayUsed.load(ordering: .relaxed) : 0
            guard (limits.minute > 0 && minute >= limits.minute)
                || (limits.hour > 0 && hour >= limits.hour)
                || (limits.day > 0 && day >= limits.day) else { return }
            guard let quota = quota(minute: minute, hour: hour, day: day, limits: limits, now: now) else { return }
            let retryAfter = max(0, quota.reset - now)
            switch quota.window {
            case 60:
                OmMetrics.limiterMinutelyExceededTotal.add(1, ordering: .relaxed)
                throw RateLimitError.minutelyExceeded(quota: quota, retryAfter: retryAfter)
            case 3600:
                OmMetrics.limiterHourlyExceededTotal.add(1, ordering: .relaxed)
                throw RateLimitError.hourlyExceeded(quota: quota, retryAfter: retryAfter)
            default:
                OmMetrics.limiterDailyExceededTotal.add(1, ordering: .relaxed)
                throw RateLimitError.dailyExceeded(quota: quota, retryAfter: retryAfter)
            }
        }

        private func quota(minute: Float, hour: Float, day: Float, limits: (minute: Float, hour: Float, day: Float), now: Int) -> Quota? {
            let resetTime = lastReset.load(ordering: .acquiring)
            let offset = Int(resetTime % 60)
            var limit: Float = 0
            var remaining = Float.infinity
            var window = 0
            var reset = 0

            if limits.minute > 0 {
                limit = limits.minute
                remaining = max(0, limits.minute - minute)
                window = 60
                reset = ((now - offset) / 60 + 1) * 60 + offset
            }

            if limits.hour > 0 {
                let hourlyRemaining = max(0, limits.hour - hour)
                let hourlyReset = ((now - offset) / 3600 + 1) * 3600 + offset
                if hourlyRemaining < remaining || (hourlyRemaining == remaining && hourlyReset > reset) {
                    limit = limits.hour
                    remaining = hourlyRemaining
                    window = 3600
                    reset = hourlyReset
                }
            }

            if limits.day > 0 {
                let dailyRemaining = max(0, limits.day - day)
                let dailyReset = ((now - offset) / 86400 + 1) * 86400 + offset
                if dailyRemaining < remaining || (dailyRemaining == remaining && dailyReset > reset) {
                    limit = limits.day
                    remaining = dailyRemaining
                    window = 86400
                    reset = dailyReset
                }
            }

            guard limit > 0 else { return nil }
            return Quota(limit: limit, remaining: remaining, window: window, reset: reset)
        }

        /// Return the quota using the updated values, without reloading usage.
        @discardableResult
        func increment(_ count: Float, limits: (minute: Float, hour: Float, day: Float), now: Int = Timestamp.now().timeIntervalSince1970) -> Quota? {
            let minute = limits.minute > 0 ? minuteUsed.add(count) : 0
            let hour = limits.hour > 0 ? hourUsed.add(count) : 0
            let day = limits.day > 0 ? dayUsed.add(count) : 0
            return quota(minute: minute, hour: hour, day: day, limits: limits, now: now)
        }
    }

    func counter(uint32 ip: UInt32, now: Int? = nil) -> ClientUsageCounter? {
        guard limits.minute > 0 || limits.hour > 0 || limits.day > 0 else { return nil }
        if let counter = perIPv4[ip] { return counter }
        let counter = ClientUsageCounter(lastReset: UInt32(now ?? Timestamp.now().timeIntervalSince1970))
        perIPv4[ip] = counter
        return counter
    }

    func counter(int64 ip: Int, now: Int? = nil) -> ClientUsageCounter? {
        guard limits.minute > 0 || limits.hour > 0 || limits.day > 0 else { return nil }
        if let counter = perIPv6[ip] { return counter }
        let counter = ClientUsageCounter(lastReset: UInt32(now ?? Timestamp.now().timeIntervalSince1970))
        perIPv6[ip] = counter
        return counter
    }

    /// Look up the shared counter and retain it for the duration of the request.
    func counter(address: SocketAddress, now: Int? = nil) -> ClientUsageCounter? {
        if allowlistedIPs?.contains(address) == true {
            return nil
        }
        switch address {
        case .v4(let socket):
            return counter(uint32: socket.address.sin_addr.s_addr, now: now)
        case .v6:
            var hasher = Hasher()
            address.hash(into: &hasher)
            return counter(int64: hasher.finalize(), now: now)
        case .unixDomainSocket:
            return nil
        }
    }

}

extension CIDR {
    /// Check if the IP is explicitly listed
    func contains(_ socket: SocketAddress) -> Bool {
        switch socket {
        case .v4(let ip4):
            return self.contains(ip4.address.sin_addr.mappedToV6)
        case .v6(let ip6):
            return self.contains(ip6.address.sin6_addr)
        case .unixDomainSocket(_):
            return false
        }
    }
}

enum RateLimitError: Error, AbortError, Equatable {
    case dailyExceeded(quota: RateLimiter.Quota, retryAfter: Int)
    case hourlyExceeded(quota: RateLimiter.Quota, retryAfter: Int)
    case minutelyExceeded(quota: RateLimiter.Quota, retryAfter: Int)
    case tooManyConcurrentRequests
    case serviceOverloaded

    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .serviceOverloaded:
            return .serviceUnavailable
        default:
            return .tooManyRequests
        }
    }

    var reason: String {
        switch self {
        case .dailyExceeded:
            return "Daily API request limit exceeded. Please try again tomorrow."
        case .hourlyExceeded:
            return "Hourly API request limit exceeded. Please try again in the next hour."
        case .minutelyExceeded:
            return "Minutely API request limit exceeded. Please try again in one minute."
        case .tooManyConcurrentRequests:
            return "Too many concurrent requests"
        case .serviceOverloaded:
            return "The service is overloaded"
        }
    }
}
