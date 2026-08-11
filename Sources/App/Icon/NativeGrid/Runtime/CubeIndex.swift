import Foundation
import OmFileFormat

extension IconNativeGrid {
    /// Metre-bounded nearest-official-mass-point search over an implicit uniform cube quadtree.
    ///
    /// The artifact stores Float32 XYZ centres in cube-bucket order. The only spatial index
    /// is a compact prefix-offset directory at the leaf level. Internal nodes, bounds and face
    /// adjacency are derived from `(face, level, x, y)`.
    final class CubeIndex: Sendable {
        typealias Artifact = IconNativeGrid.CubeArtifact
        typealias BucketLayout = Artifact.BucketLayout
        typealias FaceSection = Artifact.FaceSection

        private protocol BucketLayoutDecoder {
            static var tileShift: Int { get }
        }

        private struct RowMajorLayoutDecoder: BucketLayoutDecoder {
            static let tileShift = 0
        }

        private struct Tiled8LayoutDecoder: BucketLayoutDecoder {
            static let tileShift = 3
        }

        struct Lookup: Sendable {
            let query: IconNativeLookupVector
            let location: IconNativeGrid.CubeGeometry.Location
            let cell: Int
            let position: Int
            let distanceSquared: Float
        }

        static let scoreTieTolerance = 1e-15
        private static let floatSelectionUlpMargin: Float = 32
        static let floatChordError = 8 * Double(Float.ulpOfOne)

        private let mapped: MmapFile
        let faceSections: [FaceSection]
        private let offsetsOffset: Int
        let centersOffset: Int
        private let canonicalPositionsOffset: Int
        private let maximumDistanceSquared: Float
        let resolutionScale: Double
        private let boundaryValues: [Double]
        private let boundaryInverseNormSquared: [Double]
        let isGlobal: Bool

        let cellCount: Int
        let level: Int
        let resolution: Int
        private let bucketCount: Int
        let artifactBytes: Int
        let gridNumber: UInt32
        let gridUUID: [UInt8]
        let bucketLayout: BucketLayout

        init(file: URL) throws {
            let artifact = try Artifact.open(file: file)
            mapped = artifact.mapped
            faceSections = artifact.faceSections
            offsetsOffset = artifact.offsetsOffset
            centersOffset = artifact.centersOffset
            canonicalPositionsOffset = artifact.canonicalPositionsOffset
            let maximumAngle = Double(artifact.maximumDistanceMeters) / 6_371_229
            let maximumChord = 2 * sin(maximumAngle * 0.5)
            maximumDistanceSquared = Float(maximumChord * maximumChord)
            isGlobal = artifact.isGlobal
            cellCount = artifact.cellCount
            level = artifact.level
            resolution = artifact.resolution
            resolutionScale = Double(artifact.resolution) * 0.5
            bucketCount = artifact.bucketCount
            artifactBytes = artifact.artifactBytes
            gridNumber = artifact.gridNumber
            gridUUID = artifact.gridUUID
            bucketLayout = artifact.isGlobal ? .tiled8 : .rowMajor
            let bucketWidth = 2 / Double(artifact.resolution)
            boundaryValues = (0...artifact.resolution).map { -1 + Double($0) * bucketWidth }
            boundaryInverseNormSquared = boundaryValues.map { 1 / (1 + $0 * $0) }
        }

        @inline(__always)
        func findNearestCell(latitude: Float, longitude: Float) -> Int? {
            findNearestLookup(latitude: latitude, longitude: longitude)?.cell
        }

        @inline(__always)
        func findNearestLookup(latitude: Float, longitude: Float) -> Lookup? {
            guard latitude.isFinite, longitude.isFinite, latitude >= -90, latitude <= 90 else {
                return nil
            }
            let normalizedLongitude = IconNativeCenter.normalizedLongitude(longitude)
            return withBytes { bytes in
                let query = IconNativeCenter.fastCubeLookupVector(
                    latitudeDegrees: latitude,
                    longitudeDegrees: Float(normalizedLongitude)
                )
                let location = IconNativeGrid.CubeGeometry.location(
                    for: query.center,
                    resolution: resolution,
                    resolutionScale: resolutionScale
                )
                guard let nearest = nearestHot(to: query, location: location, bytes: bytes) else {
                    return nil
                }
                return Lookup(
                    query: query,
                    location: location,
                    cell: nearest.cell,
                    position: nearest.position,
                    distanceSquared: nearest.distanceSquared
                )
            }
        }

        @inline(__always)
        func centerVector(at cell: Int) -> IconNativeCenter {
            precondition(cell >= 0 && cell < cellCount, "ICON grid point out of range")
            return withBytes { bytes in
                let position = Int(
                    Artifact.readUInt32(
                        bytes,
                        at: canonicalPositionsOffset + cell * 4
                    )
                )
                return Artifact.center(
                    position: position,
                    bytes: bytes,
                    centersOffset: centersOffset
                )
            }
        }

