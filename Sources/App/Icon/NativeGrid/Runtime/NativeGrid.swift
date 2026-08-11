import Foundation
import OmFileFormat

typealias LatLon = (latitude: Float, longitude: Float)

struct IconNativeLookupVector: Sendable {
    let x: Float
    let y: Float
    let z: Float

    var center: IconNativeCenter {
        IconNativeCenter(x: Double(x), y: Double(y), z: Double(z))
    }
}

/// Canonical Double-precision unit vector derived from the official ICON `clat`/`clon` values.
/// The serialized XYZ values are the shared numerical contract for every artifact reader.
struct IconNativeCenter: Sendable, Equatable {
    private static let degreesToRadians = Double.pi / 180
    private static let degreesToRadiansFloat = Float.pi / 180

    let x: Double
    let y: Double
    let z: Double

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    private init(normalizingX x: Double, y: Double, z: Double) {
        let length = sqrt(x * x + y * y + z * z)
        precondition(length.isFinite && length > 0, "Invalid ICON center vector")
        self.x = x / length
        self.y = y / length
        self.z = z / length
    }

    init(latitudeRadians: Double, longitudeRadians: Double) {
        let latitudeCosine = cos(latitudeRadians)
        self.init(
            normalizingX: latitudeCosine * cos(longitudeRadians),
            y: latitudeCosine * sin(longitudeRadians),
            z: sin(latitudeRadians)
        )
    }

    init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.init(
            latitudeRadians: latitudeDegrees * Self.degreesToRadians,
            longitudeRadians: longitudeDegrees * Self.degreesToRadians
        )
    }

    /// The public grid inputs are already Float. Keeping trigonometry at that precision reduces
    /// lookup latency while remaining within the cube artifact's accepted metre-scale error.
    @inline(__always) static func fastCubeLookupVector(
        latitudeDegrees: Float,
        longitudeDegrees: Float
    ) -> IconNativeLookupVector {
        let latitude = latitudeDegrees * Self.degreesToRadiansFloat
        let longitude = longitudeDegrees * Self.degreesToRadiansFloat
        let latitudeCosine = cos(latitude)
        return IconNativeLookupVector(
            x: latitudeCosine * cos(longitude),
            y: latitudeCosine * sin(longitude),
            z: sin(latitude)
        )
    }

    var coordinate: LatLon {
        (
            latitude: Float(asin(max(-1, min(1, z))) * 180 / .pi),
            longitude: Float(atan2(y, x) * 180 / .pi)
        )
    }

    @inline(__always) func dot(_ other: Self) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    @inline(__always) func squaredDistance(to other: Self) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return dx * dx + dy * dy + dz * dz
    }

    @inline(__always) static func normalizedLongitude(_ longitude: Float) -> Float {
        if longitude >= -180, longitude < 180 { return longitude }
        var wrapped = longitude.truncatingRemainder(dividingBy: 360)
        if wrapped < -180 { wrapped += 360 }
        if wrapped >= 180 { wrapped -= 360 }
        return wrapped
    }

}

/// Metre-bounded nearest-official-mass-point lookup backed by the portable Float32 cube artifact.
struct IconNativeGrid: Gridable {
    typealias SliceType = Range<Int>

    let storage: IconNativeGrid.CubeIndex

    init(storage: IconNativeGrid.CubeIndex) {
        self.storage = storage
    }

    static func load(file: URL) throws -> Self {
        Self(storage: try IconNativeGrid.CubeIndex(file: file))
    }

    var nx: Int { storage.cellCount }
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
        storage.findNearestCell(latitude: lat, longitude: lon)
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? { nil }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? { nil }

    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? { nil }

    func getCoordinates(gridpoint: Int) -> LatLon {
        precondition(gridpoint >= 0 && gridpoint < storage.cellCount, "ICON grid point out of range")
        return storage.centerVector(at: gridpoint).coordinate
    }

    func findPointInSea(
        lat: Float,
        lon: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let lookup = storage.findNearestLookup(latitude: lat, longitude: lon) else {
            return nil
        }
        let nearest = lookup.cell
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest, file: elevationFile)
        if nearestElevation <= -999 {
            return (nearest, .sea)
        }
        let candidates = storage.findNearestCells(from: lookup)
        let elevations = try await readElevations(
            candidates: candidates,
            knownValue: nearestElevation,
            elevationFile: elevationFile
        )

        for position in 1..<candidates.count where elevations[position] <= -999 {
            return (candidates.points[position], .sea)
        }
        return elevationResult(gridpoint: nearest, value: nearestElevation)
    }

    func findPointTerrainOptimised(
        lat: Float,
        lon: Float,
        elevation: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let lookup = storage.findNearestLookup(latitude: lat, longitude: lon) else {
            return nil
        }
        let nearest = lookup.cell
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest, file: elevationFile)
        if nearestElevation.isFinite, nearestElevation > -999, abs(nearestElevation - elevation) <= 100 {
            return elevationResult(gridpoint: nearest, value: nearestElevation)
        }
        let candidates = storage.findNearestCells(from: lookup)
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
            if score < bestScore || (score == bestScore && (bestPosition < 0 || candidates.points[position] < candidates.points[bestPosition])) {
                bestScore = score
                bestPosition = position
            }
        }

        if bestPosition < 0 || bestScore > 1500 {
            return elevationResult(gridpoint: nearest, value: nearestElevation)
        }
        return elevationResult(gridpoint: candidates.points[bestPosition], value: elevations[bestPosition])
    }

    private func readElevations(
        candidates: IconNativeGrid.CubeIndex.NearbyCells,
        knownValue: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> InlineArray<10, Float> {
        var sortedCells = InlineArray<10, Int>(repeating: -1)
        var sortedPositions = InlineArray<10, Int>(repeating: -1)
        var sortedCount = 0
        if candidates.count > 1 {
            for originalPosition in 1..<candidates.count {
                let cell = candidates.points[originalPosition]
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
