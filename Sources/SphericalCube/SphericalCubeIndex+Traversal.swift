import Foundation

extension SphericalCubeIndex {
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

}
