import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: WebsiteController())
    
    try app.register(collection: ForecastapiController())
    
    try app.register(collection: S3DataController())
}

extension RoutesBuilder {
    @preconcurrency
    public func getAndPost<Response>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    )
    where Response: AsyncResponseEncodable
    {
        self.on(.GET, path, use: closure)
        self.on(.POST, path, use: closure)
    }
}
