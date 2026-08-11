import Foundation
import OmFileFormat

extension IconNativeGrid.CubeIndex {
    private struct ScoreCandidate: Sendable {
        var cell: Int
        var score: Double

        static let empty = Self(cell: -1, score: -.infinity)
    }

    /// Used by artifact validation to avoid losing information by converting an official centre
    /// through Float latitude/longitude before checking its canonical round trip.
    @inline(__always)
    func findNearestCell(to center: IconNativeCenter) -> Int {
        withBytes { nearest(to: center, bytes: $0) }
    }

    @inline(never)
    func nearest(
        to unnormalizedQuery: IconNativeCenter,
        bytes: borrowing RawSpan
    ) -> Int {
        let queryNormSquared = unnormalizedQuery.dot(unnormalizedQuery)
        let inverseQueryNorm = 1 / sqrt(queryNormSquared)
        let query = IconNativeCenter(
            x: unnormalizedQuery.x * inverseQueryNorm,
            y: unnormalizedQuery.y * inverseQueryNorm,
            z: unnormalizedQuery.z * inverseQueryNorm
        )
        let queryLocation = IconNativeGrid.CubeGeometry.location(
            for: query,
            resolution: resolution,
            resolutionScale: resolutionScale
        )
        var candidates = InlineArray<4, ScoreCandidate>(repeating: .empty)
        var candidateCount = 0
        var candidateOverflow = false
        var bestScore = -Double.infinity
        var maximumCandidateDistanceSquared = Double.infinity

        @inline(__always)
        func scanRange(_ range: Range<Int>) {
            for position in range {
                let candidate = scoreAndCell(at: position, query: query, bytes: bytes)
                let cell = candidate.cell
                let score = candidate.score
                if score > bestScore {
                    bestScore = score
                    maximumCandidateDistanceSquared = max(
                        0,
                        2 - 2 * (bestScore - Self.scoreTieTolerance)
                    )
                    var destination = 0
                    for position in 0..<candidateCount
                    where candidates[position].score >= bestScore - Self.scoreTieTolerance {
                        candidates[destination] = candidates[position]
                        destination += 1
                    }
                    candidateCount = destination
                }
                if score >= bestScore - Self.scoreTieTolerance {
                    if candidateCount < 4 {
                        candidates[candidateCount] = ScoreCandidate(cell: cell, score: score)
                        candidateCount += 1
                    } else {
                        candidateOverflow = true
                    }
                }
            }
        }

        @inline(__always)
        func scanBucket(x: Int, y: Int) {
            scanRange(bucketRange(face: queryLocation.face, x: x, y: y, bytes: bytes))
        }

        @inline(__always)
        func scanBucketRow(y: Int, xRange: ClosedRange<Int>) {
            let section = faceSections[queryLocation.face]
            guard y >= section.minimumY, y < section.minimumY + section.rows else { return }
            let lowerX = max(xRange.lowerBound, section.minimumX)
            let upperX = min(xRange.upperBound, section.minimumX + section.columns - 1)
            guard lowerX <= upperX else { return }
            if bucketLayout.tileShift != nil {
                for x in lowerX...upperX { scanBucket(x: x, y: y) }
                return
            }
            let firstBucket =
                section.firstBucket
                + (y - section.minimumY) * section.columns + lowerX - section.minimumX
            let lastBucket = firstBucket + upperX - lowerX
            let begin = directoryPosition(firstBucket, bytes: bytes)
            let end = directoryPosition(lastBucket + 1, bytes: bytes)
            scanRange(begin..<end)
        }

        @inline(__always)
        func selectedCell() -> Int {
            var cell = Int.max
            for position in 0..<candidateCount where candidates[position].cell < cell {
                cell = candidates[position].cell
            }
            return cell
        }

        // The leaf containing the query is an exceptionally cheap exact fast path whenever
        // the winning distance is smaller than the distance to all four leaf boundaries.
        scanBucket(x: queryLocation.x, y: queryLocation.y)
        if !candidateOverflow, candidateCount > 0,
            regionIsCertified(
                location: queryLocation,
                xRange: queryLocation.x...queryLocation.x,
                yRange: queryLocation.y...queryLocation.y,
                maximumCandidateDistanceSquared: maximumCandidateDistanceSquared
            )
        {
            return selectedCell()
        }

        // A 3x3 leaf window puts an ordinary query at least one complete bucket away from the
        // searched boundary. Only cube-seam and unusually empty-area queries need the general
        // implicit-quadtree fallback below.
        let xRange = max(0, queryLocation.x - 1)...min(resolution - 1, queryLocation.x + 1)
        let yRange = max(0, queryLocation.y - 1)...min(resolution - 1, queryLocation.y + 1)
        for y in yRange {
            if y != queryLocation.y {
                scanBucketRow(y: y, xRange: xRange)
                continue
            }
            if xRange.lowerBound < queryLocation.x {
                scanBucketRow(y: y, xRange: xRange.lowerBound...(queryLocation.x - 1))
            }
            if queryLocation.x < xRange.upperBound {
                scanBucketRow(y: y, xRange: (queryLocation.x + 1)...xRange.upperBound)
            }
        }
        if !candidateOverflow, candidateCount > 0,
            regionIsCertified(
                location: queryLocation,
                xRange: xRange,
                yRange: yRange,
                maximumCandidateDistanceSquared: maximumCandidateDistanceSquared
            )
        {
            return selectedCell()
        }

        // Retain the fast-path winner as an exact pruning seed, but rebuild the tie set while
        // traversing so a bucket scanned above cannot insert the same candidate twice.
        candidateCount = 0
        candidateOverflow = false
        var maximumCandidateDistance = sqrt(maximumCandidateDistanceSquared)
        var stack = InlineArray<64, IconNativeGrid.CubeGeometry.Node>(repeating: .empty)
        var stackCount = 0
        for face in 0..<6 where face != queryLocation.face {
            stack[stackCount] = IconNativeGrid.CubeGeometry.Node(face: face, level: 0, x: 0, y: 0)
            stackCount += 1
        }
        stack[stackCount] = IconNativeGrid.CubeGeometry.Node(
            face: queryLocation.face,
            level: 0,
            x: 0,
            y: 0
        )
        stackCount += 1

        while stackCount > 0 {
            stackCount -= 1
            let node = stack[stackCount]
            if !nodeIntersectsStoredBuckets(node) { continue }
            if bestScore != -Double.infinity,
                IconNativeGrid.CubeGeometry.nodeCannotImprove(
                    node,
                    query: query,
                    maximumCandidateDistance: maximumCandidateDistance
                )
            {
                continue
            }
            if node.level == level {
                scanRange(bucketRange(face: node.face, x: node.x, y: node.y, bytes: bytes))
                maximumCandidateDistance = sqrt(maximumCandidateDistanceSquared)
                continue
            }

            let childLevel = node.level + 1
            let queryShift = level - childLevel
            let preferredX =
                node.face == queryLocation.face
                ? (queryLocation.x >> queryShift) & 1 : -1
            let preferredY =
                node.face == queryLocation.face
                ? (queryLocation.y >> queryShift) & 1 : -1
            let preferred = preferredY * 2 + preferredX
            for child in 0..<4 where child != preferred {
                precondition(stackCount < 64, "ICON cube-bucket traversal stack overflow")
                stack[stackCount] = IconNativeGrid.CubeGeometry.Node(
                    face: node.face,
                    level: childLevel,
                    x: node.x * 2 + child % 2,
                    y: node.y * 2 + child / 2
                )
                stackCount += 1
            }
            if preferred >= 0 {
                precondition(stackCount < 64, "ICON cube-bucket traversal stack overflow")
                stack[stackCount] = IconNativeGrid.CubeGeometry.Node(
                    face: node.face,
                    level: childLevel,
                    x: node.x * 2 + preferredX,
                    y: node.y * 2 + preferredY
                )
                stackCount += 1
            }
        }

        precondition(bestScore != -Double.infinity, "ICON cube-bucket index contains no centres")
        if candidateOverflow {
            var bestCell = Int.max
            for position in 0..<cellCount {
                let candidate = scoreAndCell(at: position, query: query, bytes: bytes)
                let score = candidate.score
                if score >= bestScore - Self.scoreTieTolerance {
                    bestCell = min(bestCell, candidate.cell)
                }
            }
            return bestCell
        }
        var bestCell = Int.max
        for position in 0..<candidateCount where candidates[position].cell < bestCell {
            bestCell = candidates[position].cell
        }
        return bestCell
    }

