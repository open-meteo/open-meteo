import Foundation

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
    package struct NearbyPoints: Sendable {
        package var pointIDs = InlineArray<10, Int>(repeating: -1)
        package var distancesSquared = InlineArray<10, Float>(repeating: .infinity)
        package var count = 0
    }

    private static let nearbyPointLimit = 10

    /// Reuses a completed nearest lookup, avoiding duplicate coordinate conversion and search.
    package func nearestCandidates(from lookup: Lookup) -> NearbyPoints {
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
        func scanRow(face: Int, y: Int, lowerX: Int, upperX: Int) {
            forEachRowPointRange(face: face, y: y, xRange: lowerX...upperX, bytes: bytes) { range in
                scanRange(range.lowerBound, range.upperBound)
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

        // Expand directly on the query face for every ring that fits. Only rings that actually
        // cross a cube edge need the more expensive spherical projection and bucket deduplication.
        // Certification can stop as soon as the retained candidates are provably closer than every
        // unscanned bucket in the current face rectangle.
        let maximumRadius = 8
        let maximumDirectRadius = min(
            maximumRadius,
            queryLocation.x,
            resolution - queryLocation.x - 1,
            queryLocation.y,
            resolution - queryLocation.y - 1
        )
        scanRow(
            face: queryLocation.face,
            y: queryLocation.y,
            lowerX: queryLocation.x,
            upperX: queryLocation.x
        )
        var searchComplete = searchIsComplete(
            xRange: queryLocation.x...queryLocation.x,
            yRange: queryLocation.y...queryLocation.y,
            canCertify: true
        )
        if !searchComplete, maximumDirectRadius > 0 {
            for radius in 1...maximumDirectRadius {
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
                searchComplete = searchIsComplete(
                    xRange: (queryLocation.x - radius)...(queryLocation.x + radius),
                    yRange: (queryLocation.y - radius)...(queryLocation.y + radius),
                    canCertify: true
                )
                if searchComplete { break }
            }
        }
        if !searchComplete, maximumDirectRadius < maximumRadius {
            // The next ring crosses an edge or corner. Convert its offsets through a spherical
            // direction, project them to their actual faces, and deduplicate buckets where several
            // offsets map to the same destination. Earlier direct rings cannot overlap these
            // adjacent-face buckets.
            var visited = VisitedBuckets()
            for radius in (maximumDirectRadius + 1)...maximumRadius {
                forEachProjectedRing(around: queryLocation, radius: radius, visited: &visited) { bucket in
                    let range = pointRange(in: bucket, bytes: bytes)
                    scanRange(range.lowerBound, range.upperBound)
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
