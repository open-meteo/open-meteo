import Foundation
import Vapor
import NIO
import NIOConcurrencyHelpers


/**
 Limit API request rate limit for the free API.
 Count how many calls have been made by a given IP address.
 */
final class RateLimiterLifecycle: LifecycleHandler {
    private let backgroundWatcher = NIOLockedValueBox<RepeatedTask?>(nil)
    
    public static var instance = RateLimiterLifecycle()
        
    private init() {}
    
    /// Setup timer to empty statics every minute, hour or day
    func didBoot(_ application: Application) throws {
        backgroundWatcher.withLockedValue({
            let eventloop = application.eventLoopGroup.next()
            $0 = eventloop.scheduleRepeatedAsyncTask(
                initialDelay: .seconds(Int64(60 - Timestamp.now().second)),
                delay: .seconds(60),
                { task in
                    eventloop.makeFutureWithTask({
                        await RateLimiter.instance.minutelyCallback()
                    })
                }
            )
        })
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher.withLockedValue {
            $0?.cancel()
        }
    }
}

/// Thread safe access to rate limiter
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
    
    public static var instance = RateLimiter()
        
    private init() {}
    
    func minutelyCallback() {
        let now = Timestamp.now().timeIntervalSince1970
        minutelyPerIPv4.removeAll(keepingCapacity: true)
        minutelyPerIPv6.removeAll(keepingCapacity: true)
        if (now % 3600) < 60 {
            hourlyPerIPv4.removeAll(keepingCapacity: true)
            hourlyPerIPv6.removeAll(keepingCapacity: true)
        }
        if (now % (24*3600)) < 60 {
            dailyPerIPv4.removeAll(keepingCapacity: true)
            dailyPerIPv6.removeAll(keepingCapacity: true)
        }
    }
    
    /// Check if the current IP address is over quota and throw an error. If not return.
    func check(address: SocketAddress) throws {
        guard Self.limitDaily > 0 || Self.limitHourly > 0 || Self.limitMinutely > 0 else {
            return
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
        case .v6(_):
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
        case .unixDomainSocket(_):
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
        case .v6(_):
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
        case .unixDomainSocket(_):
            break
        }
    }
}

enum RateLimitError: Error, AbortError {
    case dailyExceeded
    case hourlyExceeded
    case minutelyExceeded
    
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
        }
    }
}

extension Request {
    /// On open-meteo servers, make sure, the right domain is active
    func ensureSubdomain(_ subdomain: String, alias: String? = nil) async throws {
        guard let host = headers[.host].first(where: {$0.contains("open-meteo.com")}) else {
            return
        }
        let isFreeApi = host.starts(with: subdomain) || alias.map({host.starts(with: $0)}) == true
        let isCustomerApi = host.starts(with: "customer-\(subdomain)") || alias.map({host.starts(with: "customer-\($0)")}) == true
        
        if !(isFreeApi || isCustomerApi) {
            throw Abort.init(.notFound)
        }
        
        if isFreeApi {
            guard let address = peerAddress ?? remoteAddress else {
                return
            }
            try await RateLimiter.instance.check(address: address)
        }
    }
    
    /// For customer API endpoints, check API key.
    func ensureApiKey(_ subdomain: String, alias: String? = nil, apikey: String?) throws {
        guard let host = headers[.host].first(where: {$0.contains("open-meteo.com")}) else {
            return
        }
        let isCustomerApi = host.starts(with: "customer-\(subdomain)") || alias.map({host.starts(with: "customer-\($0)")}) == true
        
        /// API node dedicated to customers
        if !ApiKeyManager.apiKeys.isEmpty && isCustomerApi {
            guard let apikey else {
                throw ApiKeyManagerError.apiKeyRequired
            }
            guard ApiKeyManager.apiKeys.contains(String.SubSequence(apikey)) else {
                throw ApiKeyManagerError.apiKeyInvalid
            }
        }
    }
    
    func incrementRateLimiter(weight: Float) async {
        guard let address = peerAddress ?? remoteAddress else {
            return
        }
        /// Free API
        if headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "customer-") }) {
            await RateLimiter.instance.increment(address: address, count: weight)
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



