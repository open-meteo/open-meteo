import Foundation
import Vapor
import NIO
import NIOConcurrencyHelpers


/**
 Limit API request rate limit for the free API.
 Count how many calls have been made by a given IP address.
 */
final class RateLimiter: LifecycleHandler {
    private static let limitDaily = Float(Environment.get("CALL_LIMIT_DAILY").flatMap(Int.init) ?? 10_000)
    
    private static let limitHourly = Float(Environment.get("CALL_LIMIT_HOURLY").flatMap(Int.init) ?? 5_000)
    
    private static let limitMinutely = Float(Environment.get("CALL_LIMIT_MINUTELY").flatMap(Int.init) ?? 600)
    
    /// Ensure thread safety
    private let lock = NIOLock()
    
    private var backgroundWatcher: RepeatedTask?
        
    private var dailyPerIPv4 = [UInt32: Float]()
    
    private var dailyPerIPv6 = [Int: Float]()
    
    private var hourlyPerIPv4 = [UInt32: Float]()
    
    private var hourlyPerIPv6 = [Int: Float]()
    
    private var minutelyPerIPv4 = [UInt32: Float]()
    
    private var minutelyPerIPv6 = [Int: Float]()
    
    public static var instance = RateLimiter()
        
    private init() {}
    
    /// Setup timer to empty statics every minute, hour or day
    func didBoot(_ application: Application) throws {
        backgroundWatcher = application.eventLoopGroup.next().scheduleRepeatedTask(
            initialDelay: .seconds(Int64(60 - Timestamp.now().second)),
            delay: .seconds(60),
            { task in
            let now = Timestamp.now().timeIntervalSince1970
            self.lock.withLockVoid {
                self.minutelyPerIPv4.removeAll(keepingCapacity: true)
                self.minutelyPerIPv6.removeAll(keepingCapacity: true)
                if (now % 3600) < 60 {
                    self.hourlyPerIPv4.removeAll(keepingCapacity: true)
                    self.hourlyPerIPv6.removeAll(keepingCapacity: true)
                }
                if (now % (24*3600)) < 60 {
                    self.dailyPerIPv4.removeAll(keepingCapacity: true)
                    self.dailyPerIPv6.removeAll(keepingCapacity: true)
                }
            }
        })
    }
    
    /// Check if the current IP address is over quota and throw an error. If not, update counter and return.
    /// `count` can be later used to increase the weight for "heavy" API calls. E.g. calls with many weather variables my account for more than just 1.
    func check(request: Request, count: Float) throws {
        guard Self.limitDaily > 0 || Self.limitHourly > 0 || Self.limitMinutely > 0 else {
            return
        }
        guard let address = request.peerAddress ?? request.remoteAddress else {
            return
        }
        switch address {
        case .v4(let socket):
            let ip: UInt32 = socket.address.sin_addr.s_addr
            return try lock.withLock({
                let usageMinutely = Self.limitMinutely > 0 ? minutelyPerIPv4[ip] ?? 0 : 0
                if usageMinutely >= Self.limitMinutely {
                    throw RateLimitError.minutlyExceeded
                }
                let usageHourly = Self.limitHourly > 0 ? hourlyPerIPv4[ip] ?? 0 : 0
                if usageHourly >= Self.limitHourly {
                    throw RateLimitError.hourlyExceeded
                }
                let usageDaily = Self.limitDaily > 0 ? dailyPerIPv4[ip] ?? 0 : 0
                if usageDaily >= Self.limitDaily {
                    throw RateLimitError.dailyExceeded
                }
                if Self.limitMinutely > 0 {
                    minutelyPerIPv4[ip] = count + usageMinutely
                }
                if Self.limitHourly > 0 {
                    hourlyPerIPv4[ip] = count + usageHourly
                }
                if Self.limitDaily > 0 {
                    dailyPerIPv4[ip] = count + usageDaily
                }
                return
            })
        case .v6(let socket):
            let i32 = socket.address.sin6_addr.__u6_addr.__u6_addr32
            let ip: Int = (Int(i32.0) << 32 &+ Int(i32.1)) ^ (Int(i32.2) << 32 &+ Int(i32.3))
            return try lock.withLock({
                let usageMinutely = Self.limitMinutely > 0 ? minutelyPerIPv6[ip] ?? 0 : 0
                if usageMinutely >= Self.limitMinutely {
                    throw RateLimitError.minutlyExceeded
                }
                let usageHourly = Self.limitHourly > 0 ? hourlyPerIPv6[ip] ?? 0 : 0
                if usageHourly >= Self.limitHourly {
                    throw RateLimitError.hourlyExceeded
                }
                let usageDaily = Self.limitDaily > 0 ? dailyPerIPv6[ip] ?? 0 : 0
                if usageDaily >= Self.limitDaily {
                    throw RateLimitError.dailyExceeded
                }
                if Self.limitMinutely > 0 {
                    minutelyPerIPv6[ip] = count + usageMinutely
                }
                if Self.limitHourly > 0 {
                    hourlyPerIPv6[ip] = count + usageHourly
                }
                if Self.limitDaily > 0 {
                    dailyPerIPv6[ip] = count + usageDaily
                }
                return
            })
        case .unixDomainSocket(_):
            return
        }
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher?.cancel()
    }
}

enum RateLimitError: Error, AbortError {
    case dailyExceeded
    case hourlyExceeded
    case minutlyExceeded
    
    var status: NIOHTTP1.HTTPResponseStatus {
        return .tooManyRequests
    }
    
    var reason: String {
        switch self {
        case .dailyExceeded:
            return "Daily API request limit exceeded. Please try again tomorrow."
        case .hourlyExceeded:
            return "Hourly API request limit exceeded. Please try again in the next hour."
        case .minutlyExceeded:
            return "Minutely API request limit exceeded. Please try again in one minute."
        }
    }
}

extension Request {
    /// On open-meteo servers, make sure, the right domain is active. For reserved API instances an API key required.
    func ensureSubdomain(_ subdomain: String) throws {
        if headers[.host].contains(where: { $0.contains("open-meteo.com") && !($0.starts(with: subdomain) || $0.starts(with: "customer-\(subdomain)")) }) {
            throw Abort.init(.notFound)
        }
        
        /// Free API
        if headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "customer-") }) {
            try RateLimiter.instance.check(request: self, count: 1)
        }
        
        /// API node dedicated to customers
        if !ApiKeyManager.apiKeys.isEmpty && headers[.host].contains(where: { $0.contains("open-meteo.com") && $0.starts(with: "customer-\(subdomain)") }) {
            guard let apikey: String = try query.get(at: "apikey") else {
                throw ApiKeyManagerError.apiKeyRequired
            }
            guard ApiKeyManager.apiKeys.contains(String.SubSequence(apikey)) else {
                throw ApiKeyManagerError.apiKeyInvalid
            }
        }
    }
}


/// Simple API key management. Ensures API calls do not get blocked by automatic rate limiting above 10k daily calls.
fileprivate struct ApiKeyManager {
    static var apiKeys: [String.SubSequence] = Environment.get("API_APIKEYS")?.split(separator: ",") ?? []
}

enum ApiKeyManagerError: Error {
    case apiKeyRequired
    case apiKeyInvalid
}

extension ApiKeyManagerError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .apiKeyRequired:
            return .unauthorized
        case .apiKeyInvalid:
            return .badRequest
        }
    }
    
    var reason: String {
        switch self {
        case .apiKeyRequired:
            return "API key required. Please add &apikey= to the URL."
        case .apiKeyInvalid:
            return "The supplied API key is invalid."
        }
    }
}



