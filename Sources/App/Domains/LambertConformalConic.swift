import Foundation

/// Converts to spherical coordinates in meters from origin 0°/0°
struct LambertConformalConicProjection: Projectable {
    let ρ0: Float
    let F: Float
    let n: Float
    let λ0: Float
    
    /// Radius of Earth
    var R: Float { 6370.997 }
    
    /// λ0 reference longitude in degrees
    /// ϕ0  reference latitude in degrees
    /// ϕ1 and ϕ2 standard parallels in degrees
    public init(λ0 λ0_dec: Float, ϕ0 ϕ0_dec: Float, ϕ1 ϕ1_dec: Float, ϕ2 ϕ2_dec: Float) {
        // https://mathworld.wolfram.com/LambertConformalConicProjection.html
        // https://pubs.usgs.gov/pp/1395/report.pdf page 104
        λ0 = (λ0_dec + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        let ϕ0 = ϕ0_dec.degreesToRadians
        let ϕ1 = ϕ1_dec.degreesToRadians
        let ϕ2 = ϕ2_dec.degreesToRadians
        if ϕ1 == ϕ2 {
            n = sin(ϕ1)
        } else {
            n = log(cos(ϕ1) / cos(ϕ2)) / log(tan(.pi/4 + ϕ2/2) / tan(.pi/4 + ϕ1/2))
        }
        
        F = (cos(ϕ1) * powf(tan(.pi/4 + ϕ1/2), n))/n
        ρ0 = F/powf(tan(.pi/4 + ϕ0/2),n)
    }
    
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let ϕ = latitude.degreesToRadians
        let λ = (longitude + 360).truncatingRemainder(dividingBy: 360).degreesToRadians
        // If (λ - λ0) exceeds the range:±: 180°, 360° should be added or subtracted.
        let θ = n * ((λ - λ0 + .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi)
        
        let p = F/powf(tan(.pi/4 + ϕ/2), n)
        let x = R * p * sin(θ)
        let y = R * (ρ0 - p * cos(θ))
        return (x, y)
    }
    
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x_skaliert = x / R
        let y_skaliert = y / R
        
        let θ = atan(x_skaliert/(ρ0 - y_skaliert))
        let ρ = (n>0 ? 1 : -1) * sqrt(powf(x_skaliert,2) + powf(ρ0 - y_skaliert,2))

        let ϕ_rad = 2*atan(powf(F/ρ, 1/n)) - .pi/2
        let λ_rad = λ0 + θ/n

        let ϕ = ϕ_rad.radiansToDegrees
        let λ = λ_rad.radiansToDegrees

        return (ϕ, λ > 180 ? λ - 360 : λ)
    }
}
