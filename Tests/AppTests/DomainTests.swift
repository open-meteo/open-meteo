import Foundation
@testable import App
import Testing
// import Vapor

@Suite struct DomainTests {
    @Test func regularGridSlice() {
        let grid = RegularGrid(nx: 10, ny: 10, latMin: 10, lonMin: 10, dx: 0.1, dy: 0.1)
        let sub = RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<6)
        #expect(sub.map { $0 } == [14, 15, 24, 25])
        #expect(sub[0] == 14)
        #expect(sub[1] == 15)
        #expect(sub[2] == 24)
        #expect(sub[3] == 25)
        #expect(RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<4).map { $0 }.isEmpty)
        #expect(RegularGridSlice(grid: grid, yRange: 1..<1, xRange: 4..<6).map { $0 }.isEmpty)

        let slice = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 10.4..<10.6, longitude: 10.7..<10.9)) as! RegularGridSlice
        #expect(slice.yRange == 4..<6)
        #expect(slice.xRange == 7..<9)
        #expect(slice.map { $0 } == [47, 48, 57, 58])
    }

    @Test func gaussianGridSlice() {
        let grid = GaussianGrid(type: .o1280)
        let sub = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8..<8.5))!
        #expect(sub.map { $0 } == [823061, 823062, 823063, 823064, 825629, 825630, 825631, 825632])

        let sub2 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8.5..<9))!
        #expect(sub2.map { $0 } == [823065, 823066, 823067, 825633, 825634, 825635])

        let sub3 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 9..<9.5))!
        #expect(sub3.map { $0 } == [823068, 823069, 823070, 823071, 825636, 825637, 825638, 825639])
    }
}
