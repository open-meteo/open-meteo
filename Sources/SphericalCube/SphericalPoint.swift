import Foundation

/// Float representation used by the hot lookup path.
///
/// Query and artifact vectors use the same precision so candidate distances require no
/// Float-to-Double conversion. `point` is used by cube geometry and coordinate conversion.
struct SphericalLookupVector: Sendable {
    let x: Float
    let y: Float
    let z: Float

    var point: SphericalPoint {
        SphericalPoint(x: Double(x), y: Double(y), z: Double(z))
    }
}

/// Three-dimensional direction on the unit sphere.
///
/// Generation uses Double. Artifacts and runtime candidate comparisons use Float32; coordinate
/// access promotes and normalizes stored values before converting them back to latitude/longitude.
package struct SphericalPoint: Sendable, Equatable {
    /// ICON's spherical Earth radius in metres.
    package static let earthRadiusMeters: Double = 6_371_229

    /// Converts a surface distance using ICON's Earth radius to squared chord distance on the unit sphere.
    package static func squaredChordDistance(meters: Double) -> Float {
        let chord = 2 * sin(meters / earthRadiusMeters * 0.5)
        return Float(chord * chord)
    }

    private static let degreesToRadians = Double.pi / 180
    private static let degreesToRadiansFloat = Float.pi / 180

    let x: Double
    let y: Double
    let z: Double

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Converts geographic radians to a Cartesian unit direction.
    package init(latitudeRadians: Double, longitudeRadians: Double) {
        let latitudeCosine = cos(latitudeRadians)
        self.init(
            x: latitudeCosine * cos(longitudeRadians),
            y: latitudeCosine * sin(longitudeRadians),
            z: sin(latitudeRadians)
        )
    }

    init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.init(
            latitudeRadians: latitudeDegrees * Self.degreesToRadians,
            longitudeRadians: longitudeDegrees * Self.degreesToRadians
        )
    }

    /// Converts geographic degrees directly to the Float representation used by nearest lookup.
    /// Geographic lookup inputs are Float, matching the stored point precision.
    @inline(__always) static func fastLookupVector(
        latitudeDegrees: Float,
        longitudeDegrees: Float
    ) -> SphericalLookupVector {
        let latitude = latitudeDegrees * Self.degreesToRadiansFloat
        let longitude = longitudeDegrees * Self.degreesToRadiansFloat
        let latitudeCosine = cos(latitude)
        return SphericalLookupVector(
            x: latitudeCosine * cos(longitude),
            y: latitudeCosine * sin(longitude),
            z: sin(latitude)
        )
    }

    /// Converts the direction back to geographic degrees.
    package var coordinate: (latitude: Float, longitude: Float) {
        (
            latitude: Float(asin(max(-1, min(1, z))) * 180 / .pi),
            longitude: Float(atan2(y, x) * 180 / .pi)
        )
    }

    @inline(__always) func dot(_ other: Self) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    @inline(__always) func squaredDistance(to other: Self) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return dx * dx + dy * dy + dz * dz
    }

    /// Wraps any finite longitude to `[-180, 180)` without changing values already in that range.
    @inline(__always) static func normalizedLongitude(_ longitude: Float) -> Float {
        if longitude >= -180, longitude < 180 { return longitude }
        var wrapped = longitude.truncatingRemainder(dividingBy: 360)
        if wrapped < -180 { wrapped += 360 }
        if wrapped >= 180 { wrapped -= 360 }
        return wrapped
    }
}
