import AsyncHTTPClient
import Synchronization

/// One process-wide connection pool for remote data listings, metadata, range reads and health checks.
/// See `docs/remote-data.md` at the repository root for HTTP connection settings.
extension HTTPClient {
    private static let remoteDataInitialized = Atomic(false)

    public static let sharedRemoteData: HTTPClient = {
        var configuration = HTTPClient.Configuration.singletonConfiguration
        configuration.httpVersion = .http1Only
        configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = OpenMeteo.remoteDataHTTPConnections
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
