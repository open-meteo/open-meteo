import Foundation
@testable import App
@testable import SphericalCube
@testable import SphericalCubeTests
import OmFileFormat
import Synchronization
import Testing

@Suite struct IconNativeGridTests {
    @Test func int16ElevationCacheEncodingIsLossless() throws {
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

    @Test func cachePinsExplicitlyResolvedGrid() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let cache = IconNativeGridCache(file: fixture.file.path, identity: makeIdentity(fixture))
        #expect(throws: IconNativeDomainError.missingGridArtifact(fixture.file.path)) {
            _ = try cache.get()
        }
        try cache.validateFileAndInstall()
        let identifiers = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<16 {
                group.addTask { ObjectIdentifier(try cache.get().storage) }
            }
            var values = [ObjectIdentifier]()
            for try await value in group { values.append(value) }
            return values
        }
        #expect(Set(identifiers).count == 1)

        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        let unavailable = IconNativeGridCache(file: published.path, identity: makeIdentity(fixture))
        #expect(throws: IconNativeDomainError.missingGridArtifact(published.path)) {
            _ = try unavailable.get()
        }
        unavailable.install(fixture.grid)
        #expect(try unavailable.get().nx == fixture.centers.count)

        try truncateLastByte(of: fixture.file)
        #expect(throws: IconNativeDomainError.self) {
            try cache.validateFileAndInstall()
        }
        #expect(ObjectIdentifier(try cache.get().storage) == identifiers[0])
    }

    @Test func remoteArtifactIsValidatedBeforeLocalPublication() async throws {
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

    @Test func terrainAndSeaSelectionUseSpatialCandidates() async throws {
        let centers = [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1),
        ]
        let fixture = try makeFixture(centers: centers)
        defer { fixture.remove() }
        let terrainFile = try await makeElevationFile([0, 500])
        let seaFile = try await makeElevationFile([100, -999])
        defer {
            try? FileManager.default.removeItem(atPath: terrainFile.path)
            try? FileManager.default.removeItem(atPath: seaFile.path)
        }

        let terrain = try #require(try await fixture.grid.findPointTerrainOptimised(
            lat: 0,
            lon: 0.04,
            elevation: 500,
            elevationFile: terrainFile.reader
        ))
        #expect(terrain.gridpoint == 1)

        let sea = try #require(try await fixture.grid.findPointInSea(
            lat: 0,
            lon: 0.04,
            elevationFile: seaFile.reader
        ))
        #expect(sea.gridpoint == 1)
    }

    @Test func terrainElevationReadsReuseDecodedGrid() async throws {
        var centers = (0..<400).map { pointID in
            SphericalPoint(
                latitudeDegrees: -80 + Double(pointID) * 160 / 399,
                longitudeDegrees: 180
            )
        }
        for localPoint in 0..<10 {
            centers[localPoint * 40] = SphericalPoint(
                latitudeDegrees: 0,
                longitudeDegrees: Double(localPoint) * 0.01
            )
        }
        let fixture = try makeFixture(centers: centers)
        defer { fixture.remove() }

        var elevations = [Float](repeating: 0, count: centers.count)
        elevations[40] = 500
        let elevationFile = try await makeElevationFile(elevations)
        defer { try? FileManager.default.removeItem(atPath: elevationFile.path) }
        let loads = Mutex(0)
        let count = elevations.count
        let cache = ElevationCache(elementCount: count) {
            loads.withLock { $0 += 1 }
            return try await elevationFile.reader.read(range: [0..<1, 0..<UInt64(count)])
        }
        for _ in 0..<2 {
            let terrain = try #require(try await fixture.grid.findPointTerrainOptimised(
                lat: 0, lon: 0, elevation: 500,
                elevationFile: elevationFile.reader, elevationCache: cache
            ))
            #expect(terrain.gridpoint == 40)
        }
        #expect(loads.withLock { $0 } == 1)
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

    @Test func surfaceElevationCacheCoalescesConcurrentLoads() async throws {
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

    @Test func surfaceElevationCacheRetriesFailedConcurrentLoad() async throws {
        let loads = Mutex(0)
        let cache = ElevationCache(elementCount: 2) {
            let attempt = loads.withLock { $0 += 1; return $0 }
            await Task.yield()
            if attempt == 1 { throw ElevationTestError.injectedFailure }
            return [0, 17]
        }
        let failures = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    do {
                        #expect(try await cache.loadValues()[1] == 17)
                        return false
                    } catch {
                        #expect(error as? ElevationTestError == .injectedFailure)
                        return true
                    }
                }
            }
            var failures = 0
            for await failed in group { if failed { failures += 1 } }
            return failures
        }
        #expect(failures > 0)
        #expect(try await cache.loadValues()[1] == 17)
        #expect(try await cache.loadValues()[0] == 0)
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
            try? FileManager.default.removeItem(atPath: file.path)
            try? FileManager.default.removeItem(atPath: replacement.path)
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

    @Test func nativeSelectionPreservesRawResultsAndLazyPaths() async throws {
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ], maximumDistanceMeters: 20_000)
        defer { fixture.remove() }
        let file = try await makeElevationFile([100, -999])
        defer { try? FileManager.default.removeItem(atPath: file.path) }
        let cache = try #require(ElevationCache(reader: file.reader))
        for (mode, elevation) in [(GridSelectionMode.nearest, Float(500)), (.land, .nan)] {
            _ = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: elevation,
                elevationFile: file.reader, mode: mode, elevationCache: cache)
            #expect(cache.cachedValues == nil)
        }
        _ = try await fixture.grid.readElevation(gridpoint: 0, elevationFile: file.reader)
        #expect(cache.cachedValues == nil)
        for latitude in [Float.nan, 50] {
            let outside = try await fixture.grid.findPoint(lat: latitude, lon: 0, elevation: 500,
                elevationFile: file.reader, mode: .sea, elevationCache: cache)
            #expect(outside == nil)
            #expect(cache.cachedValues == nil)
        }
        for mode in [GridSelectionMode.sea, .land] {
            let raw = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                elevationFile: file.reader, mode: mode)
            let cached = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
                elevationFile: file.reader, mode: mode, elevationCache: cache)
            #expect(raw?.gridpoint == cached?.gridpoint)
            #expect(raw?.gridElevation.numeric == cached?.gridElevation.numeric)
            #expect(raw?.gridElevation.isSea == cached?.gridElevation.isSea)
        }
        #expect(cache.cachedValues != nil)
    }

    @Test func unsupportedElevationFormatUsesDirectReads() async throws {
        let file = try await makeElevationFile([100, -999], scaleFactor: 10)
        defer { try? FileManager.default.removeItem(atPath: file.path) }
        #expect(ElevationCache(reader: file.reader) == nil)
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0.1)
        ])
        defer { fixture.remove() }
        let result = try await fixture.grid.findPoint(lat: 0, lon: 0.04, elevation: 500,
            elevationFile: file.reader, mode: .sea, elevationCache: nil)
        #expect(result?.gridpoint == 1)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"] != nil))
    func officialGlobalGridMeetsTheFloat32Contract() throws {
        try validateOfficialGrid(
            sourceFile: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"],
            identity: .global,
            maximumArtifactBytes: 128 * 1_024 * 1_024,
            sampleLimit: 100_000
        )
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] != nil))
    func officialD2GridMeetsTheFloat32Contract() throws {
        try validateOfficialGrid(
            sourceFile: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"],
            identity: .d2,
            maximumArtifactBytes: 32 * 1_024 * 1_024,
            sampleLimit: .max
        )
    }

}

