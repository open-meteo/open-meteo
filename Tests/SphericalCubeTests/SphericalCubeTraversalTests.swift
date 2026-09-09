import Foundation
import OmFileFormat
@testable import SphericalCube
@testable import SphericalCubeTestSupport
import Testing

@Suite struct SphericalCubeTraversalTests {
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

    @Test(arguments: [true, false])
    func projectedRingsMatchSquareEnumeration(isGlobal: Bool) throws {
        let fixture = try makeFixture(
            centers: [SphericalPoint(latitudeDegrees: 52, longitudeDegrees: 13)],
            isGlobal: isGlobal
        )
        defer { fixture.remove() }
        let index = fixture.index
        for face in 0..<6 {
            for (u, v) in [(0.0, 0.0), (1.0, 0.2), (-1.0, 0.2), (1.0, 1.0), (-1.0, -1.0)] {
                let location = SphericalCubeGeometry.location(
                    for: SphericalCubeGeometry.faceVector(face: face, u: u, v: v),
                    resolution: index.resolution
                )
                var visited = SphericalCubeIndex.VisitedBuckets()
                var actual = [Int]()
                for radius in 0...8 {
                    index.forEachProjectedRing(around: location, radius: radius, visited: &visited) {
                        actual.append($0)
                    }
                    // An independent full-square enumeration verifies coverage across all rings.
                    let expected = Set((-radius...radius).flatMap { dy in
                        (-radius...radius).compactMap { dx in
                            index.projectedBucket(around: location, dx: dx, dy: dy)
                        }
                    })
                    #expect(Set(actual) == expected)
                    #expect(actual.count == expected.count)
                    var repeated = [Int]()
                    index.forEachProjectedRing(around: location, radius: radius, visited: &visited) {
                        repeated.append($0)
                    }
                    #expect(repeated.isEmpty)
                }

                // Preserve the first two rings' order: early-exit searches depend on visitation order.
                let offsets = [(0, 0), (-1, -1), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 1), (-1, 0), (1, 0)]
                var expectedOrder = [Int]()
                for (dx, dy) in offsets {
                    if let bucket = index.projectedBucket(around: location, dx: dx, dy: dy),
                        !expectedOrder.contains(bucket) {
                        expectedOrder.append(bucket)
                    }
                }
                #expect(Array(actual.prefix(expectedOrder.count)) == expectedOrder)
            }
        }
    }
}
