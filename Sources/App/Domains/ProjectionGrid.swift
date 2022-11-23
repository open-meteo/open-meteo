import Foundation

protocol Projectable {
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float)
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float)
}


struct ProjectionGrid<Projection: Projectable>: Gridable {
    let projection: Projection
    let nx: Int
    let ny: Int
    let xrange: ClosedRange<Float>
    let yrange: ClosedRange<Float>
    
    public init(nx: Int, ny: Int, latitude: ClosedRange<Float>, longitude: ClosedRange<Float>, projection: Projection) {
        self.nx = nx
        self.ny = ny
        self.projection = projection
        let sw = projection.forward(latitude: latitude.lowerBound, longitude: longitude.lowerBound)
        let ne = projection.forward(latitude: latitude.upperBound, longitude: longitude.upperBound)
        xrange = sw.x ... ne.x
        yrange = sw.y ... ne.y
    }
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        let pos = projection.forward(latitude: lat, longitude: lon)
        let x = Int(round((pos.x - xrange.lowerBound) / xrange.length * Float(nx-1)))
        let y = Int(round((pos.y - yrange.lowerBound) / yrange.length * Float(ny-1)))
        if y < 0 || x < 0 || y >= ny || x >= nx {
            return nil
        }
        return y * nx + x
    }

    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint / nx
        let x = gridpoint-y * nx
        let xcord = Float(x)/Float(nx-1) * xrange.length + xrange.lowerBound
        let ycord = Float(y)/Float(ny-1) * yrange.length + yrange.lowerBound
        let (lat,lon) = projection.inverse(x: xcord, y: ycord)
        return (lat, (lon+180).truncatingRemainder(dividingBy: 360) - 180 )
    }
    
    /// Get angle towards true north. 0 = points towards north pole (e.g. no correction necessary), range -180;180
    func getTrueNorthDirection() -> [Float] {
        let pos = projection.forward(latitude: 90, longitude: 0)
        let northPoleX = (pos.x - xrange.lowerBound) / xrange.length * Float(nx-1)
        let northPoleY = (pos.y - yrange.lowerBound) / yrange.length * Float(ny-1)
        let trueNorthDirection = (0..<count).map { gridpoint in
            let x = Float(gridpoint % nx)
            let y = Float(gridpoint / nx)
            return atan2(northPoleX - x, northPoleY - y).radiansToDegrees
        }
        return trueNorthDirection
    }
}

fileprivate extension ClosedRange where Bound == Float {
    var length: Float {
        return upperBound - lowerBound
    }
}
