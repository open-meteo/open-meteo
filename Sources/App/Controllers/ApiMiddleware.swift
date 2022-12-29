import Foundation
import FluentMySQLDriver
import Fluent
import Vapor
import NIO


enum ApiMiddlewareError: AbortError {
    case invalidApiKey
    case apikeyRequired
    case apikeyCannotBeUsedOnPublicApi
    
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .invalidApiKey:
            return .unauthorized
        case .apikeyRequired:
            return .unauthorized
        case .apikeyCannotBeUsedOnPublicApi:
            return .forbidden
        }
    }
    
    var reason: String {
        switch self {
        case .invalidApiKey:
            return "Invalid API key"
        case .apikeyRequired:
            return "API key required"
        case .apikeyCannotBeUsedOnPublicApi:
            return "API key cannot be used on free API"
        }
    }
}


final class ApiKey: Model {
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "apikey")
    var apikey: String
    
    @Field(key: "apikey2")
    var apikey2: String
    
    @Field(key: "valid_until")
    var valid_until: Date
    
    @Field(key: "last_modified")
    var last_modified: Date
    
    @Field(key: "active")
    var active: Bool
    
    @Field(key: "has_histroy_access")
    var has_histroy_access: Bool
    
    @Field(key: "has_raw_data_access")
    var has_raw_data_access: Bool
    
    @Field(key: "limit_daily")
    var limit_daily: Int
    
    @Field(key: "limit_minutely")
    var limit_minutely: Int
    
    @Field(key: "limit_monthly")
    var limit_monthly: Int
    
    @Field(key: "subscription_id")
    var subscription_id: String
    
    static let schema = "apikeys"
    
    init() { }
}

extension ApiKey: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Self.schema)
            .field(.id, .uuid, .identifier(auto: false))
            .field($apikey.key, .string, .required)
            .field($apikey2.key, .string, .required)
            .field($valid_until.key, .datetime, .required)
            .field($last_modified.key, .datetime, .required)
            .field($active.key, .bool, .required)
            .field($has_histroy_access.key, .bool, .required)
            .field($has_raw_data_access.key, .bool, .required)
            .field($limit_daily.key, .int64, .required)
            .field($limit_minutely.key, .int64, .required)
            .field($limit_monthly.key, .int64, .required)
            .field($subscription_id.key, .string, .required)
            .ignoreExisting()
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Self.schema).delete()
    }
}
    

/// Keeps all API keys in memory. Thread safe.
final actor ApikeyContainer {
    var apikeys = [UUID: ApiKey]()
    
    var last_updated = Date(timeIntervalSince1970: 0)
    
    /// True if API keys have been loaded
    var ready: Bool {
        apikeys.count > 0
    }
    
    func update(updated: [ApiKey]) {
        for apikey in updated {
            apikeys[apikey.id!] = apikey
            last_updated = max(last_updated, apikey.last_modified)
        }
    }
}

/// Request counting and API key protection
final class ApiMiddleware: LifecycleHandler {
    fileprivate var apikeys = ApikeyContainer()
    
    private var backgroundWatcher: RepeatedTask?
    
    static var instance = ApiMiddleware()
    
    func didBoot(_ application: Application) throws {
        let logger = application.logger
        let eventloop = application.eventLoopGroup.next()
        guard let database = application.databases.database(.mysql, logger: logger, on: eventloop) else {
            logger.debug("No database configured, allowing all API keys")
            return
        }
        
        logger.debug("Starting API key manager")
        backgroundWatcher = eventloop.scheduleRepeatedAsyncTask(initialDelay: .seconds(0), delay: .seconds(2), {
            task in
            let promise = eventloop.makePromise(of: Void.self)
            promise.completeWithTask {
                do {
                    let updated = try await ApiKey.query(on: database).filter(\.$last_modified > self.apikeys.last_updated).all()
                    await self.apikeys.update(updated: updated)
                } catch {
                    logger.error("API key manager error: \(error)")
                }
            }
            return promise.futureResult
        })
    }
    
    public func authorise(apikey: UUID?, calls: Float) throws {
        // TODO: check available call per minute/day/month
    }
    
    public func settle(apikey: UUID?, calls: Float) {
        // TODO: account used calls
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher?.cancel()
    }
}

extension Request {
    /// Find the API key or throw an error
    func checkApiKey() async throws {
        let isCustomerApi = headers[.host].contains(where: { $0.contains("open-meteo.com") && $0.starts(with: "customer-") })
        
        guard let apikey: String = try query.get(at: "apikey") else {
            if await ApiMiddleware.instance.apikeys.ready && isCustomerApi {
                throw ApiMiddlewareError.apikeyRequired
            }
            // TODO: IP rate limiting
            return
        }
        // API key used in public API
        if isCustomerApi == false {
            throw ApiMiddlewareError.apikeyCannotBeUsedOnPublicApi
        }
        guard await ApiMiddleware.instance.apikeys.apikeys.contains(where: { $0.value.apikey == apikey || $0.value.apikey2 == apikey }) else {
            throw ApiMiddlewareError.invalidApiKey
        }
        // TODO: check active flag and expiration date
    }
}
