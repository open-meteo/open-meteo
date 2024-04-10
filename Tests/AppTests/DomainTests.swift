import Foundation
@testable import App
import XCTest
//import Vapor


final class DomainTests: XCTestCase {
    func testRegularGridSlice() {
        let grid = RegularGrid(nx: 10, ny: 10, latMin: 10, lonMin: 10, dx: 0.1, dy: 0.1)
        let sub = RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<6)
        XCTAssertEqual(sub.map{$0}, [14, 15, 24, 25])
        XCTAssertTrue(RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<4).map{$0}.isEmpty)
        XCTAssertTrue(RegularGridSlice(grid: grid, yRange: 1..<1, xRange: 4..<6).map{$0}.isEmpty)
        
        let slice = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 10.4..<10.6, longitude: 10.7..<10.9)) as! RegularGridSlice
        XCTAssertEqual(slice.yRange, 4..<6)
        XCTAssertEqual(slice.xRange, 7..<9)
        XCTAssertEqual(slice.map{$0}, [47, 48, 57, 58])
    }
}
