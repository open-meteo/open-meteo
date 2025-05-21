import Foundation
import OmFileFormat

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

    /// Grid mapping name according to CF conventions
    /// https://cfconventions.org/cf-conventions/cf-conventions.html#appendix-grid-mappings
    var cfProjectionParameters: CfProjectionParameters { get }
}

extension Gridable {
    var gridBounds: GridBounds {
        let sw = getCoordinates(gridpoint: 0)
        let ne = getCoordinates(gridpoint: nx * ny - 1)
        return GridBounds(lat_bounds: (sw.latitude, ne.latitude), lon_bounds: (sw.longitude, ne.longitude))
    }
}

public struct CfProjectionParameters: Sendable {
    let gridMappingName: String
    let gridMappingAttributes: [String: Float]
}

public struct GridBounds {
    let lat_bounds: (lower: Float, upper: Float)
    let lon_bounds: (lower: Float, upper: Float)
}

public struct GridPoint2DFraction {
    let gridpoint: Int
    let xFraction: Float
    let yFraction: Float
}

enum ElevationOrSea {
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

        let deltaCenter = abs(elevationSurrounding[elevationSurrounding.count / 2] - elevation )
        if deltaCenter <= 100 {
            return (center, .elevation(elevationSurrounding[elevationSurrounding.count / 2]))
        }

        var minDelta = deltaCenter
        var minPos = elevationSurrounding.count / 2
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN || elevationSurrounding[i] <= -999 {
                continue
            }
            /// 9999 is used in satellite datasets to mark land locations, use closest grid-cell, regardless of terrain elevation
            /// Ideally we store elevation and sea mark separately, but this would require large refactoring
            let delta = elevationSurrounding[i] >= 9999 ? distanceSquared(
                x: xrange.lowerBound + i % xrange.count,
                y: yrange.lowerBound + i / xrange.count,
                lat: lat,
                lon: lon
            ) : abs(elevationSurrounding[i] - elevation)
            if delta < minDelta {
                minDelta = delta
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
        if elevationSurrounding[minPos] >= 9999 {
            /// 9999 marks land points in satellite datasets
            return (gridpoint, .landWithoutElevation)
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
