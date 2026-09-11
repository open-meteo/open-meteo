import Foundation
import OmFileFormat
@testable import SphericalCube
@testable import SphericalCubeTestSupport
import Testing

@Suite struct SphericalCubeTraversalTests {
    @Test(arguments: [9, 11])
    func distanceCoverageIncludesFaceEdgesAndCorners(level: Int) throws {
        let width = 2 / Double(1 << level)
        let lookupDistance = SphericalPoint.squaredChordDistance(meters: level == 9 ? 20_000 : 4_000)
        let distance = SphericalPoint.squaredChordDistance(meters: level == 9 ? 30_000 : 6_000)
        var centers = [SphericalPoint]()
        var queries = [SphericalPoint]()
        for face in 0..<6 {
            for (u, v) in [(0.0, 0.0), (1.0, 0.25), (1.0, 1.0)] {
                for offset in [-0.000001, 0.0, 0.000001] {
                    queries.append(SphericalCubeGeometry.faceVector(face: face, u: u + offset, v: v - offset))
                }
                for dy in -3...3 {
                    for dx in -3...3 {
                        centers.append(SphericalCubeGeometry.faceVector(face: face,
                            u: u + (Double(dx) + 0.5) * width, v: v + (Double(dy) + 0.5) * width))
                    }
                }
            }
        }
        let fixture = try makeFixture(centers: centers, isGlobal: false, level: level)
        defer { fixture.remove() }
        let index = fixture.index
        #expect(index.requiredSearchRadius(maximumChordDistanceSquared: lookupDistance) == 2)
        #expect(index.requiredSearchRadius(maximumChordDistanceSquared: distance) == 3)
        let stored = centers.indices.map { index.point(at: $0) }
        for point in queries {
            let coordinate = point.coordinate
            let query = SphericalPoint.fastLookupVector(latitudeDegrees: coordinate.latitude,
                longitudeDegrees: coordinate.longitude).point
            let location = SphericalCubeGeometry.location(for: query, resolution: index.resolution)
            for searchedRadius in [-1, 0, 1] {
                var visited = Set<Int>()
                index.withBytes { bytes in
                    if searchedRadius >= 0 {
                        for y in (location.y - searchedRadius)...(location.y + searchedRadius) {
                            index.forEachRowPointRange(face: location.face, y: y,
                                xRange: (location.x - searchedRadius)...(location.x + searchedRadius), bytes: bytes) { range in
                                for position in range {
                                    visited.insert(SphericalCubeArtifact.pointID(position: position, bytes: bytes, pointsOffset: index.pointsOffset))
                                }
                            }
                        }
                    }
                    index.forEachSearchRange(around: query, location: location, searchedRadius: searchedRadius,
                        maximumChordDistanceSquared: distance, bytes: bytes, state: &visited) { range, visited in
                        for position in range {
                            let id = SphericalCubeArtifact.pointID(position: position, bytes: bytes, pointsOffset: index.pointsOffset)
                            #expect(visited.insert(id).inserted)
                        }
                    }
                }
                for id in stored.indices where query.squaredDistance(to: stored[id]) <= Double(distance) {
                    #expect(visited.contains(id))
                }
            }
        }
    }

    @Test(arguments: [true, false])
    func rowRangesMatchBucketEnumeration(isGlobal: Bool) throws {
        // A rectangle starting inside a tile and ending in partial tiles on both axes.
        let resolution = 32
        let centers = (5...19).flatMap { y in
            (3...21).map { x in
                SphericalCubeGeometry.faceVector(
                    face: 0,
                    u: -1 + (Double(x) + 0.5) * 2 / Double(resolution),
                    v: -1 + (Double(y) + 0.5) * 2 / Double(resolution)
                )
            }
        }
        let fixture = try makeFixture(centers: centers, isGlobal: isGlobal, level: 5)
        defer { fixture.remove() }
        let index = fixture.index
        index.withBytes { bytes in
            for face in 0..<6 {
                for y in -1...resolution {
                    for xRange in [-3...40, 2...9, 9...17, 21...27] {
                        var expected = [Int]()
                        for x in xRange {
                            guard let bucket = index.faceSections[face].bucket(x: x, y: y) else { continue }
                            let begin = index.directoryPosition(bucket, bytes: bytes)
                            let end = index.directoryPosition(bucket + 1, bytes: bytes)
                            expected.append(contentsOf: begin..<end)
                        }
                        var actual = [Int]()
                        index.forEachRowPointRange(face: face, y: y, xRange: xRange, bytes: bytes) {
                            actual.append(contentsOf: $0)
                        }
                        #expect(actual == expected)
                    }
                }
            }
        }
    }

}
