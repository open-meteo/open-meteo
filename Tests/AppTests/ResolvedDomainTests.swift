import Foundation
@testable import App
import OmFileFormat
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

    @Test func yearlyMergeResolvesGridBeforeUsingDimensions() async throws {
        let source = DeferredDomain()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("temperature_2m"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let year = TimerangeDt(start: Timestamp(2001, 1, 1), to: Timestamp(2002, 1, 1), dtSeconds: source.dtSeconds)
        let start = year.toIndexTime().lowerBound
        let chunk = start / source.omFileLength
        let input = directory.appendingPathComponent("temperature_2m/chunk_\(chunk).om").path
        let file = try FileHandle.createNewFile(file: input)
        let values = (0..<12).flatMap { cell in (0..<source.omFileLength).map { Float(cell * 100 + $0) } }
        try values.writeOmFile(fn: file, dimensions: [1, 12, source.omFileLength], chunks: [1, 6, 24], compression: .pfor_delta2d_int16, scalefactor: 1)
        try file.close()
        try await MergeYearlyCommand.generateYearlyFile(logger: logger, domain: source, year: 2001, variable: "temperature_2m", force: false, allowMissing: true, domainDirectory: directory.path)
        let output = try await OmFileReader(file: directory.appendingPathComponent("temperature_2m/year_2001.om").path).expectArray(of: Float.self)
        #expect(Array(output.getDimensions()) == [1, 12, UInt64(year.count)])
        let data = try await output.read()
        for cell in 0..<12 {
            #expect(data[cell * year.count] == Float(cell * 100 + start % source.omFileLength))
            #expect(data[(cell + 1) * year.count - 1].isNaN)
        }
        #expect(source.resolutions.withLock { $0 } == 1)
    }

    @Test func failedResolutionPreventsYearlyOutput() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("temperature_2m"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = DeferredDomain(fail: true)
        await #expect(throws: DeferredDomain.Failure.self) {
            try await MergeYearlyCommand.generateYearlyFile(logger: logger, domain: source, year: 2001, variable: "temperature_2m", force: true, allowMissing: true, domainDirectory: directory.path)
        }
        for name in ["year_2001.om", "year_2001.om~"] {
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("temperature_2m/\(name)").path))
        }
        #expect(source.resolutions.withLock { $0 } == 1)
    }
}

/// Exposes no synchronous grid and rejects repeated resolution.
private final class DeferredDomain: GenericDomain, CustomStringConvertible {
    enum Failure: Error { case unavailable }
    let resolutions = Mutex(0)
    private let resolvedGrid = RegularGrid(nx: 12, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1)
    private let fail: Bool

    init(fail: Bool = false) {
        self.fail = fail
    }

    func getGrid(context: DomainInitContext) async throws -> any Gridable {
        let attempt = resolutions.withLock { $0 += 1; return $0 }
        guard !fail, attempt == 1 else { throw Failure.unavailable }
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
