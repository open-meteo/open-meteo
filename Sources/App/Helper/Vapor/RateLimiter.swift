import Foundation
import Vapor
import NIO

/**
 Limit API request rate for the free API.
 Count how many calls have been made by a given IP address.
 */
final actor RateLimiter {
    private static let limitDaily = Float(Environment.get("CALL_LIMIT_DAILY").flatMap(Int.init) ?? 10_000)

    private static let limitHourly = Float(Environment.get("CALL_LIMIT_HOURLY").flatMap(Int.init) ?? 5_000)

    private static let limitMinutely = Float(Environment.get("CALL_LIMIT_MINUTELY").flatMap(Int.init) ?? 600)

    private var dailyPerIPv4 = [UInt32: Float]()

    private var dailyPerIPv6 = [Int: Float]()

    private var hourlyPerIPv4 = [UInt32: Float]()

    private var hourlyPerIPv6 = [Int: Float]()

    private var minutelyPerIPv4 = [UInt32: Float]()

    private var minutelyPerIPv6 = [Int: Float]()
    
    /// List of IP addresses / networks to disable rate limited
    var allowlistedIPs: CIDR?
    
    /// See https://www.cloudflare.com/en-gb/ips/
    /// Last updated 2026-02-19
    nonisolated(unsafe) static let cloudFlareWorkerIPs = CIDR("173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0/14,172.64.0.0/13,131.0.72.0/22,2400:cb00::/32,2606:4700::/32,2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32")

    public static let instance = RateLimiter()

    private init() {
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
    func minutelyCallback() {
        let now = Timestamp.now().timeIntervalSince1970
        minutelyPerIPv4.removeAll(keepingCapacity: true)
        minutelyPerIPv6.removeAll(keepingCapacity: true)
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
            hourlyPerIPv4.removeAll(keepingCapacity: true)
            hourlyPerIPv6.removeAll(keepingCapacity: true)
        }
        if (now % (24 * 3600)) < 60 {
            dailyPerIPv4.removeAll(keepingCapacity: true)
            dailyPerIPv6.removeAll(keepingCapacity: true)
        }
    }

    /// Check if the current IP address is over quota and throw an error. If not return.
    func check(address: SocketAddress) throws {
        guard Self.limitDaily > 0 || Self.limitHourly > 0 || Self.limitMinutely > 0 else {
            return
        }
        if allowlistedIPs?.contains(address) == true {
            return // always allow this IP address
        }
        switch address {
        case .v4(let socket):
            try check(uint32: socket.address.sin_addr.s_addr)
        case .v6:
            var hasher = Hasher()
            address.hash(into: &hasher)
            let ip = hasher.finalize()
            try check(int64: ip)
        case .unixDomainSocket:
            break
        }
    }
    
    func check(uint32 ip: UInt32) throws {
        if Self.limitMinutely > 0, let usageMinutely = minutelyPerIPv4[ip], usageMinutely >= Self.limitMinutely {
            throw RateLimitError.minutelyExceeded
        }
        if Self.limitHourly > 0, let usageHourly = hourlyPerIPv4[ip], usageHourly >= Self.limitHourly {
            throw RateLimitError.hourlyExceeded
        }
        if Self.limitDaily > 0, let usageDaily = dailyPerIPv4[ip], usageDaily >= Self.limitDaily {
            throw RateLimitError.dailyExceeded
        }
    }
    
    func check(int64 ip: Int) throws {
        if Self.limitMinutely > 0, let usageMinutely = minutelyPerIPv6[ip], usageMinutely >= Self.limitMinutely {
            throw RateLimitError.minutelyExceeded
        }
        if Self.limitHourly > 0, let usageHourly = hourlyPerIPv6[ip], usageHourly >= Self.limitHourly {
            throw RateLimitError.hourlyExceeded
        }
        if Self.limitDaily > 0, let usageDaily = dailyPerIPv6[ip], usageDaily >= Self.limitDaily {
            throw RateLimitError.dailyExceeded
        }
    }

    /// Increment the current IP address by the specified counter
    /// `count` can be later used to increase the weight for "heavy" API calls. E.g. calls with many weather variables my account for more than just 1.
    func increment(address: SocketAddress, count: Float) {
        guard Self.limitDaily > 0 || Self.limitHourly > 0 || Self.limitMinutely > 0 else {
            return
        }
        switch address {
        case .v4(let socket):
            increment(uint32: socket.address.sin_addr.s_addr, count: count)
        case .v6:
            var hasher = Hasher()
            address.hash(into: &hasher)
            let ip = hasher.finalize()
            increment(int64: ip, count: count)
        case .unixDomainSocket:
            break
        }
    }
    
    func increment(uint32 ip: UInt32, count: Float) {
        if Self.limitMinutely > 0 {
            minutelyPerIPv4[ip] = count + (minutelyPerIPv4[ip] ?? 0)
        }
        if Self.limitHourly > 0 {
            hourlyPerIPv4[ip] = count + (hourlyPerIPv4[ip] ?? 0)
        }
        if Self.limitDaily > 0 {
            dailyPerIPv4[ip] = count + (dailyPerIPv4[ip] ?? 0)
        }
    }
    
    func increment(int64 ip: Int, count: Float) {
        if Self.limitMinutely > 0 {
            minutelyPerIPv6[ip] = count + (minutelyPerIPv6[ip] ?? 0)
        }
        if Self.limitHourly > 0 {
            hourlyPerIPv6[ip] = count + (hourlyPerIPv6[ip] ?? 0)
        }
        if Self.limitDaily > 0 {
            dailyPerIPv6[ip] = count + (dailyPerIPv6[ip] ?? 0)
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

enum RateLimitError: Error, AbortError {
    case dailyExceeded
    case hourlyExceeded
    case minutelyExceeded
    case tooManyConcurrentRequests

    var status: NIOHTTP1.HTTPResponseStatus {
        return .tooManyRequests
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
        }
    }
}

extension Request {
    func incrementRateLimiter(weight: Float, apikey: String?) async {
        guard let address = peerAddress ?? remoteAddress else {
            return
        }
        if let apikey {
            await ApiKeyManager.instance.increment(apikey: String.SubSequence(apikey), weight: weight)
        }
        /// Free API
        if headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "customer-") }) {
            await RateLimiter.instance.increment(address: address, count: weight)
        }
    }
}
