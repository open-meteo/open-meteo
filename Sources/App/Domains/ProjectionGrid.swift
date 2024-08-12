import Foundation

protocol Projectable {
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float)
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float)
}


struct ProjectionGrid<Projection: Projectable>: Gridable {
    let projection: Projection
    let nx: Int
    let ny: Int
    let origin: (x: Float, y: Float)
    /// In metres
    let dx: Float
    /// In metres
    let dy: Float
    
    let searchRadius: Int
    let excludeBorderPixel: Int
    
    public init(nx: Int, ny: Int, latitude: ClosedRange<Float>, longitude: ClosedRange<Float>, projection: Projection, searchRadius: Int = 1, excludeBorderPixel: Int = 0) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        self.searchRadius = searchRadius
        self.excludeBorderPixel = excludeBorderPixel
        let sw = projection.forward(latitude: latitude.lowerBound, longitude: longitude.lowerBound)
        let ne = projection.forward(latitude: latitude.upperBound, longitude: longitude.upperBound)
        origin = sw
        dx = (ne.x - sw.x) / Float(nx-1)
        dy = (ne.y - sw.y) / Float(ny-1)
    }
    
    public init(nx: Int, ny: Int, latitude: Float, longitude: Float, dx: Float, dy: Float, projection: Projection, searchRadius: Int = 1, excludeBorderPixel: Int = 0) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        origin = projection.forward(latitude: latitude, longitude: longitude)
        self.dx = dx
        self.dy = dy
        self.searchRadius = searchRadius
        self.excludeBorderPixel = excludeBorderPixel
    }
    
    public init(nx: Int, ny: Int, latitudeProjectionOrigion: Float, longitudeProjectionOrigion: Float, dx: Float, dy: Float, projection: Projection, searchRadius: Int = 1, excludeBorderPixel: Int = 0) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        origin = (longitudeProjectionOrigion, latitudeProjectionOrigion)
        self.dx = dx
        self.dy = dy
        self.searchRadius = searchRadius
        self.excludeBorderPixel = excludeBorderPixel
    }
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        guard let (x,y) = findPointXy(lat: lat, lon: lon) else {
            return nil
        }
        return y * nx + x
    }
    
    func findPointXy(lat: Float, lon: Float, excludeBorderPixel: Int? = nil) -> (x: Int, y: Int)? {
        let excludeBorderPixel = excludeBorderPixel ?? self.excludeBorderPixel
        let pos = projection.forward(latitude: lat, longitude: lon)
        let x = Int(round((pos.x - origin.x) / dx))
        let y = Int(round((pos.y - origin.y) / dy))
        if y < excludeBorderPixel || 
            x < excludeBorderPixel ||
            y >= ny-excludeBorderPixel ||
            x >= nx-excludeBorderPixel {
            return nil
        }
        return (x, y)
    }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        let (x,y) = projection.forward(latitude: lat, longitude: lon)
        if y < Float(excludeBorderPixel) ||
            x < Float(excludeBorderPixel) ||
            y >= Float(ny-excludeBorderPixel) ||
            x >= Float(nx-excludeBorderPixel) {
            return nil
        }
        let xFraction = x.truncatingRemainder(dividingBy: 1)
        let yFraction = y.truncatingRemainder(dividingBy: 1)
        return GridPoint2DFraction(gridpoint: Int(y) * nx + Int(x), xFraction: xFraction, yFraction: yFraction)
    }
    

    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint / nx
        let x = gridpoint-y * nx
        let xcord = Float(x) * dx + origin.x
        let ycord = Float(y) * dy + origin.y
        let (lat,lon) = projection.inverse(x: xcord, y: ycord)
        return (lat, (lon+180).truncatingRemainder(dividingBy: 360) - 180 )
    }
    
    /// Get angle towards true north. 0 = points towards north pole (e.g. no correction necessary), range -180;180
    func getTrueNorthDirection() -> [Float] {
        let pos = projection.forward(latitude: 90, longitude: 0)
        let northPoleX = (pos.x - origin.x) / dx
        let northPoleY = (pos.y - origin.y) / dy
        let trueNorthDirection = (0..<count).map { gridpoint in
            let x = Float(gridpoint % nx)
            let y = Float(gridpoint / nx)
            return atan2(northPoleX - x, northPoleY - y).radiansToDegrees
        }
        return trueNorthDirection
    }
    
    func findBox(boundingBox bb: BoundingBoxWGS84) -> Optional<any Sequence<Int>> {
        guard let sw = findPointXy(lat: bb.latitude.lowerBound, lon: bb.longitude.lowerBound, excludeBorderPixel: 0),
              let se = findPointXy(lat: bb.latitude.lowerBound, lon: bb.longitude.upperBound, excludeBorderPixel: 0),
              let nw = findPointXy(lat: bb.latitude.upperBound, lon: bb.longitude.lowerBound, excludeBorderPixel: 0),
              let ne = findPointXy(lat: bb.latitude.upperBound, lon: bb.longitude.upperBound, excludeBorderPixel: 0) else {
            return []
        }
        
        let xRange = min(sw.x, nw.x) ..< max(se.x, ne.x)
        let yRange = min(sw.y, nw.y) ..< max(se.y, ne.y)
        
        return ProjectionGridSlice(grid: self, yRange: yRange, xRange: xRange)
    }
}

fileprivate extension ClosedRange where Bound == Float {
    var length: Float {
        return upperBound - lowerBound
    }
}


struct ProjectionGridSlice<Projection: Projectable> {
    let grid: ProjectionGrid<Projection>
    let yRange: Range<Int>
    let xRange: Range<Int>
}

extension ProjectionGridSlice: Sequence {
    func makeIterator() -> GridSliceXyIterator {
        return GridSliceXyIterator(yRange: yRange, xRange: xRange, nx: grid.nx)
    }
}
