import Foundation

/// Stored Float32 direction. Construction preserves the supplied component bit patterns.
/// Latitude/longitude bands select candidate buckets; Cartesian directions make distance
/// comparisons cheap: squared chord distance needs only subtraction, multiplication, and addition,
/// with no per-candidate trigonometry or square root. On the unit sphere it has the same ordering
/// as great-circle distance, subject to Float32 rounding, and naturally handles poles and the dateline.
package struct ReducedLatLonPoint: Sendable, Equatable {
    /// Cartesian component towards latitude 0°, longitude 0°.
    package let x: Float
    /// Cartesian component towards latitude 0°, longitude 90° east.
    package let y: Float
    /// Cartesian component towards the north pole.
    package let z: Float

    /// Stores components without normalization. The artifact writer validates their unit norm.
    package init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Converts geographic radians to a unit direction using Double trigonometry, rounded to Float32.
    /// Callers supply finite coordinates, with latitude within [-π/2, π/2].
    package init(latitudeRadians: Double, longitudeRadians: Double) {
        self.init(x: Float(cos(latitudeRadians) * cos(longitudeRadians)),
                  y: Float(cos(latitudeRadians) * sin(longitudeRadians)), z: Float(sin(latitudeRadians)))
    }

    var radians: (latitude: Double, longitude: Double) {
        (atan2(Double(z), hypot(Double(x), Double(y))), atan2(Double(y), Double(x)))
    }

    /// Converts the stored direction to latitude/longitude in degrees, independent of radial rounding.
    package var coordinate: (latitude: Float, longitude: Float) {
        let angles = radians
        return (Float(angles.latitude * 180 / .pi), Float(angles.longitude * 180 / .pi))
    }

    @inline(__always) static func query(latitude: Float, longitude: Float) -> Self {
        queryWithCosine(latitude: latitude, longitude: longitude).point
    }

    @inline(__always) static func queryWithCosine(latitude: Float, longitude: Float) -> (point: Self, cosine: Double) {
        let latitude = latitude * (Float.pi / 180)
        let longitude = longitude * (Float.pi / 180)
        let cosine = cos(latitude)
        // A lower bound for the cosine at the original geographic latitude, including
        // the Float degree/radian conversion and libm rounding. Reused by both searches.
        return (Self(x: cosine * cos(longitude), y: cosine * sin(longitude), z: sin(latitude)),
                max(0, Double(abs(cosine)) - 4 * Double(Float.ulpOfOne)))
    }

    @inline(__always) static func normalizeLongitude(_ value: Float) -> Float {
        if value >= -180, value < 180 { return value }
        var wrapped = value.truncatingRemainder(dividingBy: 360)
        if wrapped < -180 { wrapped += 360 }
        if wrapped >= 180 { wrapped -= 360 }
        return wrapped
    }

    @inline(__always) func squaredDistance(to other: Self) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return dx * dx + dy * dy + dz * dz
    }
}
