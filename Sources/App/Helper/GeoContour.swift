import Foundation

/// A closed outline on the latitude/longitude plane, used by the `best_match` routing table to
/// limit a regional model to its home area.
///
/// Rings are outer rings only, given as flat longitude/latitude pairs; a point is inside when it
/// is inside any ring (even-odd rule). The test runs on plain lat/lon coordinates, which is
/// accurate for the coarse, buffered outlines this is used with as long as no ring crosses the
/// antimeridian. A bounding-box check rejects most points before any edge is visited.
struct GeoContour: Sendable {
    private let rings: [[SIMD2<Float>]]
    private let latitude: ClosedRange<Float>
    private let longitude: ClosedRange<Float>

    /// - Parameter flatRings: one array per ring of `[longitude, latitude, longitude, latitude, ...]`
    ///   with at least three vertices and without a repeated closing vertex.
    init(flatRings: [[Float]]) {
        rings = flatRings.map { flat in
            precondition(flat.count >= 6 && flat.count.isMultiple(of: 2), "A ring needs at least three longitude/latitude pairs")
            return stride(from: 0, to: flat.count, by: 2).map { SIMD2(flat[$0], flat[$0 + 1]) }
        }
        let vertices = rings.joined()
        let longitudes = vertices.map(\.x)
        let latitudes = vertices.map(\.y)
        longitude = (longitudes.min() ?? 0)...(longitudes.max() ?? 0)
        latitude = (latitudes.min() ?? 0)...(latitudes.max() ?? 0)
    }

    func contains(latitude lat: Float, longitude lon: Float) -> Bool {
        guard latitude.contains(lat), longitude.contains(lon) else {
            return false
        }
        var inside = false
        for ring in rings {
            var j = ring.count - 1
            for i in ring.indices {
                let a = ring[i]
                let b = ring[j]
                if (a.y > lat) != (b.y > lat) {
                    let crossing = (b.x - a.x) * (lat - a.y) / (b.y - a.y) + a.x
                    if lon < crossing {
                        inside.toggle()
                    }
                }
                j = i
            }
        }
        return inside
    }
}