private extension SphericalCubeFixture {
    var grid: IconNativeGrid { IconNativeGrid(storage: index) }
}

private struct IconNativeGridElevationFile {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>
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
        gridUUID: Array(0..<16),
        gridUUIDHex: Array(0..<16).map { String(format: "%02x", $0) }.joined(),
        cellCount: fixture.centers.count,
        isGlobal: true,
        maximumDistanceMeters: 10_000_000,
        sourceFile: "synthetic.nc.bz2"
    )
}

private func validateOfficialGrid(
    sourceFile: String?,
    identity: IconNativeGridIdentity,
    maximumArtifactBytes: Int,
    sampleLimit: Int
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
    let stride = max(1, source.count / sampleLimit)
    for cell in Swift.stride(from: 0, to: source.count, by: stride) {
        let coordinate = grid.storage.point(at: cell).coordinate
        #expect(grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude) == cell)
        #expect(centerDirectionDistance(
            source[cell],
            grid.storage.point(at: cell)
        ) <= 2)
    }
    try validateOfficialLookupRegret(grid: grid, source: source, identity: identity)
}

private func validateOfficialLookupRegret(
    grid: IconNativeGrid,
    source: [SphericalPoint],
    identity: IconNativeGridIdentity
) throws {
    var state: UInt64 = 0x243f_6a88_85a3_08d3
    var maximumRegretMeters = 0.0
    var differentPointCount = 0
    let inverseEarthRadius = 1 / 6_371_229.0
    for queryIndex in 0..<50_000 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let pointID = Int(state % UInt64(source.count))
        let center = grid.storage.point(at: pointID)
        let coordinate = center.coordinate
        let lookup = try #require(grid.storage.nearestLookup(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
        let candidates = grid.storage.nearestCandidates(from: lookup)
        let neighbour = grid.storage.point(at: candidates.pointIDs[1])
        let midpointLength = sqrt(
            (center.x + neighbour.x) * (center.x + neighbour.x)
                + (center.y + neighbour.y) * (center.y + neighbour.y)
                + (center.z + neighbour.z) * (center.z + neighbour.z)
        )
        let midpoint = SphericalPoint(
            x: (center.x + neighbour.x) / midpointLength,
            y: (center.y + neighbour.y) / midpointLength,
            z: (center.z + neighbour.z) / midpointLength
        )
        let tangentLength = sqrt(center.squaredDistance(to: neighbour))
        let tangent = SphericalPoint(
            x: (neighbour.x - center.x) / tangentLength,
            y: (neighbour.y - center.y) / tangentLength,
            z: (neighbour.z - center.z) / tangentLength
        )
        let offsetMeters = Double(queryIndex % 3 - 1) * 3
        let raw = SphericalPoint(
            x: midpoint.x + offsetMeters * inverseEarthRadius * tangent.x,
            y: midpoint.y + offsetMeters * inverseEarthRadius * tangent.y,
            z: midpoint.z + offsetMeters * inverseEarthRadius * tangent.z
        )
        let inverseNorm = 1 / sqrt(raw.dot(raw))
        let queryCoordinate = SphericalPoint(
            x: raw.x * inverseNorm,
            y: raw.y * inverseNorm,
            z: raw.z * inverseNorm
        ).coordinate
        let query = SphericalPoint.fastLookupVector(
            latitudeDegrees: queryCoordinate.latitude,
            longitudeDegrees: queryCoordinate.longitude
        ).point
        let expected = nearestCandidate(
            point: query,
            candidates: candidates,
            grid: grid
        )
        let actual = try #require(grid.findPoint(
            lat: queryCoordinate.latitude,
            lon: queryCoordinate.longitude
        ))
        if actual != expected { differentPointCount += 1 }
        maximumRegretMeters = max(
            maximumRegretMeters,
            distanceRegret(
                query: query,
                expected: grid.storage.point(at: expected),
                actual: grid.storage.point(at: actual)
            )
        )
    }
    print("Grid \(identity.gridNumber) Float lookup: \(differentPointCount) differing IDs, \(maximumRegretMeters) m maximum regret")
    #expect(maximumRegretMeters <= 3)
}

