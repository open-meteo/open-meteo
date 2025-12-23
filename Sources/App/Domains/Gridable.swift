import Foundation
import OmFileFormat
import OrderedCollections

public protocol Gridable: Sendable {
    var nx: Int { get }
    var ny: Int { get }

    /// Typically `1` to search in a `3x3` grid. Use `2` for `5x5`. E.g. MF Wave has large boarders around the coast
    var searchRadius: Int { get }

    func findPoint(lat: Float, lon: Float) -> Int?
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction?
    associatedtype SliceType: Sequence<Int>
    func findBox(boundingBox bb: BoundingBoxWGS84) -> SliceType?
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float)
    func findPointTerrainOptimised(lat: Float, lon: Float, elevation: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)?
    func findPointInSea(lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)?

    /// Grid mapping name according to CF conventions
    /// https://cfconventions.org/cf-conventions/cf-conventions.html#appendix-grid-mappings
    var cfProjectionParameters: any CfProjectionConvertible { get }
}

extension Gridable {
    var gridBounds: GridBounds {
        let sw = getCoordinates(gridpoint: 0)
        let ne = getCoordinates(gridpoint: nx * ny - 1)
        return GridBounds(lat_bounds: sw.latitude...ne.latitude, lon_bounds: sw.longitude...ne.longitude)
    }
}

public struct GridBounds: Equatable, Codable, Sendable {
    let lat_bounds: ClosedRange<Float>
    let lon_bounds: ClosedRange<Float>
}

public struct GridPoint2DFraction {
    let gridpoint: Int
    let xFraction: Float
    let yFraction: Float
}

public enum ElevationOrSea {
    case noData
    case sea
    case landWithoutElevation
    case elevation(Float)

    var isSea: Bool {
        switch self {
        case .sea:
            return true
        default:
            return false
        }
    }

    var hasNoData: Bool {
        switch self {
        case .noData:
            return true
        default:
            return false
        }
    }

    var numeric: Float {
        switch self {
        case .noData:
            return .nan
        case .sea:
            return 0
        case .elevation(let float):
            return float
        case .landWithoutElevation:
            return .nan
        }
    }
}

extension Gridable {
    /// number of grid cells
    var count: Int {
        return nx * ny
    }

    func findPoint(lat: Float, lon: Float, elevation: Float, elevationFile: (any OmFileReaderArrayProtocol<Float>)?, mode: GridSelectionMode) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let elevationFile = elevationFile else {
            guard let point = findPoint(lat: lat, lon: lon) else {
                return nil
            }
            return (point, .noData)
        }

