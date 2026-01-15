import Foundation

/// See https://mathworld.wolfram.com/LambertAzimuthalEqual-AreaProjection.html
struct LambertAzimuthalEqualAreaProjection: Projectable {
    let λ0: Float
    let λ0_dec: Float
    let ϕ1: Float
    let R: Float

    func crsWkt2(latMin: Float, lonMin: Float, latMax: Float, lonMax: Float) -> String {
        return """
            PROJCRS["Lambert Azimuthal Equal-Area",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",\(R),0.0]]],
                CONVERSION["Lambert Azimuthal Equal-Area",
                    METHOD["Lambert Azimuthal Equal-Area"],
                    PARAMETER["Latitude of natural origin", \(ϕ1.radiansToDegrees)],
                    PARAMETER["Longitude of natural origin", \(λ0_dec)],
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

    /*
     λ0 central longitude
     ϕ1 standard parallel
     radius of earth
     */
    init(λ0 λ0_dec: Float, ϕ1 ϕ1_dec: Float, radius: Float = 6371229) {
        λ0 = λ0_dec.degreesToRadians
        ϕ1 = ϕ1_dec.degreesToRadians
        R = radius
        self.λ0_dec = λ0_dec
    }

    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let λ = longitude.degreesToRadians
        let ϕ = latitude.degreesToRadians
        let k = sqrtf(2 / (1 + sinf(ϕ1) * sinf(ϕ) + cosf(ϕ1) * cosf(ϕ) * cosf(λ - λ0)))

        let x = R * k * cosf(ϕ) * sinf(λ - λ0)
        let y = R * k * (cosf(ϕ1) * sinf(ϕ) - sinf(ϕ1) * cos(ϕ) * cosf(λ - λ0))
        return (x, y)
    }

    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x = x / R
        let y = y / R
        let p = sqrtf(x * x + y * y)
        let c = 2 * asinf(0.5 * p)
        let ϕ = asinf(cosf(c) * sinf(ϕ1) + (y * sinf(c) * cosf(ϕ1)) / p)
        let λ = λ0 + atanf((x * sinf(c) / (p * cosf(ϕ1) * cosf(c) - y * sinf(ϕ1) * sinf(c))))
        return (ϕ.radiansToDegrees, λ.radiansToDegrees)
    }
}
