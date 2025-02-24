import Foundation
import Vapor
import AsyncHTTPClient

/**
 Keep track of API keys and update a list of API keys from a file
 */
public final actor ApiKeyManager {
    public static var instance = ApiKeyManager()
    
    private init() {
        guard let apikeysPath = Environment.get("API_APIKEYS_PATH") else {
            return
        }
        let keys = ((try? String(contentsOfFile: apikeysPath, encoding: .utf8))?.split(separator: ",") ?? []).sorted()
        self.apiKeys = keys
        self.usage = .init(repeating: (0,0), count: keys.count)
    }
    
    var apiKeys = [String.SubSequence]()
    
    var usage = [(calls: Int32, weight: Float)]()
    
    func set(_ keys: [String.SubSequence]) {
        if self.apiKeys == keys {
            return
        }
        self.apiKeys = keys
        self.usage = .init(repeating: (0,0), count: keys.count)
    }
    
    /// Return current API key usage
    func getUsage() -> String {
        let usage = zip(self.apiKeys, self.usage).sorted { $0.1.weight > $1.1.weight }
        return usage[0..<min(10, usage.count)].map{"\($0.0)=\($0.1.calls) (w\($0.1.weight))"}.joined(separator: ", ")
    }
    
    
    func isEmpty() -> Bool {
        return apiKeys.isEmpty
    }
    
    func contains(_ string: String.SubSequence) -> Bool {
        return apiKeys.contains(string)
    }
    
    func increment(apikey: String.SubSequence, weight: Float) {
        guard let index = apiKeys.firstIndex(where: { $0 == apikey }) else {
            return
        }
        usage[index] = (usage[index].calls + 1, usage[index].weight + weight)
    }
    
    /// Fetch API keys and update database
    @Sendable public static func update(application: Application) async {
        guard let apikeysPath = Environment.get("API_APIKEYS_PATH") else {
            return
        }
        let logger = application.logger
        if (0..<10).contains(Timestamp.now().second) {
            let usage = await ApiKeyManager.instance.getUsage()
            logger.error("API key usage: \(usage)")
        }
        guard let string = try? String(contentsOfFile: apikeysPath, encoding: .utf8) else {
            logger.error("Could not read content from API_APIKEYS_PATH \(apikeysPath)")
            return
        }
        // Set new keys
        await ApiKeyManager.instance.set(string.split(separator: ",").sorted())
    }
}

extension Request {
    /// On open-meteo servers, make sure, the right domain is active
    /// Returns the hostdomain if running on "open-meteo.com"
    @discardableResult
    func ensureSubdomain(_ subdomain: String, alias: [String] = []) async throws -> String? {
        guard let host = headers[.host].first(where: {$0.contains("open-meteo.com")}) else {
            return nil
        }
        let isDevNode = host.contains("eu0") || host.contains("us0")
        let isFreeApi = host.starts(with: subdomain) || alias.contains(where: {host.starts(with: $0)}) == true || isDevNode
        let isCustomerApi = host.starts(with: "customer-\(subdomain)") || alias.contains(where: {host.starts(with: "customer-\($0)")}) == true
        
        if !(isFreeApi || isCustomerApi) {
            throw Abort.init(.notFound)
        }
        
        if isFreeApi {
            guard let address = peerAddress ?? remoteAddress else {
                return host
            }
            try await RateLimiter.instance.check(address: address)
        }
        return host
    }
    
    /// For customer API endpoints, check API key.
    func ensureApiKey(_ subdomain: String, alias: [String] = [], apikey: String?) async throws -> (numberOfLocations: Int, apikey: String?) {
        guard let host = headers[.host].first(where: {$0.contains("open-meteo.com")}) else {
            return (OpenMeteo.numberOfLocationsMaximum, nil)
        }
        let isCustomerApi = host.starts(with: "customer-\(subdomain)") || alias.contains(where: {host.starts(with: "customer-\($0)")}) == true
        
        /// API node dedicated to customers
        if await !ApiKeyManager.instance.isEmpty() && isCustomerApi {
            guard let apikey else {
                throw ApiKeyManagerError.apiKeyRequired
            }
            guard await ApiKeyManager.instance.contains(String.SubSequence(apikey)) else {
                throw ApiKeyManagerError.apiKeyInvalid
            }
            return (apikey.starts(with: "ojHdOi7") ? 200_000 : 10_000, apikey);
        }
        return (OpenMeteo.numberOfLocationsMaximum, nil)
    }
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

