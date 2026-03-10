enum RegionGeometry {
    struct Point {
        let lat: Float
        let lon: Float
    }

    struct Triangle {
        let a: Point
        let b: Point
        let c: Point

        @inlinable
        func contains(lat: Float, lon: Float) -> Bool {
            @inline(__always)
            func cross(_ a: Point, _ b: Point, _ p: Point) -> Float {
                (p.lon - a.lon) * (b.lat - a.lat) - (p.lat - a.lat) * (b.lon - a.lon)
            }

            let p = Point(lat: lat, lon: lon)
            let d1 = cross(a, b, p)
            let d2 = cross(b, c, p)
            let d3 = cross(c, a, p)

            let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
            let hasPositive = d1 > 0 || d2 > 0 || d3 > 0

            return !(hasNegative && hasPositive)
        }
    }

    // Region checks used by best_match routing.
    @inlinable static func isInRectangle(lat: Float, lon: Float, latitude: Range<Float>, longitude: Range<Float>) -> Bool {
        latitude.contains(lat) && longitude.contains(lon)
    }
    
    static func isInUKVArea(lat: Float, lon: Float) -> Bool {
        let isInUkRectangle = RegionGeometry.isInRectangle(lat: lat, lon: lon, latitude: 49.9..<61, longitude: -11..<1.8)
        let channelTriangle = Triangle(
            a: Point(lat: 49.9, lon: -0.2),
            b: Point(lat: 49.9, lon: 1.8),
            c: Point(lat: 51.1, lon: 1.8)
        )
        let isInChannelCutOutTriangle = channelTriangle.contains(lat: lat, lon: lon)
        return isInUkRectangle && !isInChannelCutOutTriangle
    }
}

