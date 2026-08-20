import Foundation
import OmFileFormat

/// Memory-mapped nearest-point search over an implicit uniform cube quadtree on the unit sphere.
///
/// The index is independent of ICON and accepts any set of canonical point directions. Its only
/// stored spatial structure is a leaf-bucket prefix directory; internal quadtree nodes, bounds,
/// and cube-face adjacency are derived from `(face, level, x, y)` when needed.
///
/// A normal lookup follows three progressively more expensive paths:
///
/// 1. compare the query bucket's Float32 point records;
/// 2. if the result cannot be certified, compare the surrounding 3×3 buckets;
/// 3. if that region still cannot be certified, run the exact implicit-tree search in Double.
///
/// Certification proves that a sphere around the current candidate cannot cross the searched
/// cube-region boundary. Thus the common path remains small without assuming mesh connectivity.
///
/// ```text
/// latitude / longitude
///         |
///         v
/// normalize longitude and form Float32 unit vector (x, y, z)
///         |
///         v
/// choose dominant-axis cube face and project to (u, v)
///         |
///         v
/// quantize to leaf (face, x, y) and derive its tiled bucket number
///         |
///         v
/// decode directory[bucket ..< bucket + 1]
///         |
///         v
/// scan Float32 XYZ records and minimize squared chord distance
///         |
/// can the leaf be certified against its four boundaries?
///         +-- yes --> apply limit --> ID / nil
///         |
///         no
///         |
///         v
/// scan the same-face 3 x 3 leaves
///         |
/// can that region be certified?
///         +-- yes --> apply limit --> ID / nil
///         |
///         no
///         |
///         v
/// exact implicit-tree search over six faces --> apply limit --> canonical ID / nil
/// ```
final class SphericalCubeIndex: Sendable {
    typealias Artifact = SphericalCubeArtifact
    typealias FaceSection = Artifact.FaceSection

    /// Reusable result of nearest lookup. Nearby-point selection retains the query projection so it
    /// does not repeat trigonometry or the exact-nearest search.
    struct Lookup: Sendable {
        let query: SphericalLookupVector
        let location: SphericalCubeGeometry.Location
        let pointID: Int
        let position: Int
        let distanceSquared: Float
    }

    private struct Boundary: Sendable {
        let value: Double
        let inverseNormSquared: Double
    }

    /// Conservative Double score margin retained while pruning the exact fallback tree.
    static let exactScoreMargin = 1e-15
    static let floatChordError = 8 * Double(Float.ulpOfOne)

    private let mapped: MmapFile
    let faceSections: [FaceSection]
    private let directoryBasesOffset: Int
    private let directoryLocalsOffset: Int
    let pointsOffset: Int
    private let positionsByIDOffset: Int
    private let maximumDistanceSquared: Float
    let resolutionScale: Double
    private let boundaries: [Boundary]
    let coversWholeSphere: Bool

    let pointCount: Int
    let level: Int
    let resolution: Int
    let identity: SphericalCubeArtifact.DatasetIdentity

    /// Opens and validates the artifact, then precomputes leaf-boundary terms used by certification.
    init(file: URL) throws {
        let artifact = try Artifact.open(file: file)
        mapped = artifact.mapped
        faceSections = artifact.faceSections
        directoryBasesOffset = artifact.directoryBasesOffset
        directoryLocalsOffset = artifact.directoryLocalsOffset
        pointsOffset = artifact.pointsOffset
        positionsByIDOffset = artifact.positionsByIDOffset
        maximumDistanceSquared = artifact.maximumChordDistanceSquared
        coversWholeSphere = artifact.coversWholeSphere
        pointCount = artifact.pointCount
        level = artifact.level
        resolution = artifact.resolution
        resolutionScale = Double(artifact.resolution) * 0.5
        identity = artifact.identity
        let bucketWidth = 2 / Double(artifact.resolution)
        boundaries = (0...artifact.resolution).map {
            let value = -1 + Double($0) * bucketWidth
            return Boundary(value: value, inverseNormSquared: 1 / (1 + value * value))
        }
    }

    /// Returns the canonical ID nearest to the coordinate, or `nil` for invalid input or when the
    /// closest stored point exceeds the artifact's maximum chord distance.
    @inline(__always)
    func nearestPointID(latitude: Float, longitude: Float) -> Int? {
        nearestLookup(latitude: latitude, longitude: longitude)?.pointID
    }

