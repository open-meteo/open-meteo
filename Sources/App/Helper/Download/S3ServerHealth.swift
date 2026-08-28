import Foundation
import Vapor
import AsyncHTTPClient
import Logging

enum S3ServerHealthError: Error {
    case allEndpointsUnavailable
}

/// Monitors a list of S3 Servers. On initialisation performs the first server check and then checks every 10 seconds in the background
actor S3ServerHealth {
    let logger: Logger
    var states: [ServerState]
    var monitor: Task<Void, Never>?
    
    struct ServerState: Sendable {
        let server: S3BucketEndpoint
        var isOnline: Bool
    }
    
    init(logger: Logger, servers: [S3BucketEndpoint]) async {
        self.logger = logger
        self.states = servers.map({ .init(server: $0, isOnline: true) })
        await performHealthChecks()
        self.monitor = Task { [weak self] in
            while let self {
                do {
                    try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                } catch {
                    return
                }
                await self.performHealthChecks()
            }
        }
    }
    
    /// Deterministically returns the same server for the same hash. Used to distribute load to different endpoints. Throws `S3ServerHealthError.allEndpointsUnavailable` if all servers are offline
    /// If a server is offline, the hash is distributed to other server endpoints evenly.
    func getServerFor(hash: UInt64) throws -> S3BucketEndpoint {
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
    
    func activeServers() async -> [S3BucketEndpoint] {
        return states.filter(\.isOnline).map(\.server)
    }
    
    private func performHealthChecks() async {
        let client = HTTPClient.shared
        for i in states.indices {
            let server = states[i].server
            do {
                var request = HTTPClientRequest(url: server.uploadServer)
                request.method = .HEAD
                request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
                _ = try await client.executeRetry(
                    request,
                    logger: logger,
                    deadline: .seconds(20),
                    timeoutPerRequest: .seconds(5)
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
    }
}

/// Wraps `S3ServerHealth` into a vapor usable service that does not allow an async init
actor S3ServerHealthService {
    private var state: State
    
    private enum State {
        case uninitialised(servers: [S3BucketEndpoint], logger: Logger)
        case initialising(queue: [CheckedContinuation<S3ServerHealth, Never>])
        case initialised(states: S3ServerHealth)
    }

    init(logger: Logger, servers: [S3BucketEndpoint]) {
        self.state = .uninitialised(servers: servers, logger: logger)
    }
    
    func getInstance() async -> S3ServerHealth {
        switch state {
        case .uninitialised(let servers, let logger):
            self.state = .initialising(queue: [])
            let watcher = await S3ServerHealth(logger: logger, servers: servers)
            guard case .initialising(let queued) = self.state else {
                fatalError("State was not .initialising()")
            }
            self.state = .initialised(states: watcher)
            queued.forEach {
                $0.resume(with: .success(watcher))
            }
            return watcher
        case .initialising(let queue):
            let watcher = await withCheckedContinuation { continuation in
                self.state = .initialising(queue: queue + [continuation])
            }
            return watcher
        case .initialised(let watcher):
            return watcher
        }
    }

    nonisolated func activeServers() async -> [S3BucketEndpoint] {
        return await getInstance().activeServers()
    }
}

extension Application {
    fileprivate struct S3ServerHealthKey: StorageKey, LockKey {
        typealias Value = S3ServerHealthService
    }

    /// Monitored S3 hosts to replicate upload S3 files
    var s3UploadReplicationServer: S3ServerHealthService {
        let lock = self.locks.lock(for: S3ServerHealthKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3ServerHealthKey.self] {
            return existing
        }
        let servers = S3BucketEndpoint.loadFromEnvironment(variable: "S3_UPLOAD_REPLICATION_SERVERS")
        let manager = S3ServerHealthService(logger: logger, servers: servers)
        self.storage[S3ServerHealthKey.self] = manager
        return manager
    }
}
