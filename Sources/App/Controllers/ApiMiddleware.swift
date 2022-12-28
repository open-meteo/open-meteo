import Foundation
import FluentMySQLDriver
import Fluent
import Vapor
import NIOConcurrencyHelpers
import NIO

final class ApiKey: Model {
    @ID(key: .id)
    var id: Int?
    
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
    
    @Field(key: "has_histrocal_access")
    var has_histrocal_access: Bool
    
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

/// Request counting and API key protection
final class ApiMiddleware: LifecycleHandler {
    private var apikeys = [String: ApiKey]()
    
    private var backgroundWatcher: RepeatedTask?
    
    static var instance = ApiMiddleware()
    
    private let lock = NIOLock()
    
    private init() {}
    
    func didBoot(_ application: Application) throws {
        let logger = application.logger
        let eventloop = application.eventLoopGroup.next()
        guard let database = application.databases.database(.mysql, logger: logger, on: eventloop) else {
            logger.debug("No database configured, allowing all API keys")
            return
        }
        
        logger.debug("Starting API key manager")
        backgroundWatcher = eventloop.scheduleRepeatedAsyncTask(initialDelay: .seconds(2), delay: .seconds(2), {
            task in
            
            let promise = eventloop.makePromise(of: Void.self)
            promise.completeWithTask {
                var last_update = Date(timeIntervalSince1970: 0)
                let updated = await try ApiKey.query(on: database).filter(\.$last_modified > last_update).all()
                
                let copy = self.lock.withLock {
                    fatalError()
                }
            }
            return promise.futureResult
        })
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher?.cancel()
    }
}
