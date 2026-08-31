import Vapor


extension TimeError: AbortError {
    public var status: NIOHTTP1.HTTPResponseStatus {
        return .badRequest
    }
}
