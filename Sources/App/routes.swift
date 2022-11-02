import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: WebsiteController())
    
    try app.register(collection: ForecastapiController())
    
    try app.register(collection: SyncController())
}
