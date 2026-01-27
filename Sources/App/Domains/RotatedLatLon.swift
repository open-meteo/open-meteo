import Foundation

/// RotatedLatLon projection for HRDP continental
/// https://gis.stackexchange.com/questions/10808/manually-transforming-rotated-lat-lon-to-regular-lat-lon
struct RotatedLatLonProjection: Projectable {
    /// Rotation around y-axis
    let θ: Float

    /// Rotation around z-axis
    let ϕ: Float

    func crsWkt2(latMin: Float, lonMin: Float, latMax: Float, lonMax: Float) -> String {
        let o_lat_p = -(θ.radiansToDegrees - 90)
        return """
            GEOGCRS["Rotated Lat/Lon",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",6371229.0,0.0]]],
                DERIVINGCONVERSION["Rotated Lat/Lon",
                    METHOD["PROJ ob_tran o_proj=longlat"],
                    PARAMETER["o_lon_p",0],
                    PARAMETER["o_lat_p",\(o_lat_p)],
                    PARAMETER["lon_0",\(ϕ.radiansToDegrees)]]
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433],
                USAGE[
                    SCOPE["grid"],
                    BBOX[\(latMin),\(lonMin),\(latMax),\(lonMax)]]]
            """
    }

    public init(latitude: Float, longitude: Float) {
        θ = (90 + latitude).degreesToRadians
        ϕ = longitude.degreesToRadians
    }

    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let lon = longitude.degreesToRadians
        let lat = latitude.degreesToRadians

        let x = cos(lon) * cos(lat)
        let y = sin(lon) * cos(lat)
        let z = sin(lat)

        let x2 = cos(θ) * cos(ϕ) * x + cos(θ) * sin(ϕ) * y + sin(θ) * z
        let y2 = -sin(ϕ) * x + cos(ϕ) * y
        let z2 = -sin(θ) * cos(ϕ) * x - sin(θ) * sin(ϕ) * y + cos(θ) * z

        return (-1 * atan2(y2, x2).radiansToDegrees, -1 * asin(z2).radiansToDegrees)
    }

    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let lon = x.degreesToRadians
        let lat = y.degreesToRadians

        // quick solution without conversion in cartesian space
        let lat2 = -1 * asin(cos(θ) * sin(lat) - cos(lon) * sin(θ) * cos(lat))
        let lon2 = -1 * (atan2(sin(lon), tan(lat) * sin(θ) + cos(lon) * cos(θ)) - ϕ)
        return (lat2.radiansToDegrees, (lon2.radiansToDegrees + 180).truncatingRemainder(dividingBy: 360) - 180)
    }
}
