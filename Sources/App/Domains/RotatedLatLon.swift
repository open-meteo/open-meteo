import Foundation


/// RotatedLatLon projection for HRDP continental
/// https://gis.stackexchange.com/questions/10808/manually-transforming-rotated-lat-lon-to-regular-lat-lon
struct RotatedLatLonProjection: Projectable {
    /// Rotation around y-axis
    let θ: Float
    
    /// Rotation around z-axis
    let ϕ: Float
    
    public init(latitude: Float, longitude: Float) {
        θ = (90+latitude).degreesToRadians
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

        return (atan2(y2, x2).radiansToDegrees, asin(z2).radiansToDegrees)
    }
    
    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let lon = x.degreesToRadians
        let lat = y.degreesToRadians
        
        let θ = -1 * θ
        let ϕ = -1 * ϕ

        /*let x = cos(lon) * cos(lat)
        let y = sin(lon) * cos(lat)
        let z = sin(lat)
        let x2 = cos(θ) * cos(ϕ) * x + sin(ϕ) * y + sin(θ) * cos(ϕ) * z
        let y2 = -cos(θ) * sin(ϕ) * x + cos(ϕ) * y - sin(θ) * sin(ϕ) * z
        let z2 = -sin(θ) * x + cos(θ) * z*/
        //return (asin(z2).radiansToDegrees, atan2(y2, x2).radiansToDegrees)
        
        // quick solution without conversion in cartesian space
        let lat2 = asin(cos(θ) * sin(lat) - cos(lon) * sin(θ) * cos(lat))
        let lon2 = atan2(sin(lon), tan(lat) * sin(θ) + cos(lon) * cos(θ)) - ϕ
        return (lat2.radiansToDegrees, lon2.radiansToDegrees)
    }
}
