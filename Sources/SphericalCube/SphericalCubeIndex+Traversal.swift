import Foundation

extension SphericalCubeIndex {
    /// Fixed storage is needed only when traversal crosses cube faces. A radius-eight stencil
    /// contains at most 17 × 17 projected buckets, including its center.
    struct VisitedBuckets {
        private var buckets = InlineArray<289, Int>(repeating: -1)
        private var count = 0

        @inline(__always)
        mutating func insert(_ bucket: Int) -> Bool {
            for position in 0..<count where buckets[position] == bucket {
                return false
            }
            precondition(count < 289, "spherical projected-bucket bound exceeded")
            buckets[count] = bucket
            count += 1
            return true
        }
    }

    /// Coordinates must be within the cube face; regional rectangles may still exclude them.
    @inline(__always)
    func bucket(face: Int, x: Int, y: Int) -> Int? {
        if coversWholeSphere {
            let tileShift = Artifact.tileShift
            let tileSize = Artifact.tileSize
            return face * resolution * resolution
                + (y >> tileShift) * tileSize * resolution
                + (x >> tileShift) * tileSize * tileSize
                + (y & (tileSize - 1)) * tileSize
                + (x & (tileSize - 1))
        }
        return faceSections[face].bucket(x: x, y: y)
    }

    @inline(__always)
    func pointRange(in bucket: Int, bytes: borrowing RawSpan) -> Range<Int> {
        directoryPosition(bucket, bytes: bytes)..<directoryPosition(bucket + 1, bytes: bytes)
    }

    /// Clips a logical row to its stored rectangle and visits contiguous tiled segments in order.
    /// The callback receives storage positions, leaving distance calculations and selection to callers.
    @inline(__always)
    func forEachRowPointRange(
        face: Int,
        y: Int,
        xRange: ClosedRange<Int>,
        bytes: borrowing RawSpan,
        _ body: (Range<Int>) -> Void
    ) {
        let section = faceSections[face]
        guard y >= section.minimumY, y < section.minimumY + section.rows else { return }
        let lowerX = max(xRange.lowerBound, section.minimumX)
        let upperX = min(xRange.upperBound, section.minimumX + section.columns - 1)
        guard lowerX <= upperX else { return }
        var segmentLowerX = lowerX
        while segmentLowerX <= upperX {
            let localX = segmentLowerX - section.minimumX
            let tileUpperX = section.minimumX + (((localX >> Artifact.tileShift) + 1) << Artifact.tileShift) - 1
            let segmentUpperX = min(upperX, tileUpperX)
            let firstBucket = bucket(face: face, x: segmentLowerX, y: y)!
            let lastBucket = firstBucket + segmentUpperX - segmentLowerX
            body(directoryPosition(firstBucket, bytes: bytes)..<directoryPosition(lastBucket + 1, bytes: bytes))
            segmentLowerX = segmentUpperX + 1
        }
    }

    /// Visits one projected ring in top/bottom, then left/right order. Retain `visited` across
    /// successive rings; callers decide when to stop and whether earlier direct scans are included.
    @inline(__always)
    func forEachProjectedRing(
        around location: SphericalCubeGeometry.Location,
        radius: Int,
        visited: inout VisitedBuckets,
        _ body: (Int) -> Void
    ) {
        precondition(radius >= 0 && radius <= 8, "spherical projected-ring radius out of range")
        @inline(__always)
        func visit(dx: Int, dy: Int) {
            guard let bucket = projectedBucket(around: location, dx: dx, dy: dy),
                visited.insert(bucket)
            else { return }
            body(bucket)
        }
        if radius == 0 {
            visit(dx: 0, dy: 0)
            return
        }
        for dx in -radius...radius {
            visit(dx: dx, dy: -radius)
            visit(dx: dx, dy: radius)
        }
        for dy in (-radius + 1)..<radius {
            visit(dx: -radius, dy: dy)
            visit(dx: radius, dy: dy)
        }
    }
}
