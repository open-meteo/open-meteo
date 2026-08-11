import Foundation
@testable import App
import OmFileFormat
import Testing

@Suite struct IconNativeGridTests {
    @Test func nearestLookupStaysWithinMeterBudgetAcrossCubeFaces() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        for latitude in stride(from: Float(-89), through: 89, by: 4.75) {
            for longitude in stride(from: Float(-179), to: 180, by: 5.25) {
                let query = IconNativeCenter(
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
            let midpoint = IconNativeCenter(
                x: (center.x + other.x) / midpointLength,
                y: (center.y + other.y) / midpointLength,
                z: (center.z + other.z) / midpointLength
            )
            let tangentLength = sqrt(center.squaredDistance(to: other))
            let tangent = IconNativeCenter(
                x: (other.x - center.x) / tangentLength,
                y: (other.y - center.y) / tangentLength,
                z: (other.z - center.z) / tangentLength
            )

            for offsetMeters in [-3.0, 0, 3.0] {
                let offset = offsetMeters * inverseEarthRadius
                let raw = IconNativeCenter(
                    x: midpoint.x + offset * tangent.x,
                    y: midpoint.y + offset * tangent.y,
                    z: midpoint.z + offset * tangent.z
                )
                let coordinate = raw.coordinate
                let query = IconNativeCenter(
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
            let query = IconNativeCenter.fastCubeLookupVector(
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            ).center
            let ranked = fixture.centers.indices.sorted { lhs, rhs in
                let lhsScore = query.dot(fixture.grid.storage.centerVector(at: lhs))
                let rhsScore = query.dot(fixture.grid.storage.centerVector(at: rhs))
                if lhsScore > rhsScore + IconNativeGrid.CubeIndex.scoreTieTolerance { return true }
                if rhsScore > lhsScore + IconNativeGrid.CubeIndex.scoreTieTolerance { return false }
                return lhs < rhs
            }
            let actual = try #require(fixture.grid.storage.findNearestCells(
                latitude: latitude,
                longitude: longitude
            ))
            let actualCells = (0..<actual.count).map { actual.points[$0] }
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
            IconNativeCenter(latitudeDegrees: 0, longitudeDegrees: 0)
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
            IconNativeCenter(latitudeDegrees: 50, longitudeDegrees: 5),
            IconNativeCenter(latitudeDegrees: 50, longitudeDegrees: 10),
            IconNativeCenter(latitudeDegrees: 55, longitudeDegrees: 5),
            IconNativeCenter(latitudeDegrees: 55, longitudeDegrees: 10),
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
        #expect(IconNativeGrid.CubeArtifact.magic == Array("ICONCUB5".utf8))
        #expect(IconNativeGrid.CubeArtifact.version == 5)
        #expect(IconNativeGrid.CubeArtifact.globalFlag == 1)
        #expect(IconNativeGrid.CubeArtifact.headerBytes == 144)
        #expect(IconNativeGrid.CubeArtifact.centerStride == 16)
        let artifact = try IconNativeGrid.CubeArtifact.open(file: fixture.file)
        #expect(artifact.isGlobal)
        #expect(artifact.gridNumber == globalMetadata.gridNumber)
        #expect(artifact.cellCount == fixture.centers.count)
        #expect(artifact.level == 4)
        #expect(artifact.centersOffset.isMultiple(of: 16))
        try validateGeneratedArtifact(fixture)

        for cell in fixture.centers.indices {
            let expected = fixture.centers[cell]
            let actual = fixture.grid.storage.centerVector(at: cell)
            #expect(centerDirectionDistance(expected, actual) <= 2)
            #expect(fixture.grid.storage.findNearestCell(to: expected) == cell)
        }
    }

    @Test func malformedLayoutAndSizeBudgetAreRejected() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let corruptedFile = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: corruptedFile) }
        try FileManager.default.copyItem(at: fixture.file, to: corruptedFile)
        try truncateLastByte(of: corruptedFile)
        #expect(throws: IconNativeGrid.ArtifactError.invalidHeader) {
            _ = try IconNativeGrid.load(file: corruptedFile)
        }

        let tooSmall = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: tooSmall) }
        #expect(throws: IconNativeGrid.ArtifactError.self) {
            try IconNativeGrid.Generator.ArtifactWriter.write(
                to: tooSmall,
                metadata: globalMetadata,
                centers: fixture.centers,
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

    @Test func concurrentLookupsAreStable() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let expected = (0..<360).map { offset in
            fixture.grid.findPoint(lat: 37.5, lon: Float(offset) - 179.75)
        }

        let stable = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    for offset in expected.indices {
                        if fixture.grid.findPoint(
                            lat: 37.5,
                            lon: Float(offset) - 179.75
                        ) != expected[offset] {
                            return false
                        }
                    }
                    return true
                }
            }
            for await result in group where !result { return false }
            return true
        }
        #expect(stable)
    }

    @Test func invalidNetcdfUsesTheSourceErrorDomain() throws {
        let file = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try "not a NetCDF file".write(to: file, atomically: true, encoding: .utf8)

        #expect(throws: IconNativeGridSourceError.self) {
            _ = try IconNativeGrid.Generator.readSource(file: file.path, identity: .d2)
        }
    }

    @Test func terrainAndSeaSelectionUseSpatialCandidates() async throws {
        let centers = [
            IconNativeCenter(latitudeDegrees: 0, longitudeDegrees: 0),
            IconNativeCenter(latitudeDegrees: 0, longitudeDegrees: 0.1),
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
    let centers: [IconNativeCenter]

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

private struct IconNativeGridElevationFile {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>
}

private let globalMetadata = IconNativeGrid.CubeArtifact.Metadata(
    gridNumber: 26,
    gridUUID: Array(0..<16),
    isGlobal: true,
    maximumDistanceMeters: 10_000_000
)

private func makeGlobalFixture() throws -> IconNativeGridFixture {
    let count = 257
    let goldenAngle = Double.pi * (3 - sqrt(5.0))
    let centers = (0..<count).map { cell in
        let z = 1 - 2 * (Double(cell) + 0.5) / Double(count)
        let radius = sqrt(max(0, 1 - z * z))
        let longitude = Double(cell) * goldenAngle
        return IconNativeCenter(
            x: radius * cos(longitude),
            y: radius * sin(longitude),
            z: z
        )
    }
    return try makeFixture(centers: centers)
}

private func makeFixture(
    centers: [IconNativeCenter],
    isGlobal: Bool = true,
    maximumDistanceMeters: Float = 10_000_000
) throws -> IconNativeGridFixture {
    let file = temporaryArtifactFile()
    let metadata = isGlobal ? globalMetadata : IconNativeGrid.CubeArtifact.Metadata(
        gridNumber: 47,
        gridUUID: Array(repeating: 47, count: 16),
        isGlobal: false,
        maximumDistanceMeters: maximumDistanceMeters
    )
    do {
        try IconNativeGrid.Generator.ArtifactWriter.write(
            to: file,
            metadata: metadata,
            centers: centers,
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
    typealias Artifact = IconNativeGrid.CubeArtifact
    let artifact = try Artifact.open(file: fixture.file)
    let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(artifact.mapped.data))
    var previous = 0
    for bucket in 0...artifact.bucketCount {
        let current = Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            offsetsOffset: artifact.offsetsOffset,
            bucketCount: artifact.bucketCount
        )
        #expect(current >= previous)
        #expect(current <= artifact.cellCount)
        previous = current
    }
    #expect(previous == artifact.cellCount)

    var seen = [Bool](repeating: false, count: artifact.cellCount)
    for position in 0..<artifact.cellCount {
        let center = Artifact.center(
            position: position,
            bytes: bytes,
            centersOffset: artifact.centersOffset
        )
        #expect(center.x.isFinite && center.y.isFinite && center.z.isFinite)
        #expect(abs(center.dot(center) - 1) <= 4e-12)

        let cell = Artifact.cell(
            position: position,
            bytes: bytes,
            centersOffset: artifact.centersOffset
        )
        guard cell >= 0, cell < artifact.cellCount else {
            Issue.record("Invalid canonical cell \(cell) at artifact position \(position)")
            continue
        }
        #expect(!seen[cell])
        seen[cell] = true
        #expect(
            Artifact.readUInt32(bytes, at: artifact.canonicalPositionsOffset + cell * 4)
                == UInt32(position)
        )

        let location = IconNativeGrid.CubeGeometry.location(
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
            offsetsOffset: artifact.offsetsOffset,
            bucketCount: artifact.bucketCount
        )
        let end = Artifact.directoryPosition(
            bucket + 1,
            bytes: bytes,
            offsetsOffset: artifact.offsetsOffset,
            bucketCount: artifact.bucketCount
        )
        #expect(position >= begin && position < end)
    }
    #expect(seen.allSatisfy { $0 })

}

private func nearest(point: IconNativeCenter, centers: [IconNativeCenter]) -> Int {
    var bestScore = -Double.infinity
    for center in centers { bestScore = max(bestScore, point.dot(center)) }
    return centers.indices.first {
        point.dot(centers[$0]) >= bestScore - IconNativeGrid.CubeIndex.scoreTieTolerance
    }!
}

private func distanceRegret(
    query: IconNativeCenter,
    expected: IconNativeCenter,
    actual: IconNativeCenter
) -> Double {
    let expectedDistance = acos(max(-1, min(1, query.dot(expected))))
    let actualDistance = acos(max(-1, min(1, query.dot(actual))))
    return max(0, actualDistance - expectedDistance) * 6_371_229
}

private func centerDirectionDistance(_ lhs: IconNativeCenter, _ rhs: IconNativeCenter) -> Double {
    let inverseNorms = 1 / sqrt(lhs.dot(lhs) * rhs.dot(rhs))
    let dot = max(-1, min(1, lhs.dot(rhs) * inverseNorms))
    return acos(dot) * 6_371_229
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
            centers: source.centers
        )
    )

    #expect(grid.nx == identity.cellCount)
    #expect(grid.storage.artifactBytes <= maximumArtifactBytes)
    let stride = max(1, source.centers.count / sampleLimit)
    for cell in Swift.stride(from: 0, to: source.centers.count, by: stride) {
        #expect(grid.storage.findNearestCell(to: source.centers[cell]) == cell)
        #expect(centerDirectionDistance(
            source.centers[cell],
            grid.storage.centerVector(at: cell)
        ) <= 2)
    }
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
