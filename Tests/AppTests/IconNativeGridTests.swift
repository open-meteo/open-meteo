import Foundation
@testable import App
@testable import SphericalCube
@testable import SphericalCubeTestSupport
import OmFileFormat
import Synchronization
import Testing

@Suite struct IconNativeGridTests {
    @Test func initializedDomainPinsElevationForGenericReaders() async throws {
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        let file = try await makeElevationFile([100, 500])
        let replacement = try await makeElevationFile([900, 700])
        defer { file.remove(); replacement.remove() }
        let payload = try await file.payload()
        let grid = IconNativeGrid(storage: fixture.grid.storage, elevationPayload: payload)
        let domain = IconNativeDomain(definition: .iconD2Native, nativeGrid: grid)
        let quarterHourly = IconNativeDomain(definition: .iconD2Native15min, nativeGrid: grid)
        #expect(domain.nativeGrid.storage === quarterHourly.nativeGrid.storage)
        #expect(domain.nativeGrid.elevationPayload?.elevationCache === quarterHourly.nativeGrid.elevationPayload?.elevationCache)
        #expect(domain.dtSeconds == 3600)
        #expect(quarterHourly.dtSeconds == 900)

        try FileManager.default.removeItem(atPath: file.path)
        try FileManager.default.moveItem(atPath: replacement.path, toPath: file.path)
        let options = try GenericReaderOptions(logger: .init(label: "NativeDomainTests"), httpClient: nil)
        let reader = try await GenericReader<IconNativeDomain, IconSurfaceVariable>(domain: domain, position: 0, options: options)
        #expect(reader.modelElevation.numeric == 100)
        #expect(try await reader.getStatic(type: .elevation) == 100)
        #expect(try await file.payload().reader.read(range: [0..<1, 0..<1]) == [900])
        #expect(payload.elevationCache?.cachedValues == nil)

        let selected = try #require(await GenericReader<IconNativeDomain, IconSurfaceVariable>(
            domain: domain, lat: 0, lon: 0.04, elevation: 500, mode: .land, options: options
        ))
        #expect(selected.position == 1)
        #expect(selected.modelElevation.numeric == 500)
        #expect(payload.elevationCache?.cachedValues != nil)
    }

    @Test func elevationEncodingRoundTripsSamples() throws {
        let source: [Float] = [-999, 0, 2_048, 8_765, 9_999, .nan]
        let encoded = try ElevationValues.encode(source)

        #expect(encoded == [-999, 0, 2_048, 8_765, 9_999, .min])
        let decoded = encoded.map(ElevationValues.decode)
        #expect(decoded.dropLast() == source.dropLast())
        #expect(decoded.last?.isNaN == true)

        #expect(throws: ElevationValues.EncodingError.self) {
            try ElevationValues.encode([1.5])
        }
        #expect(throws: ElevationValues.EncodingError.self) {
            try ElevationValues.encode([Float(Int16.min)])
        }
    }

    @Test func installedGridSurvivesFailedRevalidation() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let file = IconNativeGridFile(localFile: fixture.file.path, identity: makeIdentity(fixture))
        #expect(file.cache.get() == nil)
        try file.validateFileAndInstall()
        let installed = try #require(file.cache.get()).storage

        try truncateLastByte(of: fixture.file)
        #expect(throws: IconNativeDomainError.self) {
            try file.validateFileAndInstall()
        }
        #expect(try #require(file.cache.get()).storage === installed)
    }

    @Test func materializeRejectsTruncatedArtifact() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        let file = IconNativeGridFile(
            localFile: published.path,
            identity: makeIdentity(fixture)
        )

        let grid = try await file.materialize(
            file: DataAsClass(data: try Data(contentsOf: fixture.file))
        )
        #expect(grid.nx == fixture.centers.count)
        #expect(FileManager.default.fileExists(atPath: published.path))

        let handle = try FileHandle.openFileReading(file: published.path)
        let payload = try IconNativeGridPayload(fd: handle, size: Int64(try handle.seekToEnd()))
        #expect(try makeIdentity(fixture).validate(grid: payload.grid, path: published.path).nx == grid.nx)
        #expect(throws: IconNativeDomainError.self) {
            try IconNativeGridIdentity.d2.validate(grid: payload.grid, path: published.path)
        }

        try FileManager.default.removeItem(at: published)
        var invalid = try Data(contentsOf: fixture.file)
        invalid.removeLast()
        await #expect(throws: IconNativeDomainError.self) {
            _ = try await file.materialize(file: DataAsClass(data: invalid))
        }
        #expect(!FileManager.default.fileExists(atPath: published.path))
    }

    @Test func seaAndTerrainSelectionReuseElevations() async throws {
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        for (mode, elevations) in [(GridSelectionMode.land, [Float(0), 500]), (.sea, [100, -999])] {
            let file = try await makeElevationFile(elevations)
            defer { file.remove() }
            let payload = try await file.payload()
            let cache = try #require(payload.elevationCache)
            let grid: any Gridable = IconNativeGrid(storage: fixture.grid.storage, elevationPayload: payload)
            let raw = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                elevationFile: file.reader, mode: mode)
            #expect(raw?.gridpoint == 1)
            for _ in 0..<2 {
                let cached = try await grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                    elevationFile: file.reader, mode: mode)
                #expect(cached?.gridpoint == 1)
                #expect(cached?.gridElevation.numeric == raw?.gridElevation.numeric)
            }
            #expect(cache.cachedValues != nil)
        }
    }

    @Test func surfaceElevationCacheInitializesLazilyOnce() async throws {
        let loads = Mutex(0)
        let cache = ElevationCache(elementCount: 800) {
            loads.withLock { $0 += 1 }
            return (0..<800).map(Float.init)
        }
        var pointIDs = InlineArray<10, Int>(repeating: -1)
        pointIDs[0] = 10
        pointIDs[1] = 20
        pointIDs[2] = 410
        #expect(cache.cachedValues == nil)
        #expect(loads.withLock { $0 } == 0)
        let values = try await cache.loadValues()
        let first = values.read(pointIDs: pointIDs, count: 3)
        #expect(first[0] == 10)
        #expect(first[1] == 20)
        #expect(first[2] == 410)
        #expect(values.count == 800)
        #expect(cache.cachedValues === values)
        #expect(try await cache.loadValues() === values)
        #expect(loads.withLock { $0 } == 1)
    }

    @Test func cancelledWaiterDoesNotCancelSharedElevationLoad() async throws {
        let loader = GatedElevationLoader()
        let cache = ElevationCache(elementCount: 2) { try await loader.load() }
        let first = Task { try await cache.loadValues() }
        await loader.waitUntilStarted()
        first.cancel()
        let identifiers = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let values = try await cache.loadValues()
                    #expect(values[1] == 17)
                    return ObjectIdentifier(values)
                }
            }
            await loader.release()
            var identifiers = [ObjectIdentifier]()
            for try await id in group { identifiers.append(id) }
            return identifiers
        }
        #expect(Set(identifiers).count == 1)
        #expect(try await ObjectIdentifier(first.value) == identifiers[0])
        #expect(await loader.loads == 1)
    }

    @Test func failedElevationLoadCanRetry() async throws {
        let loads = Mutex(0)
        let cache = ElevationCache(elementCount: 2) {
            let attempt = loads.withLock { $0 += 1; return $0 }
            if attempt == 1 { throw ElevationTestError.injectedFailure }
            return [0, 17]
        }
        await #expect(throws: ElevationTestError.injectedFailure) {
            _ = try await cache.loadValues()
        }
        #expect(cache.cachedValues == nil)
        #expect(try await cache.loadValues()[1] == 17)
        #expect(loads.withLock { $0 } == 2)
    }

    @Test func invalidElevationLoadIsNotPublished() async throws {
        let loads = Mutex(0)
        let cache = ElevationCache(elementCount: 2) {
            let attempt = loads.withLock { $0 += 1; return $0 }
            return attempt == 1 ? [0] : [0, 17]
        }
        await #expect(throws: ElevationCacheError.unexpectedCount(expected: 2, actual: 1)) {
            _ = try await cache.loadValues()
        }
        #expect(cache.cachedValues == nil)
        #expect(try await cache.loadValues()[1] == 17)
        let invalid = ElevationCache(elementCount: 1) { [1.5] }
        await #expect(throws: ElevationValues.EncodingError.self) {
            _ = try await invalid.loadValues()
        }
        #expect(invalid.cachedValues == nil)
    }

    @Test func payloadReplacementOwnsIndependentElevationCache() async throws {
        let file = try await makeElevationFile([0, 17])
        let replacement = try await makeElevationFile([0, 23])
        defer {
            file.remove()
            replacement.remove()
        }
        func payload(_ path: String) async throws -> OmFileLocalRemoteOmReader {
            let handle = try FileHandle.openFileReading(file: path)
            return try await OmFileLocalRemoteOmReader(fd: handle, size: Int64(handle.seekToEnd()))
        }
        let old = try await payload(file.path)
        let oldCache = try #require(old.elevationCache)
        #expect(try await old.reader.read(range: [0..<1, 1..<2]) == [17])
        #expect(oldCache.cachedValues == nil)
        let oldValues = try await oldCache.loadValues()
        try FileManager.default.removeItem(atPath: file.path)
        try FileManager.default.moveItem(atPath: replacement.path, toPath: file.path)
        let new = try await payload(file.path)
        let newCache = try #require(new.elevationCache)
        #expect(newCache !== oldCache)
        #expect(newCache.cachedValues == nil)
        #expect(try await newCache.loadValues()[1] == 23)
        #expect(oldValues[1] == 17)
    }

    @Test func selectionWithoutElevationSearchLeavesCacheUnloaded() async throws {
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ], maximumDistanceMeters: 20_000)
        defer { fixture.remove() }
        let file = try await makeElevationFile([100, -999])
        defer { file.remove() }
        let payload = try await file.payload()
        let cache = try #require(payload.elevationCache)
        let grid: any Gridable = IconNativeGrid(storage: fixture.grid.storage, elevationPayload: payload)
        for (mode, elevation) in [(GridSelectionMode.nearest, Float(500)), (.land, .nan)] {
            _ = try await grid.findPoint(lat: 0, lon: 0.04, elevation: elevation,
                elevationFile: file.reader, mode: mode)
            #expect(cache.cachedValues == nil)
        }
        _ = try await grid.readElevation(gridpoint: 0, elevationFile: file.reader)
        #expect(cache.cachedValues == nil)
        for latitude in [Float.nan, 50] {
            let outside = try await grid.findPoint(lat: latitude, lon: 0, elevation: 500,
                elevationFile: file.reader, mode: .sea)
            #expect(outside == nil)
            #expect(cache.cachedValues == nil)
        }
    }

    @Test func scaledElevationReaderWorksWithoutCache() async throws {
        let file = try await makeElevationFile([100, -999], scaleFactor: 10)
        defer { file.remove() }
        #expect(ElevationCache(reader: file.reader) == nil)
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        let result = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
            elevationFile: file.reader, mode: .sea)
        #expect(result?.gridpoint == 1)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"] != nil))
    func sampledGlobalSourceRoundTrips() throws {
        try checkSourceRoundTrips(
            sourceFile: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"],
            identity: .global,
            maximumArtifactBytes: 128 * 1_024 * 1_024,
            targetSampleCount: 100_000
        )
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] != nil))
    func d2SourceRoundTrips() throws {
        try checkSourceRoundTrips(
            sourceFile: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"],
            identity: .d2,
            maximumArtifactBytes: 32 * 1_024 * 1_024,
            targetSampleCount: .max
        )
    }

}

