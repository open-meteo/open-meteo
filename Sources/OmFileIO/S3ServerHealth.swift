import Foundation
import AsyncHTTPClient
import Logging

public enum S3ServerHealthError: Error {
    case allEndpointsUnavailable
}

/// Wraps `S3ServerHealth` into a vapor usable service that does not allow an async init
public actor S3ServerHealth {
    public nonisolated let logger: Logger
    public nonisolated let client: HTTPClient
    private var downloadSchedulers: [String: RemoteDownloadScheduler] = [:]
    private let downloadLimit: Int
    private let backgroundDownloadLimit: Int
    public nonisolated let cacheWarmer = RemoteCacheWarmer()
    var states: [ServerState]
    var monitor: Task<Void, Never>?
    var initialWaitQueue: [CheckedContinuation<Void, Never>]?
    
    struct ServerState: Sendable {
        let server: S3BucketEndpoint
        var isOnline: Bool
    }
    
    public init(logger: Logger, servers: [S3BucketEndpoint], client: HTTPClient = .shared, downloadLimit: Int = 32, backgroundDownloadLimit: Int = 4) {
        precondition(downloadLimit > 0 && backgroundDownloadLimit > 0 && backgroundDownloadLimit <= downloadLimit)
        self.downloadLimit = downloadLimit
        self.backgroundDownloadLimit = backgroundDownloadLimit
        self.logger = logger
        self.client = client
        self.states = servers.map({ .init(server: $0, isOnline: true) })
        self.initialWaitQueue = []
    }
    
    public func downloadScheduler(for endpoint: S3BucketEndpoint) -> RemoteDownloadScheduler {
        let cleanURL = endpoint.uploadServer.extractSchemaUserNamePasswordCleanUrl()?.url ?? endpoint.uploadServer
        let url = URL(string: cleanURL)
        let origin = "\(url?.scheme ?? "https")://\(url?.host?.lowercased() ?? ""):\(url?.port ?? (url?.scheme == "http" ? 80 : 443))"
        if let scheduler = downloadSchedulers[origin] { return scheduler }
        let scheduler = RemoteDownloadScheduler(limit: downloadLimit, backgroundLimit: backgroundDownloadLimit)
        downloadSchedulers[origin] = scheduler
        return scheduler
    }

    public func downloadMetrics() async -> [(String, RemoteDownloadScheduler.Snapshot)] {
        var result: [(String, RemoteDownloadScheduler.Snapshot)] = []
        for (origin, scheduler) in downloadSchedulers {
            result.append((origin, await scheduler.snapshot))
        }
        return result
    }

    private func ensureChecks() async {
        if monitor == nil {
            monitor = Task { [weak self] in
                while let self {
                    await self.performHealthChecks()
                    do {
                        try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                    } catch {
                        return
                    }
                }
            }
        }
        if initialWaitQueue != nil {
            await withCheckedContinuation({
                self.initialWaitQueue?.append($0)
            })
        }
    }
    
    /// Deterministically returns the same server for the same hash. Used to distribute load to different endpoints. Throws `S3ServerHealthError.allEndpointsUnavailable` if all servers are offline
    /// If a server is offline, the hash is distributed to other server endpoints evenly.
    public func getServerFor(hash: UInt64) async throws -> S3BucketEndpoint {
        await ensureChecks()
        
        var selected: S3BucketEndpoint?
        var highestScore: UInt64 = 0

        for (index, state) in states.enumerated() where state.isOnline {
            // Rendezvous hashing assigns a stable score to every key/server
            // pair. Removing an offline server only remaps its own keys.
            var score = hash ^ ((UInt64(index) &+ 1) &* 0x9e3779b97f4a7c15)
            score = (score ^ (score >> 30)) &* 0xbf58476d1ce4e5b9
            score = (score ^ (score >> 27)) &* 0x94d049bb133111eb
            score ^= score >> 31

            if selected == nil || score > highestScore {
                selected = state.server
                highestScore = score
            }
        }

        guard let selected else {
            throw S3ServerHealthError.allEndpointsUnavailable
        }
        return selected
    }
    
    public func activeServers() async -> [S3BucketEndpoint] {
        await ensureChecks()
        return states.filter(\.isOnline).map(\.server)
    }
    
    private func performHealthChecks() async {
        for i in states.indices {
            let server = states[i].server
            do {
                var request = HTTPClientRequest(url: server.uploadServer)
                request.method = .HEAD
                request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
                // Keep health checks independent of the remote-data connection pool.
                _ = try await HTTPClient.shared.executeRetry(
                    request,
                    logger: logger,
                    deadline: .seconds(60),
                    timeoutPerRequest: .seconds(10)
                )

                if states[i].isOnline == false {
                    logger.error("S3 server is online again: \(server.uploadServer.stripHttpPassword())")
                }
                states[i].isOnline = true
            } catch {
                logger.error("S3 server HEAD failed: \(server.uploadServer.stripHttpPassword()). Error: \(error)")
                states[i].isOnline = false
            }
        }
        
        if let initialWaitQueue {
            initialWaitQueue.forEach({ $0.resume() })
            self.initialWaitQueue = nil
        }
    }

    public func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }
}
