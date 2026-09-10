import Foundation
import OmFileFormat
@testable import SphericalCube
@testable import SphericalCubeTestSupport
import Testing

@Suite struct SphericalCubeTraversalTests {
    @Test(arguments: [3, 4], [true, false])
    func ringsMatchIndependentProjection(level: Int, isGlobal: Bool) throws {
        let resolution = 1 << level
        var centers = [SphericalPoint]()
        for face in 0..<6 {
            for y in 0..<resolution {
                for x in 0..<resolution {
                    if !isGlobal {
                        let firstRectangle = face == 0 && (2..<(resolution - 1)).contains(x) && (1..<(resolution - 2)).contains(y)
                        let secondRectangle = face == 2 && x < 3 && y >= resolution / 2
                        guard firstRectangle || secondRectangle else { continue }
                    }
                    centers.append(SphericalCubeGeometry.faceVector(face: face,
                        u: -1 + (Double(x) + 0.5) * 2 / Double(resolution),
                        v: -1 + (Double(y) + 0.5) * 2 / Double(resolution)))
                }
            }
        }
        let fixture = try makeFixture(centers: centers, isGlobal: isGlobal, level: level)
        defer { fixture.remove() }
        let index = fixture.index
        let coordinates = Set([0, 1, 3, 7, resolution / 2, resolution - 2, resolution - 1]).sorted()
        for face in 0..<6 {
            for x in coordinates {
                for y in coordinates {
                    let location = SphericalCubeGeometry.location(for: SphericalCubeGeometry.faceVector(
                        face: face, u: -1 + (Double(x) + 0.5) * 2 / Double(resolution),
                        v: -1 + (Double(y) + 0.5) * 2 / Double(resolution)), resolution: resolution)
                    index.withBytes { bytes in
                        var visited: SphericalCubeIndex.VisitedBuckets?
                        var actual = [Int]()
                        for radius in 0...8 {
                            index.forEachNeighborhoodRing(around: location, radius: radius, visited: &visited,
                                bytes: bytes, state: &actual) { range, positions in
                                positions.append(contentsOf: range)
                            }
                            var expected = Set<Int>()
                            // Deliberately project every offset, including those inside the face.
                            for dy in -radius...radius {
                                for dx in -radius...radius {
                                    let point = SphericalCubeGeometry.faceVector(face: face,
                                        u: -1 + (Double(x + dx) + 0.5) * 2 / Double(resolution),
                                        v: -1 + (Double(y + dy) + 0.5) * 2 / Double(resolution))
                                    let projected = SphericalCubeGeometry.location(for: point, resolution: resolution)
                                    if let bucket = index.faceSections[projected.face].bucket(x: projected.x, y: projected.y) {
                                        expected.formUnion(index.pointRange(in: bucket, bytes: bytes))
                                    }
                                }
                            }
                            #expect(Set(actual) == expected)
                            #expect(actual.count == expected.count)
                            if radius <= min(x, y, resolution - 1 - x, resolution - 1 - y) {
                                #expect(visited == nil)
                            }
                        }
                    }
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
