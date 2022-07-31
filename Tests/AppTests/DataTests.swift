import Foundation
@testable import App
import XCTest


final class DataTests: XCTestCase {
    override func setUp() {
        #if Xcode
        let projectHome = String(#file[...#file.range(of: "/Tests/")!.lowerBound])
        FileManager.default.changeCurrentDirectoryPath(projectHome)
        #endif
    }
    
    func testDem90() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Dem90.omDirectory), "Elevation information unavailable")
        
        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.670080), 991)
        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.669093), 1028)
        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.670988), 1001)
        // island
        XCTAssertEqual(try Dem90.read(lat: 65.03738, lon: -17.75940), 715)
        // greenland
        XCTAssertEqual(try Dem90.read(lat: 72.71190, lon: -31.81641), 2878.0)
        // bolivia
        XCTAssertEqual(try Dem90.read(lat: -15.11455, lon: -65.74219), 171)
        // antarctica
        XCTAssertEqual(try Dem90.read(lat: -70.52490, lon: -65.30273), 1509)
        XCTAssertEqual(try Dem90.read(lat: -80.95610, lon: -70.66406), 253)
        XCTAssertEqual(try Dem90.read(lat: -81.20142, lon: 2.10938), 2389)
        XCTAssertEqual(try Dem90.read(lat: -80.58973, lon: 108.28125), 3388)
    }
    
    func testElevationMatching() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Dem90.omDirectory), "Elevation information unavailable")
        
        let optimised = try IconDomains.iconD2.grid.findPointTerrainOptimised(lat: 46.88, lon: 8.67, elevation: 650, elevationFile: IconDomains.iconD2.elevationFile!)!
        XCTAssertEqual(optimised.gridpoint, 225405)
        XCTAssertEqual(optimised.gridElevation, 600)
        
        let nearest = try IconDomains.iconD2.grid.findPointNearest(lat: 46.88, lon: 8.67, elevationFile: IconDomains.iconD2.elevationFile!)!
        XCTAssertEqual(nearest.gridpoint, 225406)
        XCTAssertEqual(nearest.gridElevation, 1006.0)
    }
}
