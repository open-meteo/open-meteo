import Vapor
import NIO
import Synchronization

/// Counters to hold metrics
enum OmMetrics {
    static let fileLocalOpen = Atomic(0)
    static let fileLocalModifiedTotal = Atomic(0)
    static let fileLocalDirectoriesOpen = Atomic(0)
    static let fileLocalDirectoryUpdatedTotal = Atomic(0)
    static let fileLocalDirectoryModifiedTotal = Atomic(0)
    
    static let fileRemoteOpen = Atomic(0)
    static let fileRemoteModifiedTotal = Atomic(0)
    static let fileRemoteModifiedUnexpectedlyTotal = Atomic(0)
    static let fileRemoteDirectoriesOpen = Atomic(0)
    static let fileRemoteDirectoryUpdatedTotal = Atomic(0)
    static let fileRemoteDirectoryUpdateWaiting = Atomic(0)
    static let fileRemoteDirectoryModifiedTotal = Atomic(0)
    
    static let requestsQueued = Atomic(0)
    static let requestsRunning = Atomic(0)
    static let requestsTooManyLocationsTotal = Atomic(0)
    static let requestsErrorThrownTotal = Atomic(0)
    static let requestsForecastApiTotal = Atomic(0)
    static let requestsS3ApiTotal = Atomic(0)
    static let requestsElevationApiTotal = Atomic(0)
    static let requestsCloudflareWorkersTotal = Atomic(0)
    static let requestsServiceOverloadedTotal = Atomic(0)
    
    static let memoryReadAllocated = Atomic(0)
    
    static let limiterMinutelyExceededTotal = Atomic(0)
    static let limiterHourlyExceededTotal = Atomic(0)
    static let limiterDailyExceededTotal = Atomic(0)
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

        let monitored_ips = await ConcurrencyGroupLimiter.instance.numberOfTrackedSlots()

