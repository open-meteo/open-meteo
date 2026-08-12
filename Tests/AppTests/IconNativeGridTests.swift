import Foundation
@testable import App
import OmFileFormat
import Testing

private extension SphericalCubeIndex {
    /// Preserve the official Double-precision centre during artifact round-trip validation.
    func nearestPointID(to center: SphericalPoint) -> Int {
        withBytes {
            nearest(
                to: center,
                maximumDistanceSquared: .infinity,
                seedPosition: nil,
                bytes: $0
            )!
        }
    }
}

@Suite struct IconNativeGridTests {
    @Test func nearestLookupStaysWithinMeterBudgetAcrossCubeFaces() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        for latitude in stride(from: Float(-89), through: 89, by: 4.75) {
            for longitude in stride(from: Float(-179), to: 180, by: 5.25) {
                let query = SphericalPoint(
                    latitudeDegrees: Double(latitude),
                    longitudeDegrees: Double(longitude)
                )
                let expected = nearest(point: query, centers: fixture.centers)
                let actual = try #require(grid.findPoint(lat: latitude, lon: longitude))
                #expect(distanceRegret(
                    query: query,
                    expected: fixture.centers[expected],
                    actual: fixture.centers[actual]
                ) <= 2)
            }
        }
    }

    @Test func floatCandidateDistancesStayAccurateNearVoronoiBoundaries() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let inverseEarthRadius = 1 / 6_371_229.0

        for cell in fixture.centers.indices {
            let center = fixture.centers[cell]
            let neighbour = fixture.centers.indices
                .filter { $0 != cell }
                .max { center.dot(fixture.centers[$0]) < center.dot(fixture.centers[$1]) }!
            let other = fixture.centers[neighbour]
            let midpointLength = sqrt(
                (center.x + other.x) * (center.x + other.x)
                    + (center.y + other.y) * (center.y + other.y)
                    + (center.z + other.z) * (center.z + other.z)
            )
            let midpoint = SphericalPoint(
                x: (center.x + other.x) / midpointLength,
                y: (center.y + other.y) / midpointLength,
                z: (center.z + other.z) / midpointLength
            )
            let tangentLength = sqrt(center.squaredDistance(to: other))
            let tangent = SphericalPoint(
                x: (other.x - center.x) / tangentLength,
                y: (other.y - center.y) / tangentLength,
                z: (other.z - center.z) / tangentLength
            )

            for offsetMeters in [-3.0, 0, 3.0] {
                let offset = offsetMeters * inverseEarthRadius
                let raw = SphericalPoint(
                    x: midpoint.x + offset * tangent.x,
                    y: midpoint.y + offset * tangent.y,
                    z: midpoint.z + offset * tangent.z
                )
                let coordinate = raw.coordinate
                let query = SphericalPoint(
                    latitudeDegrees: Double(coordinate.latitude),
                    longitudeDegrees: Double(coordinate.longitude)
                )
                let expected = nearest(point: query, centers: fixture.centers)
                let actual = try #require(fixture.grid.findPoint(
                    lat: coordinate.latitude,
                    lon: coordinate.longitude
                ))
                #expect(distanceRegret(
                    query: query,
                    expected: fixture.centers[expected],
                    actual: fixture.centers[actual]
                ) <= 3)
            }
        }
    }

    @Test func spatialTerrainCandidatesStayLocalAcrossCubeFaces() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let coordinates: [(Float, Float)] = [
            (0, 45), (0, -45), (0, 135), (0, -135),
            (35.26439, 45), (-35.26439, -45),
            (89.9, 0), (-89.9, 180), (52.52, 13.405),
        ]

        for (latitude, longitude) in coordinates {
            let query = SphericalPoint.fastLookupVector(
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            ).point
            let ranked = fixture.centers.indices.sorted { lhs, rhs in
                let lhsScore = query.dot(fixture.grid.storage.point(at: lhs))
                let rhsScore = query.dot(fixture.grid.storage.point(at: rhs))
                if lhsScore > rhsScore + SphericalCubeIndex.exactScoreMargin { return true }
                if rhsScore > lhsScore + SphericalCubeIndex.exactScoreMargin { return false }
                return lhs < rhs
            }
            let lookup = try #require(fixture.grid.storage.nearestLookup(
                latitude: latitude,
                longitude: longitude
            ))
            let actual = fixture.grid.storage.nearestCandidates(from: lookup)
            let actualCells = (0..<actual.count).map { actual.pointIDs[$0] }
            let nearestTen = Set(ranked.prefix(10))
            let nearestTwenty = Set(ranked.prefix(20))

            #expect(actual.count == 10)
            #expect(actualCells.first == ranked[0])
            #expect(Set(actualCells).count == actual.count)
            #expect(actualCells.filter { nearestTen.contains($0) }.count >= 8)
            #expect(actualCells.allSatisfy { nearestTwenty.contains($0) })
        }
    }

    @Test func canonicalCoordinatesAndTiesAreStable() throws {
        let centers = (0..<128).map { _ in
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0)
        }
        let fixture = try makeFixture(centers: centers)
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        #expect(grid.findPoint(lat: 0, lon: 0) == 0)
        let coordinate = grid.getCoordinates(gridpoint: 37)
        #expect(abs(coordinate.latitude) < 1e-5)
        #expect(abs(coordinate.longitude) < 1e-5)
    }

    @Test func regionalDistanceLimitAndLongitudeWrappingArePreserved() throws {
        let centers = [
            SphericalPoint(latitudeDegrees: 50, longitudeDegrees: 5),
            SphericalPoint(latitudeDegrees: 50, longitudeDegrees: 10),
            SphericalPoint(latitudeDegrees: 55, longitudeDegrees: 5),
            SphericalPoint(latitudeDegrees: 55, longitudeDegrees: 10),
        ]
        let fixture = try makeFixture(
            centers: centers,
            isGlobal: false,
            maximumDistanceMeters: 10_000
        )
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        #expect(grid.findPoint(lat: 50, lon: 5) == 0)
        #expect(grid.findPoint(lat: 50, lon: 365) == 0)
        #expect(grid.findPoint(lat: 50.05, lon: 5) == 0)
        #expect(grid.findPoint(lat: 50.2, lon: 5) == nil)
        #expect(grid.findPoint(lat: 48, lon: 5) == nil)
        #expect(grid.findPoint(lat: .nan, lon: 5) == nil)
        #expect(grid.findPoint(lat: 91, lon: 5) == nil)
    }

    @Test func artifactUsesSinglePortableFloat32Format() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let artifact = try SphericalCubeArtifact.open(file: fixture.file)
        #expect(artifact.coversWholeSphere)
        #expect(artifact.identity == globalMetadata.identity)
        #expect(artifact.pointCount == fixture.centers.count)
        #expect(artifact.level == 4)
        #expect(artifact.pointsOffset.isMultiple(of: 16))
        try validateGeneratedArtifact(fixture)

        for cell in fixture.centers.indices {
            let expected = fixture.centers[cell]
            let actual = fixture.grid.storage.point(at: cell)
            #expect(centerDirectionDistance(expected, actual) <= 2)
            #expect(fixture.grid.storage.nearestPointID(to: expected) == cell)
        }
    }

    @Test func malformedLayoutAndSizeBudgetAreRejected() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let corruptedFile = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: corruptedFile) }
        try FileManager.default.copyItem(at: fixture.file, to: corruptedFile)
        try truncateLastByte(of: corruptedFile)
        #expect(throws: SphericalCubeArtifactError.invalidHeader) {
            _ = try IconNativeGrid.load(file: corruptedFile)
        }

        let tooSmall = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: tooSmall) }
        #expect(throws: SphericalCubeArtifactError.self) {
            try SphericalCubeArtifact.Writer.write(
                to: tooSmall,
                metadata: globalMetadata,
                points: fixture.centers,
                level: 4,
                maximumFileSize: 1
            )
        }
    }

    @Test func cacheMemoizesItsFirstLookupResult() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let cache = IconNativeGridCache(file: fixture.file.path, identity: makeIdentity(fixture))
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
        try FileManager.default.copyItem(at: fixture.file, to: published)
        #expect(throws: IconNativeDomainError.missingGridArtifact(published.path)) {
            _ = try unavailable.get()
        }
        let fresh = IconNativeGridCache(file: published.path, identity: makeIdentity(fixture))
        #expect(try fresh.get().nx == fixture.centers.count)

        try truncateLastByte(of: fixture.file)
        #expect(throws: IconNativeDomainError.self) {
            try cache.validateFileAndInstall()
        }
        #expect(ObjectIdentifier(try cache.get().storage) == identifiers[0])
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