    @inline(__always)
    private func bucketRange(
        face: Int,
        x: Int,
        y: Int,
        bytes: borrowing RawSpan
    ) -> Range<Int> {
        guard
            let bucket = faceSections[face].bucket(
                x: x,
                y: y,
                tileShift: bucketLayout.tileShift
            )
        else { return 0..<0 }
        let begin = directoryPosition(bucket, bytes: bytes)
        let end = directoryPosition(bucket + 1, bytes: bytes)
        return begin..<end
    }

    @inline(__always)
    private func nodeIntersectsStoredBuckets(
        _ node: IconNativeGrid.CubeGeometry.Node
    ) -> Bool {
        let shift = level - node.level
        let minimumX = node.x << shift
        let minimumY = node.y << shift
        return faceSections[node.face].intersects(
            minimumX: minimumX,
            maximumX: ((node.x + 1) << shift) - 1,
            minimumY: minimumY,
            maximumY: ((node.y + 1) << shift) - 1
        )
    }

    @inline(__always)
    private func scoreAndCell(
        at position: Int,
        query: IconNativeCenter,
        bytes: borrowing RawSpan
    ) -> (score: Double, cell: Int) {
        return (
            Artifact.score(
                position: position,
                query: query,
                bytes: bytes,
                centersOffset: centersOffset
            ),
            Artifact.cell(
                position: position,
                bytes: bytes,
                centersOffset: centersOffset
            )
        )
    }

}