private extension SphericalCubeFixture {
    var grid: IconNativeGrid { IconNativeGrid(storage: index) }
}

private enum ElevationTestError: Error, Equatable {
    case injectedFailure
}

/// Holds the shared load until the test cancels a waiter and starts concurrent readers.
private actor GatedElevationLoader {
    private var started: CheckedContinuation<Void, Never>?
    private var gates = [CheckedContinuation<Void, Never>]()
    private var released = false
    private(set) var loads = 0

    func load() async throws -> [Float] {
        loads += 1
        if !released {
            await withCheckedContinuation {
                gates.append($0)
                started?.resume()
                started = nil
            }
        }
        try Task.checkCancellation()
        return [0, 17]
    }

    func waitUntilStarted() async {
        if loads > 0 { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        released = true
        gates.forEach { $0.resume() }
        gates.removeAll()
    }
}

private func makeIdentity(_ fixture: SphericalCubeFixture) -> IconNativeGridIdentity {
    IconNativeGridIdentity(
        gridNumber: 26,
        gridUUID: UUID(uuidString: "00010203-0405-0607-0809-0a0b0c0d0e0f")!,
        cellCount: fixture.centers.count,
        isGlobal: true,
        maximumDistanceMeters: 10_000_000,
        sourceFile: "synthetic.nc.bz2"
    )
}

private func checkSourceRoundTrips(
    sourceFile: String?,
    identity: IconNativeGridIdentity,
    maximumArtifactBytes: Int,
    targetSampleCount: Int
) throws {
    let sourceFile = try #require(sourceFile)
    let artifactFile = temporaryArtifactFile()
    defer { try? FileManager.default.removeItem(at: artifactFile) }
    let grid = try IconNativeGrid.Generator.generateAndPublish(
        sourceFile: sourceFile,
        identity: identity,
        artifactFile: artifactFile.path
    )
    let source = try IconNativeGrid.Generator.readSource(file: sourceFile, identity: identity)
    try validateGeneratedArtifact(file: artifactFile, centers: source)

    #expect(grid.nx == identity.cellCount)
    let artifactBytes = try #require(
        artifactFile.resourceValues(forKeys: [.fileSizeKey]).fileSize
    )
    #expect(artifactBytes <= maximumArtifactBytes)
    let stride = max(1, source.count / targetSampleCount)
    for cell in Swift.stride(from: 0, to: source.count, by: stride) {
        let coordinate = grid.storage.point(at: cell).coordinate
        #expect(grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude) == cell)
    }
}

