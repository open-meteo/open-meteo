import Foundation
@testable import App
import Synchronization
import Testing
import Vapor

@Suite struct ResolvedDomainTests {
    private let logger = Logger(label: "ResolvedDomainTests")

    @Test func resolvesOnceAndPreservesDescriptionAndFlags() async throws {
        let source = DeferredDomain()
        let context = DomainInitContext(logger: logger, httpClient: nil)
        let domain = try await ResolvedDomain(source, context: context)
        let reused = try await ResolvedDomain(domain, context: context)
        #expect(try await reused.getGrid(context: context).nx == 12)
        #expect(domain.grid.ny == 1)
        #expect(source.resolutions.withLock { $0 } == 1)
        #expect(domain.description == source.description)
        #expect(!domain.generateFullRun)
        #expect(!domain.generateTimeSeries)
    }

    @Test func writerHandleRetainsResolvedGrid() async throws {
        // Temporary writer files use this directory even when storeOnDisk is false.
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let source = DeferredDomain()
        let domain = try await ResolvedDomain(source, context: .init(logger: logger, httpClient: nil))
        let time = Timestamp(2001, 1, 1)
        let writer = OmSpatialTimestepWriter(domain: domain, run: time, time: time, storeOnDisk: false, realm: nil, logger: logger)
        try await writer.write(member: 0, variable: IconSurfaceVariable.temperature_2m, data: (0..<12).map(Float.init))
        let handles = try await writer.finalise()
        try #require(handles.count == 1)
        #expect(handles[0].domain.grid.nx == 12)
        #expect(handles[0].domain.grid.crsWkt2 == domain.grid.crsWkt2)
        #expect(source.resolutions.withLock { $0 } == 1)
    }

}

/// Exposes no synchronous grid and rejects repeated resolution.
private final class DeferredDomain: GenericDomain, CustomStringConvertible {
    enum Failure: Error { case unavailable }
    let resolutions = Mutex(0)
    private let resolvedGrid = RegularGrid(nx: 12, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1)
    func getGrid(context: DomainInitContext) async throws -> any Gridable {
        let attempt = resolutions.withLock { $0 += 1; return $0 }
        guard attempt == 1 else { throw Failure.unavailable }
        return resolvedGrid
    }
    let description = "deferred-native-test"
    let domainRegistry = DomainRegistry.dwd_icon_global_native
    let domainRegistryStatic: DomainRegistry? = .dwd_icon_global_native
    let dtSeconds = 3600
    let updateIntervalSeconds = 21600
    let hasYearlyFiles = true
    let masterTimeRange: Range<Timestamp>? = Timestamp(2000, 1, 1)..<Timestamp(2001, 1, 1)
    let omFileLength = 504
    let countEnsembleMember = 1
    let generateFullRun = false
    let generateTimeSeries = false
}
