import Testing
@testable import App

struct PolygonTests {
    @Test func multiplePolygonsWithHoles() throws {
        let polygon = try Polygon(text: "[[[[0,0],[4,0],[4,4],[0,4],[0,0]],[[1,1],[1,3],[3,3],[3,1],[1,1]]],[[[10,0],[14,0],[14,4],[10,4],[10,0]],[[11,1],[11,3],[13,3],[13,1],[11,1]]]]")
        #expect(polygon.contains(x: 0, y: 2))
        #expect(!polygon.contains(x: 2, y: 2))
        #expect(!polygon.contains(x: 7, y: 2))
        #expect(polygon.contains(x: 10, y: 2))
        #expect(!polygon.contains(x: 12, y: 2))
        #expect(polygon.contains(x: 13, y: 2))
        #expect(!polygon.contains(x: 14, y: 2))
    }

    /// Being inside a hole's bounding box does not imply being inside the hole.
    @Test func slopingHole() throws {
        let polygon = try Polygon(text: "[[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[5,2],[2,5],[5,8],[8,5],[5,2]]]]")
        #expect(polygon.contains(x: 2.5, y: 2.5))
        #expect(!polygon.contains(x: 5, y: 5))
    }

    @Test func smallRingFarFromOrigin() throws {
        // Naive Float shoelace products cancel to zero for a one-ULP-wide square.
        let x: Float = 130, y: Float = 30
        let ring: [Polygon.Position] = [(x, y), (x.nextUp, y), (x.nextUp, y.nextUp), (x, y.nextUp), (x, y)]
        let polygon = try Polygon(text: "[[[" + ring.map { "[\($0.x),\($0.y)]" }.joined(separator: ",") + "]]]")
        #expect(polygon.contains(x: x, y: y))
        #expect(!polygon.contains(x: x.nextUp, y: y))
        #expect(!polygon.contains(x: x, y: y.nextUp))
        #expect(throws: Polygon.GeometryError.self) { try Polygon(text: "[[[" + ring.reversed().map { "[\($0.x),\($0.y)]" }.joined(separator: ",") + "]]]") }
    }

    @Test func nearlyCollinearEdge() throws {
        let one: Float = 1
        let polygon = try Polygon(text: "[[[[0,0], [\(one.nextUp),1], [0,2], [0,0]]]]")
        // Float rounds both cross products to 1, wrongly putting this interior point on the edge.
        #expect(polygon.contains(x: 1, y: one.nextDown))
        #expect(!polygon.contains(x: one.nextUp, y: one.nextDown))
    }

    @Test func diagonalBoundaryAndWinding() throws {
        let polygon = try Polygon(text: "[[[[0,0], [4,0], [0,4], [0,0]]]]")
        #expect(polygon.contains(x: 0, y: 0))
        #expect(polygon.contains(x: 0, y: 2))
        #expect(!polygon.contains(x: 2, y: 2))
        #expect(polygon.contains(x: Float(2).nextDown, y: 2))
        #expect(!polygon.contains(x: Float(2).nextUp, y: 2))
        #expect(!polygon.contains(x: .nan, y: 2))
        #expect(!polygon.contains(x: 2, y: .infinity))
    }

    @Test(arguments: ["1e100", "nan", "inf", "-inf"])
    func nonFiniteCoordinates(value: String) {
        #expect(throws: Polygon.GeometryError.self) {
            try Polygon(text: "[[[[0,0], [\(value),0], [1,1], [0,0]]]]")
        }
    }

    @Test(arguments: [
        "", "[]", "[[]]", "[[[]]]", "[[[[]]]]",
        "(((0 0, 1 0, 1 1, 0 0)))",
        "[[[0,0],[1,0],[1,1],[0,0]]]",
        "[[[[0,0],[1,0],[1,1],[0,1]]]]", // Unclosed ring.
        "[[[[0,0],[1,0],[0,0]]]]", // Too few positions.
        "[[[[0,0,0],[1,0],[1,1],[0,0]]]]",
        "[[[[0],[1,0],[1,1],[0,0]]]]",
        "[[[[null,0],[1,0],[1,1],[0,0]]]]",
        "[[[[true,0],[1,0],[1,1],[0,0]]]]",
        #"[[[["0",0],[1,0],[1,1],[0,0]]]]"#,
        #"{"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,0]]]]}"#,
        "((0 0, 1 0, 1 1, 0 0))",
        "POLYGON ((0 0, 1 0, 1 1, 0 0))",
        "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)))"
    ])
    func invalidSyntax(text: String) {
        #expect(throws: Polygon.GeometryError.self) { try Polygon(text: text) }
    }

    @Test func collapsedRing() {
        // A ring that collapses at Float precision must fail, rather than silently select no cells.
        #expect(throws: Polygon.GeometryError.self) {
            try Polygon(text: "[[[[130,30], [130.0000001,30], [130.0000001,30.0000001], [130,30]]]]")
        }
    }

    @Test func parsingAndPlanarCoordinates() throws {
        let polygon = try Polygon(text: " \n [[[[1000,2000],[1002,2000],[1002,2002],[1000,2002],[1000,2000]]]]\t")
        #expect(polygon.contains(x: 1001, y: 2001))
        #expect(throws: Polygon.GeometryError.self) {
            try Polygon(text: "[[[[0,0], [1,0], [1,1], [0,0]]]] trailing")
        }
    }
}
