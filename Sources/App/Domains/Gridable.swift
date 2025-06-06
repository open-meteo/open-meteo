import Foundation
import OmFileFormat
import OrderedCollections

public protocol Gridable: Sendable {
    var nx: Int { get }
    var ny: Int { get }

    /// Typically `1` to seach in a `3x3` grid. Use `2` for `5x5`. E.g. MF Wave has large boarders around the coast
    var searchRadius: Int { get }

    func findPoint(lat: Float, lon: Float) -> Int?
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction?
    func findBox(boundingBox bb: BoundingBoxWGS84) -> (any Sequence<Int>)?
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float)

    /// Grid mapping name according to CF conventions
    /// https://cfconventions.org/cf-conventions/cf-conventions.html#appendix-grid-mappings
    var cfProjectionParameters: CfProjectionParameters { get }
}

extension Gridable {
    var gridBounds: GridBounds {
        let sw = getCoordinates(gridpoint: 0)
        let ne = getCoordinates(gridpoint: nx * ny - 1)
        return GridBounds(lat_bounds: sw.latitude...ne.latitude, lon_bounds: sw.longitude...ne.longitude)
    }
}

enum GridMappingName: String, Codable {
    case lambertConformalConic = "lambert_conformal_conic"
    case lambertAzimuthalEqualArea = "lambert_azimuthal_equal_area"
    case stereographic = "stereographic"
    case rotatedLatLon = "rotated_latitude_longitude"
    case latitudeLongitude = "latitude_longitude"

    var proj4Name: String {
        switch self {
        case .lambertConformalConic:
            return "lcc"
        case .lambertAzimuthalEqualArea:
            return "laea"
        case .stereographic:
            return "stere"
        case .rotatedLatLon:
            return "ob_tran"
        case .latitudeLongitude:
            return "longlat"
        }
    }
}

public struct CfProjectionParameters: Sendable {
    let gridMappingName: GridMappingName
    let gridMappingAttributes: OrderedDictionary<String, Float>

    func toProj4String() -> String {
        var proj4String = "+proj=\(gridMappingName.proj4Name)"
        // convert cf-conformant attributes to proj4
        for (key, value) in gridMappingAttributes {
            if key == "latitude_of_projection_origin" {
                proj4String += " +lat_0=\(value)"
            } else if key == "longitude_of_projection_origin" || key == "straight_vertical_longitude_from_pole" || key == "longitude_of_central_meridian" {
                proj4String += " +lon_0=\(value)"
            } else if key == "grid_north_pole_latitude" {
                proj4String += " +o_lat_p=\(value)"
            } else if key == "grid_north_pole_longitude" {
                proj4String += " +o_lon_p=\(value)"
            } else if key == "north_pole_grid_longitude" {
                proj4String += " +lon_1=\(value)"
            } else if key == "standard_parallel" {
                proj4String += " +lat_1=\(value)"
            } else if key == "false_easting" {
                proj4String += " +x_0=\(value)"
            } else if key == "false_northing" {
                proj4String += " +y_0=\(value)"
            } else if key == "earth_radius" {
                proj4String += " +R=\(value)"
            } else {
                fatalError("Unknown CF attribute \(key) for projection \(gridMappingName.rawValue)")
            }
        }
        // add default attributes
        proj4String += " +units=m +datum=WGS84 +no_defs +type=crs"
        return proj4String
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

enum ElevationOrSea {
    case noData
    case sea
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
            // sea gtid point
            return .sea
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
            // sea gtid point
            return .sea
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

        // TODO find a solution to reuse buffers inside read... maybe allocate buffers in a pool per eventloop?
        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        let elevationSurrounding = try await elevationFile.read(range: [yrange.toUInt64(), xrange.toUInt64()])

        if elevationSurrounding[elevationSurrounding.count / 2] <= -999 {
            return (center, .sea)
        }

        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN {
                continue
            }
            if elevationSurrounding[i] <= -999 {
                let dx = i % xrange.count - (x - xrange.lowerBound)
                let dy = i / xrange.count - (y - yrange.lowerBound)
                let gridpoint = (y + dy) * nx + (x + dx)
                return (gridpoint, .sea)
            }
        }

        // all land, take center
        if elevationSurrounding[elevationSurrounding.count / 2].isNaN {
            return nil
        }
        return (center, .elevation(elevationSurrounding[elevationSurrounding.count / 2]))
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

        if abs(elevationSurrounding[elevationSurrounding.count / 2] - elevation ) <= 100 {
            return (center, .elevation(elevationSurrounding[elevationSurrounding.count / 2]))
        }

        var minDelta = Float(10_000)
        var minPos = elevationSurrounding.count / 2
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN {
                continue
            }
            if abs(elevationSurrounding[i] - elevation) < minDelta {
                minDelta = abs(elevationSurrounding[i] - elevation)
                minPos = i
            }
        }

        /// only sea points or elevation ish hugly off -> just use center
        if minDelta > 900 {
            minPos = elevationSurrounding.count / 2
        }

        let dx = minPos % xrange.count - (x - xrange.lowerBound)
        let dy = minPos / xrange.count - (y - yrange.lowerBound)
        let gridpoint = (y + dy) * nx + (x + dx)
        if elevationSurrounding[minPos].isNaN {
            return nil
        }
        if elevationSurrounding[minPos] <= -999 {
            return (gridpoint, .sea)
        }
        return (gridpoint, .elevation(elevationSurrounding[minPos]))
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
