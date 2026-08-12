import Foundation
import OmFileFormat

extension SphericalCubeIndex {
    private struct DistanceCandidate: Sendable {
        var pointID: Int
        var distanceSquared: Float

        static let empty = Self(pointID: -1, distanceSquared: .infinity)
    }

    /// Fixed-capacity candidates for terrain and sea selection.
    ///
    /// Entry zero is always the result of the main nearest-point lookup. Remaining entries are
    /// distance-ordered local candidates; unlike nearest lookup, they are not promised to be the
    /// globally exact k-nearest points because the search may stop after collecting a sufficiently
    /// useful local set.
    struct NearbyPoints: Sendable {
        var pointIDs = InlineArray<10, Int>(repeating: -1)
        var distancesSquared = InlineArray<10, Float>(repeating: .infinity)
        var count = 0
    }

    private static let nearbyPointLimit = 10

    /// Returns the exact nearest point followed by close candidates found in nearby buckets.
    func nearestCandidates(
        latitude: Float,
        longitude: Float
    ) -> (pointIDs: InlineArray<10, Int>, count: Int)? {
        guard let lookup = nearestLookup(latitude: latitude, longitude: longitude) else {
            return nil
        }
        let candidates = nearestCandidates(from: lookup)
        return (candidates.pointIDs, candidates.count)
    }

    /// Reuses a completed nearest lookup, avoiding duplicate coordinate conversion and search.
    func nearestCandidates(from lookup: Lookup) -> NearbyPoints {
        withBytes {
            nearestCandidates(
                from: lookup,
                bytes: $0
            )
        }
    }

