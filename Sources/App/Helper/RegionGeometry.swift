enum RegionGeometry {
    // Region checks used by best_match routing.
    @inlinable static func isInRectangle(lat: Float, lon: Float, latitude: Range<Float>, longitude: Range<Float>) -> Bool {
        latitude.contains(lat) && longitude.contains(lon)
    }

    @inlinable static func isInTriangle(
        lat: Float,
        lon: Float,
        a: (lat: Float, lon: Float),
        b: (lat: Float, lon: Float),
        c: (lat: Float, lon: Float)
    ) -> Bool {
        let p = (x: lon, y: lat)
        let a = (x: a.lon, y: a.lat)
        let b = (x: b.lon, y: b.lat)
        let c = (x: c.lon, y: c.lat)

        let denominator = ((b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y))
        if denominator == 0 {
            return false
        }

        let alpha = ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / denominator
        let beta = ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / denominator
        let gamma = 1 - alpha - beta

        return alpha >= 0 && beta >= 0 && gamma >= 0
    }
}