    /// Performs nearest lookup and retains the intermediate state used by nearby-point search.
    @inline(__always)
    func nearestLookup(latitude: Float, longitude: Float) -> Lookup? {
        guard latitude.isFinite, longitude.isFinite, latitude >= -90, latitude <= 90 else {
            return nil
        }
        let normalizedLongitude = SphericalPoint.normalizedLongitude(longitude)
        return withBytes { bytes in
            let query = SphericalPoint.fastLookupVector(
                latitudeDegrees: latitude,
                longitudeDegrees: normalizedLongitude
            )
            let location = SphericalCubeGeometry.location(
                for: query.point,
                resolution: resolution,
                resolutionScale: resolutionScale
            )
            guard let nearest = nearestHot(to: query, location: location, bytes: bytes) else {
                return nil
            }
            return Lookup(
                query: query,
                location: location,
                pointID: nearest.pointID,
                position: nearest.position,
                distanceSquared: nearest.distanceSquared
            )
        }
    }

    /// Returns a canonical point direction through the reverse ID-to-storage permutation.
    @inline(__always)
    func point(at pointID: Int) -> SphericalPoint {
        precondition(pointID >= 0 && pointID < pointCount, "Spherical point ID out of range")
        return withBytes { bytes in
            let position = Int(
                Artifact.readUInt32(
                    bytes,
                    at: positionsByIDOffset + pointID * 4
                )
            )
            return Artifact.point(
                position: position,
                bytes: bytes,
                pointsOffset: pointsOffset
            )
        }
    }

    /// Allocation-free production path. Float distances choose certified local winners; uncommon
    /// non-local traversal is delegated to the Double exact search.
    @inline(never)
    private func nearestHot(
        to query: SphericalLookupVector,
        location queryLocation: SphericalCubeGeometry.Location,
        bytes: borrowing RawSpan
    ) -> (pointID: Int, position: Int, distanceSquared: Float)? {
        let geometryQuery = query.point
        var bestDistanceSquared = Float.infinity
        var bestPosition = -1

        @inline(__always)
        func consider(distanceSquared: Float, position: Int) {
            if distanceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                bestPosition = position
            }
        }

        @inline(__always)
        func scanRange(_ range: Range<Int>) {
            for position in range {
                let distanceSquared = Artifact.squaredDistance(
                    position: position,
                    query: query,
                    bytes: bytes,
                    pointsOffset: pointsOffset
                )
                consider(distanceSquared: distanceSquared, position: position)
            }
        }

        @inline(__always)
        func selected() -> (pointID: Int, position: Int, distanceSquared: Float) {
            (
                Artifact.pointID(
                    position: bestPosition,
                    bytes: bytes,
                    pointsOffset: pointsOffset
                ),
                bestPosition,
                bestDistanceSquared
            )
        }

        @inline(__always)
        func selectedWithinMaximumDistance() -> (pointID: Int, position: Int, distanceSquared: Float)? {
            bestDistanceSquared <= maximumDistanceSquared ? selected() : nil
        }

        @inline(__always)
        func exactFallback() -> (pointID: Int, position: Int, distanceSquared: Float)? {
            guard
                let pointID = nearest(
                    to: geometryQuery,
                    maximumDistanceSquared: Double(maximumDistanceSquared),
                    seedPosition: bestPosition >= 0 ? bestPosition : nil,
                    bytes: bytes
                )
            else { return nil }
            let position = Int(
                Artifact.readUInt32(
                    bytes,
                    at: positionsByIDOffset + pointID * 4
                ))
            return (
                pointID,
                position,
                Artifact.squaredDistance(
                    position: position,
                    query: query,
                    bytes: bytes,
                    pointsOffset: pointsOffset
                )
            )
        }

        /// The complete-face layout is known analytically and avoids loading face-section fields in
        /// the global hot path. Partial datasets use their occupied face rectangles.
        @inline(__always)
        func bucket(x: Int, y: Int) -> Int? {
            if coversWholeSphere {
                let tileShift = Artifact.tileShift
                let tileSize = Artifact.tileSize
                let tileX = x >> tileShift
                let tileY = y >> tileShift
                return queryLocation.face * resolution * resolution
                    + tileY * tileSize * resolution
                    + tileX * tileSize * tileSize
                    + (y & (tileSize - 1)) * tileSize
                    + (x & (tileSize - 1))
            }
            return faceSections[queryLocation.face].bucket(
                x: x,
                y: y
            )
        }

        @inline(__always)
        func scanBucket(x: Int, y: Int) {
            guard let bucket = bucket(x: x, y: y) else { return }
            let begin = directoryPosition(bucket, bytes: bytes)
            let end = directoryPosition(bucket + 1, bytes: bytes)
            scanRange(begin..<end)
        }

        @inline(__always)
        func scanBucketInterval(firstBucket: Int, lastBucket: Int) {
            let begin = directoryPosition(firstBucket, bytes: bytes)
            let end = directoryPosition(lastBucket + 1, bytes: bytes)
            scanRange(begin..<end)
        }

