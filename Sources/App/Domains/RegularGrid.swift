import Foundation

struct RegularGrid: Gridable {
    let nx: Int
    let ny: Int
    let latMin: Float
    let lonMin: Float
    let dx: Float
    let dy: Float
    let searchRadius: Int

    let cfProjectionParameters = CfProjectionParameters(
        gridMappingName: .latitudeLongitude,
        gridMappingAttributes: [:]
    )

    public init(nx: Int, ny: Int, latMin: Float, lonMin: Float, dx: Float, dy: Float, searchRadius: Int = 1) {
        self.nx = nx
        self.ny = ny
        self.latMin = latMin
        self.lonMin = lonMin
        self.dx = dx
        self.dy = dy
        self.searchRadius = searchRadius
    }

    var isGlobal: Bool {
        return (Float(nx) * dx) >= 360 && (Float(ny) * dy) >= 180
    }

    func findPoint(lat: Float, lon: Float) -> Int? {
        guard let (x, y) = findPointXy(lat: lat, lon: lon) else {
            return nil
        }
        return y * nx + x
    }

    func findPointXy(lat: Float, lon: Float) -> (x: Int, y: Int)? {
        let x = Int(roundf((lon - lonMin) / dx))
        let y = Int(roundf((lat - latMin) / dy))

        /// Allow points on the border. `x == nx+1` is for ICON global to work on the date line crossing
        let xx = Float(nx) * dx >= 359 ? x == -1 ? 0 : (x == nx || x == nx+1) ? nx-1 : x : x
        let yy = Float(ny) * dy >= 179 ? y == -1 ? 0 : y == ny ? ny-1 : y : y
        if yy < 0 || xx < 0 || yy >= ny || xx >= nx {
            return nil
        }
        return (xx, yy)
    }

    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint / nx
        let x = gridpoint - y * nx
        let lat = latMin + Float(y) * dy
        let lon = lonMin + Float(x) * dx
        return (lat, lon)
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        let x = (lon - lonMin) / dx
        let y = (lat - latMin) / dy

        if y < 0 || x < 0 || y >= Float(ny) || x >= Float(nx) {
            return nil
        }

        let xFraction = (lon - lonMin).truncatingRemainder(dividingBy: dx)
        let yFraction = (lat - latMin).truncatingRemainder(dividingBy: dy)
        return GridPoint2DFraction(gridpoint: Int(y) * nx + Int(x), xFraction: xFraction, yFraction: yFraction)
    }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> RegularGridSlice? {
        let x1 = Int(roundf((bb.longitude.lowerBound - lonMin) / dx))
        let yLower = Int(roundf((bb.latitude.lowerBound - latMin) / dy))
        let x2 = Int(roundf((bb.longitude.upperBound - lonMin) / dx))
        let yUpper = Int(roundf((bb.latitude.upperBound - latMin) / dy))
        let y1 = dy > 0 ? yLower : yUpper
        let y2 = dy > 0 ? yUpper : yLower
        guard x1 >= 0, x2 >= 0, x1 <= nx, x2 <= nx, y1 >= 0, y2 >= 0, y1 <= ny, y2 <= ny, x1 <= x2, y1 <= y2 else {
            return RegularGridSlice(grid: self, yRange: 0..<0, xRange: 0..<0)
        }
        let xRange = x1 ..< x2
        let yRange = y1 ..< y2
        return RegularGridSlice(grid: self, yRange: yRange, xRange: xRange)
    }
}

/// Represent a subsection of a grid. Similar to an array slice, but using two dimensions
/// Important: The iterated coordinates are in global coordinates (-> gridpoint index). Array slices would use local indices.
struct RegularGridSlice {
    let nx: Int
    let ny: Int
    let yRange: Range<Int>
    let xRange: Range<Int>

    public init<Grid: Gridable>(grid: Grid, yRange: Range<Int>, xRange: Range<Int>) {
        self.xRange = xRange
        self.yRange = yRange
        self.nx = grid.nx
        self.ny = grid.ny
    }
}

extension RegularGridSlice: Sequence {
    func makeIterator() -> GridSliceXyIterator {
        return GridSliceXyIterator(yRange: yRange, xRange: xRange, nx: nx)
    }
}

extension RegularGridSlice: RandomAccessCollection {
    subscript(position: Int) -> Int {
        _read {
            let x = position % xRange.count
            let y = position / xRange.count
            let gridpoint = (y + yRange.lowerBound) * nx + x + xRange.lowerBound
            yield gridpoint
        }
    }

    var startIndex: Int {
        0
    }

    var endIndex: Int {
        yRange.count * xRange.count
    }

    typealias Index = Int
}

/// Iterate over a subset of a grib following x and y ranges. The element returns the global grid coordinate (grid point index as integer)
struct GridSliceXyIterator: IteratorProtocol {
    /// Current position of the iteration
    var position: Int
    /// End of the iteration (not including)
    let end: Int
    /// Number of x steps in the grid slice
    let nxSlice: Int
    /// Number of x steps in the grid
    let nx: Int

    let yLowerBound: Int
    let xLowerBound: Int

    init(yRange: Range<Int>, xRange: Range<Int>, nx: Int) {
        self.end = xRange.count * yRange.count
        self.position = 0
        self.nxSlice = xRange.count
        self.nx = nx
        self.xLowerBound = xRange.lowerBound
        self.yLowerBound = yRange.lowerBound
    }

    mutating func next() -> Int? {
        guard position < end else {
            // End of iteration
            return nil
        }
        let x = position % nxSlice
        let y = position / nxSlice
        let gridpoint = (y + yLowerBound) * nx + x + xLowerBound
        position += 1
        return gridpoint
    }
}
