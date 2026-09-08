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
        let encoded = try OmFileLazyInt16ArrayReader.encode(source)

        #expect(encoded == [-999, 0, 2_048, 8_765, 9_999, .min])
        let decoded = encoded.map(OmFileLazyInt16ArrayReader.decode)
        #expect(decoded.dropLast() == source.dropLast())
        #expect(decoded.last?.isNaN == true)

        #expect(throws: OmFileLazyInt16ArrayReader.EncodingError.self) {
            try OmFileLazyInt16ArrayReader.encode([1.5])
        }
        #expect(throws: OmFileLazyInt16ArrayReader.EncodingError.self) {
            try OmFileLazyInt16ArrayReader.encode([Float(Int16.min)])
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
        let recordingReader = RecordingElevationReader(reader: elevationFile.reader)
        let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: recordingReader))

        let terrain = try #require(try await fixture.grid.findPointTerrainOptimised(
            lat: 0,
            lon: 0,
            elevation: 500,
            elevationFile: cachedReader
        ))

        #expect(terrain.gridpoint == 40)
        #expect(recordingReader.arrayReadRanges == [0..<400])
    }

    @Test func surfaceElevationCacheInitializesLazilyOnce() async throws {
        let elevationFile = try await makeElevationFile(
            (0..<800).map(Float.init),
            chunkWidth: 400
        )
        defer { try? FileManager.default.removeItem(atPath: elevationFile.path) }
        let recordingReader = RecordingElevationReader(reader: elevationFile.reader)
        let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: recordingReader))
        var pointIDs = InlineArray<10, Int>(repeating: -1)
        pointIDs[0] = 10
        pointIDs[1] = 20
        pointIDs[2] = 410

        #expect(recordingReader.arrayReadRanges.isEmpty)
        #expect(try await cachedReader.read(range: [0..<1, 10..<11]) == [10])
        #expect(recordingReader.arrayReadRanges == [10..<11])

        let first = try await cachedReader.read(pointIDs: pointIDs, count: 3)
        #expect(first[0] == 10)
        #expect(first[1] == 20)
        #expect(first[2] == 410)
        #expect(recordingReader.arrayReadRanges == [10..<11, 0..<800])

        _ = try await cachedReader.read(pointIDs: pointIDs, count: 3)
        #expect(recordingReader.arrayReadRanges == [10..<11, 0..<800])
    }

    @Test func surfaceElevationCacheCoalescesConcurrentLoads() async throws {
        let elevationFile = try await makeElevationFile(
            (0..<400).map(Float.init),
            chunkWidth: 400
        )
        defer { try? FileManager.default.removeItem(atPath: elevationFile.path) }
        let recordingReader = RecordingElevationReader(reader: elevationFile.reader)
        let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: recordingReader))

        let values = try await withThrowingTaskGroup(of: Float.self) { group in
            for _ in 0..<16 {
                group.addTask { try await cachedReader.read(pointID: 17) }
            }
            var values = [Float]()
            for try await value in group { values.append(value) }
            return values
        }

        #expect(values == [Float](repeating: 17, count: 16))
        #expect(recordingReader.arrayReadRanges == [0..<400])
    }

    @Test func surfaceElevationCacheRetriesFailedLoad() async throws {
        let elevationFile = try await makeElevationFile([0, 17], chunkWidth: 2)
        defer { try? FileManager.default.removeItem(atPath: elevationFile.path) }
        let recordingReader = RecordingElevationReader(reader: elevationFile.reader, failFirstRead: true)
        let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: recordingReader))

        await #expect(throws: RecordingElevationReader.ReadError.injectedFailure) {
            _ = try await cachedReader.read(pointID: 1)
        }
        #expect(recordingReader.arrayReadRanges == [0..<2])

        #expect(try await cachedReader.read(pointID: 1) == 17)
        #expect(recordingReader.arrayReadRanges == [0..<2, 0..<2])

        #expect(try await cachedReader.read(pointID: 0) == 0)
        #expect(recordingReader.arrayReadRanges == [0..<2, 0..<2])
    }

    @Test func surfacePayloadOffersLazyNativeElevationReader() async throws {
        let elevationFile = try await makeElevationFile([0, 1], chunkWidth: 2)
        defer { try? FileManager.default.removeItem(atPath: elevationFile.path) }

        let handle = try FileHandle.openFileReading(file: elevationFile.path)
        let size = Int64(try handle.seekToEnd())
        let payload = try await OmFileLocalRemoteOmReader(fd: handle, size: size)
        #expect(payload.nativeElevationReader is OmFileLazyInt16ArrayReader)
        #expect(!(payload.reader is OmFileLazyInt16ArrayReader))
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

private final class RecordingElevationReader: OmFileReaderArrayForwarding, Sendable {
    typealias OmType = Float

    enum ReadError: Error, Equatable {
        case injectedFailure
    }

    let wrappedReader: any OmFileReaderArrayProtocol<Float>
    private let failFirstRead: Bool
    private let recordedArrayReadRanges = Mutex<[Range<UInt64>]>([])

    init(reader: OmFileReaderArray<FileHandleWithCount, Float>, failFirstRead: Bool = false) {
        wrappedReader = reader
        self.failFirstRead = failFirstRead
    }

    var arrayReadRanges: [Range<UInt64>] {
        recordedArrayReadRanges.withLock { $0 }
    }

    func read<let nDimensions: Int>(
        range: InlineArray<nDimensions, Range<UInt64>>
    ) async throws -> [Float] {
        if nDimensions == 2 {
            let shouldFail = recordedArrayReadRanges.withLock {
                $0.append(range[1])
                return failFirstRead && $0.count == 1
            }
            if shouldFail { throw ReadError.injectedFailure }
        }
        return try await wrappedReader.read(range: range)
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
    chunkWidth: Int? = nil
) async throws -> IconNativeGridElevationFile {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-elevation-\(UUID().uuidString).om").path
    let handle = try FileHandle.createNewFile(file: path)
    try elevations.writeOmFile(
        fn: handle,
        dimensions: [1, elevations.count],
        chunks: [1, min(chunkWidth ?? elevations.count, elevations.count)],
        compression: .pfor_delta2d_int16,
        scalefactor: 1
    )
    try handle.close()
    return IconNativeGridElevationFile(
        path: path,
        reader: try await OmFileReader(file: path).expectArray(of: Float.self)
    )
}
