import Foundation
import OmFileFormat

/// Memory-mapped nearest-point search over uniform cube buckets on the unit sphere.
///
/// The index is independent of ICON and accepts any set of canonical point directions. Its only
/// stored spatial structure is a leaf-bucket prefix directory; cube-face adjacency is derived from
/// `(face, level, x, y)` when the bounded fallback crosses a seam.
///
/// A normal lookup starts locally and expands only when necessary:
///
/// 1. compare the query bucket's Float32 point records;
/// 2. scan new rings, projecting offsets only when they cross a cube face;
/// 3. stop after a certified 3×3 region, or finish the bounded stencil without rescanning.
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
/// scan the surrounding ring, including adjacent faces at seams
///         |
/// can that region be certified?
///         +-- yes --> apply limit --> ID / nil
///         |
///         no
///         |
///         v
/// continue through remaining rings --> apply limit --> canonical ID / nil
/// ```
package final class SphericalCubeIndex: Sendable {
    typealias Artifact = SphericalCubeArtifact
    typealias FaceSection = Artifact.FaceSection

    /// Reusable result of nearest lookup. Nearby-point selection retains the query projection so it
    /// does not repeat trigonometry or cube projection.
    package struct Lookup: Sendable {
        let query: SphericalLookupVector
        let location: SphericalCubeGeometry.Location
        package let pointID: Int
        let position: Int
        let distanceSquared: Float
    }

    private struct Boundary: Sendable {
        let value: Double
        let inverseNormSquared: Double
    }

    static let floatChordError = 8 * Double(Float.ulpOfOne)
    private static let maximumFallbackRadius = 8

    private let mapped: MmapFile
    let faceSections: [FaceSection]
    private let directoryBasesOffset: Int
    private let directoryLocalsOffset: Int
    let pointsOffset: Int
    private let positionsByIDOffset: Int
    let resolutionScale: Double
    private let boundaries: [Boundary]
    package let coversWholeSphere: Bool

    package let pointCount: Int
    package let level: Int
    package let resolution: Int
    package let identity: SphericalCubeArtifact.DatasetIdentity

    /// Opens and validates the artifact, then precomputes leaf-boundary terms used by certification.
    package convenience init(file: URL) throws {
        let handle = try FileHandle.openFileReading(file: file.path)
        try self.init(mapped: MmapFile(fn: handle))
    }

    /// Validates an existing mapping and precomputes search geometry.
    package init(mapped: MmapFile) throws {
        let artifact = try Artifact.open(mapped: mapped)
        self.mapped = artifact.mapped
        faceSections = artifact.faceSections
        directoryBasesOffset = artifact.directoryBasesOffset
        directoryLocalsOffset = artifact.directoryLocalsOffset
        pointsOffset = artifact.pointsOffset
        positionsByIDOffset = artifact.positionsByIDOffset
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

    /// Returns the closest stored Float32 direction found by the bounded cube-bucket search, or
    /// `nil` for invalid input or when the selected point exceeds the configured distance limit.
    @inline(__always)
    package func nearestPointID(latitude: Float, longitude: Float, maximumChordDistanceSquared: Float) -> Int? {
        nearestLookup(latitude: latitude, longitude: longitude, maximumChordDistanceSquared: maximumChordDistanceSquared)?.pointID
    }

    /// Performs nearest lookup and retains the intermediate state used by nearby-point search.
    @inline(__always)
    package func nearestLookup(latitude: Float, longitude: Float, maximumChordDistanceSquared: Float) -> Lookup? {
        assert(maximumChordDistanceSquared.isFinite && maximumChordDistanceSquared > 0 && maximumChordDistanceSquared <= 4)
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
            guard let nearest = nearestHot(to: query, location: location, maximumChordDistanceSquared: maximumChordDistanceSquared, bytes: bytes) else {
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
    package func point(at pointID: Int) -> SphericalPoint {
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
    /// cube-seam cases scan a bounded cross-face stencil using the same Float32 metric.
    @inline(never)
    private func nearestHot(
        to query: SphericalLookupVector,
        location queryLocation: SphericalCubeGeometry.Location,
        maximumChordDistanceSquared: Float,
        bytes: borrowing RawSpan
    ) -> (pointID: Int, position: Int, distanceSquared: Float)? {
        typealias Match = (pointID: Int, position: Int, distanceSquared: Float)
        var best: Match = (-1, -1, .infinity)

        @inline(__always)
        func scanRange(_ range: Range<Int>, best: inout Match) {
            for position in range {
                let distanceSquared = Artifact.squaredDistance(
                    position: position,
                    query: query,
                    bytes: bytes,
                    pointsOffset: pointsOffset
                )
                if distanceSquared < best.distanceSquared {
                    best = (Artifact.pointID(position: position, bytes: bytes, pointsOffset: pointsOffset),
                            position, distanceSquared)
                } else if distanceSquared == best.distanceSquared {
                    let pointID = Artifact.pointID(position: position, bytes: bytes, pointsOffset: pointsOffset)
                    if best.pointID < 0 || pointID < best.pointID {
                        best.pointID = pointID
                        best.position = position
                    }
                }
            }
        }

        @inline(__always)
        func selectedWithinMaximumDistance() -> (pointID: Int, position: Int, distanceSquared: Float)? {
            best.distanceSquared <= maximumChordDistanceSquared ? best : nil
        }

        @inline(__always)
        func certified(
            xRange: ClosedRange<Int>,
            yRange: ClosedRange<Int>
        ) -> Bool {
            guard best.position >= 0 else { return false }
            let maximumCandidateDistance =
                sqrt(Double(max(0, best.distanceSquared))) + Self.floatChordError
            return regionIsCertified(
                location: queryLocation,
                xRange: xRange,
                yRange: yRange,
                maximumCandidateDistanceSquared:
                    maximumCandidateDistance * maximumCandidateDistance
            )
        }

        if let bucket = bucket(face: queryLocation.face, x: queryLocation.x, y: queryLocation.y) {
            scanRange(pointRange(in: bucket, bytes: bytes), best: &best)
        }
        let leafXRange = queryLocation.x...queryLocation.x
        let leafYRange = queryLocation.y...queryLocation.y
        if certified(xRange: leafXRange, yRange: leafYRange) {
            return selectedWithinMaximumDistance()
        }

        // Cube projection expands angular distances near face corners. Keep the existing bounded
        // stencil, computing its radius only when the initial bucket cannot certify the result.
        let fallbackRadius = min(Self.maximumFallbackRadius,
            max(2, Int(ceil(sqrt(Double(maximumChordDistanceSquared)) * resolutionScale * 3)) + 2))
        var visited: VisitedBuckets?
        for radius in 1...fallbackRadius {
            forEachNeighborhoodRing(around: queryLocation, radius: radius, visited: &visited,
                bytes: bytes, state: &best, scanRange)
            // Keep the original stopping rule. A larger cross-face region is not certified
            // by these four same-face boundary planes, so finish the existing bounded stencil.
            if radius == 1, certified(
                xRange: max(0, queryLocation.x - 1)...min(resolution - 1, queryLocation.x + 1),
                yRange: max(0, queryLocation.y - 1)...min(resolution - 1, queryLocation.y + 1)
            ) {
                return selectedWithinMaximumDistance()
            }
        }
        guard best.position >= 0 else { return nil }
        return selectedWithinMaximumDistance()
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
    /// boundary arc, making this a conservative stopping condition even at cube seams.
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

    /// Projects a logical offset around a query bucket through the sphere, allowing a bounded
    /// stencil to cross cube-face edges without storing an adjacency table.
    @inline(__always)
    func projectedBucket(
        around location: SphericalCubeGeometry.Location,
        dx: Int,
        dy: Int
    ) -> Int? {
        let scale = 2 / Double(resolution)
        let point = SphericalCubeGeometry.faceVector(
            face: location.face,
            u: -1 + (Double(location.x + dx) + 0.5) * scale,
            v: -1 + (Double(location.y + dy) + 0.5) * scale
        )
        let projected = SphericalCubeGeometry.location(
            for: point,
            resolution: resolution,
            resolutionScale: resolutionScale
        )
        return faceSections[projected.face].bucket(x: projected.x, y: projected.y)
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
