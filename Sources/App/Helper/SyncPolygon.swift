/**
 Multipolygon in WGS84 for `sync --polygon`, written as well-known text (WKT) with `longitude latitude` positions:
 `POLYGON ((130 30, 131 30, 131 31, 130 31, 130 30))` is one polygon with one ring, `MULTIPOLYGON (((...)), ((...)))` holds several.
 The first ring of a polygon is the outer ring, the others are holes.
 Outer rings run counter-clockwise and holes clockwise, which is checked while parsing. Polygons must not cross the 180th meridian.

 Like `BoundingBoxWGS84`, a point on the lower bound is inside and a point on the upper bound is outside.
 Every ring and every polygon keeps its bounding box, so most points are decided without visiting the edges.
 */
struct SyncPolygon: Sendable {
    typealias Position = (lon: Double, lat: Double)

    private struct Ring: Sendable {
        let positions: [Position]
        let minLon, maxLon, minLat, maxLat: Double

        init(positions: [Position]) {
            self.positions = positions
            minLon = positions.map(\.lon).min()!
            maxLon = positions.map(\.lon).max()!
            minLat = positions.map(\.lat).min()!
            maxLat = positions.map(\.lat).max()!
        }

        /// Twice the signed area, positive for counter-clockwise rings
        var signedArea: Double {
            zip(positions, positions.dropFirst()).reduce(0) { $0 + $1.0.lon * $1.1.lat - $1.1.lon * $1.0.lat }
        }

        /// Even-odd rule: an odd number of edges west of the point. The box test never rejects a point the edges would accept
        func contains(latitude: Double, longitude: Double) -> Bool {
            guard minLat <= latitude, latitude < maxLat, minLon <= longitude, longitude <= maxLon else {
                return false
            }
            var inside = false
            for (a, b) in zip(positions, positions.dropFirst()) where (a.lat > latitude) != (b.lat > latitude) {
                if a.lon + (latitude - a.lat) * (b.lon - a.lon) / (b.lat - a.lat) <= longitude {
                    inside.toggle()
                }
            }
            return inside
        }
    }

    private let polygons: [(outer: Ring, holes: [Ring])]

    /// The text itself, or `@path` to a file holding it
    init(argument: String) throws {
        guard argument.hasPrefix("@") else {
            try self.init(text: argument)
            return
        }
        do {
            try self.init(text: try String(contentsOfFile: String(argument.dropFirst()), encoding: .utf8))
        } catch {
            throw Self.error("cannot read the file \(argument.dropFirst()): \(error)")
        }
    }

    init(text: String) throws {
        var parser = Parser(text: text)
        polygons = try parser.geometry().enumerated().map { p, rings in
            let rings = try rings.enumerated().map { r, positions in
                let name = "ring \(r) of polygon \(p)"
                guard positions.count >= 4, positions.first! == positions.last! else {
                    throw Self.error("\(name) needs at least four positions and the last must equal the first")
                }
                let ring = Ring(positions: positions)
                guard ring.signedArea != 0, (ring.signedArea > 0) == (r == 0) else {
                    throw Self.error("\(name) must have an area and run \(r == 0 ? "counter-clockwise" : "clockwise")")
                }
                return ring
            }
            return (rings[0], Array(rings.dropFirst()))
        }
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        polygons.contains { polygon in
            polygon.outer.contains(latitude: latitude, longitude: longitude)
                && !polygon.holes.contains { $0.contains(latitude: latitude, longitude: longitude) }
        }
    }

    private static func error(_ message: String) -> ForecastApiError {
        .generic(message: "--polygon: \(message)")
    }

    /// Recursive descent over WKT split into words, parentheses and commas
    private struct Parser {
        var tokens: [Substring]
        var index = 0

        init(text: String) {
            tokens = String(text.flatMap { "(),".contains($0) ? [" ", $0, " "] : [$0] }).split(whereSeparator: \.isWhitespace)
        }

        func fail(_ expected: String) -> ForecastApiError {
            SyncPolygon.error("expected \(expected) at word \(index), found '\(index < tokens.count ? String(tokens[index]) : "the end")'")
        }

        mutating func take(_ token: String) -> Bool {
            guard index < tokens.count, tokens[index] == token else {
                return false
            }
            index += 1
            return true
        }

        /// `POLYGON` or `MULTIPOLYGON`, as a list of polygons
        mutating func geometry() throws -> [[[Position]]] {
            let polygons: [[[Position]]]
            switch tokens.first?.uppercased() {
            case "POLYGON": index = 1; polygons = [try polygon()]
            case "MULTIPOLYGON": index = 1; polygons = try list { try $0.polygon() }
            default: throw fail("POLYGON or MULTIPOLYGON")
            }
            guard index == tokens.count else {
                throw fail("the end")
            }
            return polygons
        }

        mutating func polygon() throws -> [[Position]] {
            try list { try $0.list { try $0.position() } }
        }

        /// `(item, item, ...)`
        mutating func list<T>(_ item: (inout Parser) throws -> T) throws -> [T] {
            guard take("(") else {
                throw fail("'('")
            }
            var items = [T]()
            repeat {
                items.append(try item(&self))
            } while take(",")
            guard take(")") else {
                throw fail("',' or ')', the parentheses may be unbalanced")
            }
            return items
        }

        /// `longitude latitude`
        mutating func position() throws -> Position {
            guard index + 1 < tokens.count, let lon = Double(tokens[index]), let lat = Double(tokens[index + 1]), lon.isFinite, lat.isFinite else {
                throw fail("a position 'longitude latitude'")
            }
            index += 2
            // Grid coordinates are Float, so a bound written as 30.3 meets the row at Float 30.3
            return (Double(Float(lon)), Double(Float(lat)))
        }
    }
}
