import Foundation

/// See https://mathworld.wolfram.com/LambertAzimuthalEqual-AreaProjection.html
struct LambertAzimuthalEqualAreaProjection: Projectable {
    let λ0: Float
    let ϕ1: Float
    let R: Float

    let cfProjectionParameters: CfProjectionParameters

    /*
     λ0 central longitude
     ϕ1 standard parallal
     radius of earth
     */
    init(λ0 λ0_dec: Float, ϕ1 ϕ1_dec: Float, radius: Float = 6371229) {
        self.cfProjectionParameters = CfProjectionParameters(
            gridMappingName: .lambertAzimuthalEqualArea,
            gridMappingAttributes: [
                "longitude_of_projection_origin": λ0_dec,
                "latitude_of_projection_origin": ϕ1_dec,
                "false_easting": 0,
                "false_northing": 0,
                "earth_radius": radius
            ]
        )
        λ0 = λ0_dec.degreesToRadians
        ϕ1 = ϕ1_dec.degreesToRadians
        R = radius
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
