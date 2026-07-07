import Vapor

struct MetricsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("metrics", use: self.metricsHandler)
    }

    @Sendable
    func metricsHandler(_ req: Request) async throws -> Response {
        let inactiveEvictions = OmStatistics.inactivity.load(ordering: .relaxed)
        let localModified = OmStatistics.localModified.load(ordering: .relaxed)
        let remoteModified = OmStatistics.remoteModified.load(ordering: .relaxed)
        let remoteDeleted = OmStatistics.remoteDeleted.load(ordering: .relaxed)
        let remoteRevalidated = OmStatistics.remoteRevalidated.load(ordering: .relaxed)
        let remoteCheckedExist = OmStatistics.remoteCheckedExist.load(ordering: .relaxed)
        let currentlyOpeningFiles = OmStatistics.currentlyOpeningFiles.load(ordering: .relaxed)
        let currentlyWaitingOnOpeningFiles = OmStatistics.currentlyWaitingOnOpeningFiles.load(ordering: .relaxed)

        let cacheStats = OpenMeteo.dataBlockCacheInitialized.load(ordering: .relaxed)
            ? OpenMeteo.dataBlockCache.cache.statistics()
            : .zero

        let concurrencyStats = await ConcurrencyGroupLimiter.instance.stats()

        let body = """
# TYPE om_file_cache_inactive_evictions counter
# HELP om_file_cache_inactive_evictions File cache entries evicted after inactivity
om_file_cache_inactive_evictions_total \(inactiveEvictions)
# TYPE om_file_cache_local_modified counter
# HELP om_file_cache_local_modified Local files modified
om_file_cache_local_modified_total \(localModified)
# TYPE om_file_cache_remote_modified counter
# HELP om_file_cache_remote_modified Remote files modified
om_file_cache_remote_modified_total \(remoteModified)
# TYPE om_file_cache_remote_deleted counter
# HELP om_file_cache_remote_deleted Remote files deleted
om_file_cache_remote_deleted_total \(remoteDeleted)
# TYPE om_file_cache_remote_revalidated counter
# HELP om_file_cache_remote_revalidated Remote file revalidations
om_file_cache_remote_revalidated_total \(remoteRevalidated)
# TYPE om_file_cache_remote_checked_exist counter
# HELP om_file_cache_remote_checked_exist Remote existence checks
om_file_cache_remote_checked_exist_total \(remoteCheckedExist)
# TYPE om_file_cache_opening_files gauge
# HELP om_file_cache_opening_files Currently opening files
om_file_cache_opening_files \(currentlyOpeningFiles)
# TYPE om_file_cache_waiting_on_opening gauge
# HELP om_file_cache_waiting_on_opening Files queued waiting to open
om_file_cache_waiting_on_opening \(currentlyWaitingOnOpeningFiles)
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
