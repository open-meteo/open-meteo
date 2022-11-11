import Foundation


struct LambertConformalGrid: Gridable {
    let projection: LambertConformalConicProjection
    let nx: Int
    let ny: Int
    let xrange: ClosedRange<Float>
    let yrange: ClosedRange<Float>
    
    public init(nx: Int, ny: Int, latitude: ClosedRange<Float>, longitude: ClosedRange<Float>, projection: LambertConformalConicProjection) {
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
        return projection.inverse(x: xcord, y: ycord)
    }
}

fileprivate extension ClosedRange where Bound == Float {
    var length: Float {
        return upperBound - lowerBound
    }
}


/// Converts to spherical coordinates in meters from origin 0°/0°
struct LambertConformalConicProjection {
    let ρ0: Float
    let F: Float
    let n: Float
    let λ0_rad: Float
    let ϕ0_rad: Float
    
    /// Radius of Earth
    static var R: Float = 6370.997
    
    /// λ0 reference longitude
    /// ϕ0  reference latitude
    /// ϕ0 and ϕ1 standard parallels
    public init(λ0: Float, ϕ0: Float, ϕ1: Float) {
        // https://mathworld.wolfram.com/LambertConformalConicProjection.html
        λ0_rad = (λ0 + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        ϕ0_rad = ϕ0.degreesToRadians
        let ϕ1_rad = ϕ1.degreesToRadians
        n = sin(ϕ1_rad)
        F = (cos(ϕ1_rad) * powf(tan(.pi/4 + ϕ1_rad/2), n))/n
        ρ0 = F/powf(tan(.pi/4 + ϕ0_rad/2),n)
    }
    
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let latitudeRadians = latitude.degreesToRadians
        let longitudeRadians = (longitude + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        let delta = longitudeRadians - λ0_rad
        
        let p = F/powf(tan(.pi/4 + latitudeRadians/2), n)
        let x = Self.R * p * sin(n*(delta))
        let y = Self.R * (ρ0 - p * cos(n*(delta)))
        return (x, y)
    }
    
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x_skaliert = x / Self.R
        let y_skaliert = y / Self.R
        
        let θ = atan(x_skaliert/(ρ0 - y_skaliert))
        let ρ = (n>0 ? 1 : -1) * sqrt(powf(x_skaliert,2) + powf(ρ0 - y_skaliert,2))

        let ϕ_rad = 2*atan(powf(F/ρ, 1/n)) - .pi/2
        let λ_rad = λ0_rad + θ/n

        let ϕ = ϕ_rad.radiansToDegrees
        let λ = λ_rad.radiansToDegrees

        return (ϕ, λ > 180 ? λ - 360 : λ)
    }
}
