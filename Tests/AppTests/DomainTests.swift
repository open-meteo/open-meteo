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
    
    func testExcludeGridPointsRegular() {
        let grid = RegularGrid(nx: 390, ny: 390, latMin: 49, lonMin: 0, dx: 0.029, dy: 0.018)
        let hamburg = grid.findPointXy(lat: 53.5507, lon: 9.993)
        XCTAssertEqual(hamburg?.x, 345)
        XCTAssertEqual(hamburg?.y, 253)
        
        let grid2 = RegularGrid(nx: 390, ny: 390, latMin: 49, lonMin: 0, dx: 0.029, dy: 0.018, excludeBorderPixel: 50)
        XCTAssertNil(grid2.findPointXy(lat: 53.5507, lon: 9.993))
    }
    
    func testExcludeGridPointsProjection() {
        let grid = ProjectionGrid(
            nx: 676,
            ny: 564,
            latitude: 39.740627...62.619324,
            longitude: -25.162262...38.75702,
            projection: RotatedLatLonProjection(latitude: -35, longitude: -8)
        )
        let pos = grid.findPointXy(lat: 53.5507, lon: 19.993)
        XCTAssertEqual(pos?.x, 594)
        XCTAssertEqual(pos?.y, 308)
        
        let grid2 = ProjectionGrid(
            nx: 676,
            ny: 564,
            latitude: 39.740627...62.619324,
            longitude: -25.162262...38.75702,
            projection: RotatedLatLonProjection(latitude: -35, longitude: -8),
            excludeBorderPixel: 100
        )
        XCTAssertNil(grid2.findPointXy(lat: 53.5507, lon: 19.993))
    }
}
