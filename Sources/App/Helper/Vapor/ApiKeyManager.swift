import Foundation
import Vapor
import AsyncHTTPClient
import NIO

/**
 Keep track of API keys and update a list of API keys from a file
 */
public final actor ApiKeyManager {
    public static let instance = ApiKeyManager()

    struct KeyAndLimit: Equatable {
        let key: String.SubSequence
        let limit: Int
        let id: String.SubSequence?

        static func readApiKeys(path: String) -> [KeyAndLimit] {
            return (try? String(contentsOfFile: path, encoding: .utf8))?.split(separator: ",").sorted().map {
                let parts = $0.split(separator: ";")
                let limit = parts.count <= 1 ? 0 : Int(parts[1]) ?? 0
                let id = parts.count <= 2 ? nil : parts[2]
                return KeyAndLimit(key: parts[0], limit: limit, id: id)
            } ?? []
        }
    }

    private init() {
        guard let apiKeysPath = Environment.get("API_APIKEYS_PATH") else {
            return
        }
        self.apiKeys = KeyAndLimit.readApiKeys(path: apiKeysPath)
        self.usage = .init()
        self.usage.reserveCapacity(apiKeys.count)
    }

    var apiKeys = [KeyAndLimit]()

    /// usage per customer id
    var usage = [String: (calls: Int32, weight: Float)]()

    func set(_ keys: [KeyAndLimit]) {
        if self.apiKeys == keys {
            return
        }
        self.apiKeys = keys
    }

    /// Return current API key usage
    func getUsage() -> String {
        let usage = self.usage.sorted { $0.1.weight > $1.1.weight }
        return usage[0..<min(10, usage.count)].map { "\($0.0)=\($0.1.calls) (w\($0.1.weight))" }.joined(separator: ", ")
    }
    
    /// Return current usage and reset counter to 0
    func flushUsage() -> [String: (calls: Int32, weight: Float)] {
        let usage = self.usage
        self.usage = .init()
        self.usage.reserveCapacity(self.apiKeys.count)
        return usage
    }

    func isEmpty() -> Bool {
        return apiKeys.isEmpty
    }

    func getLimit(_ string: String.SubSequence) -> Int? {
        return apiKeys.first(where: {$0.key == string})?.limit
    }

    func increment(apikey: String.SubSequence, weight: Float) {
        guard let id = apiKeys.first(where: { $0.key == apikey })?.id.map(String.init) else {
            return
        }
        guard let used = usage[id] else {
            usage[id] = (1, weight)
            return
        }
        usage[id] = (used.calls + 1, used.weight + weight)
    }

    /// Fetch API keys and update database
    @Sendable public static func update(application: Application) async {
        guard let apiKeysPath = Environment.get("API_APIKEYS_PATH") else {
            return
        }
        let concurrencyLimit = apiConcurrencyLimiter.stats()
        let logger = application.logger
        if (0..<10).contains(Timestamp.now().second) {
            let usage = await ApiKeyManager.instance.getUsage()
            logger.error("API key usage: \(usage). Concurrency \(concurrencyLimit)")
        }
        let keys = KeyAndLimit.readApiKeys(path: apiKeysPath)
        guard keys.count > 0 else {
            logger.error("Could not read content from API_APIKEYS_PATH \(apiKeysPath)")
            return
        }
        // Set new keys
        await ApiKeyManager.instance.set(keys)
    }
    
    /// Upload metered API usage events
    @Sendable public static func uploadApiKeyMetrics(application: Application) async {
        guard let apiKey = Environment.get("STRIPE_API_KEY") else {
            return
        }
        let logger = application.logger
        let events = await Self.instance.flushUsage()
        guard events.count > 0 else {
            return
        }
        logger.error("API Key Metrics: Getting session to upload \(events.count) events")
        let meter = StripeMeterEvents(apiKey: apiKey, client: application.http.client.shared, logger: logger)
        do {
            let time = DispatchTime.now()
            let session = try await meter.getAuthenticationToken()
            logger.error("API Key Metrics: Established session in \(time.timeElapsedPretty())")
            let time2 = DispatchTime.now()
            try await session.submit(events: events)
            logger.error("API Key Metrics: Upload of \(events.count) entries completed in \(time2.timeElapsedPretty())")
        } catch {
            logger.error("API Key Metrics: Failed to upload. Error: \(error)")
        }
    }
}


extension SocketAddress {
    var rateLimitSlot: Int {
        switch self {
        case .v4(let socket):
            return Int(socket.address.sin_addr.s_addr)
        case .v6:
            var hasher = Hasher()
            self.hash(into: &hasher)
            return hasher.finalize()
        case .unixDomainSocket:
            return 0
        }
    }
}

extension Request {
    func parseApiParams() throws -> ApiQueryParameter {
        self.method == .POST ? try self.content.decode(ApiQueryParameter.self) : try self.query.decode(ApiQueryParameter.self)
    }

    /// http or https
    fileprivate var scheme: String {
        return headers.first(name: "X-Forwarded-Proto") ?? url.scheme ?? "http"
    }

