import Foundation
import Vapor

/// Planar polygons with holes, independent of CLI, grid and coordinate reference system.
/// Coordinates use Float storage; orientation and edge predicates use Double intermediates.
/// Outer rings must be counter-clockwise, holes clockwise. Self-intersections and hole topology
/// are not validated. Input is a JSON MultiPolygon coordinates array: `[[[[x, y], ...]], ...]`.
/// For geographic coordinates, x is longitude and y is latitude (GeoJSON order).
/// Geometry objects and single-polygon nesting are not accepted.
/// Uses westward even-odd ray casting: rectangles include lower bounds and exclude upper bounds.
struct Polygon: Sendable {
    typealias Position = (x: Float, y: Float)

    private struct Ring: Sendable {
        let range: Range<Int>
        let minX, maxX, minY, maxY: Float

        init(positions: ArraySlice<Position>) {
            range = positions.startIndex..<positions.endIndex
            var minX = positions.first!.x, maxX = minX
            var minY = positions.first!.y, maxY = minY
            for p in positions.dropFirst() {
                minX = min(minX, p.x)
                maxX = max(maxX, p.x)
                minY = min(minY, p.y)
                maxY = max(maxY, p.y)
            }
            self.minX = minX
            self.maxX = maxX
            self.minY = minY
            self.maxY = maxY
        }

        /// Twice the signed area, positive for counter-clockwise rings
        static func signedArea(positions: ArraySlice<Position>) -> Double {
            // Translate before multiplying to avoid cancellation for small rings far from zero.
            // Promote BEFORE subtraction: Float differences/products can lose the orientation.
            let origin = positions.first!
            var sum = 0.0, correction = 0.0
            for (a, b) in zip(positions, positions.dropFirst()) {
                let term = (Double(a.x) - Double(origin.x)) * (Double(b.y) - Double(origin.y))
                    - (Double(b.x) - Double(origin.x)) * (Double(a.y) - Double(origin.y))
                let adjusted = term - correction
                let next = sum + adjusted
                correction = (next - sum) - adjusted
                sum = next
            }
            return sum
        }

        /// Even-odd rule: an odd number of edges west of the point. The box test never rejects a point the edges would accept
        func contains(x: Float, y: Float, positions: [Position]) -> Bool {
            guard minY <= y, y < maxY, minX <= x, x <= maxX else {
                return false
            }
            var inside = false
            for i in range.dropLast() {
                let a = positions[i], b = positions[i + 1]
                guard (a.y > y) != (b.y > y) else { continue }
                // Compare cross products instead of dividing and adding an intersection to a.x.
                // Double retains the small residual near an edge that Float can round to zero.
                let dx = Double(b.x) - Double(a.x)
                let dy = Double(b.y) - Double(a.y)
                let cross = (Double(x) - Double(a.x)) * dy - (Double(y) - Double(a.y)) * dx
                if dy > 0 ? cross >= 0 : cross <= 0 {
                    inside.toggle()
                }
            }
            return inside
        }
    }

    /// One contiguous coordinate buffer; rings index positions, polygons index rings.
    /// The first ring in each polygon is its outer ring, the remaining rings are holes.
    private let positions: [Position]
    private let rings: [Ring]
    private let polygons: [Range<Int>]

    init(text: String) throws {
        do {
            let coordinates = try JSONDecoder().decode(Coordinates.self, from: Data(text.utf8))
            positions = coordinates.positions
            rings = coordinates.rings
            polygons = coordinates.polygons
        } catch let error as GeometryError {
            throw error
        } catch {
            throw GeometryError.invalidCoordinates(underlying: error)
        }
    }

