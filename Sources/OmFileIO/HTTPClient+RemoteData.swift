import AsyncHTTPClient
import Synchronization
import Vapor

/// One process-wide connection pool for remote data listings, metadata and range reads.
/// Health checks use `HTTPClient.shared` independently.
extension HTTPClient {
    private static let remoteDataInitialized = Atomic(false)

    public static let sharedRemoteData: HTTPClient = {
        let rawLimit = Environment.get("REMOTE_DATA_HTTP_CONNECTIONS") ?? "8"
        guard let limit = Int(rawLimit), limit > 0 else {
            fatalError("REMOTE_DATA_HTTP_CONNECTIONS must be a positive integer")
        }
        var configuration = HTTPClient.Configuration.singletonConfiguration
        // HTTP/2 uses the peer's concurrent-stream limit instead.
        configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = limit
        let client = HTTPClient(eventLoopGroup: HTTPClient.defaultEventLoopGroup, configuration: configuration)
        remoteDataInitialized.store(true, ordering: .releasing)
        return client
    }()

    /// Avoid creating the pool during shutdown of commands that never used remote data.
    public static func shutdownRemoteDataIfInitialized() async throws {
        guard remoteDataInitialized.load(ordering: .acquiring) else {
            return
        }
        try await sharedRemoteData.shutdown()
    }
}
