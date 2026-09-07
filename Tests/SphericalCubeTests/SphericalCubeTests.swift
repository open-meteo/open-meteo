import Foundation
import OmFileFormat
@testable import SphericalCube
import Testing

private let oracleScoreTolerance = 1e-15

@Suite struct SphericalCubeTests {
    @Test func nearestLookupStaysWithinMeterBudgetAcrossCubeFaces() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }

        for latitude in stride(from: Float(-89), through: 89, by: 4.75) {
            for longitude in stride(from: Float(-179), to: 180, by: 5.25) {
                let query = SphericalPoint(
                    latitudeDegrees: Double(latitude),
                    longitudeDegrees: Double(longitude)
                )
                let expected = nearest(point: query, centers: fixture.centers)
                let actual = try #require(fixture.index.nearestPointID(
                    latitude: latitude,
                    longitude: longitude
                ))
                #expect(distanceRegret(
                    query: query,
                    expected: fixture.centers[expected],
                    actual: fixture.centers[actual]
                ) <= 2)
            }
        }
    }

    @Test func nearbyExpansionKeepsSuppliedNearestFirstOnTies() throws {
        let fixture = try makeFixture(centers: Array(
            repeating: SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 0), count: 128
        ))
        defer { fixture.remove() }
        let lookup = try #require(fixture.index.nearestLookup(latitude: 0, longitude: 0))
        // Simulate a bounded lookup supplying a higher-ID tied point. Nearby expansion must
        // preserve the supplied point because its elevation has already been read by the caller.
        let supplied = SphericalCubeIndex.Lookup(
            query: lookup.query, location: lookup.location,
            pointID: 127, position: 127, distanceSquared: 0
        )
        let nearby = fixture.index.nearestCandidates(from: supplied)
        #expect(nearby.count == 10)
        #expect(nearby.pointIDs[0] == 127)
        for index in 1..<nearby.count { #expect(nearby.pointIDs[index] == index - 1) }
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
                let actual = try #require(fixture.index.nearestPointID(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ))
                #expect(distanceRegret(
                    query: query,
                    expected: fixture.centers[expected],
                    actual: fixture.centers[actual]
                ) <= 3)
            }
        }
    }

    @Test func spatialCandidatesStayLocalAcrossCubeFaces() throws {
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
                let lhsScore = query.dot(fixture.index.point(at: lhs))
                let rhsScore = query.dot(fixture.index.point(at: rhs))
                if lhsScore > rhsScore + oracleScoreTolerance { return true }
                if rhsScore > lhsScore + oracleScoreTolerance { return false }
                return lhs < rhs
            }
            let lookup = try #require(fixture.index.nearestLookup(
                latitude: latitude,
                longitude: longitude
            ))
            let actual = fixture.index.nearestCandidates(from: lookup)
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

        #expect(fixture.index.nearestPointID(latitude: 0, longitude: 0) == 0)
        let coordinate = fixture.index.point(at: 37).coordinate
        #expect(abs(coordinate.latitude) < 1e-5)
        #expect(abs(coordinate.longitude) < 1e-5)
    }

    @Test func crossFaceFloatTiePrefersLowerPointID() throws {
        // ID 1 occupies the query's +X face while lower ID 0 occupies +Y. A query on the seam
        // therefore verifies that projected fallback order does not decide an equal Float distance.
        let fixture = try makeFixture(centers: [
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 46),
            SphericalPoint(latitudeDegrees: 0, longitudeDegrees: 44),
        ])
        defer { fixture.remove() }

        #expect(fixture.index.nearestPointID(latitude: 0, longitude: 45) == 0)
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

        #expect(fixture.index.nearestPointID(latitude: 50, longitude: 5) == 0)
        #expect(fixture.index.nearestPointID(latitude: 50, longitude: 365) == 0)
        #expect(fixture.index.nearestPointID(latitude: 50.05, longitude: 5) == 0)
        #expect(fixture.index.nearestPointID(latitude: 50.2, longitude: 5) == nil)
        #expect(fixture.index.nearestPointID(latitude: 48, longitude: 5) == nil)
        #expect(fixture.index.nearestPointID(latitude: .nan, longitude: 5) == nil)
        #expect(fixture.index.nearestPointID(latitude: 91, longitude: 5) == nil)
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
            let actual = fixture.index.point(at: cell)
            #expect(centerDirectionDistance(expected, actual) <= 2)
            let coordinate = fixture.index.point(at: cell).coordinate
            #expect(fixture.index.nearestPointID(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) == cell)
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
            _ = try SphericalCubeIndex(file: corruptedFile)
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
}

private struct SphericalCubeFixture {
    let file: URL
    let index: SphericalCubeIndex
    let centers: [SphericalPoint]

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

private let globalMetadata = SphericalCubeArtifact.Metadata(
    identity: .init(number: 26, uuid: Array(0..<16)),
    coversWholeSphere: true,
    maximumChordDistanceSquared: maximumChordDistanceSquared(meters: 10_000_000)
)

private func makeGlobalFixture() throws -> SphericalCubeFixture {
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
) throws -> SphericalCubeFixture {
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
        return SphericalCubeFixture(
            file: file,
            index: try SphericalCubeIndex(file: file),
            centers: centers
        )
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
}

/// Expensive semantic verification belongs to artifact generation tests, not mmap startup.
private func validateGeneratedArtifact(_ fixture: SphericalCubeFixture) throws {
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
        point.dot(centers[$0]) >= bestScore - oracleScoreTolerance
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

private func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("spherical-cube-\(UUID().uuidString).bin")
}

private func truncateLastByte(of file: URL) throws {
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    try handle.truncate(atOffset: size - 1)
}
