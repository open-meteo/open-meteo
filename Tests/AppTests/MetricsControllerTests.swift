@testable import App
import Testing
import Vapor

@Suite struct MetricsControllerTests {
    @Test func metricsUseOpenMetricsFormat() async throws {
        let app = try await Application.make(.testing)
        do {
            OpenMeteo.dataBlockCacheInitialized.store(false, ordering: .relaxed)

            let response = try await metricsResponse(app: app)
            let body = try await response.string(on: app.eventLoopGroup.next())

            #expect(response.headers.first(name: .contentType) == "application/openmetrics-text; version=1.0.0; charset=utf-8")
            #expect(body.hasSuffix("# EOF\n"))
            #expect(!body.contains("\r"))
            #expect(body.contains("# TYPE om_file_cache_remote_modified counter\n"))
            #expect(body.contains("om_file_cache_remote_modified_total "))
            #expect(!body.contains("# TYPE om_file_cache_remote_modified_total counter"))
            #expect(!body.contains("om_file_cache_inactivity_seconds"))
            #expect(body.contains("# UNIT om_block_cache_used_bytes bytes\n"))
            #expect(body.contains("om_block_cache_used_bytes 0\n"))
            #expect(body.contains("om_block_cache_free_bytes 0\n"))

            let typeIndex = try #require(body.range(of: "# TYPE om_block_cache_used_bytes gauge")?.lowerBound)
            let unitIndex = try #require(body.range(of: "# UNIT om_block_cache_used_bytes bytes")?.lowerBound)
            let helpIndex = try #require(body.range(of: "# HELP om_block_cache_used_bytes Used cache bytes")?.lowerBound)
            #expect(typeIndex < unitIndex)
            #expect(unitIndex < helpIndex)

            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    @Test func metricsDoNotInitializeDataBlockCache() async throws {
        let app = try await Application.make(.testing)
        do {
            OpenMeteo.dataBlockCacheInitialized.store(false, ordering: .relaxed)

            let response = try await metricsResponse(app: app)
            let body = try await response.string(on: app.eventLoopGroup.next())

            #expect(OpenMeteo.dataBlockCacheInitialized.load(ordering: .relaxed) == false)
            #expect(body.contains("om_block_cache_used_bytes 0\n"))

            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    @Test func statisticsAreExposedAsLifetimeTotals() async throws {
        let app = try await Application.make(.testing)
        do {
            OpenMeteo.dataBlockCacheInitialized.store(false, ordering: .relaxed)

            OmStatistics.fileCacheInactivityEvictions.store(7, ordering: .relaxed)
            OmStatistics.fileCacheLocalModified.store(11, ordering: .relaxed)
            OmStatistics.fileCacheRemoteModified.store(13, ordering: .relaxed)
            OmStatistics.fileCacheRemoteDeleted.store(17, ordering: .relaxed)
            OmStatistics.fileCacheRemoteRevalidated.store(19, ordering: .relaxed)
            OmStatistics.fileCacheRemoteCheckedExist.store(23, ordering: .relaxed)

            let response = try await metricsResponse(app: app)
            let body = try await response.string(on: app.eventLoopGroup.next())

            #expect(body.contains("om_file_cache_inactive_evictions_total 7\n"))
            #expect(body.contains("om_file_cache_local_modified_total 11\n"))
            #expect(body.contains("om_file_cache_remote_modified_total 13\n"))
            #expect(body.contains("om_file_cache_remote_deleted_total 17\n"))
            #expect(body.contains("om_file_cache_remote_revalidated_total 19\n"))
            #expect(body.contains("om_file_cache_remote_checked_exist_total 23\n"))

            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    private func metricsResponse(app: Application) async throws -> Response {
        let request = Request(
            application: app,
            method: .GET,
            url: URI(path: "/metrics"),
            on: app.eventLoopGroup.next()
        )
        return try await MetricsController().metricsHandler(request)
    }
}

private extension Response {
    func string(on eventLoop: any EventLoop) async throws -> String {
        var buffer = try #require(try await body.collect(on: eventLoop).get())
        let length = buffer.writerIndex
        guard let string = buffer.readString(length: length) else {
            throw MetricsControllerTestError.invalidResponseBody
        }
        return string
    }
}

private enum MetricsControllerTestError: Error {
    case invalidResponseBody
}
