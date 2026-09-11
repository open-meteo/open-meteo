import Foundation

extension SphericalCubeIndex {
    private struct DistanceCandidate: Sendable {
        var pointID: Int
        var distanceSquared: Float

        static let empty = Self(pointID: -1, distanceSquared: .infinity)
    }

    private struct CandidateSearchState {
        var candidates = InlineArray<10, DistanceCandidate>(repeating: .empty)
        var count = 0
    }

    /// Fixed-capacity candidates for terrain and sea selection.
    ///
    /// Entry zero is always the result of the main nearest-point lookup. Remaining entries are the
    /// exact distance-ordered nearest points within the caller's distance limit.
    package struct NearbyPoints: Sendable {
        package var pointIDs = InlineArray<10, Int>(repeating: -1)
        package var distancesSquared = InlineArray<10, Float>(repeating: .infinity)
        package var count = 0
    }

    private static let nearbyPointLimit = 10

    /// Reuses a completed nearest lookup, avoiding duplicate coordinate conversion and search.
    /// Returns up to ten nearest points within the supplied inclusive distance limit.
    package func nearestCandidates(
        from lookup: Lookup,
        maximumChordDistanceSquared: Float = 4
    ) -> NearbyPoints {
        assert(maximumChordDistanceSquared.isFinite && maximumChordDistanceSquared > 0
            && maximumChordDistanceSquared <= 4
            && lookup.distanceSquared <= maximumChordDistanceSquared)
        return withBytes {
            nearestCandidates(
                from: lookup,
                maximumChordDistanceSquared: maximumChordDistanceSquared,
                bytes: $0
            )
        }
    }

    @inline(never)
    private func nearestCandidates(
        from lookup: Lookup,
        maximumChordDistanceSquared: Float,
        bytes: borrowing RawSpan
    ) -> NearbyPoints {
        let query = lookup.query
        let queryLocation = lookup.location
        var state = CandidateSearchState()

        @inline(__always)
        func precedes(_ lhs: DistanceCandidate, _ rhs: DistanceCandidate) -> Bool {
            if lhs.distanceSquared < rhs.distanceSquared { return true }
            if rhs.distanceSquared < lhs.distanceSquared { return false }
            return lhs.pointID < rhs.pointID
        }

        @inline(__always)
        func consider(
            position: Int,
            distanceSquared: Float,
            state: inout CandidateSearchState
        ) {
            if position == lookup.position || distanceSquared > maximumChordDistanceSquared { return }
            let last = Self.nearbyPointLimit - 2
            if state.count == Self.nearbyPointLimit - 1,
                distanceSquared > state.candidates[last].distanceSquared
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
            if state.count == Self.nearbyPointLimit - 1,
                !precedes(candidate, state.candidates[last])
            {
                return
            }
            var destination = min(state.count, last)
            if state.count < Self.nearbyPointLimit - 1 { state.count += 1 }
            while destination > 0, precedes(candidate, state.candidates[destination - 1]) {
                state.candidates[destination] = state.candidates[destination - 1]
                destination -= 1
            }
            state.candidates[destination] = candidate
        }

        @inline(__always)
        func scanRange(_ range: Range<Int>, state: inout CandidateSearchState) {
            for position in range {
                consider(
                    position: position,
                    distanceSquared: Artifact.squaredDistance(
                        position: position,
                        query: query,
                        bytes: bytes,
                        pointsOffset: pointsOffset
                    ),
                    state: &state
                )
            }
        }

        @inline(__always)
        func searchLimit(_ state: borrowing CandidateSearchState) -> Float {
            state.count == Self.nearbyPointLimit - 1
                ? min(maximumChordDistanceSquared, state.candidates[state.count - 1].distanceSquared)
                : maximumChordDistanceSquared
        }

        @inline(__always)
        func scanRow(y: Int, xRange: ClosedRange<Int>, state: inout CandidateSearchState) {
            forEachRowPointRange(face: queryLocation.face, y: y, xRange: xRange, bytes: bytes) {
                scanRange($0, state: &state)
            }
        }

        // Each completed square establishes a lower bound on every unsearched point, including
        // other faces. Once full, only points nearer than the tenth candidate can change the set.
        var searchedRadius = 0
        scanRow(y: queryLocation.y, xRange: queryLocation.x...queryLocation.x, state: &state)
        let maximumDirectRadius = min(
            queryLocation.x, resolution - queryLocation.x - 1,
            queryLocation.y, resolution - queryLocation.y - 1
        )
        while true {
            let limit = searchLimit(state)
            let distance = sqrt(Double(limit)) + Self.floatChordError
            let xRange = (queryLocation.x - searchedRadius)...(queryLocation.x + searchedRadius)
            let yRange = (queryLocation.y - searchedRadius)...(queryLocation.y + searchedRadius)
            // The sine-based certificate is monotonic only up to a hemisphere. Strict
            // certification and rounding inflation also preserve equal-distance ID ordering.
            if distance * distance < 2, regionIsCertified(
                location: queryLocation,
                xRange: xRange,
                yRange: yRange,
                maximumCandidateDistanceSquared: distance * distance
            ) {
                break
            }
            if searchedRadius >= maximumDirectRadius
                || searchedRadius >= requiredSearchRadius(maximumChordDistanceSquared: limit) {
                // Cross-face searches enumerate destination rectangles directly, bounded by the
                // current tenth distance, and skip the square already scanned on the query face.
                forEachSearchRange(
                    around: query.point,
                    location: queryLocation,
                    searchedRadius: searchedRadius,
                    maximumChordDistanceSquared: limit,
                    bytes: bytes,
                    state: &state,
                    scanRange
                )
                break
            }
            searchedRadius += 1
            let lowerX = queryLocation.x - searchedRadius
            let upperX = queryLocation.x + searchedRadius
            let lowerY = queryLocation.y - searchedRadius
            let upperY = queryLocation.y + searchedRadius
            scanRow(y: lowerY, xRange: lowerX...upperX, state: &state)
            scanRow(y: upperY, xRange: lowerX...upperX, state: &state)
            for y in (lowerY + 1)..<upperY {
                scanRow(y: y, xRange: lowerX...lowerX, state: &state)
                scanRow(y: y, xRange: upperX...upperX, state: &state)
            }
        }

        var result = NearbyPoints()
        result.pointIDs[0] = lookup.pointID
        result.distancesSquared[0] = lookup.distanceSquared
        result.count = 1
        for position in 0..<state.count {
            let destination = position + 1
            result.pointIDs[destination] = state.candidates[position].pointID
            result.distancesSquared[destination] = state.candidates[position].distanceSquared
            result.count += 1
        }
        return result
    }

}
