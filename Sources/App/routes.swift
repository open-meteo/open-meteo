import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: WebsiteController())
    
    try app.register(collection: ForecastapiController())
    
    try app.register(collection: SyncController())
}

extension RoutesBuilder {
    @preconcurrency
    public func getAndPost<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) throws -> Response
    )
    where Response: ResponseEncodable
    {
        self.on(.GET, path, use: closure)
        self.on(.POST, path, use: closure)
    }
}
