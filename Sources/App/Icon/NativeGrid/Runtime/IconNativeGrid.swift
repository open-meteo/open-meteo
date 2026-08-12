import Foundation
import OmFileFormat

/// Metre-bounded nearest-official-mass-point lookup backed by the portable Float32 cube artifact.
struct IconNativeGrid: Gridable {
    typealias SliceType = Range<Int>

    let storage: SphericalCubeIndex

    init(storage: SphericalCubeIndex) {
        self.storage = storage
    }

    static func load(file: URL) throws -> Self {
        Self(storage: try SphericalCubeIndex(file: file))
    }

    var nx: Int { storage.pointCount }
    var ny: Int { 1 }
    var searchRadius: Int { 2 }

    var crsWkt2: String {
        """
        GEOGCRS["ICON Native Grid",
            DATUM["Sphere",
                ELLIPSOID["Sphere",6371229,0]],
            CS[ellipsoidal,2],
                AXIS["latitude",north],
                AXIS["longitude",east],
                ANGLEUNIT["degree",0.0174532925199433]]
        """
    }

    func findPoint(lat: Float, lon: Float) -> Int? {
        storage.nearestPointID(latitude: lat, longitude: lon)
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? { nil }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? { nil }

    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? { nil }

    func getCoordinates(gridpoint: Int) -> LatLon {
        precondition(gridpoint >= 0 && gridpoint < storage.pointCount, "ICON grid point out of range")
        return storage.point(at: gridpoint).coordinate
    }

    func findPointInSea(
        lat: Float,
        lon: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let lookup = storage.nearestLookup(latitude: lat, longitude: lon) else {
            return nil
        }
        let nearest = lookup.pointID
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest, file: elevationFile)
        if nearestElevation <= -999 {
            return (nearest, .sea)
        }
        let candidates = storage.nearestCandidates(from: lookup)
        let elevations = try await readElevations(
            candidates: candidates,
            knownValue: nearestElevation,
            elevationFile: elevationFile
        )

        for position in 1..<candidates.count where elevations[position] <= -999 {
            return (candidates.pointIDs[position], .sea)
        }
        return elevationResult(gridpoint: nearest, value: nearestElevation)
    }

    func findPointTerrainOptimised(
        lat: Float,
        lon: Float,
        elevation: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let lookup = storage.nearestLookup(latitude: lat, longitude: lon) else {
            return nil
        }
        let nearest = lookup.pointID
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest, file: elevationFile)
        if nearestElevation.isFinite, nearestElevation > -999, abs(nearestElevation - elevation) <= 100 {
            return elevationResult(gridpoint: nearest, value: nearestElevation)
        }
        let candidates = storage.nearestCandidates(from: lookup)
        let elevations = try await readElevations(
            candidates: candidates,
            knownValue: nearestElevation,
            elevationFile: elevationFile
        )

        var bestPosition = -1
        var bestScore = Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let candidateElevation = elevations[position]
            if !candidateElevation.isFinite || candidateElevation <= -999 {
                continue
            }
            let distanceKilometres = sqrt(max(0, candidates.distancesSquared[position])) * 6371.229
            if distanceKilometres >= 50 {
                continue
            }
            let elevationDelta = candidateElevation >= 9999 ? 0 : abs(candidateElevation - elevation)
            let score = elevationDelta + distanceKilometres * 30
            if score < bestScore || (score == bestScore && (bestPosition < 0 || candidates.pointIDs[position] < candidates.pointIDs[bestPosition])) {
                bestScore = score
                bestPosition = position
            }
        }

        if bestPosition < 0 || bestScore > 1500 {
            return elevationResult(gridpoint: nearest, value: nearestElevation)
        }
        return elevationResult(gridpoint: candidates.pointIDs[bestPosition], value: elevations[bestPosition])
    }

    private func readElevations(
        candidates: SphericalCubeIndex.NearbyPoints,
        knownValue: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> InlineArray<10, Float> {
        var sortedCells = InlineArray<10, Int>(repeating: -1)
        var sortedPositions = InlineArray<10, Int>(repeating: -1)
        var sortedCount = 0
        if candidates.count > 1 {
            for originalPosition in 1..<candidates.count {
                let cell = candidates.pointIDs[originalPosition]
                var insertion = sortedCount
                while insertion > 0, cell < sortedCells[insertion - 1] {
                    sortedCells[insertion] = sortedCells[insertion - 1]
                    sortedPositions[insertion] = sortedPositions[insertion - 1]
                    insertion -= 1
                }
                sortedCells[insertion] = cell
                sortedPositions[insertion] = originalPosition
                sortedCount += 1
            }
        }
        var result = InlineArray<10, Float>(repeating: .nan)
        result[0] = knownValue
        var start = 0
        while start < sortedCount {
            var end = start
            while end + 1 < sortedCount, sortedCells[end + 1] == sortedCells[end] + 1 {
                end += 1
            }
            let lower = UInt64(sortedCells[start])
            let upper = UInt64(sortedCells[end] + 1)
            let values = try await elevationFile.read(range: [0..<1, lower..<upper])
            for position in start...end {
                result[sortedPositions[position]] = values[sortedCells[position] - sortedCells[start]]
            }
            start = end + 1
        }
        return result
    }

    private func elevationResult(gridpoint: Int, value: Float) -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        if value.isNaN { return nil }
        if value <= -999 { return (gridpoint, .sea) }
        if value >= 9999 { return (gridpoint, .landWithoutElevation) }
        return (gridpoint, .elevation(value))
    }
}
