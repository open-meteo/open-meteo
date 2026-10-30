/// A region tested with WGS84 coordinates in degrees.
/// Callers normalize longitude to -180..<180 before testing grid coordinates.
protocol GeographicRegion: Sendable {
    func contains(latitude: Float, longitude: Float) -> Bool
}

extension BoundingBoxWGS84: GeographicRegion {
    func contains(latitude: Float, longitude: Float) -> Bool {
        self.latitude.contains(latitude) && self.longitude.contains(longitude)
    }
}

extension Polygon: GeographicRegion {
    func contains(latitude: Float, longitude: Float) -> Bool {
        contains(x: longitude, y: latitude)
    }
}
