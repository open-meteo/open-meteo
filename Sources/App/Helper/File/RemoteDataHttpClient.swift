import AsyncHTTPClient
import OmFileIO
import Vapor

/// Stops remote health monitoring and shuts down the shared data request pool.
struct RemoteDataHttpClientLifecycle: LifecycleHandler {
    func shutdownAsync(_ application: Application) async {
        if OmFileSystemManager.isInitialized {
            await OmFileSystemManager.instance.remoteFileSystem?.server.stopMonitoring()
        }
        do {
            try await HTTPClient.shutdownRemoteDataIfInitialized()
        } catch {
            application.logger.error("Remote data HTTP client shutdown failed: \(error)")
        }
    }
}
