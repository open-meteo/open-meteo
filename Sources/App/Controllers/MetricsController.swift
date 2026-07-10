import Vapor
import NIO
import Synchronization

/// Runtime statistics print to the console regularly
/// Could be further improved
enum OmStatistics {
    static let fileCacheInactivityEvictions = Atomic(0)
    static let fileCacheLocalModified = Atomic(0)
    static let fileCacheRemoteModified = Atomic(0)
    static let fileCacheRemoteDeleted = Atomic(0)
    static let fileCacheRemoteRevalidated = Atomic(0)
    static let fileCacheRemoteCheckedExist = Atomic(0)
    static let fileCacheCurrentlyOpeningFiles = Atomic(0)
    static let fileCacheCurrentlyWaitingOnOpeningFiles = Atomic(0)
}


struct MetricsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("metrics", use: self.metricsHandler)
    }

    @Sendable
    func metricsHandler(_ req: Request) async throws -> Response {
        guard req.remoteAddress?.isLocalhost == true else {
            throw Abort(.forbidden)
        }
        let cacheStats = OpenMeteo.dataBlockCacheInitialized.load(ordering: .relaxed)
            ? OpenMeteo.dataBlockCache.cache.statistics()
            : .zero

        let concurrencyStats = await ConcurrencyGroupLimiter.instance.stats()

        let body = """
# TYPE om_file_cache_inactive_evictions counter
# HELP om_file_cache_inactive_evictions File cache entries evicted after inactivity
om_file_cache_inactive_evictions_total \(OmStatistics.fileCacheInactivityEvictions.load(ordering: .relaxed))
# TYPE om_file_cache_local_modified counter
# HELP om_file_cache_local_modified Local files modified
om_file_cache_local_modified_total \(OmStatistics.fileCacheLocalModified.load(ordering: .relaxed))
# TYPE om_file_cache_remote_modified counter
# HELP om_file_cache_remote_modified Remote files modified
om_file_cache_remote_modified_total \(OmStatistics.fileCacheRemoteModified.load(ordering: .relaxed))
# TYPE om_file_cache_remote_deleted counter
# HELP om_file_cache_remote_deleted Remote files deleted
om_file_cache_remote_deleted_total \(OmStatistics.fileCacheRemoteDeleted.load(ordering: .relaxed))
# TYPE om_file_cache_remote_revalidated counter
# HELP om_file_cache_remote_revalidated Remote file revalidations
om_file_cache_remote_revalidated_total \(OmStatistics.fileCacheRemoteRevalidated.load(ordering: .relaxed))
# TYPE om_file_cache_remote_checked_exist counter
# HELP om_file_cache_remote_checked_exist Remote existence checks
om_file_cache_remote_checked_exist_total \(OmStatistics.fileCacheRemoteCheckedExist.load(ordering: .relaxed))
# TYPE om_file_cache_opening_files gauge
# HELP om_file_cache_opening_files Currently opening files
om_file_cache_opening_files \(OmStatistics.fileCacheCurrentlyOpeningFiles.load(ordering: .relaxed))
# TYPE om_file_cache_waiting_on_opening gauge
# HELP om_file_cache_waiting_on_opening Files queued waiting to open
om_file_cache_waiting_on_opening \(OmStatistics.fileCacheCurrentlyWaitingOnOpeningFiles.load(ordering: .relaxed))
# TYPE om_block_cache_used_bytes gauge
# UNIT om_block_cache_used_bytes bytes
# HELP om_block_cache_used_bytes Used cache bytes
om_block_cache_used_bytes \(cacheStats.used)
# TYPE om_block_cache_free_bytes gauge
# UNIT om_block_cache_free_bytes bytes
# HELP om_block_cache_free_bytes Free cache bytes
om_block_cache_free_bytes \(cacheStats.free)
# HELP om_block_cache_accessed_bytes Block cache accessed data volume over a given window.
# TYPE om_block_cache_accessed_bytes gauge
om_block_cache_accessed_bytes{window="15m"} \(cacheStats.accessed_15min)
om_block_cache_accessed_bytes{window="30m"} \(cacheStats.accessed_30min)
om_block_cache_accessed_bytes{window="60m"} \(cacheStats.accessed_60min)
om_block_cache_accessed_bytes{window="3h"} \(cacheStats.accessed_3hours)
om_block_cache_accessed_bytes{window="24h"} \(cacheStats.accessed_24hours)
# TYPE om_concurrency_monitored_ips gauge
# HELP om_concurrency_monitored_ips Distinct IPs currently rate-limited
om_concurrency_monitored_ips \(concurrencyStats.monitored_ips)
# TYPE om_concurrency_total_running gauge
# HELP om_concurrency_total_running Currently running requests
om_concurrency_total_running \(concurrencyStats.total_running)
# TYPE om_concurrency_queued_requests gauge
# HELP om_concurrency_queued_requests Queued requests waiting for slot
om_concurrency_queued_requests \(concurrencyStats.queued_requests)
# EOF

"""

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/openmetrics-text; version=1.0.0; charset=utf-8")
        return Response(status: .ok, headers: headers, body: .init(string: body))
    }
}


extension SocketAddress {
    /// Returns `true` if the socket address corresponds to localhost / loopback.
    public var isLocalhost: Bool {
        switch self {
        case .v4(let v4Address):
            // 127.0.0.1 in network byte order is 0x7F000001
            let ip4 = v4Address.address.sin_addr.s_addr
            return ip4 == UInt32(0x7F000001).bigEndian
            
        case .v6(let v6Address):
            // IPv6 loopback is ::1 (15 bytes of 0, 1 byte of 1)
            var loopbackAddr6 = in6_addr()
            #if os(Windows)
            loopbackAddr6.u.Byte[15] = 1
            #else
            loopbackAddr6.__u6_addr.__u6_addr8.15 = 1
            #endif
            
            // Compare bytes or memory safely
            var currentAddr6 = v6Address.address.sin6_addr
            return memcmp(&currentAddr6, &loopbackAddr6, MemoryLayout<in6_addr>.size) == 0
            
        case .unixDomainSocket:
            // UNIX domain sockets are local-only by definition
            return true
        }
    }
}
