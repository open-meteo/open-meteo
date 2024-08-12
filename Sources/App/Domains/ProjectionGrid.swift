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
    
    var searchRadius: Int {
        return 1
    }
    
    public init(nx: Int, ny: Int, latitude: ClosedRange<Float>, longitude: ClosedRange<Float>, projection: Projection) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        let sw = projection.forward(latitude: latitude.lowerBound, longitude: longitude.lowerBound)
        let ne = projection.forward(latitude: latitude.upperBound, longitude: longitude.upperBound)
        origin = sw
        dx = (ne.x - sw.x) / Float(nx-1)
        dy = (ne.y - sw.y) / Float(ny-1)
    }
    
    public init(nx: Int, ny: Int, latitude: Float, longitude: Float, dx: Float, dy: Float, projection: Projection) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        origin = projection.forward(latitude: latitude, longitude: longitude)
        self.dx = dx
        self.dy = dy
    }
    
    public init(nx: Int, ny: Int, latitudeProjectionOrigion: Float, longitudeProjectionOrigion: Float, dx: Float, dy: Float, projection: Projection) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        origin = (longitudeProjectionOrigion, latitudeProjectionOrigion)
        self.dx = dx
        self.dy = dy
    }
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        guard let (x,y) = findPointXy(lat: lat, lon: lon) else {
            return nil
        }
        return y * nx + x
    }
    
    func findPointXy(lat: Float, lon: Float) -> (x: Int, y: Int)? {
        let pos = projection.forward(latitude: lat, longitude: lon)
        let x = Int(round((pos.x - origin.x) / dx))
        let y = Int(round((pos.y - origin.y) / dy))
        if y < 0 || x < 0 || y >= ny || x >= nx {
            return nil
        }
        return (x, y)
    }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        let (x,y) = projection.forward(latitude: lat, longitude: lon)
        if y < 0 || x < 0 || y >= Float(ny) || x >= Float(nx) {
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
        guard let sw = findPointXy(lat: bb.latitude.lowerBound, lon: bb.longitude.lowerBound),
              let se = findPointXy(lat: bb.latitude.lowerBound, lon: bb.longitude.upperBound),
              let nw = findPointXy(lat: bb.latitude.upperBound, lon: bb.longitude.lowerBound),
              let ne = findPointXy(lat: bb.latitude.upperBound, lon: bb.longitude.upperBound) else {
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
