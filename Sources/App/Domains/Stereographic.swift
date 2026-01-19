import Foundation

/// Stereographic projection
/// https://mathworld.wolfram.com/StereographicProjection.html
struct StereographicProjection: Projectable {
    /// Central longitude
    let λ0: Float

    /// Central latitude
    let ϕ1_dec: Float

    /// Sinus of central latitude
    let sinϕ1: Float

    /// Cosine of central latitude
    let cosϕ1: Float

    /// Radius of Earth in meters
    var R: Float

    func crsWkt2(latMin: Float, lonMin: Float, latMax: Float, lonMax: Float) -> String {
        return """
            PROJCRS["Stereographic",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",\(R),0.0]]],
                CONVERSION["Stereographic",
                    METHOD["Stereographic"],
                    PARAMETER["Latitude of natural origin", \(ϕ1_dec)],
                    PARAMETER["Longitude of natural origin", \(λ0.radiansToDegrees)],
                    PARAMETER["Scale factor at natural origin", 1.0],
                    PARAMETER["False easting", 0.0],
                    PARAMETER["False northing", 0.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                    LENGTHUNIT["metre",1.0],
                USAGE[
                    SCOPE["grid"],
                    BBOX[\(latMin),\(lonMin),\(latMax),\(lonMax)]]]
            """
    }

    public init(latitude: Float, longitude: Float, radius: Float) {
        λ0 = longitude.degreesToRadians
        ϕ1_dec = latitude
        sinϕ1 = sin(latitude.degreesToRadians)
        cosϕ1 = cos(latitude.degreesToRadians)
        R = radius
    }

    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let ϕ = latitude.degreesToRadians
        let λ = longitude.degreesToRadians
        let k = 2 * R / (1 + sinϕ1 * sin(ϕ) + cosϕ1 * cos(ϕ) * cos(λ - λ0))
        let x = k * cos(ϕ) * sin(λ - λ0)
        let y = k * (cosϕ1 * sin(ϕ) - sinϕ1 * cos(ϕ) * cos(λ - λ0))
        return (x, y)
    }

    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let p = sqrt(x * x + y * y)
        let c = 2 * atan2(p, 2 * R)
        let ϕ = asin(cos(c) * sinϕ1 + (y * sin(c) * cosϕ1) / p)
        let λ = λ0 + atan2(x * sin(c), p * cosϕ1 * cos(c) - y * sinϕ1 * sin(c))
        return (ϕ.radiansToDegrees, λ.radiansToDegrees)
    }
}