    @inline(never)
    private func nearestCandidates(
        from lookup: Lookup,
        bytes: borrowing RawSpan
    ) -> NearbyPoints {
        let query = lookup.query
        let queryLocation = lookup.location
        var candidates = InlineArray<10, DistanceCandidate>(repeating: .empty)
        var candidateCount = 0
        var scannedPointCount = 0

        @inline(__always)
        func precedes(_ lhs: DistanceCandidate, _ rhs: DistanceCandidate) -> Bool {
            if lhs.distanceSquared < rhs.distanceSquared { return true }
            if rhs.distanceSquared < lhs.distanceSquared { return false }
            return lhs.pointID < rhs.pointID
        }

        @inline(__always)
        func consider(position: Int, distanceSquared: Float) {
            if position == lookup.position { return }
            let last = Self.nearbyPointLimit - 2
            if candidateCount == Self.nearbyPointLimit - 1,
                distanceSquared > candidates[last].distanceSquared
            {
                return
            }
            let candidate = DistanceCandidate(
                pointID: Artifact.pointID(
                    position: position,
                    bytes: bytes,
                    pointsOffset: pointsOffset
                ),
                distanceSquared: distanceSquared
            )
            if candidateCount == Self.nearbyPointLimit - 1,
                !precedes(candidate, candidates[last])
            {
                return
            }
            var destination = min(candidateCount, last)
            if candidateCount < Self.nearbyPointLimit - 1 { candidateCount += 1 }
            while destination > 0, precedes(candidate, candidates[destination - 1]) {
                candidates[destination] = candidates[destination - 1]
                destination -= 1
            }
            candidates[destination] = candidate
        }

        @inline(__always)
        func scanRange(_ begin: Int, _ end: Int) {
            scannedPointCount += end - begin
            for position in begin..<end {
                consider(
                    position: position,
                    distanceSquared: Artifact.squaredDistance(
                        position: position,
                        query: query,
                        bytes: bytes,
                        pointsOffset: pointsOffset
                    )
                )
            }
        }

        @inline(__always)
        func scanBucket(_ bucket: Int) {
            scanRange(
                directoryPosition(bucket, bytes: bytes),
                directoryPosition(bucket + 1, bytes: bytes)
            )
        }

        @inline(__always)
        func scanRow(face: Int, y: Int, lowerX requestedLowerX: Int, upperX requestedUpperX: Int) {
            let section = faceSections[face]
            guard y >= section.minimumY, y < section.minimumY + section.rows else { return }
            let lowerX = max(requestedLowerX, section.minimumX)
            let upperX = min(requestedUpperX, section.minimumX + section.columns - 1)
            guard lowerX <= upperX else { return }
            let tileShift = Artifact.tileShift
            var segmentLowerX = lowerX
            while segmentLowerX <= upperX {
                let localX = segmentLowerX - section.minimumX
                let tileUpperX =
                    section.minimumX
                    + (((localX >> tileShift) + 1) << tileShift) - 1
                let segmentUpperX = min(upperX, tileUpperX)
                let first = section.bucket(
                    x: segmentLowerX,
                    y: y
                )!
                scanRange(
                    directoryPosition(first, bytes: bytes),
                    directoryPosition(
                        first + segmentUpperX - segmentLowerX + 1,
                        bytes: bytes
                    )
                )
                segmentLowerX = segmentUpperX + 1
            }
        }

        @inline(__always)
        func searchIsComplete(
            xRange: ClosedRange<Int>,
            yRange: ClosedRange<Int>,
            canCertify: Bool
        ) -> Bool {
            guard candidateCount == Self.nearbyPointLimit - 1 else { return false }
            if canCertify {
                let farthestDistance =
                    sqrt(Double(max(0, candidates[candidateCount - 1].distanceSquared)))
                    + Self.floatChordError
                if regionIsCertified(
                    location: queryLocation,
                    xRange: xRange,
                    yRange: yRange,
                    maximumCandidateDistanceSquared: farthestDistance * farthestDistance
                ) {
                    return true
                }
            }
            return scannedPointCount >= Self.nearbyPointLimit * 4
        }

        // Away from seams, expand square rings directly in the query face. Certification can stop
        // as soon as the retained candidates are provably closer than every unscanned bucket.
        let maximumRadius = 8
        let staysOnFace =
            queryLocation.x >= maximumRadius
            && queryLocation.x < resolution - maximumRadius
            && queryLocation.y >= maximumRadius
            && queryLocation.y < resolution - maximumRadius
        scanRow(
            face: queryLocation.face,
            y: queryLocation.y,
            lowerX: queryLocation.x,
            upperX: queryLocation.x
        )
        if staysOnFace {
            var radius = 0
            while radius < maximumRadius,
                !searchIsComplete(
                    xRange: (queryLocation.x - radius)...(queryLocation.x + radius),
                    yRange: (queryLocation.y - radius)...(queryLocation.y + radius),
                    canCertify: true
                )
            {
                radius += 1
                let lowerX = queryLocation.x - radius
                let upperX = queryLocation.x + radius
                scanRow(
                    face: queryLocation.face,
                    y: queryLocation.y - radius,
                    lowerX: lowerX,
                    upperX: upperX
                )
                scanRow(
                    face: queryLocation.face,
                    y: queryLocation.y + radius,
                    lowerX: lowerX,
                    upperX: upperX
                )
                for y in (queryLocation.y - radius + 1)..<(queryLocation.y + radius) {
                    scanRow(
                        face: queryLocation.face,
                        y: y,
                        lowerX: lowerX,
                        upperX: lowerX
                    )
                    scanRow(
                        face: queryLocation.face,
                        y: y,
                        lowerX: upperX,
                        upperX: upperX
                    )
                }
            }
        } else {
            // Near an edge or corner, bucket offsets may cross onto another cube face. Convert each
            // offset through a spherical direction, project it to its actual face, and deduplicate
            // buckets where several offsets map to the same destination.
            var scannedBuckets = InlineArray<289, Int>(repeating: -1)
            var scannedBucketCount = 0
            let scale = 2 / Double(resolution)

            @inline(__always)
            func scanOffset(dx: Int, dy: Int) {
                let point = SphericalCubeGeometry.faceVector(
                    face: queryLocation.face,
                    u: -1 + (Double(queryLocation.x + dx) + 0.5) * scale,
                    v: -1 + (Double(queryLocation.y + dy) + 0.5) * scale
                )
                let location = SphericalCubeGeometry.location(
                    for: point,
                    resolution: resolution,
                    resolutionScale: resolutionScale
                )
                guard
                    let bucket = faceSections[location.face].bucket(
                        x: location.x,
                        y: location.y
                    )
                else { return }
                for position in 0..<scannedBucketCount where scannedBuckets[position] == bucket {
                    return
                }
                precondition(scannedBucketCount < 289, "spherical nearby-bucket bound exceeded")
                scannedBuckets[scannedBucketCount] = bucket
                scannedBucketCount += 1
                scanBucket(bucket)
            }

            for radius in 1...maximumRadius {
                for dx in -radius...radius {
                    scanOffset(dx: dx, dy: -radius)
                    scanOffset(dx: dx, dy: radius)
                }
                for dy in (-radius + 1)..<radius {
                    scanOffset(dx: -radius, dy: dy)
                    scanOffset(dx: radius, dy: dy)
                }
                if searchIsComplete(
                    xRange: max(0, queryLocation.x - radius)...min(resolution - 1, queryLocation.x + radius),
                    yRange: max(0, queryLocation.y - radius)...min(resolution - 1, queryLocation.y + radius),
                    canCertify: false
                ) {
                    break
                }
            }
        }

        var result = NearbyPoints()
        result.pointIDs[0] = lookup.pointID
        result.distancesSquared[0] = lookup.distanceSquared
        result.count = 1
        for position in 0..<candidateCount {
            let destination = position + 1
            result.pointIDs[destination] = candidates[position].pointID
            result.distancesSquared[destination] = candidates[position].distanceSquared
            result.count += 1
        }
        return result
    }

}
