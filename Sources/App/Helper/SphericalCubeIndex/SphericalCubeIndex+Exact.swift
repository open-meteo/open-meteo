import Foundation
import OmFileFormat

extension SphericalCubeIndex {
    struct ExactRegion: Sendable {
        let xRange: ClosedRange<Int>
        let yRange: ClosedRange<Int>
    }

    private struct ScoreCandidate: Sendable {
        var pointID: Int
        var score: Double

        static let empty = Self(pointID: -1, score: -.infinity)
    }

    @inline(never)
    func nearest(
        to unnormalizedQuery: SphericalPoint,
        maximumDistanceSquared distanceLimitSquared: Double,
        seedPosition: Int?,
        certifiedRegion: ExactRegion?,
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
        var candidates = InlineArray<4, ScoreCandidate>(repeating: .empty)
        var candidateCount = 0
        var candidateOverflow = false
        var bestScore = distanceLimitSquared.isFinite ? 1 - distanceLimitSquared * 0.5 : -.infinity
        var maximumCandidateDistanceSquared = distanceLimitSquared

        @inline(__always)
        func scanRange(_ range: Range<Int>) {
            for position in range {
                let candidate = scoreAndPointID(at: position, query: query, bytes: bytes)
                let pointID = candidate.pointID
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
                        candidates[candidateCount] = ScoreCandidate(pointID: pointID, score: score)
                        candidateCount += 1
                    } else {
                        candidateOverflow = true
                    }
                }
            }
        }

        if let seedPosition {
            let seedScore = scoreAndPointID(at: seedPosition, query: query, bytes: bytes).score
            if seedScore > bestScore {
                bestScore = seedScore
                maximumCandidateDistanceSquared = max(
                    0,
                    2 - 2 * (bestScore - Self.scoreTieTolerance)
                )
            }
        }

        @inline(__always)
        func selectedPointID() -> Int? {
            guard candidateCount > 0 else { return nil }
            if candidateOverflow {
                var bestPointID = Int.max
                for position in 0..<pointCount {
                    let candidate = scoreAndPointID(at: position, query: query, bytes: bytes)
                    if candidate.score >= bestScore - Self.scoreTieTolerance {
                        bestPointID = min(bestPointID, candidate.pointID)
                    }
                }
                return bestPointID == .max ? nil : bestPointID
            }
            var bestPointID = Int.max
            for position in 0..<candidateCount where candidates[position].pointID < bestPointID {
                bestPointID = candidates[position].pointID
            }
            return bestPointID == .max ? nil : bestPointID
        }

        if let certifiedRegion {
            let section = faceSections[queryLocation.face]
            let lowerY = max(certifiedRegion.yRange.lowerBound, section.minimumY)
            let upperY = min(certifiedRegion.yRange.upperBound, section.minimumY + section.rows - 1)
            let lowerX = max(certifiedRegion.xRange.lowerBound, section.minimumX)
            let upperX = min(certifiedRegion.xRange.upperBound, section.minimumX + section.columns - 1)
            if lowerX <= upperX, lowerY <= upperY {
                for y in lowerY...upperY {
                    for x in lowerX...upperX {
                        scanRange(
                            bucketRange(
                                face: queryLocation.face,
                                x: x,
                                y: y,
                                bytes: bytes
                            ))
                    }
                }
            }
            return selectedPointID()
        }

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

        return selectedPointID()
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
