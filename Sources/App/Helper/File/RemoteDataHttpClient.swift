import AsyncHTTPClient
import Vapor

/// Owns the remote filesystem client's configuration and application shutdown.
struct RemoteDataHttpClient: LifecycleHandler {
    static func positiveLimit(_ name: String, default value: Int) -> Int {
        guard let limit = Int(Environment.get(name) ?? String(value)), limit > 0 else {
            fatalError("\(name) must be a positive integer")
        }
        return limit
    }

    static func makeClient() -> HTTPClient {
        let rawLimit = Environment.get("REMOTE_DATA_HTTP_CONNECTIONS") ?? "8"
        guard let limit = Int(rawLimit), limit > 0 else {
            fatalError("REMOTE_DATA_HTTP_CONNECTIONS must be a positive integer")
        }
        var configuration = HTTPClient.Configuration.singletonConfiguration
        // HTTP/2 uses the peer's concurrent-stream limit instead.
        configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = limit
        return HTTPClient(eventLoopGroup: HTTPClient.defaultEventLoopGroup, configuration: configuration)
    }

    func shutdownAsync(_ application: Application) async {
        guard OmFileSystemManager.isInitialized,
              let server = OmFileSystemManager.instance.remoteFileSystem?.server else {
            return
        }
        await server.cacheWarmer.shutdown()
        await server.stopMonitoring()
        do {
            try await server.client.shutdown()
        } catch {
            application.logger.error("Remote data HTTP client shutdown failed: \(error)")
        }
    }
}
