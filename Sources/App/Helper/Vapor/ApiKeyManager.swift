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
        self.apiKeys = (try? String(contentsOfFile: apikeysPath, encoding: .utf8))?.split(separator: ",") ?? []
    }
    
    var apiKeys = [String.SubSequence]()
    
    var usage = [Int]()
    
    func set(_ keys: [String.SubSequence]) {
        if self.apiKeys == keys {
            return
        }
        self.apiKeys = keys
        self.usage = [Int](repeating: 0, count: keys.count)
    }
    
    /// Return current API key usage
    func getUsage() -> String {
        let usage: [(String.SubSequence, Int)] = zip(self.apiKeys, self.usage).sorted { $0.1 > $1.1 }
        return usage[0..<min(10, usage.count)].map{"\($0.0)=\($0.1)"}.joined(separator: ", ")
    }
    
    
    func isEmpty() -> Bool {
        return apiKeys.isEmpty
    }
    
    func contains(_ string: String.SubSequence) -> Bool {
        guard let index = apiKeys.firstIndex(where: { $0 == string }) else {
            return false
        }
        usage[index] += 1
        return true
    }
    
    /// Fetch API keys and update database
    @Sendable public static func update(application: Application) async {
        guard let apikeysPath = Environment.get("API_APIKEYS_PATH") else {
            return
        }
        let logger = application.logger
        if Timestamp.now().second == 0 {
            let usage = await ApiKeyManager.instance.getUsage()
            logger.warning("API key usage: \(usage)")
        }
        guard let string = try? String(contentsOfFile: apikeysPath, encoding: .utf8) else {
            logger.error("Could not read content from API_APIKEYS_PATH \(apikeysPath)")
            return
        }
        // Set new keys
        await ApiKeyManager.instance.set(string.split(separator: ","))
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
    func ensureApiKey(_ subdomain: String, alias: [String] = [], apikey: String?) async throws -> Int {
        guard let host = headers[.host].first(where: {$0.contains("open-meteo.com")}) else {
            return OpenMeteo.numberOfLocationsMaximum
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
            return apikey.starts(with: "ojHdOi7") ? 200_000 : 10_000;
        }
        return OpenMeteo.numberOfLocationsMaximum
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

