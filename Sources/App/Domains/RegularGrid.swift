import Foundation


struct RegularGrid: Gridable {
    let nx: Int
    let ny: Int
    let latMin: Float
    let lonMin: Float
    let dx: Float
    let dy: Float
    let searchRadius: Int
    
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
        guard let (x,y) = findPointXy(lat: lat, lon: lon) else {
            return nil
        }
        return y * nx + x
    }
    
    func findPointXy(lat: Float, lon: Float) -> (x: Int, y: Int)? {
        let x = Int(roundf((lon-lonMin) / dx))
        let y = Int(roundf((lat-latMin) / dy))
        
        // Allow points on the border. For global grids, this grid point now wrappes to the eastern side
        let xx = Float(nx) * dx >= 359 ? x.moduloPositive(nx) : x
        let yy = Float(ny) * dy >= 179 ? y.moduloPositive(ny) : y
        if yy < 0 || xx < 0 || yy >= ny || xx >= nx {
            return nil
        }
        return (xx, yy)
    }
    
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint / nx
        let x = gridpoint-y * nx
        let lat = latMin + Float(y) * dy
        let lon = lonMin + Float(x) * dx
        return (lat, lon)
    }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        let x = (lon-lonMin) / dx
        let y = (lat-latMin) / dy
        
        if y < 0 || x < 0 || y >= Float(ny) || x >= Float(nx) {
            return nil
        }
        
        let xFraction = (lon-lonMin).truncatingRemainder(dividingBy: dx)
        let yFraction = (lat-latMin).truncatingRemainder(dividingBy: dy)
        return GridPoint2DFraction(gridpoint: Int(y) * nx + Int(x), xFraction: xFraction, yFraction: yFraction)
    }
    
    func findBox(boundingBox bb: BoundingBoxWGS84) -> Optional<any Sequence<Int>> {
        guard let (x1, y1) = findPointXy(lat: bb.latitude.lowerBound, lon: bb.longitude.lowerBound),
              let (x2, y2) = findPointXy(lat: bb.latitude.upperBound, lon: bb.longitude.upperBound) else {
            return []
        }
        
        let xRange = x1 ..< x2
        let yRange = y1 > y2 ? y2 ..< y1 : y1 ..< y2
        
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
    
    init(yRange: Range<Int>, xRange: Range<Int>, nx: Int) {
        let count = xRange.count * yRange.count
        self.end = ((yRange.upperBound - 1) * nx + xRange.upperBound)
        // For empty grids, set the position pointer to the end of iteration
        self.position = count == 0 ? self.end : (yRange.lowerBound * nx + xRange.lowerBound - 1)
        self.nxSlice = xRange.count
        self.nx = nx
    }
    
    mutating func next() -> Int? {
        guard (position + 1) < end else {
            // End of iteration
            return nil
        }
        let xSliceUpperBound = end % nx
        guard (position + 1) % nx < xSliceUpperBound else {
            // X range exceeded, increment Y, restart x
            position = position + 1 + nx - nxSlice
            return position
        }
        position += 1
        return position
    }
}
