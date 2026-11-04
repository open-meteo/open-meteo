import AsyncHTTPClient
import OmFileIO
import Vapor

/// Stops remote health monitoring and shuts down the shared data request pool.
/// Also stops preload jobs and rotation warming before shutting down the pool.
struct RemoteDataHttpClientLifecycle: LifecycleHandler {
    static func positiveLimit(_ name: String, default value: Int) -> Int {
        guard let limit = Int(Environment.get(name) ?? String(value)), limit > 0 else {
            fatalError("\(name) must be a positive integer")
        }
        return limit
    }

    func shutdownAsync(_ application: Application) async {
        if OmFileSystemManager.isInitialized {
            await OmFileSystemManager.instance.remoteFileSystem?.server.preloadExecutor.shutdown()
            await OmFileSystemManager.instance.remoteFileSystem?.server.stopMonitoring()
        }
        do {
            try await HTTPClient.shutdownRemoteDataIfInitialized()
        } catch {
            application.logger.error("Remote data HTTP client shutdown failed: \(error)")
        }
    }
}
