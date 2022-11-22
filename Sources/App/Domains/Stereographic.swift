import Foundation


/// Stereographic projection
/// https://mathworld.wolfram.com/StereographicProjection.html
struct StereograpicProjection: Projectable {
    /// Central longitude
    let λ0: Float
    
    /// Sinus of central latitude
    let sinϕ1: Float
    
    /// Cosine of central latitude
    let cosϕ1: Float
    
    /// Radius of Earth
    var R: Float { 6370.997 }
    
    public init(latitude: Float, longitude: Float) {
        λ0 = longitude.degreesToRadians
        sinϕ1 = sin(latitude.degreesToRadians)
        cosϕ1 = cos(latitude.degreesToRadians)
    }
    
    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let ϕ = latitude.degreesToRadians
        let λ = longitude.degreesToRadians
        let k = 2 * R / (1 + sinϕ1 * sin(ϕ) + cosϕ1 * cos(ϕ) * cos(λ-λ0))
        let x = k * cos(ϕ) * sin(λ - λ0)
        let y = k * (cosϕ1 * sin(ϕ) - sinϕ1 * cos(ϕ) * cos(λ-λ0))
        return (x, y)
    }
    
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let p = sqrt(x*x + y*y)
        let c = 2 * atan(p / (2*R))
        let ϕ = asin(cos(c) * sinϕ1 + (y * sin(c) * cosϕ1) / p)
        let λ = λ0 + atan(x * sin(c) / (p * cosϕ1 * cos(c) - y * sinϕ1 * sin(c)))
        return (ϕ.radiansToDegrees, λ.radiansToDegrees)
    }
}
