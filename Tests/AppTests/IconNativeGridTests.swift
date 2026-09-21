import Foundation
@testable import App
@testable import ReducedLatLon
import OmFileFormat
import Testing

@Suite struct IconNativeGridTests {
    @Test func initializedDomainsShareDecodedElevations() async throws {
        let fixture = try makeFixture(centers: [
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        let file = try await makeElevationFile([100, 500])
        let replacement = try await makeElevationFile([900, 700])
        defer { file.remove(); replacement.remove() }
        let elevations = try await ElevationValues(decoded: file.reader.read(), expectedCount: 2)
        let grid = IconNativeGrid(storage: fixture.grid.storage,
            maximumChordDistanceSquared: fixture.maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: fixture.maximumChordDistanceSquared,
            elevations: elevations)
        let domain = IconNativeDomain(definition: .iconD2Native, nativeGrid: grid)
        let quarterHourly = IconNativeDomain(definition: .iconD2Native15min, nativeGrid: grid)
        #expect(domain.nativeGrid.storage === quarterHourly.nativeGrid.storage)
        #expect(domain.nativeGrid.elevations === quarterHourly.nativeGrid.elevations)
        #expect(domain.dtSeconds == 3600)
        #expect(quarterHourly.dtSeconds == 900)

        try FileManager.default.removeItem(atPath: file.path)
        try FileManager.default.moveItem(atPath: replacement.path, toPath: file.path)
        let current = try await file.payload()
        #expect(try await current.reader.read(range: [0..<1, 0..<1]) == [900])
        #expect(elevations[0] == 100)
        let selected = try #require(await domain.grid.findPoint(
            lat: 0, lon: 0.04, elevation: 500, elevationFile: current.reader, mode: .land
        ))
        #expect(selected.gridpoint == 1)
        #expect(selected.gridElevation.numeric == 500)
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
        let installed = try #require(file.cache.get())

        try Data(Data(contentsOf: fixture.file).dropLast()).write(to: fixture.file, options: .atomic)
        #expect(throws: IconNativeDomainError.self) {
            try file.validateFileAndInstall()
        }
        #expect(file.cache.get() === installed)
        #expect(installed.point(at: 0) == fixture.centers[0])
    }

    @Test func identityMismatchNeverPublishesDownloadedArtifact() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let valid = makeIdentity(fixture)
        let bytes = try Data(contentsOf: fixture.file)
        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        try bytes.write(to: published)
        for mismatch in 0..<5 {
            let identity = IconNativeGridIdentity(
                gridNumber: mismatch == 0 ? 47 : valid.gridNumber,
                gridUUID: mismatch == 1 ? UUID() : valid.gridUUID,
                cellCount: valid.cellCount + (mismatch == 2 ? 1 : 0),
                isGlobal: mismatch == 3 ? false : valid.isGlobal,
                latitudeBandCount: valid.latitudeBandCount + (mismatch == 4 ? 1 : 0),
                maximumDistanceMeters: valid.maximumDistanceMeters,
                sourceFile: valid.sourceFile
            )
            let file = IconNativeGridFile(localFile: published.path, identity: identity)
            await #expect(throws: IconNativeDomainError.self) {
                _ = try await file.load(file: DataAsClass(data: bytes))
            }
            #expect(try Data(contentsOf: published) == bytes)
            #expect(file.cache.get() == nil)
        }
    }

    @Test func loadRejectsTruncatedArtifactBeforePublication() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        let file = IconNativeGridFile(
            localFile: published.path,
            identity: makeIdentity(fixture)
        )

        let original = try Data(contentsOf: fixture.file)
        let storage = try await file.load(file: DataAsClass(data: original))
        #expect(storage.pointCount == fixture.centers.count)
        #expect(try Data(contentsOf: published) == original)

        let handle = try FileHandle.openFileReading(file: published.path)
        let payload = try IconNativeGridPayload(fd: handle, size: Int64(try handle.seekToEnd()))
        try makeIdentity(fixture).validate(storage: payload.storage, path: published.path)
        #expect(payload.storage.pointCount == storage.pointCount)
        #expect(throws: IconNativeDomainError.self) {
            try IconNativeGridIdentity.d2.validate(storage: payload.storage, path: published.path)
        }

        var invalid = original
        invalid.removeLast()
        await #expect(throws: IconNativeDomainError.self) {
            _ = try await file.load(file: DataAsClass(data: invalid))
        }
        #expect(try Data(contentsOf: published) == original)
    }

    @Test func seaAndTerrainSelectionReuseElevations() async throws {
        let fixture = try makeFixture(centers: [
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        for (mode, elevations) in [(GridSelectionMode.land, [Float(0), 500]), (.sea, [100, -999])] {
            let file = try await makeElevationFile(elevations)
            defer { file.remove() }
            let elevations = try await ElevationValues(decoded: file.reader.read(), expectedCount: 2)
            let nativeGrid = IconNativeGrid(storage: fixture.grid.storage,
                maximumChordDistanceSquared: fixture.maximumChordDistanceSquared,
                nearbyMaximumChordDistanceSquared: fixture.maximumChordDistanceSquared,
                elevations: elevations)
            let grid: any Gridable = nativeGrid
            let raw = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                elevationFile: file.reader, mode: mode)
            #expect(raw?.gridpoint == 1)
            for _ in 0..<2 {
                let cached = try await grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                    elevationFile: file.reader, mode: mode)
                #expect(cached?.gridpoint == 1)
                #expect(cached?.gridElevation.numeric == raw?.gridElevation.numeric)
            }
        }
    }

    @Test func seaAndTerrainSelectionStayWithinNearbyDistance() async throws {
        let fixture = try makeFixture(centers: [
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0.1),
            ReducedLatLonPoint(latitudeDegrees: 0, longitudeDegrees: 0.4)
        ])
        defer { fixture.remove() }
        let nearbyDistance = IconNativeGridIdentity.squaredChordDistance(meters: 30_000)
        for (mode, elevations) in [
            (GridSelectionMode.land, [Float(0), 0, 2_000]),
            (.sea, [100, 100, -999])
        ] {
            let file = try await makeElevationFile(elevations)
            defer { file.remove() }
            let decoded = try await ElevationValues(decoded: file.reader.read(), expectedCount: 3)
            let grid = IconNativeGrid(
                storage: fixture.index,
                maximumChordDistanceSquared: fixture.maximumChordDistanceSquared,
                nearbyMaximumChordDistanceSquared: nearbyDistance,
                elevations: decoded
            )
            let selected = try #require(await grid.findPoint(
                lat: 0,
                lon: 0,
                elevation: 2_000,
                elevationFile: file.reader,
                mode: mode
            ))
            #expect(selected.gridpoint == 0)
        }
    }

    @Test func decodedElevationsSupportIndexedReads() throws {
        let values = try ElevationValues(decoded: (0..<800).map(Float.init), expectedCount: 800)
        var pointIDs = InlineArray<10, Int>(repeating: -1)
        pointIDs[0] = 10
        pointIDs[1] = 20
        pointIDs[2] = 410
        let selected = values.read(pointIDs: pointIDs, count: 3)
        #expect(selected[0] == 10)
        #expect(selected[1] == 20)
        #expect(selected[2] == 410)
        #expect(values.count == 800)
        #expect(throws: ElevationValuesError.unexpectedCount(expected: 2, actual: 1)) {
            try ElevationValues(decoded: [0], expectedCount: 2)
        }
    }

    /// Set ICON_GLOBAL_GRID_TEST_FILE to the decompressed official global grid NetCDF file.
    /// Generated artifacts are temporary; operational static files are never replaced.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"] != nil))
    func sampledGlobalSourceCoordinatesArePreserved() throws {
        try checkSourceCoordinates(
            sourceFile: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"],
            identity: .global,
            maximumArtifactBytes: 128 * 1_024 * 1_024,
            targetSampleCount: 100_000
        )
    }

    /// Set ICON_D2_GRID_TEST_FILE to the decompressed official D2 grid NetCDF file.
    /// Generated artifacts are temporary; operational static files are never replaced.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] != nil))
    func d2SourceCoordinatesArePreserved() throws {
        try checkSourceCoordinates(
            sourceFile: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"],
            identity: .d2,
            maximumArtifactBytes: 32 * 1_024 * 1_024,
            targetSampleCount: .max
        )
    }

}