        /// Scans a logical row in contiguous tiled segments, minimizing directory decodes.
        @inline(__always)
        func scanBucketRow(y: Int, xRange: ClosedRange<Int>) {
            let lowerX: Int
            let upperX: Int
            let section = faceSections[queryLocation.face]
            if coversWholeSphere {
                lowerX = xRange.lowerBound
                upperX = xRange.upperBound
            } else {
                guard y >= section.minimumY, y < section.minimumY + section.rows else { return }
                lowerX = max(xRange.lowerBound, section.minimumX)
                upperX = min(xRange.upperBound, section.minimumX + section.columns - 1)
                guard lowerX <= upperX else { return }
            }
            let tileShift = Artifact.tileShift
            var segmentLowerX = lowerX
            while segmentLowerX <= upperX {
                let localX = segmentLowerX - section.minimumX
                let tileUpperX =
                    section.minimumX
                    + (((localX >> tileShift) + 1) << tileShift) - 1
                let segmentUpperX = min(upperX, tileUpperX)
                let firstBucket = bucket(x: segmentLowerX, y: y)!
                scanBucketInterval(
                    firstBucket: firstBucket,
                    lastBucket: firstBucket + segmentUpperX - segmentLowerX
                )
                segmentLowerX = segmentUpperX + 1
            }
        }

        @inline(__always)
        func certified(
            xRange: ClosedRange<Int>,
            yRange: ClosedRange<Int>
        ) -> Bool {
            guard bestPosition >= 0 else { return false }
            let maximumCandidateDistance =
                sqrt(Double(max(0, bestDistanceSquared))) + Self.floatChordError
            return regionIsCertified(
                location: queryLocation,
                xRange: xRange,
                yRange: yRange,
                maximumCandidateDistanceSquared:
                    maximumCandidateDistance * maximumCandidateDistance
            )
        }

        scanBucket(x: queryLocation.x, y: queryLocation.y)
        let leafXRange = queryLocation.x...queryLocation.x
        let leafYRange = queryLocation.y...queryLocation.y
        if certified(xRange: leafXRange, yRange: leafYRange) {
            return selectedWithinMaximumDistance()
        }

        let xRange = max(0, queryLocation.x - 1)...min(resolution - 1, queryLocation.x + 1)
        let yRange = max(0, queryLocation.y - 1)...min(resolution - 1, queryLocation.y + 1)
        bestDistanceSquared = .infinity
        bestPosition = -1
        for y in yRange {
            scanBucketRow(y: y, xRange: xRange)
        }
        if certified(xRange: xRange, yRange: yRange) {
            return selectedWithinMaximumDistance()
        }
        return exactFallback()
    }

    @inline(__always)
    func directoryPosition(
        _ bucket: Int,
        bytes: borrowing RawSpan
    ) -> Int {
        Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            basesOffset: directoryBasesOffset,
            localsOffset: directoryLocalsOffset
        )
    }

    /// Certifies a direct bucket result without assuming anything about point adjacency. Leaving a
    /// cube-face rectangle requires crossing one of its four great-circle boundary planes. The
    /// distance to the complete great circle can only underestimate the distance to the finite
    /// boundary arc, making this a conservative exact stopping condition even at cube seams.
    @inline(__always)
    func regionIsCertified(
        location: SphericalCubeGeometry.Location,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        maximumCandidateDistanceSquared: Double
    ) -> Bool {
        @inline(__always)
        func boundarySineSquared(
            coordinate: Double,
            boundaryIndex: Int
        ) -> Double {
            let boundary = boundaries[boundaryIndex]
            let delta = coordinate - boundary.value
            return min(
                1,
                location.normalizedNormalComponentSquared * delta * delta
                    * boundary.inverseNormSquared
            )
        }

        let boundarySineSquared = min(
            boundarySineSquared(coordinate: location.u, boundaryIndex: xRange.lowerBound),
            boundarySineSquared(coordinate: location.u, boundaryIndex: xRange.upperBound + 1),
            boundarySineSquared(coordinate: location.v, boundaryIndex: yRange.lowerBound),
            boundarySineSquared(coordinate: location.v, boundaryIndex: yRange.upperBound + 1)
        )
        let candidateSineSquared =
            maximumCandidateDistanceSquared
            * max(0, 1 - maximumCandidateDistanceSquared * 0.25)
        return candidateSineSquared + 64 * Double.ulpOfOne < boundarySineSquared
    }

    @inline(__always)
    func withBytes<R>(
        _ body: (borrowing RawSpan) throws -> R
    ) rethrows
        -> R
    {
        try body(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data)))
    }

}
