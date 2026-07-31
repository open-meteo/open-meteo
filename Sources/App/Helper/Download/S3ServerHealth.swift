import Foundation
import Vapor
import AsyncHTTPClient
import Logging

struct S3ReplicationServer: Sendable, Hashable {
    /// URL including credentials, expected in form `s3://key:secret@server.tld/`
    let s3URL: String

    var redacted: String {
        s3URL.stripHttpPassword()
    }

    func objectURL(relativePath: String) -> String {
        let base = s3URL.hasSuffix("/") ? String(s3URL.dropLast()) : s3URL
        return "\(base)/\(relativePath)"
    }
}

actor S3ServerHealth {
    private struct ServerState: Sendable {
        let server: S3ReplicationServer
        var isOnline: Bool
    }

    private let client: HTTPClient
    private let logger: Logger
    private var states: [ServerState]
    private var initialChecksCompleted = false
    private var monitorTask: Task<Void, Never>?

    init(client: HTTPClient, logger: Logger, servers: [S3ReplicationServer]) {
        self.client = client
        self.logger = logger
        self.states = servers.map { .init(server: $0, isOnline: true) }
    }

    static func loadFromEnvironment(key: String = "S3_REPLICATION_SERVERS") -> [S3ReplicationServer] {
        guard let configured = Environment.get(key) else {
            return []
        }

        return configured
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { url in
                let withSlash = url.hasSuffix("/") ? url : url + "/"
                return S3ReplicationServer(s3URL: withSlash)
            }
    }

    func activeServers() async -> [S3ReplicationServer] {
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

    func shutdown() {
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
            var request = HTTPClientRequest(url: server.objectURL(relativePath: ""))
            request.method = .HEAD
            request.headers.add(name: "x-amz-content-sha256", value: Data().sha256Hex)
            _ = try await client.executeRetry(
                request,
                logger: logger,
                deadline: .seconds(20),
                timeoutPerRequest: .seconds(5)
            )

            if states[index].isOnline == false {
                logger.info("Replication server is online again: \(server.redacted)")
            }
            states[index].isOnline = true
        } catch {
            logger.error("Replication server HEAD failed: \(server.redacted). Error: \(error)")
            states[index].isOnline = false
        }
    }
}

private final class S3ServerHealthLifecycle: LifecycleHandler {
    private let manager: S3ServerHealth

    init(manager: S3ServerHealth) {
        self.manager = manager
    }

    func shutdown(_ application: Application) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await manager.shutdown()
            semaphore.signal()
        }
        semaphore.wait()
    }
}

extension Application {
    fileprivate struct S3ServerHealthKey: StorageKey, LockKey {
        typealias Value = S3ServerHealth
    }

    var s3ServerHealth: S3ServerHealth {
        let lock = self.locks.lock(for: S3ServerHealthKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[S3ServerHealthKey.self] {
            return existing
        }

        let manager = S3ServerHealth(client: dedicatedHttpClient, logger: logger, servers: S3ServerHealth.loadFromEnvironment())
        self.lifecycle.use(S3ServerHealthLifecycle(manager: manager))
        self.storage[S3ServerHealthKey.self] = manager
        return manager
    }
}