    /// Validate a slice of the flat coordinate buffer without allocating a per-ring array.
    private static func validatedRing(coordinates: ArraySlice<Position>, polygon: Int, ring: Int) throws -> Ring {
        guard coordinates.count >= 4, coordinates.first! == coordinates.last! else {
            throw GeometryError.invalidRing(polygon: polygon, ring: ring)
        }
        guard coordinates.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            throw GeometryError.nonFiniteCoordinates(polygon: polygon, ring: ring)
        }
        let area = Ring.signedArea(positions: coordinates)
        guard area != 0 else {
            throw GeometryError.zeroArea(polygon: polygon, ring: ring)
        }
        guard (area > 0) == (ring == 0) else {
            throw GeometryError.invalidWinding(polygon: polygon, ring: ring)
        }
        return Ring(positions: coordinates)
    }

    func contains(x: Float, y: Float) -> Bool {
        polygons.contains { polygon in
            rings[polygon.lowerBound].contains(x: x, y: y, positions: positions)
                && !polygon.dropFirst().contains { rings[$0].contains(x: x, y: y, positions: positions) }
        }
    }

    enum GeometryError: Error, CustomStringConvertible {
        case invalidCoordinates(underlying: any Error)
        case emptyMultiPolygon
        case missingOuterRing(polygon: Int)
        case invalidPositionDimensions
        case invalidRing(polygon: Int, ring: Int)
        case nonFiniteCoordinates(polygon: Int, ring: Int)
        case zeroArea(polygon: Int, ring: Int)
        case invalidWinding(polygon: Int, ring: Int)

        var description: String {
            switch self {
            case .invalidCoordinates(let underlying):
                return "invalid MultiPolygon coordinates: \(underlying)"
            case .emptyMultiPolygon:
                return "at least one polygon is required"
            case .missingOuterRing(let polygon):
                return "polygon \(polygon) needs an outer ring"
            case .invalidPositionDimensions:
                return "positions must contain exactly two numbers [x, y]"
            case .invalidRing(let polygon, let ring):
                return "ring \(ring) of polygon \(polygon) needs at least four positions and the last must equal the first"
            case .nonFiniteCoordinates(let polygon, let ring):
                return "ring \(ring) of polygon \(polygon) positions must be finite Float values"
            case .zeroArea(let polygon, let ring):
                return "ring \(ring) of polygon \(polygon) must have a nonzero area"
            case .invalidWinding(let polygon, let ring):
                return "ring \(ring) of polygon \(polygon) must run \(ring == 0 ? "counter-clockwise" : "clockwise")"
            }
        }
    }

    /// Decode into flat buffers without constructing nested coordinate arrays.
    /// JSONDecoder enforces JSON number syntax, separators and trailing-input rules.
    private struct Coordinates: Decodable {
        let positions: [Position]
        let rings: [Ring]
        let polygons: [Range<Int>]

        init(from decoder: any Decoder) throws {
            var polygons = try decoder.unkeyedContainer()
            var decodedPositions = [Position]()
            var decodedRings = [Ring]()
            var decodedPolygons = [Range<Int>]()
            guard !polygons.isAtEnd else { throw GeometryError.emptyMultiPolygon }
            while !polygons.isAtEnd {
                let polygonIndex = polygons.currentIndex
                var rings = try polygons.nestedUnkeyedContainer()
                let firstRing = decodedRings.count
                guard !rings.isAtEnd else { throw GeometryError.missingOuterRing(polygon: polygonIndex) }
                while !rings.isAtEnd {
                    let ringIndex = rings.currentIndex
                    var positions = try rings.nestedUnkeyedContainer()
                    let start = decodedPositions.count
                    while !positions.isAtEnd {
                        var position = try positions.nestedUnkeyedContainer()
                        guard position.count == 2 else {
                            throw GeometryError.invalidPositionDimensions
                        }
                        let x = try position.decode(Float.self)
                        let y = try position.decode(Float.self)
                        decodedPositions.append((x, y))
                    }
                    decodedRings.append(try Polygon.validatedRing(coordinates: decodedPositions[start...], polygon: polygonIndex, ring: ringIndex))
                }
                decodedPolygons.append(firstRing..<decodedRings.count)
            }
            self.positions = decodedPositions
            self.rings = decodedRings
            self.polygons = decodedPolygons
        }
    }
}

extension Polygon.GeometryError: AbortError {
    var status: HTTPResponseStatus { .badRequest }

    var reason: String { description }
}
