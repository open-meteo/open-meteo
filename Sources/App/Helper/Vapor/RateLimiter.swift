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

    public static let instance = RateLimiter()

    private init() {
        if let ipAllowlistPath = Environment.get("IP_ALLOWLIST_PATH") {
            do {
                let cidr = try CIDR(filename: ipAllowlistPath)
                allowlistedIPs = cidr
                print("IP allow list loaded \(cidr.ipv4.ips.count) IPv4 and \(cidr.ipv6.ips.count) IPv6 address ranges")
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
            let ip: UInt32 = socket.address.sin_addr.s_addr
            if Self.limitMinutely > 0, let usageMinutely = minutelyPerIPv4[ip], usageMinutely >= Self.limitMinutely {
                throw RateLimitError.minutelyExceeded
            }

            if Self.limitHourly > 0, let usageHourly = hourlyPerIPv4[ip], usageHourly >= Self.limitHourly {
                throw RateLimitError.hourlyExceeded
            }

            if Self.limitDaily > 0, let usageDaily = dailyPerIPv4[ip], usageDaily >= Self.limitDaily {
                throw RateLimitError.dailyExceeded
            }
        case .v6:
            var hasher = Hasher()
            address.hash(into: &hasher)
            let ip = hasher.finalize()
            if Self.limitMinutely > 0, let usageMinutely = minutelyPerIPv6[ip], usageMinutely >= Self.limitMinutely {
                throw RateLimitError.minutelyExceeded
            }
            if Self.limitHourly > 0, let usageHourly = hourlyPerIPv6[ip], usageHourly >= Self.limitHourly {
                throw RateLimitError.hourlyExceeded
            }
            if Self.limitDaily > 0, let usageDaily = dailyPerIPv6[ip], usageDaily >= Self.limitDaily {
                throw RateLimitError.dailyExceeded
            }
        case .unixDomainSocket:
            break
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
            let ip: UInt32 = socket.address.sin_addr.s_addr
            if Self.limitMinutely > 0 {
                minutelyPerIPv4[ip] = count + (minutelyPerIPv4[ip] ?? 0)
            }
            if Self.limitHourly > 0 {
                hourlyPerIPv4[ip] = count + (hourlyPerIPv4[ip] ?? 0)
            }
            if Self.limitDaily > 0 {
                dailyPerIPv4[ip] = count + (dailyPerIPv4[ip] ?? 0)
            }
        case .v6:
            var hasher = Hasher()
            address.hash(into: &hasher)
            let ip = hasher.finalize()
            if Self.limitMinutely > 0 {
                minutelyPerIPv6[ip] = count + (minutelyPerIPv6[ip] ?? 0)
            }
            if Self.limitHourly > 0 {
                hourlyPerIPv6[ip] = count + (hourlyPerIPv6[ip] ?? 0)
            }
            if Self.limitDaily > 0 {
                dailyPerIPv6[ip] = count + (dailyPerIPv6[ip] ?? 0)
            }
        case .unixDomainSocket:
            break
        }
    }
}

extension CIDR {
    /// Check if the IP is explicitly listed
    func contains(_ socket: SocketAddress) -> Bool {
        switch socket {
        case .v4(let ip4):
            return self.ipv4.contains(CIDR.IPv4(ip: ip4.address.sin_addr.s_addr.bigEndian))
        case .v6(let ip6):
            // Read IPv6 bytes portably without relying on union fields
            let v6 = ip6.address.sin6_addr
            let cidrV6: CIDR.IPv6 = withUnsafeBytes(of: v6) { rawPtr in
                let b = rawPtr.bindMemory(to: UInt8.self)
                let w0 = (UInt32(b[0]) << 24) | (UInt32(b[1]) << 16) | (UInt32(b[2]) << 8) | UInt32(b[3])
                let w1 = (UInt32(b[4]) << 24) | (UInt32(b[5]) << 16) | (UInt32(b[6]) << 8) | UInt32(b[7])
                let w2 = (UInt32(b[8]) << 24) | (UInt32(b[9]) << 16) | (UInt32(b[10]) << 8) | UInt32(b[11])
                let w3 = (UInt32(b[12]) << 24) | (UInt32(b[13]) << 16) | (UInt32(b[14]) << 8) | UInt32(b[15])
                return CIDR.IPv6(w0: w0, w1: w1, w2: w2, w3: w3)
            }
            // Detect IPv4-mapped IPv6: ::ffff:a.b.c.d => first 10 bytes zero, next two 0xff
            let isV4Mapped = withUnsafeBytes(of: v6) { rawPtr -> Bool in
                let b = rawPtr.bindMemory(to: UInt8.self)
                return b[0] == 0 && b[1] == 0 && b[2] == 0 && b[3] == 0 &&
                       b[4] == 0 && b[5] == 0 && b[6] == 0 && b[7] == 0 &&
                       b[8] == 0 && b[9] == 0 && b[10] == 0xff && b[11] == 0xff
            }
            if isV4Mapped {
                // Extract the last 4 bytes as IPv4
                let v4 = withUnsafeBytes(of: v6) { rawPtr -> CIDR.IPv4 in
                    let b = rawPtr.bindMemory(to: UInt8.self)
                    let ip = (UInt32(b[12]) << 24) | (UInt32(b[13]) << 16) | (UInt32(b[14]) << 8) | UInt32(b[15])
                    return CIDR.IPv4(ip: ip)
                }
                if self.ipv4.contains(v4) {
                    return true
                }
            }
            return self.ipv6.contains(cidrV6)
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
