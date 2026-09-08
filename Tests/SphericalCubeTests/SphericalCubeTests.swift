import Foundation
import OmFileFormat
@testable import SphericalCube
import Testing

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
        try validateGeneratedArtifact(file: fixture.file, centers: fixture.centers)

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
