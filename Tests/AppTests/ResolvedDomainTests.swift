import Foundation
@testable import App
@testable import SphericalCubeTests
import OmFileFormat
import Synchronization
import Testing
import Vapor
import VaporTesting

@Suite struct ResolvedDomainTests {
    private let logger = Logger(label: "ResolvedDomainTests")

    @Test func resolvesOnceAndForwardsMetadata() async throws {
        let fixture = try makeFixture(centers: makeSphericalCenters(count: 12))
        defer { fixture.remove() }
        let source = DeferredDomain(file: fixture.file)
        let context = DomainInitContext(logger: logger, httpClient: nil)
        let domain = try await ResolvedDomain(source, context: context)
        let reused = try await ResolvedDomain(domain, context: context)
        #expect(try await reused.getGrid(context: context).nx == 12)
        #expect(domain.grid.ny == 1)
        #expect(source.resolutions.withLock { $0 } == 1)
        #expect(domain.description == source.description)
        #expect(domain.domainRegistry == source.domainRegistry)
        #expect(domain.domainRegistryStatic == source.domainRegistryStatic)
        #expect(domain.dtSeconds == source.dtSeconds)
        #expect(domain.updateIntervalSeconds == source.updateIntervalSeconds)
        #expect(domain.hasYearlyFiles == source.hasYearlyFiles)
        #expect(domain.masterTimeRange == source.masterTimeRange)
        #expect(domain.omFileLength == source.omFileLength)
        #expect(domain.countEnsembleMember == source.countEnsembleMember)
        #expect(!domain.generateFullRun)
        #expect(!domain.generateTimeSeries)
    }

    @Test func splitterAndSpatialWriterRetainResolvedGrid() async throws {
        let fixture = try makeFixture(centers: makeSphericalCenters(count: 12))
        defer { fixture.remove() }
        let source = DeferredDomain(file: fixture.file)
        let domain = try await ResolvedDomain(source, context: .init(logger: logger, httpClient: nil))
        let splitter = OmFileSplitter(domain)
        #expect(splitter.nx == 12)
        #expect(splitter.ny == 1)
        let time = Timestamp(2001, 1, 1)
        let writer = OmSpatialTimestepWriter(domain: domain, run: time, time: time, storeOnDisk: false, realm: nil, logger: logger)
        let values = (0..<12).map(Float.init)
        try await writer.write(member: 0, variable: IconSurfaceVariable.temperature_2m, data: values)
        let handles = try await writer.finalise()
        let handle = try #require(handles.first)
        #expect(Array(handle.reader.getDimensions()) == [1, 12])
        #expect(try await handle.reader.read() == values)
        let handleDomain = try #require(handle.domain as? GridDomain)
        #expect(handleDomain.grid.crsWkt2 == domain.grid.crsWkt2)
        let file = try #require(await writer.fn)
        let root = try await OmFileReader(fn: MmapFile(fn: file))
        let crs: String? = try await root.getChild(name: "crs_wkt")?.readScalar()
        #expect(crs == domain.grid.crsWkt2)
        #expect(source.resolutions.withLock { $0 } == 1)
    }

    @Test func yearlyMergeResolvesGridBeforeUsingDimensions() async throws {
        let fixture = try makeFixture(centers: makeSphericalCenters(count: 12))
        defer { fixture.remove() }
        let source = DeferredDomain(file: fixture.file)
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

    @Test(arguments: [false, true]) func artifactFailurePrecedesOutputCreation(corrupt: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let artifact = directory.appendingPathComponent("grid.bin")
        if corrupt { try Data([0, 1, 2]).write(to: artifact) }
        let source = DeferredDomain(file: artifact)
        await #expect(throws: (any Error).self) {
            try await MergeYearlyCommand.generateYearlyFile(logger: logger, domain: source, year: 2001, variable: "temperature_2m", force: true, allowMissing: true, domainDirectory: directory.path)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("temperature_2m").path))
        #expect(source.resolutions.withLock { $0 } == 1)
    }

    @Test(arguments: ["valid", "missing", "corrupt"])
    func boundingBoxArtifactErrorsDoNotStopServer(state: String) async throws {
        let fixture = try makeFixture(centers: makeSphericalCenters(count: 12))
        defer { fixture.remove() }
        let artifact = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: artifact) }
        switch state {
        case "valid": try FileManager.default.copyItem(at: fixture.file, to: artifact)
        case "corrupt": try Data([0, 1, 2]).write(to: artifact)
        default: break
        }
        // Each case starts with an unloaded artifact and an independent resolver.
        let source = DeferredDomain(file: artifact, localOnly: false)
        try await withApp { app in
            app.middleware = .init()
            app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
            let controller = WeatherApiController(defaultModel: .dwd_icon_d2_native, boundingBoxDomain: { model in
                #expect(model == .dwd_icon_d2_native)
                return source
            })
            app.get("v1", "forecast", use: controller.query)
            app.get("health") { _ in "ok" }
            let client = try app.testing()
            try await client.test(.GET, "/v1/forecast?models=dwd_icon_d2_native&bounding_box=50,10,51,11") { response async in
                #expect(response.status == (state == "valid" ? .badRequest : .internalServerError))
                #expect(response.body.string.contains("\"error\":true"))
                if state == "valid" {
                    #expect(response.body.string.contains("Bounding box calls not supported for grid"))
                }
            }
            #expect(source.resolutions.withLock { $0 } == 1)
            try await client.test(.GET, "/health") { response async in
                #expect(response.status == .ok)
                #expect(response.body.string == "ok")
            }
        }
    }

}

/// A deferred domain exposes no synchronous grid, including after resolution.
private final class DeferredDomain: GenericDomain, CustomStringConvertible {
    let file: URL
    let resolutions = Mutex(0)
    let localOnly: Bool
    init(file: URL, localOnly: Bool = true) {
        self.file = file
        self.localOnly = localOnly
    }
    func getGrid(context: DomainInitContext) async throws -> any Gridable {
        #expect((context.httpClient == nil) == localOnly)
        resolutions.withLock { $0 += 1 }
        return try IconNativeGrid.load(file: file)
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