private extension NativeGridFixture {
    var grid: IconNativeGrid {
        IconNativeGrid(
            storage: index,
            maximumChordDistanceSquared: maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: maximumChordDistanceSquared
        )
    }
}

private func makeIdentity(_ fixture: NativeGridFixture) -> IconNativeGridIdentity {
    IconNativeGridIdentity(
        gridNumber: 26,
        gridUUID: UUID(uuidString: "00010203-0405-0607-0809-0a0b0c0d0e0f")!,
        cellCount: fixture.centers.count,
        isGlobal: true,
        latitudeBandCount: fixture.index.latitudeBandCount,
        maximumDistanceMeters: 10_000_000,
        sourceFile: "synthetic.nc.bz2"
    )
}

private func checkSourceCoordinates(
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
    let originalBytes = try Data(contentsOf: artifactFile)
    _ = try IconNativeGrid.Generator.generateAndPublish(
        sourceFile: sourceFile, identity: identity, artifactFile: artifactFile.path
    )
    #expect(try Data(contentsOf: artifactFile) == originalBytes)
    let wrongIdentity = IconNativeGridIdentity(gridNumber: identity.gridNumber, gridUUID: identity.gridUUID,
        cellCount: identity.cellCount + 1, isGlobal: identity.isGlobal,
        latitudeBandCount: identity.latitudeBandCount, maximumDistanceMeters: identity.maximumDistanceMeters,
        sourceFile: identity.sourceFile)
    #expect(throws: IconNativeGridSourceError.self) {
        _ = try IconNativeGrid.Generator.generateAndPublish(
            sourceFile: sourceFile, identity: wrongIdentity, artifactFile: artifactFile.path
        )
    }
    #expect(try Data(contentsOf: artifactFile) == originalBytes)

    #expect(grid.nx == identity.cellCount)
    let artifactBytes = try #require(
        artifactFile.resourceValues(forKeys: [.fileSizeKey]).fileSize
    )
    #expect(artifactBytes <= maximumArtifactBytes)
    let stride = max(1, source.count / targetSampleCount)
    for cell in Swift.stride(from: 0, to: source.count, by: stride) {
        let stored = grid.storage.point(at: cell)
        #expect(source[cell].x.bitPattern == stored.x.bitPattern)
        #expect(source[cell].y.bitPattern == stored.y.bitPattern)
        #expect(source[cell].z.bitPattern == stored.z.bitPattern)
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
