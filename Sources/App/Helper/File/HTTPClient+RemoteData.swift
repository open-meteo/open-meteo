import AsyncHTTPClient
import Synchronization

/// One process-wide connection pool for remote data listings, metadata, range reads and health checks.
/// See `docs/remote-data.md` at the repository root for HTTP connection settings.
extension HTTPClient {
    private static let remoteDataInitialized = Atomic(false)
    private static let remoteDataHTTPConnections = Atomic(8)

    /// Set the HTTP/1 per-host connection limit during startup, before any remote data requests.
    /// Does not initialize the pool; standalone users retain the default of eight connections.
    public static func configureRemoteDataHTTPConnections(_ limit: Int) {
        precondition(limit > 0)
        precondition(!remoteDataInitialized.load(ordering: .acquiring), "Configure remote data connections before using the pool")
        remoteDataHTTPConnections.store(limit, ordering: .releasing)
    }

    public static let sharedRemoteData: HTTPClient = {
        var configuration = HTTPClient.Configuration.singletonConfiguration
        configuration.httpVersion = .http1Only
        configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = remoteDataHTTPConnections.load(ordering: .acquiring)
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
