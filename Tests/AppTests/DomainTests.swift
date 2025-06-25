import Foundation
@testable import App
import XCTest
// import Vapor

final class DomainTests: XCTestCase {
    func testRegularGridSlice() {
        let grid = RegularGrid(nx: 10, ny: 10, latMin: 10, lonMin: 10, dx: 0.1, dy: 0.1)
        let sub = RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<6)
        XCTAssertEqual(sub.map { $0 }, [14, 15, 24, 25])
        XCTAssertEqual(sub[0], 14)
        XCTAssertEqual(sub[1], 15)
        XCTAssertEqual(sub[2], 24)
        XCTAssertEqual(sub[3], 25)
        XCTAssertTrue(RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<4).map { $0 }.isEmpty)
        XCTAssertTrue(RegularGridSlice(grid: grid, yRange: 1..<1, xRange: 4..<6).map { $0 }.isEmpty)

        let slice = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 10.4..<10.6, longitude: 10.7..<10.9)) as! RegularGridSlice
        XCTAssertEqual(slice.yRange, 4..<6)
        XCTAssertEqual(slice.xRange, 7..<9)
        XCTAssertEqual(slice.map { $0 }, [47, 48, 57, 58])
    }

    func testGaussianGridSlice() {
        let grid = GaussianGrid(type: .o1280)
        let sub = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8..<8.5))!
        XCTAssertEqual(sub.map { $0 }, [823061, 823062, 823063, 823064, 825629, 825630, 825631, 825632])

        let sub2 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8.5..<9))!
        XCTAssertEqual(sub2.map { $0 }, [823065, 823066, 823067, 825633, 825634, 825635])

        let sub3 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 9..<9.5))!
        XCTAssertEqual(sub3.map { $0 }, [823068, 823069, 823070, 823071, 825636, 825637, 825638, 825639])
    }

    func testProj4StringForKnownDomains() {
        let iconProj4 = IconDomains.icon.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(iconProj4, "+proj=longlat +units=m +datum=WGS84 +no_defs +type=crs")

        let aromeProj4 = MeteoFranceDomain.arome_france.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(aromeProj4, "+proj=longlat +units=m +datum=WGS84 +no_defs +type=crs")

        let cmcGemContinentalProj4 = GemDomain.gem_hrdps_continental.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(cmcGemContinentalProj4, "+proj=ob_tran +o_lat_p=36.0885 +o_lon_p=0.0 +lon_1=245.305 +units=m +datum=WGS84 +no_defs +type=crs")

        let cmcGemRegionalProj4 = GemDomain.gem_regional.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(cmcGemRegionalProj4, "+proj=stere +lat_0=57.295784 +lon_0=249.0 +R=6371229.0 +units=m +datum=WGS84 +no_defs +type=crs")

        let dmiHarmonieProj4 = DmiDomain.harmonie_arome_europe.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(dmiHarmonieProj4, "+proj=lcc +lat_1=55.5 +lat_0=55.5 +lon_0=352.0 +x_0=0.0 +y_0=0.0 +R=6371229.0 +units=m +datum=WGS84 +no_defs +type=crs")
    
        let ukmoRegionalDeterministicProj4 = UkmoDomain.uk_deterministic_2km.grid.cfProjectionParameters.toProj4String()
        XCTAssertEqual(ukmoRegionalDeterministicProj4, "+proj=laea +lon_0=-2.5 +lat_0=54.9 +x_0=0.0 +y_0=0.0 +R=6371229.0 +units=m +datum=WGS84 +no_defs +type=crs")
    }
}
