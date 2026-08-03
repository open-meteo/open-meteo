import Foundation
import Vapor
import AsyncHTTPClient
import Logging

actor S3ServerHealth: LifecycleHandler {
    private struct ServerState: Sendable {
        /// Well formatted server string with trailing slash
        let server: String
        var isOnline: Bool
    }

    private let client: HTTPClient
    private let logger: Logger
    private var states: [ServerState]
    private var initialChecksCompleted = false
    private var monitorTask: Task<Void, Never>?

    init(client: HTTPClient, logger: Logger, servers: [String]) {
        self.client = client
        self.logger = logger
        self.states = servers.map { .init(server: $0, isOnline: true) }
    }

    static func loadFromEnvironment(key: String = "S3_UPLOAD_REPLICATION_SERVERS") -> [String] {
        guard let configured = Environment.get(key) else {
            return []
        }

        return configured
            .split(separator: ",")
            .map { url in
                let url = String(url)
                guard url.starts(with: "s3://") else {
                    fatalError("replication server URL must start with 's3://'")
                }
                guard url.hasSuffix("/") else {
                    fatalError("replication server URL must end with '/' trailing slash")
                }
                return url
            }
    }

    func activeServers() async -> [String] {
        if initialChecksCompleted == false {
            await performHealthChecks()
            initialChecksCompleted = true

            guard monitorTask == nil else {
                return states.filter(\.isOnline).map(\.server)
            }
            monitorTask = Task { [weak self] in
                while let self {
                    do {
                        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                    } catch {
                        return
                    }
                    await self.performHealthChecks()
                }
            }
        }
        return states.filter(\.isOnline).map(\.server)
    }
    
    /// Called from lifecycle manager to shutdown application
    func shutdownAsync(_ application: Application) async {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func performHealthChecks() async {
        guard !states.isEmpty else {
            return
        }
        for i in states.indices {
            await checkServer(index: i)
        }
    }

    private func checkServer(index: Int) async {
        let server = states[index].server
        do {
            var request = HTTPClientRequest(url: server)
            request.method = .HEAD
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            _ = try await client.executeRetry(
                request,
                logger: logger,
                deadline: .seconds(20),
                timeoutPerRequest: .seconds(5)
            )

            if states[index].isOnline == false {
                logger.info("Replication server is online again: \(server.stripHttpPassword())")
            }
            states[index].isOnline = true
        } catch {
            logger.error("Replication server HEAD failed: \(server.stripHttpPassword()). Error: \(error)")
            states[index].isOnline = false
        }
    }
}

extension Application {
    fileprivate struct S3ServerHealthKey: StorageKey, LockKey {
        typealias Value = S3ServerHealth
    }

    /// Monitored S3 hosts to replicate upload S3 files
    var s3UploadReplicationServer: S3ServerHealth {
        let lock = self.locks.lock(for: S3ServerHealthKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3ServerHealthKey.self] {
            return existing
        }
        let manager = S3ServerHealth(client: dedicatedHttpClient, logger: logger, servers: S3ServerHealth.loadFromEnvironment())
        self.lifecycle.use(manager)
        self.storage[S3ServerHealthKey.self] = manager
        return manager
    }
}
