import Vapor

struct MetricsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("metrics", use: self.metricsHandler)
    }

    @Sendable
    func metricsHandler(_ req: Request) async throws -> Response {
        var lines: [String] = []
        lines.reserveCapacity(64)

        lines.append("# HELP om_file_cache_inactivity_seconds Seconds since last file activity")
        lines.append("# TYPE om_file_cache_inactivity_seconds gauge")
        lines.append("om_file_cache_inactivity_seconds \(OmStatistics.inactivity.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_local_modified_total Local files modified")
        lines.append("# TYPE om_file_cache_local_modified_total counter")
        lines.append("om_file_cache_local_modified_total \(OmStatistics.localModified.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_remote_modified_total Remote files modified")
        lines.append("# TYPE om_file_cache_remote_modified_total counter")
        lines.append("om_file_cache_remote_modified_total \(OmStatistics.remoteModified.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_remote_deleted_total Remote files deleted")
        lines.append("# TYPE om_file_cache_remote_deleted_total counter")
        lines.append("om_file_cache_remote_deleted_total \(OmStatistics.remoteDeleted.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_remote_revalidated_total Remote file revalidations")
        lines.append("# TYPE om_file_cache_remote_revalidated_total counter")
        lines.append("om_file_cache_remote_revalidated_total \(OmStatistics.remoteRevalidated.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_remote_checked_exist_total Remote existence checks")
        lines.append("# TYPE om_file_cache_remote_checked_exist_total counter")
        lines.append("om_file_cache_remote_checked_exist_total \(OmStatistics.remoteCheckedExist.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_opening_files Currently opening files")
        lines.append("# TYPE om_file_cache_opening_files gauge")
        lines.append("om_file_cache_opening_files \(OmStatistics.currentlyOpeningFiles.load(ordering: .relaxed))")

        lines.append("# HELP om_file_cache_waiting_on_opening Files queued waiting to open")
        lines.append("# TYPE om_file_cache_waiting_on_opening gauge")
        lines.append("om_file_cache_waiting_on_opening \(OmStatistics.currentlyWaitingOnOpeningFiles.load(ordering: .relaxed))")

        let cacheStats = OpenMeteo.dataBlockCache.cache.statistics()

        lines.append("# HELP om_block_cache_used_bytes Used cache bytes")
        lines.append("# TYPE om_block_cache_used_bytes gauge")
        lines.append("om_block_cache_used_bytes \(cacheStats.used)")

        lines.append("# HELP om_block_cache_free_bytes Free cache bytes")
        lines.append("# TYPE om_block_cache_free_bytes gauge")
        lines.append("om_block_cache_free_bytes \(cacheStats.free)")

        lines.append("# HELP om_block_cache_accessed_15min_bytes Bytes accessed in last 15 minutes")
        lines.append("# TYPE om_block_cache_accessed_15min_bytes gauge")
        lines.append("om_block_cache_accessed_15min_bytes \(cacheStats.accessed_15min)")

        lines.append("# HELP om_block_cache_accessed_30min_bytes Bytes accessed in last 30 minutes")
        lines.append("# TYPE om_block_cache_accessed_30min_bytes gauge")
        lines.append("om_block_cache_accessed_30min_bytes \(cacheStats.accessed_30min)")

        lines.append("# HELP om_block_cache_accessed_60min_bytes Bytes accessed in last 60 minutes")
        lines.append("# TYPE om_block_cache_accessed_60min_bytes gauge")
        lines.append("om_block_cache_accessed_60min_bytes \(cacheStats.accessed_60min)")

        lines.append("# HELP om_block_cache_accessed_3h_bytes Bytes accessed in last 3 hours")
        lines.append("# TYPE om_block_cache_accessed_3h_bytes gauge")
        lines.append("om_block_cache_accessed_3h_bytes \(cacheStats.accessed_3hours)")

        lines.append("# HELP om_block_cache_accessed_24h_bytes Bytes accessed in last 24 hours")
        lines.append("# TYPE om_block_cache_accessed_24h_bytes gauge")
        lines.append("om_block_cache_accessed_24h_bytes \(cacheStats.accessed_24hours)")

        let concurrencyStats = apiConcurrencyLimiter.stats()

        lines.append("# HELP om_concurrency_monitored_ips Distinct IPs currently rate-limited")
        lines.append("# TYPE om_concurrency_monitored_ips gauge")
        lines.append("om_concurrency_monitored_ips \(concurrencyStats.monitored_ips)")

        lines.append("# HELP om_concurrency_total_running Currently running requests")
        lines.append("# TYPE om_concurrency_total_running gauge")
        lines.append("om_concurrency_total_running \(concurrencyStats.total_running)")

        lines.append("# HELP om_concurrency_queued_requests Queued requests waiting for slot")
        lines.append("# TYPE om_concurrency_queued_requests gauge")
        lines.append("om_concurrency_queued_requests \(concurrencyStats.queued_requests)")

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/plain; version=0.0.4; charset=utf-8")
        return Response(status: .ok, headers: headers, body: .init(string: lines.joined(separator: "\n") + "\n"))
    }
}