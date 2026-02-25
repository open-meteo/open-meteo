enum RegionGeometry {
    struct Point {
        let lat: Float
        let lon: Float
    }

    struct Triangle {
        let a: Point
        let b: Point
        let c: Point
    }

    // Region checks used by best_match routing.
    @inlinable static func isInRectangle(lat: Float, lon: Float, latitude: Range<Float>, longitude: Range<Float>) -> Bool {
        latitude.contains(lat) && longitude.contains(lon)
    }

    @inlinable static func isInTriangle(
        lat: Float,
        lon: Float,
        triangle: Triangle
    ) -> Bool {
        @inline(__always)
        func cross(
            _ a: (x: Float, y: Float),
            _ b: (x: Float, y: Float),
            _ p: (x: Float, y: Float)
        ) -> Float {
            (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x)
        }

        let p = (x: lon, y: lat)
        let a = (x: triangle.a.lon, y: triangle.a.lat)
        let b = (x: triangle.b.lon, y: triangle.b.lat)
        let c = (x: triangle.c.lon, y: triangle.c.lat)

        let d1 = cross(a, b, p)
        let d2 = cross(b, c, p)
        let d3 = cross(c, a, p)

        let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
        let hasPositive = d1 > 0 || d2 > 0 || d3 > 0

        // Inside or on edge when all signs are consistent.
        return !(hasNegative && hasPositive)
    }
    
    static func isInUKVArea(lat: Float, lon: Float) -> Bool {
        let isInUkRectangle = RegionGeometry.isInRectangle(lat: lat, lon: lon, latitude: 49.9..<61, longitude: -11..<1.8)
        let channelTriangle = Triangle(
            a: Point(lat: 49.9, lon: -0.2),
            b: Point(lat: 49.9, lon: 1.8),
            c: Point(lat: 51.1, lon: 1.8)
        )
        let isInChannelCutOutTriangle = RegionGeometry.isInTriangle(lat: lat, lon: lon, triangle: channelTriangle)
        return isInUkRectangle && !isInChannelCutOutTriangle
    }
}