        let body = """
# TYPE om_file_local_open gauge
# HELP om_file_local_open Number of open local files
om_file_local_open \(OmMetrics.fileLocalOpen.load(ordering: .relaxed))
# TYPE om_file_local_modified_total counter
# HELP om_file_local_modified_total Number of local file metadata updates
om_file_local_modified_total \(OmMetrics.fileLocalModifiedTotal.load(ordering: .relaxed))
# TYPE om_file_local_modified_unexpectedly_total counter
# HELP om_file_local_modified_unexpectedly_total Number of local file metadata updates thrown while reading data
om_file_local_modified_unexpectedly_total \(OmMetrics.fileRemoteModifiedUnexpectedlyTotal.load(ordering: .relaxed))
# TYPE om_file_local_directories_open gauge
# HELP om_file_local_directories_open Number of open local directories
om_file_local_directories_open \(OmMetrics.fileLocalDirectoriesOpen.load(ordering: .relaxed))
# TYPE om_file_local_directory_updated_total counter
# HELP om_file_local_directory_updated_total Number of local directory refreshes
om_file_local_directory_updated_total \(OmMetrics.fileLocalDirectoryUpdatedTotal.load(ordering: .relaxed))
# TYPE om_file_local_directory_modified_total counter
# HELP om_file_local_directory_modified_total Number of local directory content changes
om_file_local_directory_modified_total \(OmMetrics.fileLocalDirectoryModifiedTotal.load(ordering: .relaxed))
# TYPE om_file_remote_open gauge
# HELP om_file_remote_open Number of open remote files
om_file_remote_open \(OmMetrics.fileRemoteOpen.load(ordering: .relaxed))
# TYPE om_file_remote_modified_total counter
# HELP om_file_remote_modified_total Number of remote file metadata updates
om_file_remote_modified_total \(OmMetrics.fileRemoteModifiedTotal.load(ordering: .relaxed))
# TYPE om_file_remote_directories_open gauge
# HELP om_file_remote_directories_open Number of open remote directories
om_file_remote_directories_open \(OmMetrics.fileRemoteDirectoriesOpen.load(ordering: .relaxed))
# TYPE om_file_remote_directory_updated_total counter
# HELP om_file_remote_directory_updated_total Number of remote directory refreshes
om_file_remote_directory_updated_total \(OmMetrics.fileRemoteDirectoryUpdatedTotal.load(ordering: .relaxed))
# TYPE om_file_remote_directory_update_waiting gauge
# HELP om_file_remote_directory_update_waiting Number of callers waiting for a remote directory update
om_file_remote_directory_update_waiting \(OmMetrics.fileRemoteDirectoryUpdateWaiting.load(ordering: .relaxed))
# TYPE om_file_remote_directory_modified_total counter
# HELP om_file_remote_directory_modified_total Number of remote directory content changes
om_file_remote_directory_modified_total \(OmMetrics.fileRemoteDirectoryModifiedTotal.load(ordering: .relaxed))
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
# TYPE om_requests_monitored_ips gauge
# HELP om_requests_monitored_ips Distinct IPs currently rate-limited
om_requests_monitored_ips \(monitored_ips)
# TYPE om_requests_total_running gauge
# HELP om_requests_total_running Currently running requests
om_requests_total_running \(OmMetrics.requestsRunning.load(ordering: .relaxed))
# TYPE om_requests_queued_requests gauge
# HELP om_requests_queued_requests Queued requests waiting for slot
om_requests_queued_requests \(OmMetrics.requestsQueued.load(ordering: .relaxed))
# TYPE om_requests_error_thrown_total counter
# HELP om_requests_error_thrown_total Number of API with any error thrown
om_requests_error_thrown_total \(OmMetrics.requestsErrorThrownTotal.load(ordering: .relaxed))
# TYPE om_requests_too_many_locations_total counter
# HELP om_requests_too_many_locations_total Number of API calls with too many locations
om_requests_too_many_locations_total \(OmMetrics.requestsTooManyLocationsTotal.load(ordering: .relaxed))
# TYPE om_requests_service_overloaded_total counter
# HELP om_requests_service_overloaded_total Number of API calls rejected with service overloaded error
om_requests_service_overloaded_total \(OmMetrics.requestsServiceOverloadedTotal.load(ordering: .relaxed))
# TYPE om_requests_cloudflare_workers_total counter
# HELP om_requests_cloudflare_workers_total Number of API calls from CF Workers
om_requests_cloudflare_workers_total \(OmMetrics.requestsCloudflareWorkersTotal.load(ordering: .relaxed))
# TYPE om_requests_forecast_api_total counter
# HELP om_requests_forecast_api_total Number of Forecast API calls
om_requests_forecast_api_total \(OmMetrics.requestsForecastApiTotal.load(ordering: .relaxed))
# TYPE om_requests_s3_api_total counter
# HELP om_requests_s3_api_total Number of S3 API calls
om_requests_s3_api_total \(OmMetrics.requestsS3ApiTotal.load(ordering: .relaxed))
# TYPE om_requests_elevation_api_total counter
# HELP om_requests_elevation_api_total Number of Elevation API calls
om_requests_elevation_api_total \(OmMetrics.requestsElevationApiTotal.load(ordering: .relaxed))
# HELP om_requests_rate_limited_total Block cache accessed data volume over a given window.
# TYPE om_requests_rate_limited_total counter
om_requests_rate_limited_total{window="1m"} \(OmMetrics.limiterMinutelyExceededTotal.load(ordering: .relaxed))
om_requests_rate_limited_total{window="1h"} \(OmMetrics.limiterHourlyExceededTotal.load(ordering: .relaxed))
om_requests_rate_limited_total{window="24h"} \(OmMetrics.limiterDailyExceededTotal.load(ordering: .relaxed))
# TYPE om_memory_read_allocated_bytes counter
# HELP om_memory_read_allocated_bytes Allocated read arrays
om_memory_read_allocated_bytes \(OmMetrics.memoryReadAllocated.load(ordering: .relaxed))
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
            loopbackaddr6.u.byte[15] = 1
            #elseif os(Linux)
            loopbackAddr6.__in6_u.__u6_addr8.15 = 1
            #else // macOS / iOS / Darwin
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
