import Foundation
@testable import App
import Testing
import OmFileFormat

@Suite struct IconHhlTests {
    /// Verifies `readColumnFromStaticFile` against the exact layout `convertHhlHeights` writes:
    /// a 3D `[ny, nx, nlev]` file with the level dimension last, stacked as
    /// `index = (y*nx + x) * nlev + lev`. The column read at a grid point must return all
    /// `nlev` values for that point in level order (top..surface), proving the indexing,
    /// gridpoint→(x,y) mapping and the single-I/O range read.
    @Test func readColumnFromStatic3D() async throws {
        let ny = 2, nx = 3, nlev = 4
        // value(y,x,lev) = lev*1000 + (y*nx + x)  → uniquely identifies level and location
        var data = [Float](repeating: .nan, count: ny * nx * nlev)
        for y in 0..<ny {
            for x in 0..<nx {
                let sp = y * nx + x
                for lev in 0..<nlev {
                    data[sp * nlev + lev] = Float(lev * 1000 + sp)
                }
            }
        }

        let file = "test_hhl_3d.om"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try? FileManager.default.removeItem(atPath: file) }
        try data.writeOmFile(file: file, dimensions: [ny, nx, nlev], chunks: [ny, nx, nlev], compression: .pfor_delta2d, scalefactor: 1)

        let reader = try await OmFileReader(file: file).expectArray(of: Float.self)
        let grid = RegularGrid(nx: nx, ny: ny, latMin: 0, lonMin: 0, dx: 1, dy: 1)

        // grid point (y=1, x=1) → gridpoint 4 → expected [4, 1004, 2004, 3004]
        let column = try await grid.readColumnFromStaticFile(gridpoint: 4, file: reader)
        #expect(column == [4, 1004, 2004, 3004])

        // corner (y=0, x=0) → gridpoint 0 → [0, 1000, 2000, 3000]
        let corner = try await grid.readColumnFromStaticFile(gridpoint: 0, file: reader)
        #expect(corner == [0, 1000, 2000, 3000])

        // last point (y=1, x=2) → gridpoint 5 → [5, 1005, 2005, 3005]
        let last = try await grid.readColumnFromStaticFile(gridpoint: 5, file: reader)
        #expect(last == [5, 1005, 2005, 3005])
    }

    /// Full-level height = mean of the two enclosing half levels (PDF formula).
    /// Pure-arithmetic guard so the derivation contract stays explicit independent of the reader.
    @Test func fullLevelIsMeanOfHalves() {
        let halfAsl: [Float] = [22000, 19402, 18013, 531]   // top..surface
        func fullAsl(_ fullLevel: Int) -> Float { (halfAsl[fullLevel - 1] + halfAsl[fullLevel]) / 2 }
        #expect(fullAsl(1) == (22000 + 19402) / 2)
        #expect(fullAsl(3) == (18013 + 531) / 2)
    }
}
