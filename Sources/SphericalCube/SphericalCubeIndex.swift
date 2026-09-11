import Foundation
import OmFileFormat

/// Memory-mapped nearest-point search over uniform cube buckets on the unit sphere.
///
/// The index is independent of ICON and accepts any set of canonical point directions. Its only
/// stored spatial structure is a leaf-bucket prefix directory; cube-face adjacency is derived from
/// `(face, level, x, y)` when the distance-bounded fallback crosses a seam.
///
/// A normal lookup starts locally and expands only when necessary:
///
/// 1. compare the query bucket's Float32 point records;
/// 2. stop if the query bucket certifies the result;
/// 3. scan and certify the surrounding 3×3 neighborhood if it fits inside the face;
/// 4. otherwise scan distance-bounded rectangles directly on each intersecting cube face.
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
/// if the 3×3 neighborhood fits inside the face, scan its ring and try certification
///         +-- certified --> apply limit --> ID / nil
///         |
///         v
/// scan intersecting face rectangles --> apply limit --> canonical ID / nil
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
    /// For a point on a cube face, its normal component is at least 1/sqrt(3).
    /// At chord distance d, the query's normal is at least 1/sqrt(3)-d. Since
    /// |u(point)-u(query)| <= sqrt(2)*d/queryNormal, this bounds both bucket axes,
    /// including queries on another face. Inflate d for Float32 coordinate/distance rounding.
    package func requiredSearchRadius(maximumChordDistanceSquared: Float) -> Int {
        let distance = sqrt(Double(maximumChordDistanceSquared)) + Self.floatChordError
        let minimumNormal = 1 / sqrt(3.0) - distance
        guard minimumNormal > 0 else { return resolution }
        return Int(ceil(min(Double(resolution), sqrt(2.0) * distance / minimumNormal * resolutionScale)))
    }

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

        var searchedRadius = 0
        if queryLocation.x > 0, queryLocation.x < resolution - 1,
            queryLocation.y > 0, queryLocation.y < resolution - 1 {
            let xRange = (queryLocation.x - 1)...(queryLocation.x + 1)
            let yRange = (queryLocation.y - 1)...(queryLocation.y + 1)
            for y in [yRange.lowerBound, yRange.upperBound] {
                forEachRowPointRange(face: queryLocation.face, y: y, xRange: xRange, bytes: bytes) {
                    scanRange($0, best: &best)
                }
            }
            for x in [xRange.lowerBound, xRange.upperBound] {
                if let bucket = bucket(face: queryLocation.face, x: x, y: queryLocation.y) {
                    scanRange(pointRange(in: bucket, bytes: bytes), best: &best)
                }
            }
            if certified(xRange: xRange, yRange: yRange) {
                return selectedWithinMaximumDistance()
            }
            searchedRadius = 1
        }

        let limit = min(maximumChordDistanceSquared, best.distanceSquared)
        forEachSearchRange(around: query.point, location: queryLocation, searchedRadius: searchedRadius,
            maximumChordDistanceSquared: limit, bytes: bytes, state: &best, scanRange)
        guard best.position >= 0 else { return nil }
        return selectedWithinMaximumDistance()
    }

    /// Scan each destination face directly: projected source-bucket centres alone can miss
    /// destination buckets. Skip the already searched square on the query face; other faces
    /// have disjoint storage and need no deduplication. Explicit inout state avoids heap boxes.
    func forEachSearchRange<State>(
        around point: SphericalPoint,
        location: SphericalCubeGeometry.Location,
        searchedRadius: Int,
        maximumChordDistanceSquared: Float,
        bytes: borrowing RawSpan,
        state: inout State,
        _ body: (Range<Int>, inout State) -> Void
    ) {
        let inverseLength = 1 / sqrt(point.dot(point))
        let x = point.x * inverseLength
        let y = point.y * inverseLength
        let z = point.z * inverseLength
        let distance = sqrt(Double(maximumChordDistanceSquared)) + Self.floatChordError
        let radius = requiredSearchRadius(maximumChordDistanceSquared: maximumChordDistanceSquared)
        for face in 0..<6 {
            let normal: Double
            let u: Double
            let v: Double
            switch face {
            case 0: (normal, u, v) = (x, y, z)
            case 1: (normal, u, v) = (-x, -y, z)
            case 2: (normal, u, v) = (y, -x, z)
            case 3: (normal, u, v) = (-y, x, z)
            case 4: (normal, u, v) = (z, y, -x)
            default: (normal, u, v) = (-z, y, x)
            }
            guard normal + distance >= 1 / sqrt(3.0) else { continue }
            let section = faceSections[face]
            guard section.columns > 0, section.rows > 0 else { continue }
            var lowerX = section.minimumX
            var upperX = lowerX + section.columns - 1
            var lowerY = section.minimumY
            var upperY = lowerY + section.rows - 1
            if radius < resolution {
                let centerX = face == location.face ? location.x : Int(floor((u / normal + 1) * resolutionScale))
                let centerY = face == location.face ? location.y : Int(floor((v / normal + 1) * resolutionScale))
                lowerX = max(lowerX, centerX - radius)
                upperX = min(upperX, centerX + radius)
                lowerY = max(lowerY, centerY - radius)
                upperY = min(upperY, centerY + radius)
            }
            guard lowerX <= upperX, lowerY <= upperY else { continue }
            for row in lowerY...upperY {
                if face == location.face, searchedRadius >= 0,
                    abs(row - location.y) <= searchedRadius {
                    let leftEnd = min(upperX, location.x - searchedRadius - 1)
                    if lowerX <= leftEnd {
                        forEachRowPointRange(face: face, y: row, xRange: lowerX...leftEnd, bytes: bytes) {
                            body($0, &state)
                        }
                    }
                    let rightStart = max(lowerX, location.x + searchedRadius + 1)
                    if rightStart <= upperX {
                        forEachRowPointRange(face: face, y: row, xRange: rightStart...upperX, bytes: bytes) {
                            body($0, &state)
                        }
                    }
                } else {
                    forEachRowPointRange(face: face, y: row, xRange: lowerX...upperX, bytes: bytes) {
                        body($0, &state)
                    }
                }
            }
        }
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

    @inline(__always)
    func withBytes<R>(
        _ body: (borrowing RawSpan) throws -> R
    ) rethrows
        -> R
    {
        try body(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data)))
    }

}