private func nearestCandidate(
    point: SphericalPoint,
    candidates: SphericalCubeIndex.NearbyPoints,
    grid: IconNativeGrid
) -> Int {
    var bestPointID = candidates.pointIDs[0]
    var bestScore = point.dot(grid.storage.point(at: bestPointID))
    for position in 1..<candidates.count {
        let pointID = candidates.pointIDs[position]
        let score = point.dot(grid.storage.point(at: pointID))
        if score > bestScore + oracleScoreTolerance
            || (abs(score - bestScore) <= oracleScoreTolerance && pointID < bestPointID)
        {
            bestScore = score
            bestPointID = pointID
        }
    }
    return bestPointID
}

private func makeElevationFile(
    _ elevations: [Float],
    chunkWidth: Int? = nil,
    scaleFactor: Float = 1
) async throws -> IconNativeGridElevationFile {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-elevation-\(UUID().uuidString).om").path
    let handle = try FileHandle.createNewFile(file: path)
    try elevations.writeOmFile(
        fn: handle,
        dimensions: [1, elevations.count],
        chunks: [1, min(chunkWidth ?? elevations.count, elevations.count)],
        compression: .pfor_delta2d_int16,
        scalefactor: scaleFactor
    )
    try handle.close()
    return IconNativeGridElevationFile(
        path: path,
        reader: try await OmFileReader(file: path).expectArray(of: Float.self)
    )
}