        @inline(__always)
        func coordinate(at cell: Int) -> LatLon {
            centerVector(at: cell).coordinate
        }

        /// Minimal production path. Ties and the uncommon implicit-tree traversal are deliberately
        /// delegated to `nearest`: fewer than two queries per thousand reach that cold path on the
        /// current R3B7 and ICON-D2 artifacts.
        @inline(__always)
        private func nearestHot(
            to query: IconNativeLookupVector,
            location: IconNativeGrid.CubeGeometry.Location,
            bytes: borrowing RawSpan
        ) -> (cell: Int, position: Int, distanceSquared: Float)? {
            switch bucketLayout {
            case .rowMajor:
                nearestHot(
                    to: query,
                    location: location,
                    bytes: bytes,
                    layout: RowMajorLayoutDecoder.self
                )
            case .tiled8:
                nearestHot(
                    to: query,
                    location: location,
                    bytes: bytes,
                    layout: Tiled8LayoutDecoder.self
                )
            }
        }

        @inline(never)
        private func nearestHot<Layout: BucketLayoutDecoder>(
            to query: IconNativeLookupVector,
            location queryLocation: IconNativeGrid.CubeGeometry.Location,
            bytes: borrowing RawSpan,
            layout: Layout.Type
        ) -> (cell: Int, position: Int, distanceSquared: Float)? {
            let geometryQuery = query.center
            var bestDistanceSquared = Float.infinity
            var secondBestDistanceSquared = Float.infinity
            var bestPosition = -1

            @inline(__always)
            func consider(distanceSquared: Float, position: Int) {
                if distanceSquared < bestDistanceSquared {
                    secondBestDistanceSquared = bestDistanceSquared
                    bestDistanceSquared = distanceSquared
                    bestPosition = position
                } else if distanceSquared < secondBestDistanceSquared {
                    secondBestDistanceSquared = distanceSquared
                }
            }

            @inline(__always)
            func scanRange(_ range: Range<Int>) {
                for position in range {
                    let distanceSquared = Artifact.squaredDistance(
                        position: position,
                        query: query,
                        bytes: bytes,
                        centersOffset: centersOffset
                    )
                    consider(distanceSquared: distanceSquared, position: position)
                }
            }

            @inline(__always)
            func selected() -> (cell: Int, position: Int, distanceSquared: Float) {
                (
                    Artifact.cell(
                        position: bestPosition,
                        bytes: bytes,
                        centersOffset: centersOffset
                    ),
                    bestPosition,
                    bestDistanceSquared
                )
            }

            @inline(__always)
            func selectedWithinMaximumDistance() -> (cell: Int, position: Int, distanceSquared: Float)? {
                bestDistanceSquared <= maximumDistanceSquared ? selected() : nil
            }

            @inline(__always)
            func exactFallback() -> (cell: Int, position: Int, distanceSquared: Float)? {
                guard let cell = nearest(
                    to: geometryQuery,
                    maximumDistanceSquared: Double(maximumDistanceSquared),
                    bytes: bytes
                ) else { return nil }
                let position = Int(Artifact.readUInt32(
                    bytes,
                    at: canonicalPositionsOffset + cell * 4
                ))
                return (
                    cell,
                    position,
                    Artifact.squaredDistance(
                        position: position,
                        query: query,
                        bytes: bytes,
                        centersOffset: centersOffset
                    )
                )
            }

            @inline(__always)
            func bucket(x: Int, y: Int) -> Int? {
                if isGlobal, Layout.tileShift > 0 {
                    let tileShift = Layout.tileShift
                    let tileSize = 1 << tileShift
                    let tileX = x >> tileShift
                    let tileY = y >> tileShift
                    let tileHeight = min(tileSize, resolution - tileY * tileSize)
                    let tileWidth = min(tileSize, resolution - tileX * tileSize)
                    return queryLocation.face * resolution * resolution
                        + tileY * tileSize * resolution
                        + tileX * tileSize * tileHeight
                        + (y & (tileSize - 1)) * tileWidth
                        + (x & (tileSize - 1))
                }
                if isGlobal {
                    return queryLocation.face * resolution * resolution + y * resolution + x
                }
                return faceSections[queryLocation.face].bucket(
                    x: x,
                    y: y,
                    tileShift: Layout.tileShift > 0 ? Layout.tileShift : nil
                )
            }

            @inline(__always)
            func scanBucket(x: Int, y: Int) {
                guard let bucket = bucket(x: x, y: y) else { return }
                let begin = directoryPosition(bucket, bytes: bytes)
                let end = directoryPosition(bucket + 1, bytes: bytes)
                scanRange(begin..<end)
            }

            @inline(__always)
            func scanBucketInterval(firstBucket: Int, lastBucket: Int) {
                let begin = directoryPosition(firstBucket, bytes: bytes)
                let end = directoryPosition(lastBucket + 1, bytes: bytes)
                scanRange(begin..<end)
            }

            @inline(__always)
            func scanBucketRow(y: Int, xRange: ClosedRange<Int>) {
                let lowerX: Int
                let upperX: Int
                let section = faceSections[queryLocation.face]
                if isGlobal {
                    lowerX = xRange.lowerBound
                    upperX = xRange.upperBound
                } else {
                    guard y >= section.minimumY, y < section.minimumY + section.rows else { return }
                    lowerX = max(xRange.lowerBound, section.minimumX)
                    upperX = min(xRange.upperBound, section.minimumX + section.columns - 1)
                    guard lowerX <= upperX else { return }
                }
                guard Layout.tileShift > 0 else {
                    let firstBucket = bucket(x: lowerX, y: y)!
                    scanBucketInterval(
                        firstBucket: firstBucket,
                        lastBucket: firstBucket + upperX - lowerX
                    )
                    return
                }
                let tileShift = Layout.tileShift
                var segmentLowerX = lowerX
                while segmentLowerX <= upperX {
                    let localX = segmentLowerX - section.minimumX
                    let tileUpperX =
                        section.minimumX
                        + (((localX >> tileShift) + 1) << tileShift) - 1
                    let segmentUpperX = min(upperX, tileUpperX)
                    let firstBucket = bucket(x: segmentLowerX, y: y)!
                    scanBucketInterval(
                        firstBucket: firstBucket,
                        lastBucket: firstBucket + segmentUpperX - segmentLowerX
                    )
                    segmentLowerX = segmentUpperX + 1
                }
            }

            @inline(__always)
            func certified(
                xRange: ClosedRange<Int>,
                yRange: ClosedRange<Int>
            ) -> Bool {
                guard bestPosition >= 0 else { return false }
                let maximumCandidateDistance =
                    sqrt(Double(max(0, bestDistanceSquared))) + Self.floatChordError
                return regionIsCertified(
                    location: queryLocation,
                    xRange: xRange,
                    yRange: yRange,
                    maximumCandidateDistanceSquared:
                        maximumCandidateDistance * maximumCandidateDistance
                )
            }

            @inline(__always)
            func selectionIsUnambiguous() -> Bool {
                guard secondBestDistanceSquared.isFinite else { return true }
                let tolerance = Self.floatSelectionUlpMargin
                    * max(bestDistanceSquared.ulp, secondBestDistanceSquared.ulp)
                return secondBestDistanceSquared - bestDistanceSquared > tolerance
            }

            scanBucket(x: queryLocation.x, y: queryLocation.y)
            let leafXRange = queryLocation.x...queryLocation.x
            let leafYRange = queryLocation.y...queryLocation.y
            if certified(xRange: leafXRange, yRange: leafYRange) {
                if selectionIsUnambiguous() { return selectedWithinMaximumDistance() }
                return exactFallback()
            }

            let xRange = max(0, queryLocation.x - 1)...min(resolution - 1, queryLocation.x + 1)
            let yRange = max(0, queryLocation.y - 1)...min(resolution - 1, queryLocation.y + 1)
            bestDistanceSquared = .infinity
            secondBestDistanceSquared = .infinity
            bestPosition = -1
            for y in yRange {
                scanBucketRow(y: y, xRange: xRange)
            }
            if certified(xRange: xRange, yRange: yRange) {
                if selectionIsUnambiguous() { return selectedWithinMaximumDistance() }
            }
            return exactFallback()
        }

        @inline(__always)
        func directoryPosition(
            _ index: Int,
            bytes: borrowing RawSpan
        ) -> Int {
            Artifact.directoryPosition(
                index,
                bytes: bytes,
                offsetsOffset: offsetsOffset,
                bucketCount: bucketCount
            )
        }

        /// Certifies a direct bucket result without assuming anything about ICON adjacency. Leaving a
        /// cube-face rectangle requires crossing one of its four great-circle boundary planes. The
        /// distance to the complete great circle can only underestimate the distance to the finite
        /// boundary arc, making this a conservative exact stopping condition even at cube seams.
        @inline(__always)
        func regionIsCertified(
            location: IconNativeGrid.CubeGeometry.Location,
            xRange: ClosedRange<Int>,
            yRange: ClosedRange<Int>,
            maximumCandidateDistanceSquared: Double
        ) -> Bool {
            @inline(__always)
            func boundarySineSquared(
                coordinate: Double,
                boundaryIndex: Int
            ) -> Double {
                let delta = coordinate - boundaryValues[boundaryIndex]
                return min(
                    1,
                    location.normalizedNormalComponentSquared * delta * delta
                        * boundaryInverseNormSquared[boundaryIndex]
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

}
