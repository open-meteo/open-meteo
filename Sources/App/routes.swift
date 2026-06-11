import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: WebsiteController())

    try app.register(collection: ForecastapiController())

    try app.register(collection: S3DataController())
}

extension RoutesBuilder {
    @preconcurrency
    public func getAndPost<Response: AsyncResponseEncodable & Sendable>(
        _ path: PathComponent...,
        use closure: @Sendable @escaping (Request) async throws -> Response
    ) {
        self.on(.GET, path, use: cancellableHandler(closure))
        self.on(.POST, path, body: .collect(maxSize: "128kb"), use: cancellableHandler(closure))
    }
}

private func cancellableHandler<Response: AsyncResponseEncodable & Sendable>(
    _ closure: @Sendable @escaping (Request) async throws -> Response
) -> @Sendable (Request) async throws -> Response {
    return { req in
        let task = Task {
            try await closure(req)
        }
        req.body.drain { result in
            if case .error = result {
                task.cancel()
            }
            return req.eventLoop.makeSucceededVoidFuture()
        }
        return try await task.value
    }
}