        switch mode {
        case .land:
            return try await findPointTerrainOptimised(lat: lat, lon: lon, elevation: elevation, elevationFile: elevationFile)
        case .sea:
            return try await findPointInSea(lat: lat, lon: lon, elevationFile: elevationFile)
        case .nearest:
            return try await findPointNearest(lat: lat, lon: lon, elevationFile: elevationFile)
        }
    }

    /// Read elevation for a single grid point
    func readElevation(gridpoint: Int, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> ElevationOrSea {
        let elevation = try await readFromStaticFile(gridpoint: gridpoint, file: elevationFile)
        if elevation.isNaN {
            return .noData
        }
        if elevation <= -999 {
            // sea grid point
            return .sea
        }
        if elevation >= 9999 {
            // land, but no data
            return .landWithoutElevation
        }
        return .elevation(elevation)
    }

    /// Read elevation for a single grid point. Interpolates linearly between grid-cells. Should only be used for linear interpolated reads afterwards
    func readElevationInterpolated(gridpoint: GridPoint2DFraction, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> ElevationOrSea {
        let elevation = try await elevationFile.readInterpolated(pos: gridpoint)
        if elevation.isNaN {
            return .noData
        }
        // Due to interpolation, -999 is not clearly sea
        if elevation <= -50 {
            // sea grid point
            return .sea
        }
        if elevation >= 9000 {
            // land, but no data
            return .landWithoutElevation
        }
        return .elevation(elevation)
    }

    /// Read static information e.g. elevation or soil type
    func readFromStaticFile(gridpoint: Int, file: any OmFileReaderArrayProtocol<Float>) async throws -> Float {
        let x = UInt64(gridpoint % nx)
        let y = UInt64(gridpoint / nx)
        var value = Float.nan
        try await file.read(into: &value, range: [y..<y + 1, x..<x + 1], intoCubeOffset: nil, intoCubeDimension: nil)
        return value
    }

    /// Get nearest grid point
    func findPointNearest(lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let elevation = try await readElevation(gridpoint: center, elevationFile: elevationFile)
        if elevation.hasNoData {
            // grid is masked out in certain areas
            return nil
        }
        return (center, elevation)
    }

    /// Find point, perferably in sea
    func findPointInSea(lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let x = center % nx
        let y = center / nx

        let xrange = (x - searchRadius..<x + searchRadius + 1).clamped(to: 0..<nx)
        let yrange = (y - searchRadius..<y + searchRadius + 1).clamped(to: 0..<ny)

        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        let elevationSurrounding = try await elevationFile.read(range: [yrange.toUInt64(), xrange.toUInt64()])
        let centerElevation = elevationSurrounding[elevationSurrounding.count / 2]
        if centerElevation <= -999 {
            return (center, .sea)
        }
        var minDistance = Float(9999)
        var minPosition = -1
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN {
                continue
            }
            let x = xrange.lowerBound + i % xrange.count
            let y = yrange.lowerBound + i / xrange.count
            let distance = distanceSquared(
                x: x,
                y: y,
                lat: lat,
                lon: lon
            )
            if elevationSurrounding[i] <= -999 && distance < minDistance {
                minDistance = distance
                minPosition = y * nx + x
            }
        }
        guard minPosition >= 0 else {
            if centerElevation.isNaN {
                return (y * nx + x, .noData)
            }
            if centerElevation >= 9000 {
                // land, but no data
                return (y * nx + x, .landWithoutElevation)
            }
            return (y * nx + x, .elevation(centerElevation))
        }
        return (minPosition, .sea)
    }

    /// Return distance squared of a coordinate to a grid point
    fileprivate func distanceSquared(x: Int, y: Int, lat: Float, lon: Float) -> Float {
        let coordinate = getCoordinates(gridpoint: y * nx + x)
        return pow(coordinate.latitude - lat, 2) + pow(coordinate.longitude - lon, 2)
    }

    /// Analyse 3x3 locations around the desired coordinate and return the best elevation match
    func findPointTerrainOptimised(lat: Float, lon: Float, elevation: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let x = center % nx
        let y = center / nx

        let xrange = (x - searchRadius..<x + searchRadius + 1).clamped(to: 0..<nx)
        let yrange = (y - searchRadius..<y + searchRadius + 1).clamped(to: 0..<ny)

        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        let elevationSurrounding = try await elevationFile.read(range: [yrange.toUInt64(), xrange.toUInt64()])

        let centerElevation = elevationSurrounding[elevationSurrounding.count / 2]
        let deltaCenter = abs(centerElevation - elevation )
        if deltaCenter <= 100 {
            return (center, .elevation(elevationSurrounding[elevationSurrounding.count / 2]))
        }

        var minDelta = deltaCenter
        var minPosition = elevationSurrounding.count / 2
        var minElevation = Float.nan
        
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN || elevationSurrounding[i] <= -999 {
                continue
            }
            let x = xrange.lowerBound + i % xrange.count
            let y = yrange.lowerBound + i / xrange.count
            let distanceSquared = distanceSquared(
                x: x,
                y: y,
                lat: lat,
                lon: lon
            )
            let distanceKm = sqrt(distanceSquared)*111
            /// For every 1km in distance, the elevation must be 30 m better
            let distancePenalty = distanceKm * 30
            /// 9999 is used in satellite datasets to mark land locations, use closest grid-cell, regardless of terrain elevation
            /// Ideally we store elevation and sea mark separately, but this would require large refactoring
            let delta = (elevationSurrounding[i] >= 9999 ? 0 : abs(elevationSurrounding[i] - elevation)) + distancePenalty
            if delta < minDelta && distanceKm < 50 {
                minDelta = delta
                minPosition = y * nx + x
                minElevation = elevationSurrounding[i]
            }
        }

        /// only sea points or elevation ish hugly off -> just use center
        if minElevation.isNaN || minDelta > 1500 {
            minPosition = y * nx + x
            minElevation = centerElevation
        }

        if minElevation.isNaN {
            return nil
        }
        if minElevation <= -999 {
            return (minPosition, .sea)
        }
        if minElevation >= 9999 {
            /// 9999 marks land points in satellite datasets
            return (minPosition, .landWithoutElevation)
        }
        return (minPosition, .elevation(minElevation))
    }
}

enum GridSelectionMode: String, Codable {
    case land
    case sea
    case nearest
}

public struct BoundingBoxWGS84 {
    let latitude: Range<Float>
    let longitude: Range<Float>
}
