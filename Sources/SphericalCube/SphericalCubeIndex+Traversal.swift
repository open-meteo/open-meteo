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
        forEachRingOffset(radius: radius) { dx, dy in
            guard let bucket = projectedBucket(around: location, dx: dx, dy: dy),
                visited.insert(bucket)
            else { return }
            body(bucket)
        }
    }

    /// Scan only the new ring. In-face rows are contiguous; only cross-face offsets need
    /// projection and deduplication. Projected offsets cannot return to the query face.
    /// Explicit inout state avoids heap boxes for mutable values captured by the callback.
    @inline(__always)
    func forEachNeighborhoodRing<State>(
        around location: SphericalCubeGeometry.Location,
        radius: Int,
        visited: inout VisitedBuckets?,
        bytes: borrowing RawSpan,
        state: inout State,
        _ body: (Range<Int>, inout State) -> Void
    ) {
        @inline(__always)
        func scanRow(y: Int, xRange: ClosedRange<Int>) {
            forEachRowPointRange(face: location.face, y: y, xRange: xRange, bytes: bytes) {
                body($0, &state)
            }
        }
        if radius == 0 {
            scanRow(y: location.y, xRange: location.x...location.x)
            return
        }
        let lowerX = location.x - radius
        let upperX = location.x + radius
        let lowerY = location.y - radius
        let upperY = location.y + radius
        scanRow(y: lowerY, xRange: lowerX...upperX)
        scanRow(y: upperY, xRange: lowerX...upperX)
        for y in (lowerY + 1)..<upperY {
            scanRow(y: y, xRange: lowerX...lowerX)
            scanRow(y: y, xRange: upperX...upperX)
        }
        guard lowerX < 0 || lowerY < 0 || upperX >= resolution || upperY >= resolution else { return }
        if visited == nil { visited = VisitedBuckets() }
        forEachRingOffset(radius: radius) { dx, dy in
            let x = location.x + dx
            let y = location.y + dy
            guard x < 0 || y < 0 || x >= resolution || y >= resolution,
                let bucket = projectedBucket(around: location, dx: dx, dy: dy),
                visited!.insert(bucket)
            else { return }
            body(pointRange(in: bucket, bytes: bytes), &state)
        }
    }

    @inline(__always)
    private func forEachRingOffset(radius: Int, _ visit: (Int, Int) -> Void) {
        precondition(radius >= 0 && radius <= 8, "spherical projected-ring radius out of range")
        if radius == 0 {
            visit(0, 0)
            return
        }
        for dx in -radius...radius {
            visit(dx, -radius)
            visit(dx, radius)
        }
        for dy in (-radius + 1)..<radius {
            visit(-radius, dy)
            visit(radius, dy)
        }
    }
}
