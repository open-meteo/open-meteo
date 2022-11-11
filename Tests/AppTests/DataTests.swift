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
    
    func testLambertConformal() {
        let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5, ϕ2: 38.5)
        let pos = proj.forward(latitude: 47, longitude: -8)
        XCTAssertEqual(pos.x, 5833.868)
        XCTAssertEqual(pos.y, 8632.734)
        let coords = proj.inverse(x: pos.x, y: pos.y)
        XCTAssertEqual(coords.latitude, 47, accuracy: 0.0001)
        XCTAssertEqual(coords.longitude, -8, accuracy: 0.0001)
        
        let nam = LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        let pos2 = nam.findPoint(lat: 34, lon: -118)
        XCTAssertEqual(pos2, 777441)
        let coords2 = nam.getCoordinates(gridpoint: pos2!)
        XCTAssertEqual(coords2.latitude, 34, accuracy: 0.01)
        XCTAssertEqual(coords2.longitude, -118, accuracy: 0.1)
        
        /**
         Reference coordinates directly from grib files
         grid 0 lat 21.137999999999987 lon 237.28
         grid 10000 lat 24.449714395051082 lon 265.54789437771944
         grid 20000 lat 22.73382904757237 lon 242.93190409785294
         grid 30000 lat 24.37172305316154 lon 271.6307003393202
         grid 40000 lat 24.007414634071907 lon 248.77817290935954
         grid 50000 lat 23.92956253690586 lon 277.6758828800758
         grid 60000 lat 24.937347048060033 lon 254.77970943979457
         grid 70000 lat 23.130905651993345 lon 283.6325521390893
         grid 80000 lat 25.507667211833265 lon 260.89010896163796
         grid 90000 lat 22.73233463791032 lon 238.2565604901472
         grid 100000 lat 25.70845087988845 lon 267.05749210570485
         grid 110000 lat 24.27971890479045 lon 244.03343538654653
         grid 120000 lat 25.536179388163767 lon 273.2269959284081
         grid 130000 lat 25.49286327123711 lon 250.00358615972618
         grid 140000 lat 24.993872521998018 lon 279.34364486922533
         grid 150000 lat 26.351142186999365 lon 256.1244717049604
         grid 160000 lat 24.090974440586336 lon 285.35523633547
         grid 170000 lat 26.83968158648545 lon 262.34612554931914
         grid 180000 lat 24.32811370921869 lon 239.2705262869787
         */
        
        XCTAssertEqual(nam.findPoint(lat: 21.137999999999987, lon: 237.28), 0)
        XCTAssertEqual(nam.findPoint(lat: 24.449714395051082, lon: 265.54789437771944), 10000)
        XCTAssertEqual(nam.findPoint(lat: 22.73382904757237 , lon: 242.93190409785294), 20000)
        XCTAssertEqual(nam.findPoint(lat: 24.37172305316154, lon: 271.6307003393202), 30000)
        XCTAssertEqual(nam.findPoint(lat: 24.007414634071907, lon: 248.77817290935954), 40000)
        
        XCTAssertEqual(nam.getCoordinates(gridpoint: 0).latitude, 21.137999999999987, accuracy: 0.001)
        XCTAssertEqual(nam.getCoordinates(gridpoint: 0).longitude, 237.28 - 360, accuracy: 0.001)
        
        XCTAssertEqual(nam.getCoordinates(gridpoint: 10000).latitude, 24.449714395051082, accuracy: 0.001)
        XCTAssertEqual(nam.getCoordinates(gridpoint: 10000).longitude, 265.54789437771944 - 360, accuracy: 0.001)
        
        XCTAssertEqual(nam.getCoordinates(gridpoint: 20000).latitude, 22.73382904757237, accuracy: 0.001)
        XCTAssertEqual(nam.getCoordinates(gridpoint: 20000).longitude, 242.93190409785294 - 360, accuracy: 0.001)
        
        XCTAssertEqual(nam.getCoordinates(gridpoint: 30000).latitude, 24.37172305316154, accuracy: 0.001)
        XCTAssertEqual(nam.getCoordinates(gridpoint: 30000).longitude, 271.6307003393202 - 360, accuracy: 0.001)
        
        XCTAssertEqual(nam.getCoordinates(gridpoint: 40000).latitude, 24.007414634071907, accuracy: 0.001)
        XCTAssertEqual(nam.getCoordinates(gridpoint: 40000).longitude, 248.77817290935954 - 360, accuracy: 0.001)
    }
}
