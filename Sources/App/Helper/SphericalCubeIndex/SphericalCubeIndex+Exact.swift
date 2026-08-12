import Foundation
import OmFileFormat

extension SphericalCubeIndex {
    /// Exact nearest-point fallback for the stored Float32 directions.
    ///
    /// Distances are ordered by normalized Double dot product; exactly equal scores prefer the
    /// lower canonical point ID. An implicit six-root quadtree is traversed and conservatively
    /// pruned by spherical bounds.
    @inline(never)
    func nearest(
        to unnormalizedQuery: SphericalPoint,
        maximumDistanceSquared distanceLimitSquared: Double,
        seedPosition: Int?,
        bytes: borrowing RawSpan
    ) -> Int? {
        let queryNormSquared = unnormalizedQuery.dot(unnormalizedQuery)
        let inverseQueryNorm = 1 / sqrt(queryNormSquared)
        let query = SphericalPoint(
            x: unnormalizedQuery.x * inverseQueryNorm,
            y: unnormalizedQuery.y * inverseQueryNorm,
            z: unnormalizedQuery.z * inverseQueryNorm
        )
        let queryLocation = SphericalCubeGeometry.location(
            for: query,
            resolution: resolution,
            resolutionScale: resolutionScale
        )
        var bestScore = distanceLimitSquared.isFinite ? 1 - distanceLimitSquared * 0.5 : -.infinity
        var bestPointID = -1
        var maximumCandidateDistanceSquared = distanceLimitSquared

        @inline(__always)
        func consider(_ candidate: (score: Double, pointID: Int)) {
            if candidate.score > bestScore {
                bestScore = candidate.score
                bestPointID = candidate.pointID
                maximumCandidateDistanceSquared = max(
                    0,
                    2 - 2 * (bestScore - Self.exactScoreMargin)
                )
            } else if candidate.score == bestScore,
                bestPointID < 0 || candidate.pointID < bestPointID
            {
                bestPointID = candidate.pointID
            }
        }

        @inline(__always)
        func scanRange(_ range: Range<Int>) {
            for position in range {
                consider(scoreAndPointID(at: position, query: query, bytes: bytes))
            }
        }

        if let seedPosition {
            consider(scoreAndPointID(at: seedPosition, query: query, bytes: bytes))
        }

        // The complete fallback treats each cube face as an implicit quadtree root. Visiting the
        // query-side child last places it on top of this LIFO stack and tightens pruning early.
        var maximumCandidateDistance = sqrt(maximumCandidateDistanceSquared)
        var stack = InlineArray<64, SphericalCubeGeometry.Node>(repeating: .empty)
        var stackCount = 0
        for face in 0..<6 where face != queryLocation.face {
            stack[stackCount] = SphericalCubeGeometry.Node(face: face, level: 0, x: 0, y: 0)
            stackCount += 1
        }
        stack[stackCount] = SphericalCubeGeometry.Node(
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
                SphericalCubeGeometry.nodeCannotImprove(
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
                precondition(stackCount < 64, "spherical cube-bucket traversal stack overflow")
                stack[stackCount] = SphericalCubeGeometry.Node(
                    face: node.face,
                    level: childLevel,
                    x: node.x * 2 + child % 2,
                    y: node.y * 2 + child / 2
                )
                stackCount += 1
            }
            if preferred >= 0 {
                precondition(stackCount < 64, "spherical cube-bucket traversal stack overflow")
                stack[stackCount] = SphericalCubeGeometry.Node(
                    face: node.face,
                    level: childLevel,
                    x: node.x * 2 + preferredX,
                    y: node.y * 2 + preferredY
                )
                stackCount += 1
            }
        }

        return bestPointID >= 0 ? bestPointID : nil
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
                y: y
            )
        else { return 0..<0 }
        return directoryPosition(bucket, bytes: bytes)..<directoryPosition(bucket + 1, bytes: bytes)
    }

    @inline(__always)
    private func nodeIntersectsStoredBuckets(
        _ node: SphericalCubeGeometry.Node
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
    private func scoreAndPointID(
        at position: Int,
        query: SphericalPoint,
        bytes: borrowing RawSpan
    ) -> (score: Double, pointID: Int) {
        return (
            Artifact.score(
                position: position,
                query: query,
                bytes: bytes,
                pointsOffset: pointsOffset
            ),
            Artifact.pointID(
                position: position,
                bytes: bytes,
                pointsOffset: pointsOffset
            )
        )
    }

}