private struct IconNativeGridFixture {
    let file: URL
    let grid: IconNativeGrid
    let centers: [SphericalPoint]

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

private struct IconNativeGridElevationFile {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>
}

private let globalMetadata = SphericalCubeArtifact.Metadata(
    identity: .init(number: 26, uuid: Array(0..<16)),
    coversWholeSphere: true,
    maximumChordDistanceSquared: maximumChordDistanceSquared(meters: 10_000_000)
)

private func makeGlobalFixture() throws -> IconNativeGridFixture {
    let count = 257
    let goldenAngle = Double.pi * (3 - sqrt(5.0))
    let centers = (0..<count).map { cell in
        let z = 1 - 2 * (Double(cell) + 0.5) / Double(count)
        let radius = sqrt(max(0, 1 - z * z))
        let longitude = Double(cell) * goldenAngle
        return SphericalPoint(
            x: radius * cos(longitude),
            y: radius * sin(longitude),
            z: z
        )
    }
    return try makeFixture(centers: centers)
}

private func makeFixture(
    centers: [SphericalPoint],
    isGlobal: Bool = true,
    maximumDistanceMeters: Float = 10_000_000
) throws -> IconNativeGridFixture {
    let file = temporaryArtifactFile()
    let metadata = isGlobal ? globalMetadata : SphericalCubeArtifact.Metadata(
        identity: .init(number: 47, uuid: Array(repeating: 47, count: 16)),
        coversWholeSphere: false,
        maximumChordDistanceSquared: maximumChordDistanceSquared(
            meters: Double(maximumDistanceMeters)
        )
    )
    do {
        try SphericalCubeArtifact.Writer.write(
            to: file,
            metadata: metadata,
            points: centers,
            level: isGlobal ? 4 : 3
        )
        return IconNativeGridFixture(
            file: file,
            grid: try IconNativeGrid.load(file: file),
            centers: centers
        )
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
}

/// Expensive semantic verification belongs to artifact generation tests, not mmap startup.
private func validateGeneratedArtifact(_ fixture: IconNativeGridFixture) throws {
    typealias Artifact = SphericalCubeArtifact
    let artifact = try Artifact.open(file: fixture.file)
    let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(artifact.mapped.data))
    let bucketCount = artifact.faceSections.reduce(0) { $0 + $1.columns * $1.rows }
    var previous = 0
    for bucket in 0...bucketCount {
        let current = Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        #expect(current >= previous)
        #expect(current <= artifact.pointCount)
        previous = current
    }
    #expect(previous == artifact.pointCount)

    var seen = [Bool](repeating: false, count: artifact.pointCount)
    for position in 0..<artifact.pointCount {
        let center = Artifact.point(
            position: position,
            bytes: bytes,
            pointsOffset: artifact.pointsOffset
        )
        #expect(center.x.isFinite && center.y.isFinite && center.z.isFinite)
        #expect(abs(center.dot(center) - 1) <= 4e-12)

        let cell = Artifact.pointID(
            position: position,
            bytes: bytes,
            pointsOffset: artifact.pointsOffset
        )
        guard cell >= 0, cell < artifact.pointCount else {
            Issue.record("Invalid canonical cell \(cell) at artifact position \(position)")
            continue
        }
        #expect(centerDirectionDistance(fixture.centers[cell], center) <= 2)
        #expect(!seen[cell])
        seen[cell] = true
        #expect(
            Artifact.readUInt32(bytes, at: artifact.positionsByIDOffset + cell * 4)
                == UInt32(position)
        )

        let location = SphericalCubeGeometry.location(
            for: center,
            resolution: artifact.resolution
        )
        guard let bucket = artifact.faceSections[location.face].bucket(
            x: location.x,
            y: location.y
        ) else {
            Issue.record("Center \(cell) falls outside its face section")
            continue
        }
        let begin = Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        let end = Artifact.directoryPosition(
            bucket + 1,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        #expect(position >= begin && position < end)
    }
    #expect(seen.allSatisfy { $0 })

}

private func nearest(point: SphericalPoint, centers: [SphericalPoint]) -> Int {
    var bestScore = -Double.infinity
    for center in centers { bestScore = max(bestScore, point.dot(center)) }
    return centers.indices.first {
        point.dot(centers[$0]) >= bestScore - SphericalCubeIndex.exactScoreMargin
    }!
}

private func distanceRegret(
    query: SphericalPoint,
    expected: SphericalPoint,
    actual: SphericalPoint
) -> Double {
    let expectedDistance = acos(max(-1, min(1, query.dot(expected))))
    let actualDistance = acos(max(-1, min(1, query.dot(actual))))
    return max(0, actualDistance - expectedDistance) * 6_371_229
}

private func centerDirectionDistance(_ lhs: SphericalPoint, _ rhs: SphericalPoint) -> Double {
    let inverseNorms = 1 / sqrt(lhs.dot(lhs) * rhs.dot(rhs))
    let dot = max(-1, min(1, lhs.dot(rhs) * inverseNorms))
    return acos(dot) * 6_371_229
}

private func maximumChordDistanceSquared(meters: Double) -> Float {
    let chord = 2 * sin(meters / 6_371_229 * 0.5)
    return Float(chord * chord)
}

private func makeIdentity(_ fixture: IconNativeGridFixture) -> IconNativeGridIdentity {
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
    let grid = try IconNativeGrid.Generator.generate(
        sourceFile: sourceFile,
        identity: identity,
        artifactFile: artifactFile.path
    )
    let source = try IconNativeGrid.Generator.readSource(file: sourceFile, identity: identity)
    try validateGeneratedArtifact(
        IconNativeGridFixture(
            file: artifactFile,
            grid: grid,
            centers: source
        )
    )

    #expect(grid.nx == identity.cellCount)
    let artifactBytes = try #require(
        artifactFile.resourceValues(forKeys: [.fileSizeKey]).fileSize
    )
    #expect(artifactBytes <= maximumArtifactBytes)
    let stride = max(1, source.count / sampleLimit)
    for cell in Swift.stride(from: 0, to: source.count, by: stride) {
        #expect(grid.storage.nearestPointID(to: source[cell]) == cell)
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
        let expected = grid.storage.nearestPointID(to: query)
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

private func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-cube-\(UUID().uuidString).bin")
}

private func truncateLastByte(of file: URL) throws {
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    try handle.truncate(atOffset: size - 1)
}

private func makeElevationFile(_ elevations: [Float]) async throws -> IconNativeGridElevationFile {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-elevation-\(UUID().uuidString).om").path
    let handle = try FileHandle.createNewFile(file: path)
    try elevations.writeOmFile(
        fn: handle,
        dimensions: [1, elevations.count],
        chunks: [1, elevations.count],
        compression: .pfor_delta2d_int16,
        scalefactor: 1
    )
    try handle.close()
    return IconNativeGridElevationFile(
        path: path,
        reader: try await OmFileReader(file: path).expectArray(of: Float.self)
    )
}
