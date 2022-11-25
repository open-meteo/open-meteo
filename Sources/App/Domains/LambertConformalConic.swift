import Foundation

/// Converts to spherical coordinates in meters from origin 0°/0°
struct LambertConformalConicProjection: Projectable {
    let ρ0: Float
    let F: Float
    let n: Float
    let λ0_rad: Float
    let ϕ0_rad: Float
    
    /// Radius of Earth
    var R: Float { 6370.997 }
    
    /// λ0 reference longitude
    /// ϕ0  reference latitude
    /// ϕ1 and ϕ2 standard parallels
    public init(λ0: Float, ϕ0: Float, ϕ1: Float, ϕ2: Float) {
        // https://mathworld.wolfram.com/LambertConformalConicProjection.html
        λ0_rad = (λ0 + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        ϕ0_rad = ϕ0.degreesToRadians
        let ϕ1_rad = ϕ1.degreesToRadians
        let ϕ2_rad = ϕ2.degreesToRadians
        if ϕ1 == ϕ2 {
            n = sin(ϕ1_rad)
        } else {
            n = log(cos(ϕ1_rad) / cos(ϕ2_rad)) / log(tan(.pi/4 + ϕ2_rad/2) / tan(.pi/4 + ϕ1_rad/2))
        }
        
        F = (cos(ϕ1_rad) * powf(tan(.pi/4 + ϕ1_rad/2), n))/n
        ρ0 = F/powf(tan(.pi/4 + ϕ0_rad/2),n)
    }
    
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let latitudeRadians = latitude.degreesToRadians
        let longitudeRadians = (longitude + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        let delta = longitudeRadians - λ0_rad
        
        let p = F/powf(tan(.pi/4 + latitudeRadians/2), n)
        let x = R * p * sin(n*(delta))
        let y = R * (ρ0 - p * cos(n*(delta)))
        return (x, y)
    }
    
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x_skaliert = x / R
        let y_skaliert = y / R
        
        let θ = atan(x_skaliert/(ρ0 - y_skaliert))
        let ρ = (n>0 ? 1 : -1) * sqrt(powf(x_skaliert,2) + powf(ρ0 - y_skaliert,2))

        let ϕ_rad = 2*atan(powf(F/ρ, 1/n)) - .pi/2
        let λ_rad = λ0_rad + θ/n

        let ϕ = ϕ_rad.radiansToDegrees
        let λ = λ_rad.radiansToDegrees

        return (ϕ, λ > 180 ? λ - 360 : λ)
    }
}
