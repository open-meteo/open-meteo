import Foundation
import OmFileFormat

extension IconNativeGrid.CubeIndex {
    private struct DistanceCandidate: Sendable {
        var cell: Int
        var distanceSquared: Float

        static let empty = Self(cell: -1, distanceSquared: .infinity)
    }

    struct NearbyCells: Sendable {
        var points = InlineArray<16, Int>(repeating: -1)
        var distancesSquared = InlineArray<16, Float>(repeating: .infinity)
        var count = 0
    }

    private static let terrainCandidateLimit = 10

    /// Returns the exact nearest cell followed by the closest candidates found in nearby buckets.
    func findNearestCells(
        latitude: Float,
        longitude: Float
    ) -> (points: InlineArray<16, Int>, count: Int)? {
        guard let lookup = findNearestLookup(latitude: latitude, longitude: longitude) else {
            return nil
        }
        let candidates = findNearestCells(from: lookup)
        return (candidates.points, candidates.count)
    }

    func findNearestCells(from lookup: Lookup) -> NearbyCells {
        findNearestCells(
            from: lookup,
            scanLimit: Self.terrainCandidateLimit * 4,
            certifyTopCandidates: true
        )
    }

    func findNearestCells(
        from lookup: Lookup,
        scanLimit: Int,
        certifyTopCandidates: Bool
    ) -> NearbyCells {
        withBytes {
            nearestCells(
                from: lookup,
                scanLimit: scanLimit,
                certifyTopCandidates: certifyTopCandidates,
                bytes: $0
            )
        }
    }

    @inline(never)
    private func nearestCells(
        from lookup: Lookup,
        scanLimit: Int,
        certifyTopCandidates: Bool,
        bytes: borrowing RawSpan
    ) -> NearbyCells {
        precondition(scanLimit >= Self.terrainCandidateLimit)
        let query = lookup.query
        let queryLocation = lookup.location
        var candidates = InlineArray<16, DistanceCandidate>(repeating: .empty)
        var candidateCount = 0
        var scannedCenterCount = 0

        @inline(__always)
        func precedes(_ lhs: DistanceCandidate, _ rhs: DistanceCandidate) -> Bool {
            if lhs.distanceSquared < rhs.distanceSquared { return true }
            if rhs.distanceSquared < lhs.distanceSquared { return false }
            return lhs.cell < rhs.cell
        }

        @inline(__always)
        func consider(position: Int, distanceSquared: Float) {
            if position == lookup.position { return }
            let last = Self.terrainCandidateLimit - 2
            if candidateCount == Self.terrainCandidateLimit - 1,
                distanceSquared > candidates[last].distanceSquared { return }
            let candidate = DistanceCandidate(
                cell: Artifact.cell(
                    position: position,
                    bytes: bytes,
                    centersOffset: centersOffset
                ),
                distanceSquared: distanceSquared
            )
            if candidateCount == Self.terrainCandidateLimit - 1,
                !precedes(candidate, candidates[last]) { return }
            var destination = min(candidateCount, last)
            if candidateCount < Self.terrainCandidateLimit - 1 { candidateCount += 1 }
            while destination > 0, precedes(candidate, candidates[destination - 1]) {
                candidates[destination] = candidates[destination - 1]
                destination -= 1
            }
            candidates[destination] = candidate
        }

        @inline(__always)
        func scanRange(_ begin: Int, _ end: Int) {
            scannedCenterCount += end - begin
            for position in begin..<end {
                consider(
                    position: position,
                    distanceSquared: Artifact.squaredDistance(
                        position: position,
                        query: query,
                        bytes: bytes,
                        centersOffset: centersOffset
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
                let tileUpperX = section.minimumX
                    + (((localX >> tileShift) + 1) << tileShift) - 1
                let segmentUpperX = min(upperX, tileUpperX)
                let first = section.bucket(
                    x: segmentLowerX,
                    y: y
                )!
                scanRange(
                    directoryPosition(first, bytes: bytes),
                    directoryPosition(first + segmentUpperX - segmentLowerX + 1, bytes: bytes)
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
            guard candidateCount == Self.terrainCandidateLimit - 1 else { return false }
            if certifyTopCandidates, canCertify {
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
            return scannedCenterCount >= scanLimit
        }

        let maximumRadius = 8
        let staysOnFace = queryLocation.x >= maximumRadius
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
                ) {
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
            var scannedBuckets = InlineArray<289, Int>(repeating: -1)
            var scannedBucketCount = 0
            let scale = 2 / Double(resolution)

            @inline(__always)
            func scanOffset(dx: Int, dy: Int) {
                let point = IconNativeGrid.CubeGeometry.faceVector(
                    face: queryLocation.face,
                    u: -1 + (Double(queryLocation.x + dx) + 0.5) * scale,
                    v: -1 + (Double(queryLocation.y + dy) + 0.5) * scale
                )
                let location = IconNativeGrid.CubeGeometry.location(
                    for: point,
                    resolution: resolution,
                    resolutionScale: resolutionScale
                )
                guard let bucket = faceSections[location.face].bucket(
                    x: location.x,
                    y: location.y
                ) else { return }
                for position in 0..<scannedBucketCount where scannedBuckets[position] == bucket {
                    return
                }
                precondition(scannedBucketCount < 289, "ICON nearby-bucket bound exceeded")
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
                ) { break }
            }
        }

        var result = NearbyCells()
        result.points[0] = lookup.cell
        result.distancesSquared[0] = lookup.distanceSquared
        result.count = 1
        for position in 0..<candidateCount {
            let destination = position + 1
            result.points[destination] = candidates[position].cell
            result.distancesSquared[destination] = candidates[position].distanceSquared
            result.count += 1
        }
        return result
    }

}