struct ElevationFileFixture {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>

    func payload() async throws -> OmFileLocalRemoteOmReader {
        let handle = try FileHandle.openFileReading(file: path)
        return try await OmFileLocalRemoteOmReader(fd: handle, size: Int64(handle.seekToEnd()))
    }

    func remove() { try? FileManager.default.removeItem(atPath: path) }
}

func makeElevationFile(_ elevations: [Float], scaleFactor: Float = 1) async throws -> ElevationFileFixture {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("elevation-\(UUID().uuidString).om").path
    do {
        let handle = try FileHandle.createNewFile(file: path)
        defer { try? handle.close() }
        try elevations.writeOmFile(fn: handle, dimensions: [1, elevations.count],
            chunks: [1, min(400, elevations.count)], compression: .pfor_delta2d_int16, scalefactor: scaleFactor)
        try handle.close()
        return ElevationFileFixture(path: path, reader: try await OmFileReader(file: path).expectArray(of: Float.self))
    } catch {
        try? FileManager.default.removeItem(atPath: path)
        throw error
    }
}

extension IconNativeGridFile {
    init(localFile: String, identity: IconNativeGridIdentity) {
        self.init(
            localFile: localFile,
            registry: identity.isGlobal ? .dwd_icon_global_native : .dwd_icon_d2_native,
            identity: identity
        )
    }
}
