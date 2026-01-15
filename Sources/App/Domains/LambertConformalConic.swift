import Foundation

/// Converts to spherical coordinates in meters from origin 0°/0°
struct LambertConformalConicProjection: Projectable {
    let ρ0: Float
    let F: Float
    let n: Float
    let λ0: Float

    let λ0_dec: Float
    let ϕ0_dec: Float
    let ϕ1_dec: Float
    let ϕ2_dec: Float

    /// Radius of Earth. Different radiuses may be used for different GRIBS: https://github.com/SciTools/iris-grib/issues/241#issuecomment-1239069695
    let R: Float

    func crsWkt2(latMin: Float, lonMin: Float, latMax: Float, lonMax: Float) -> String {
        return """
            PROJCRS["Lambert Conic Conformal",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",\(R),0.0]]],
                CONVERSION["Lambert Conic Conformal",
                    METHOD["Lambert Conic Conformal (2SP)"],
                    PARAMETER["Latitude of 1st standard parallel",\(ϕ1_dec)],
                    PARAMETER["Latitude of 2nd standard parallel",\(ϕ2_dec)],
                    PARAMETER["Latitude of false origin",\(ϕ0_dec)],
                    PARAMETER["Longitude of false origin",\(λ0_dec)]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                    LENGTHUNIT["metre",1],
                USAGE[
                    SCOPE["grid"],
                    BBOX[\(latMin),\(lonMin),\(latMax),\(lonMax)]]]
            """
    }

    /// λ0 reference longitude in degrees `LoVInDegrees` in grib
    /// ϕ0  reference latitude in degrees. `LaDInDegrees` in grib
    /// ϕ1 and ϕ2 standard parallels in degrees `Latin1InDegrees` and `Latin2InDegrees` in grib
    public init(λ0 λ0_dec: Float, ϕ0 ϕ0_dec: Float, ϕ1 ϕ1_dec: Float, ϕ2 ϕ2_dec: Float , radius: Float) {
        // https://mathworld.wolfram.com/LambertConformalConicProjection.html
        // https://pubs.usgs.gov/pp/1395/report.pdf page 104
        λ0 = ((λ0_dec + 180).truncatingRemainder(dividingBy: 360) - 180).degreesToRadians
        let ϕ0 = ϕ0_dec.degreesToRadians
        let ϕ1 = ϕ1_dec.degreesToRadians
        let ϕ2 = ϕ2_dec.degreesToRadians
        if ϕ1 == ϕ2 {
            n = sin(ϕ1)
        } else {
            n = log(cos(ϕ1) / cos(ϕ2)) / log(tan(.pi / 4 + ϕ2 / 2) / tan(.pi / 4 + ϕ1 / 2))
        }

        F = (cos(ϕ1) * powf(tan(.pi / 4 + ϕ1 / 2), n)) / n
        ρ0 = F / powf(tan(.pi / 4 + ϕ0 / 2), n)
        R = radius
        self.λ0_dec = λ0_dec
        self.ϕ0_dec = ϕ0_dec
        self.ϕ1_dec = ϕ1_dec
        self.ϕ2_dec = ϕ2_dec
    }

    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let ϕ = latitude.degreesToRadians
        let λ = longitude.degreesToRadians
        // If (λ - λ0) exceeds the range:±: 180°, 360° should be added or subtracted.
        let θ = n * (λ - λ0)

        let p = F / powf(tan(.pi / 4 + ϕ / 2), n)
        let x = R * p * sin(θ)
        let y = R * (ρ0 - p * cos(θ))
        return (x, y)
    }

    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x_skaliert = x / R
        let y_skaliert = y / R

        let θ = n >= 0 ? atan2(x_skaliert, ρ0 - y_skaliert) : atan2(-1 * x_skaliert, y_skaliert - ρ0)
        let ρ = (n > 0 ? 1 : -1) * sqrt(powf(x_skaliert, 2) + powf(ρ0 - y_skaliert, 2))

        let ϕ_rad = 2 * atan(powf(F / ρ, 1 / n)) - .pi / 2
        let λ_rad = λ0 + θ / n

        let ϕ = ϕ_rad.radiansToDegrees
        let λ = λ_rad.radiansToDegrees

        return (ϕ, λ > 180 ? λ - 360 : λ)
    }
}
