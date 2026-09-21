import Foundation
import OmFileFormat

/// Immutable mmap index over reduced latitude bands for global or regional point sets.
/// Nearest and candidate queries compare stored Float32 directions, with canonical-ID ties.
/// All query state is stack-local, so readers can share one index concurrently.
/// Opening validates structure, not every point's norm, ID permutation, or bucket membership:
/// artifacts must come from a trusted writer and their mapped inodes must remain immutable.
package final class ReducedLatLonIndex: Sendable {
    private let mapped: MmapFile
    let bands: [ReducedLatLonArtifact.Band]
    let firstBand: Int
    let directoryOffset: Int
    let pointsOffset: Int
    let reverseOffset: Int
    /// Number of canonical points; valid point IDs are 0..<pointCount.
    package let pointCount: Int
    /// Number of equal-height bands over the whole sphere, including omitted regional bands.
    package let latitudeBandCount: Int
    /// Dataset identity and global/regional storage policy supplied by the writer.
    package let metadata: ReducedLatLonArtifact.Metadata
    private let latitudeScale: Double
    private let latitudeHeight: Double
    // Includes the Float query's displacement from the original geographic direction.
    private static var chordMargin: Double { 0x1p-19 } // 16 * Float.ulpOfOne; no lazy static initialization.

    /// Nearest result retaining query geometry for candidate lookup without repeated trigonometry.
    /// Use it only with the index that produced it; it contains values, not borrowed mapped bytes.
    package struct Lookup: Sendable {
        let query: ReducedLatLonPoint
        let latitude: Double
        let longitude: Double
        let cosineLatitude: Double
        let seedBoundary: Double
        let bucket: Int?
        let position: Int
        /// Canonical ID of the nearest accepted point.
        package let pointID: Int
        /// Squared chord distance between the Float32 query and stored direction.
        package let distanceSquared: Float
    }

    /// Up to ten candidates. Entry zero is the supplied nearest; the remaining entries are
    /// sorted by squared distance, then ascending canonical ID. Only 0..<count is populated.
    package struct NearbyPoints: Sendable {
        /// Canonical IDs corresponding to the distances at the same positions.
        package var pointIDs = InlineArray<10, Int>(repeating: -1)
        /// Squared chord distances, not metres or angular distances.
        package var distancesSquared = InlineArray<10, Float>(repeating: .infinity)
        /// Number of populated entries, from one through ten for a candidate query.
        package var count = 0
    }

    /// Opens an immutable artifact and retains its mapping for the lifetime of this index.
    package convenience init(file: URL) throws {
        let handle = try FileHandle.openFileReading(file: file.path)
        try self.init(mapped: MmapFile(fn: handle))
    }

    /// Validates and retains an existing mapping, including one over an unpublished file.
    /// The backing inode must not be modified or truncated while any reader uses it.
    package init(mapped: MmapFile) throws {
        // The pointer bridge cannot infer mmap ownership; pin it even on validation errors.
        defer { withExtendedLifetime(mapped) {} }
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))
        let parsed = try ReducedLatLonArtifact.parse(bytes)
        self.mapped = mapped
        bands = parsed.bands
        firstBand = parsed.firstBand
        directoryOffset = parsed.layout.directoryOffset
        pointsOffset = parsed.layout.pointsOffset
        reverseOffset = parsed.layout.reverseOffset
        pointCount = parsed.pointCount
        latitudeBandCount = parsed.latitudeBandCount
        metadata = parsed.metadata
        latitudeScale = Double(parsed.latitudeBandCount) / .pi
        latitudeHeight = .pi / Double(parsed.latitudeBandCount)
    }

    /// Returns the stored direction for a canonical ID, preserving its component bits.
    /// Requires pointID in 0..<pointCount.
    package func point(at pointID: Int) -> ReducedLatLonPoint {
        precondition(pointID >= 0 && pointID < pointCount)
        return withBytes { bytes in
            ReducedLatLonArtifact.point(bytes, pointsOffset + Int(ReducedLatLonArtifact.uint(bytes, reverseOffset + pointID * 4)) * 16)
        }
    }

    /// Non-escaping byte view; callers cannot return a span or retain it in lookup state.
    /// This bridge pins the mapping through the last read, including throwing callbacks.
    @inline(__always)
    func withBytes<R>(_ body: (borrowing RawSpan) throws -> R) rethrows -> R {
        try withExtendedLifetime(mapped) {
            try body(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data)))
        }
    }

    @inline(__always) func pointRange(_ buckets: Range<Int>, bytes: borrowing RawSpan) -> Range<Int> {
        Int(ReducedLatLonArtifact.uint(bytes, directoryOffset + buckets.lowerBound * 4))..<Int(ReducedLatLonArtifact.uint(bytes, directoryOffset + buckets.upperBound * 4))
    }

    @inline(__always)
    func bucket(latitude: Double, longitude: Double) -> Int? {
        location(latitude: latitude, longitude: longitude >= .pi ? longitude - 2 * .pi : longitude, cosine: 0).bucket
    }

    /// Distance to the nearest latitude/meridian boundary is bounded from below by
    /// (2/pi) * min(deltaLatitude, cos(latitude) * deltaLongitude). Both deltas are
    /// at most pi/2, where sin(t) >= 2t/pi. This conservative certificate needs no trig.
    @inline(__always)
    private func location(latitude: Double, longitude: Double, cosine: Double) -> (bucket: Int?, boundary: Double) {
        let y = (latitude + .pi / 2) * latitudeScale
        let row = min(latitudeBandCount - 1, max(0, Int(y)))
        let localRow = row - firstBand
        guard localRow >= 0, localRow < bands.count else { return (nil, 0) }
        let band = bands[localRow]
        let scale = Double(band.longitudeColumnCount) * (1 / (2 * .pi))
        let x = (longitude + .pi) * scale
        let column = min(band.longitudeColumnCount - 1, max(0, Int(x)))
        let local = band.localColumn(column)
        guard local < band.storedColumnCount else { return (nil, 0) }
        let latitudeDistance = min(y - Double(row), Double(row + 1) - y) * latitudeHeight
        let longitudeDistance = min(x - Double(column), Double(column + 1) - x) / scale
        return (band.firstBucket + local, (2 / .pi) * min(latitudeDistance, cosine * longitudeDistance))
    }

    private struct Match {
        var id = -1
        var position = -1
        var distance = Float.infinity
    }

    private struct Candidate {
        var id = -1
        var distance = Float.infinity
    }

    private struct CandidateState {
        var values = InlineArray<9, Candidate>(repeating: Candidate())
        var count = 0
    }

    /// Returns the nearest canonical ID within the inclusive squared-chord limit.
    /// Coordinates are degrees; finite longitudes wrap to [-180, 180). Nonfinite inputs,
    /// latitudes outside [-90, 90], and queries without an accepted point return nil.
    /// The limit must be finite and in (0, 4]. Equal Float32 distances prefer the lower ID.
    @inline(__always)
    package func nearestPointID(latitude: Float, longitude: Float, maximumChordDistanceSquared: Float) -> Int? {
        nearestLookup(latitude: latitude, longitude: longitude, maximumChordDistanceSquared: maximumChordDistanceSquared)?.pointID
    }

    /// Performs nearestPointID's bounded search and retains geometry for nearestCandidates.
    /// Uses the same degree inputs, invalid-input behavior, radius precondition, and tie rule.
    @inline(__always)
    package func nearestLookup(latitude: Float, longitude: Float, maximumChordDistanceSquared: Float) -> Lookup? {
        return nearest(latitude: latitude, longitude: longitude, limit: maximumChordDistanceSquared)
    }

    @inline(__always)
    private func scanNearest(
        _ buckets: Range<Int>, bytes: borrowing RawSpan, query: ReducedLatLonPoint,
        best: inout Match
    ) {
        let range = pointRange(buckets, bytes: bytes)
        for position in range {
            let offset = pointsOffset + position * 16
            let distance = query.squaredDistance(to: ReducedLatLonArtifact.point(bytes, offset))
            // Avoid loading IDs for losing points.
            if distance < best.distance {
                best = Match(id: Int(ReducedLatLonArtifact.uint(bytes, offset + 12)), position: position, distance: distance)
            } else if distance == best.distance {
                let id = Int(ReducedLatLonArtifact.uint(bytes, offset + 12))
                if best.id < 0 || id < best.id {
                    best.id = id
                    best.position = position
                }
            }
        }
    }

    @inline(never)
    private func nearest(latitude: Float, longitude: Float, limit: Float) -> Lookup? {
        precondition(limit.isFinite && limit > 0 && limit <= 4)
        guard latitude.isFinite, longitude.isFinite, latitude >= -90, latitude <= 90 else { return nil }
        let longitude = ReducedLatLonPoint.normalizeLongitude(longitude)
        let query = ReducedLatLonPoint.queryWithCosine(latitude: latitude, longitude: longitude)
        // Keep the original angles: the enlarged chord margin covers the Float vector's
        // small displacement, including its longitude reversal at exactly +/-90 degrees.
        let latitudeRadians = Double(latitude) * (.pi / 180)
        let longitudeRadians = Double(longitude) * (.pi / 180)
        let seed = location(latitude: latitudeRadians, longitude: longitudeRadians, cosine: query.cosine)
        // Pin the mapping through the last span read, including early returns. Keeping this
        // lexical borrow in the hot entry avoids an outlined callback and its extra stack frame.
        let mapped = self.mapped
        defer { withExtendedLifetime(mapped) {} }
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))
        var best = Match()
        if let bucket = seed.bucket {
            scanNearest(bucket..<bucket + 1, bytes: bytes, query: query.point, best: &best)
        }
        let chord = Double(min(limit, best.distance)).squareRoot() + Self.chordMargin
        if chord >= seed.boundary {
            let cap = searchCap(latitude: latitudeRadians, cosine: query.cosine, chord: chord)
            if cap.lower <= cap.upper {
                for row in cap.lower...cap.upper {
                    forEachRowRange(row: row, longitude: longitudeRadians, cap: cap, excluding: seed.bucket,
                                    state: &best) { buckets, best in
                        scanNearest(buckets, bytes: bytes, query: query.point, best: &best)
                    }
                }
            }
        }
        guard best.id >= 0, best.distance <= limit else { return nil }
        return Lookup(query: query.point, latitude: latitudeRadians, longitude: longitudeRadians,
                      cosineLatitude: query.cosine, seedBoundary: seed.boundary,
                      bucket: seed.bucket, position: best.position, pointID: best.id, distanceSquared: best.distance)
    }

    /// Returns the supplied nearest plus up to nine other closest points within the inclusive limit.
    /// The lookup must originate from this index. The squared-chord limit must be finite, in
    /// (0, 4], and at least lookup.distanceSquared. No query geometry or nearest search is repeated.
    @inline(__always)
    package func nearestCandidates(from lookup: Lookup, maximumChordDistanceSquared: Float) -> NearbyPoints {
        return candidates(from: lookup, limit: maximumChordDistanceSquared)
    }

    @inline(__always)
    private func scanCandidates(
        _ buckets: Range<Int>, bytes: borrowing RawSpan, lookup: borrowing Lookup,
        limit: Float, state: inout CandidateState
    ) {
        let range = pointRange(buckets, bytes: bytes)
        for position in range where position != lookup.position {
            let offset = pointsOffset + position * 16
            let distance = lookup.query.squaredDistance(to: ReducedLatLonArtifact.point(bytes, offset))
            guard distance <= limit else { continue }
            if state.count == 9, distance > state.values[8].distance { continue }
            let id = Int(ReducedLatLonArtifact.uint(bytes, offset + 12))
            if state.count == 9, distance == state.values[8].distance, id >= state.values[8].id { continue }
            var destination = min(state.count, 8)
            while destination > 0 {
                let previous = state.values[destination - 1]
                if previous.distance < distance || (previous.distance == distance && previous.id < id) { break }
                state.values[destination] = previous
                destination -= 1
            }
            state.values[destination] = Candidate(id: id, distance: distance)
            state.count = min(9, state.count + 1)
        }
    }

    @inline(__always)
    private func searchLimit(_ state: borrowing CandidateState, limit: Float) -> Float {
        state.count == 9 ? min(limit, state.values[8].distance) : limit
    }

    @inline(never)
    private func candidates(from lookup: Lookup, limit: Float) -> NearbyPoints {
        precondition(limit.isFinite && limit > 0 && limit <= 4 && lookup.distanceSquared <= limit)
        // The span cannot outlive this scope; the deferred lifetime fence pins its owner.
        let mapped = self.mapped
        defer { withExtendedLifetime(mapped) {} }
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))
        var state = CandidateState()
        if let seed = lookup.bucket {
            scanCandidates(seed..<seed + 1, bytes: bytes, lookup: lookup, limit: limit, state: &state)
        }
        var bound = searchLimit(state, limit: limit)
        let chord = Double(bound).squareRoot() + Self.chordMargin
        if chord >= lookup.seedBoundary {
            var cap = searchCap(latitude: lookup.latitude, cosine: lookup.cosineLatitude, chord: chord)
            if cap.lower <= cap.upper {
                let center = min(cap.upper, max(cap.lower, Int((lookup.latitude + .pi / 2) * latitudeScale)))
                let maximumOffset = max(center - cap.lower, cap.upper - center)
                // Visit the query row first, then alternating rows away from it. Once full,
                // the ninth additional distance shrinks the remaining cap. Each row is
                // visited once, so shrinking needs no visited set or duplicate point scans.
                for step in 0...(maximumOffset * 2) {
                    let row = step == 0 ? center : (step & 1 == 1 ? center - (step + 1) / 2 : center + step / 2)
                    let nextBound = searchLimit(state, limit: limit)
                    if nextBound < bound {
                        bound = nextBound
                        cap = searchCap(latitude: lookup.latitude, cosine: lookup.cosineLatitude,
                                        chord: Double(bound).squareRoot() + Self.chordMargin)
                    }
                    if step > 2 * max(center - cap.lower, cap.upper - center) { break }
                    guard row >= cap.lower, row <= cap.upper else { continue }
                    forEachRowRange(row: row, longitude: lookup.longitude, cap: cap, excluding: lookup.bucket,
                                    state: &state) { buckets, state in
                        scanCandidates(buckets, bytes: bytes, lookup: lookup, limit: limit, state: &state)
                    }
                }
            }
        }
        var result = NearbyPoints()
        result.pointIDs[0] = lookup.pointID
        result.distancesSquared[0] = lookup.distanceSquared
        result.count = state.count + 1
        for i in 0..<state.count {
            result.pointIDs[i + 1] = state.values[i].id
            result.distancesSquared[i + 1] = state.values[i].distance
        }
        return result
    }

    private struct Cap {
        let lower: Int
        let upper: Int
        let extent: Double
        let allLongitudes: Bool
    }

    /// Conservative small-angle bounds avoid libm on the NWP path. For 0 <= t <= 1/4,
    /// asin(t) <= t*(1+t*t): integrate 1/sqrt(1-t*t) <= 1+3*t*t.
    /// sin(angularRadius) <= chord when angularRadius <= pi/2.
    @inline(__always)
    private func searchCap(latitude: Double, cosine: Double, chord: Double) -> Cap {
        let chord = min(2, chord)
        let angle = chord <= 0.25 ? chord * (1 + chord * chord) : 2 * asin(chord * 0.5)
        let lower = max(firstBand, Int(max(0, latitude + .pi / 2 - angle) * latitudeScale))
        let upper = min(firstBand + bands.count - 1, Int(min(.pi, latitude + .pi / 2 + angle) * latitudeScale))
        let allLongitudes = angle >= .pi / 2 - abs(latitude)
        let ratio = allLongitudes ? 1 : min(1, chord / cosine)
        let extent = allLongitudes ? Double.pi : (ratio <= 0.25 ? ratio * (1 + ratio * ratio) : asin(ratio))
        return Cap(lower: lower, upper: upper, extent: extent, allLongitudes: allLongitudes)
    }

    @inline(__always)
    private func floorInteger(_ value: Double) -> Int {
        let integer = Int(value)
        return value < Double(integer) ? integer - 1 : integer
    }

    @inline(__always)
    private func forEachRowRange<State>(
        row: Int, longitude: Double, cap: Cap, excluding seed: Int?,
        state: inout State,
        _ body: (Range<Int>, inout State) -> Void
    ) {
        let band = bands[row - firstBand]
        guard band.storedColumnCount > 0 else { return }
        @inline(__always)
        func emit(_ lower: Int, _ upper: Int, _ state: inout State) {
            guard lower < upper else { return }
            if let seed, seed >= lower, seed < upper {
                if lower < seed { body(lower..<seed, &state) }
                if seed + 1 < upper { body(seed + 1..<upper, &state) }
            } else { body(lower..<upper, &state) }
        }
        if cap.allLongitudes {
            emit(band.firstBucket, band.firstBucket + band.storedColumnCount, &state)
            return
        }
        let scale = Double(band.longitudeColumnCount) * (1 / (2 * .pi))
        let first = floorInteger((longitude - cap.extent + .pi) * scale)
        let last = floorInteger((longitude + cap.extent + .pi) * scale)
        let count = min(band.longitudeColumnCount, last - first + 1)
        // Non-polar longitude half-width is at most pi/2. At most one wrap is needed.
        let wrapped = first < 0 ? first + band.longitudeColumnCount : (first >= band.longitudeColumnCount ? first - band.longitudeColumnCount : first)
        let local = band.localColumn(wrapped)
        emit(band.firstBucket + min(local, band.storedColumnCount), band.firstBucket + min(local + count, band.storedColumnCount), &state)
        if local + count > band.longitudeColumnCount {
            emit(band.firstBucket, band.firstBucket + min(local + count - band.longitudeColumnCount, band.storedColumnCount), &state)
        }
    }

    /// Geometry-only entry for exhaustive traversal tests. Production carries forward the
    /// query cosine and uses explicit inout state, avoiding mutable closure captures.
    func forEachCapRange(latitude: Double, longitude: Double, limit: Float, excluding seed: Int?, _ body: (Range<Int>) -> Void) {
        let cap = searchCap(latitude: latitude, cosine: max(0, cos(latitude)),
                            chord: Double(limit).squareRoot() + Self.chordMargin)
        guard cap.lower <= cap.upper else { return }
        var state: Void = ()
        for row in cap.lower...cap.upper {
            forEachRowRange(row: row, longitude: longitude, cap: cap, excluding: seed, state: &state) { range, _ in
                body(range)
            }
        }
    }
}