    /// fn params: hostname, unlockSlot, numberOfLocationsMaximum, params
    @discardableResult
    func withApiParameter<T: ForecastapiResponder>(_ subdomain: String, alias: [String] = [], fn: (String?, ApiQueryParameter) async throws -> T) async throws -> Response {
        // let host = "api.open-meteo.com"
        guard let host = headers[.host].first(where: { $0.contains("open-meteo.com") }) else {
            // localhost or not an openmeteo host
            let params = try parseApiParams()
            let responder = try await fn(nil, params)
            let weight = responder.calculateQueryWeight(nVariablesModels: nil)
            return try await responder.response(format: params.formatWithOptions, concurrencySlot: nil, prefetch: weight < 10)
        }
        let isDevNode = host.contains("eu0") || host.contains("us0")
        let isFreeApi = host.starts(with: subdomain) || alias.contains(where: { host.starts(with: $0) }) == true || isDevNode
        let isCustomerApi = host.starts(with: "customer-\(subdomain)") || alias.contains(where: { host.starts(with: "customer-\($0)") }) == true

        if !(isFreeApi || isCustomerApi) {
            throw Abort(.notFound)
        }

        if isFreeApi {
            guard let address = peerAddress ?? remoteAddress else {
                throw ForecastApiError.generic(message: "Could not get remote address")
            }
            /// For CloudFlare worker applications, use the `CF-Worker` header for rate limiting instead of IP address
            let isCFWorker = RateLimiter.cloudFlareWorkerIPs.contains(address)
            let slot: Int
            if isCFWorker, let cfHash = self.headers["CF-Worker"].first?.hashValue {
                slot = cfHash
            } else {
                slot = address.rateLimitSlot
            }
            try await apiConcurrencyLimiter.wait(slot: slot, maxConcurrent: 1, maxConcurrentHard: 5)
            defer {
                apiConcurrencyLimiter.release(slot: slot)
            }
            if isCFWorker {
                try await RateLimiter.instance.check(int64: slot)
            } else {
                try await RateLimiter.instance.check(address: address)
            }
            
            let params = try parseApiParams()
            guard params.apikey == nil else {
                guard self.method != .POST else {
                    throw ForecastApiError.generic(message: "Please use the customer- prefixed URL for POST requests")
                }
                let url = "\(scheme)://customer-\(host)/\(url.string)"
                guard url.count < 3500 else {
                    throw ForecastApiError.generic(message: "Your API URL is too long for automatic redirection from the open-access API to the commercial endpoints. Instead, use the 'customer-' prefixed URLs directly. Refer to the API documentation and select 'Usage -> Commercial' to obtain the correct customer URLs.")
                }
                return self.redirect(to: url)
            }
            let responder = try await fn(host, params)
            if responder.numberOfLocations > OpenMeteo.numberOfLocationsMaximum {
                throw ForecastApiError.generic(message: "Only up to \(OpenMeteo.numberOfLocationsMaximum) locations can be requested at once")
            }
            let weight = responder.calculateQueryWeight(nVariablesModels: nil)
            guard weight <= RateLimiter.limitHourly else {
                throw ForecastApiError.generic(message: "Your API call requests too much data. Please reduce the number of variables, locations and/or weather models.")
            }
            let response = try await responder.response(format: params.formatWithOptions, concurrencySlot: slot, prefetch: weight < 10)
            if isCFWorker {
                await RateLimiter.instance.increment(int64: slot, count: weight)
            } else {
                await RateLimiter.instance.increment(address: address, count: weight)
            }
            return response
        }

        let params = try parseApiParams()
        guard let apikey = params.apikey else {
            throw ApiKeyManagerError.apiKeyRequired
        }
        guard let limit = await ApiKeyManager.instance.getLimit(String.SubSequence(apikey)) else {
            throw ApiKeyManagerError.apiKeyInvalid
        }
        let apiProfessionalApis = ["archive-api.", "climate-api.", "ensemble-api.", "historical-forecast-api.", "previous-runs-api.", "single-runs-api.", "satellite-api.", "seasonal-api."]
        if limit > 0 && limit < 5_000_000 && apiProfessionalApis.contains(where: {host.contains($0)}) {
            throw ApiKeyManagerError.apiProfessionalRequired
        }
        let numberOfLocationsMaximum = limit >= 20_000_000 ? 200_000 : 10_000
        let maxConcurrent = max(2, limit / 5_000_000)
        let slot = apikey.hash
        try await apiConcurrencyLimiter.wait(slot: slot, maxConcurrent: maxConcurrent, maxConcurrentHard: 256)
        defer {
            apiConcurrencyLimiter.release(slot: slot)
        }
        let responder = try await fn(host, params)
        if responder.numberOfLocations > numberOfLocationsMaximum {
            throw ForecastApiError.generic(message: "Only up to \(numberOfLocationsMaximum) locations can be requested at once")
        }
        let weight = responder.calculateQueryWeight(nVariablesModels: nil)
        let response = try await responder.response(format: params.formatWithOptions, concurrencySlot: slot, prefetch: weight < 10)
        await ApiKeyManager.instance.increment(apikey: String.SubSequence(apikey), weight: weight)
        return response
    }
}

enum ApiKeyManagerError: Error {
    case apiKeyRequired
    case apiKeyInvalid
    case apiProfessionalRequired
}

extension ApiKeyManagerError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .apiKeyRequired:
            return .unauthorized
        case .apiKeyInvalid:
            return .badRequest
        case .apiProfessionalRequired:
            return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .apiKeyRequired:
            return "API key required. Please add &apikey= to the URL."
        case .apiKeyInvalid:
            return "The supplied API key is invalid."
        case .apiProfessionalRequired:
            return "This API endpoint requires the API Professional or Enterprise plan"
        }
    }
}
