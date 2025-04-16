import Foundation
@testable import App
import XCTest
// import NIOFileSystem

final class DataTests: XCTestCase {
    override func setUp() {
        #if Xcode
        let projectHome = String(#file[...#file.range(of: "/Tests/")!.lowerBound])
        FileManager.default.changeCurrentDirectoryPath(projectHome)
        #endif
    }

    /*func testGribDecode() throws {
        let file = "/Users/patrick/Downloads/_mars-bol-webmars-private-svc-blue-010-7a527896970b09a4fc90fa37bf98d3ff-wvAa7C.grib"
        //let file = "/Users/patrick/Downloads/Z__C_RJTD_20240909060000_MSM_GPV_Rjp_Lsurf_FH00-15_grib2.bin"
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        data.withUnsafeBytes({ ptr in
            var offset = 0
            while offset < ptr.count {
                let mem = UnsafeRawBufferPointer(rebasing: ptr[offset..<ptr.count])
                guard let s = GribAsyncStreamHelper.seekGrib(memory: mem) else {
                    break
                }
                print(s)
                offset += s.offset + s.length
            }

        })
    }*/

    /*func testGribStream() async throws {
        let url = "/Users/patrick/Downloads/_mars-bol-webmars-private-svc-blue-009-d4755d5b313f7cded016e66ba0cd989b-hyELHH.grib"
        let fileSystem = FileSystem.shared
        
        try await fileSystem.withFileHandle(forReadingAt: FilePath(url)) { fn in
            for try await message in fn.readChunks().decodeGrib() {
                print(message.get(attribute: "shortName")!)
            }
        }
    }*/

    func testDem90() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: DomainRegistry.copernicus_dem90.directory), "Elevation information unavailable")

        XCTAssertEqual(try Dem90.read(lat: -32.878000, lon: 28.101000), 25) // beach, SE south africa
        XCTAssertEqual(try Dem90.read(lat: -32.878000, lon: 28.120000), 0) // water, SE south africa

        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.670080), 991)
        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.669093), 1028)
        XCTAssertEqual(try Dem90.read(lat: 46.885748, lon: 8.670988), 1001)
        // island
        XCTAssertEqual(try Dem90.read(lat: 65.03738, lon: -17.75940), 715)
        // greenland
        XCTAssertEqual(try Dem90.read(lat: 72.71190, lon: -31.81641), 2878.0)
        // bolivia
        XCTAssertEqual(try Dem90.read(lat: -15.11455, lon: -65.74219), 162.0)
        // antarctica
        XCTAssertEqual(try Dem90.read(lat: -70.52490, lon: -65.30273), 1749.0)
        XCTAssertEqual(try Dem90.read(lat: -80.95610, lon: -70.66406), 124.0)
        XCTAssertEqual(try Dem90.read(lat: -81.20142, lon: 2.10938), 2342.0)
        XCTAssertEqual(try Dem90.read(lat: -80.58973, lon: 108.28125), 3348.0)
    }

    func testRegularGrid() {
        let grid = RegularGrid(nx: 768, ny: 384, latMin: -90, lonMin: -180, dx: 360 / 768, dy: 180 / 384)

        // Exactly on the border
        let pos = grid.findPoint(lat: 89.90001, lon: 179.80002)!
        let (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 0)
        XCTAssertEqual(lat, -90.0, accuracy: 0.001)
        XCTAssertEqual(lon, -180.0, accuracy: 0.001)

        let pos2 = IconDomains.icon.grid.findPoint(lat: -16.805414, lon: 179.990623)!
        let (lat2, lon2) = IconDomains.icon.grid.getCoordinates(gridpoint: pos2)
        XCTAssertEqual(pos2, 1687095)
        XCTAssertEqual(lat2, -16.75, accuracy: 0.001)
        XCTAssertEqual(lon2, -179.875, accuracy: 0.001)
    }

    func testElevationMatching() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: DomainRegistry.copernicus_dem90.directory), "Elevation information unavailable")

        let optimised = try IconDomains.iconD2.grid.findPointTerrainOptimised(lat: 46.88, lon: 8.67, elevation: 650, elevationFile: IconDomains.iconD2.getStaticFile(type: .elevation)!)!
        XCTAssertEqual(optimised.gridpoint, 225405)
        XCTAssertEqual(optimised.gridElevation.numeric, 600)

        let nearest = try IconDomains.iconD2.grid.findPointNearest(lat: 46.88, lon: 8.67, elevationFile: IconDomains.iconD2.getStaticFile(type: .elevation)!)!
        XCTAssertEqual(nearest.gridpoint, 225406)
        XCTAssertEqual(nearest.gridElevation.numeric, 1006.0)
    }

    func testNbmGrid() {
        // https://vlab.noaa.gov/web/mdl/nbm-grib2-v4.0
        let proj = LambertConformalConicProjection(λ0: 265 - 360, ϕ0: 0, ϕ1: 25, ϕ2: 25, radius: 6371200)
        let grid = ProjectionGrid(nx: 2345, ny: 1597, latitude: 19.229, longitude: 233.723 - 360, dx: 2539.7, dy: 2539.7, projection: proj)
        let pos = proj.forward(latitude: 19.229, longitude: 233.723 - 360)
        XCTAssertEqual(pos.x, -3271192.0)
        XCTAssertEqual(pos.y, 2604267.8)

        let pos2 = grid.findPointXy(lat: 19.229, lon: 233.723 - 360)
        XCTAssertEqual(pos2?.x, 0)
        XCTAssertEqual(pos2?.y, 0)

        XCTAssertEqual(grid.findPoint(lat: 21.137999999999987, lon: 237.28 - 360), 117411)
        XCTAssertEqual(grid.findPoint(lat: 24.449714395051082, lon: 265.54789437771944 - 360), 188910)
        XCTAssertEqual(grid.findPoint(lat: 22.73382904757237, lon: 242.93190409785294 - 360), 180965)
        XCTAssertEqual(grid.findPoint(lat: 24.37172305316154, lon: 271.6307003393202 - 360), 196187)
        XCTAssertEqual(grid.findPoint(lat: 24.007414634071907, lon: 248.77817290935954 - 360), 232796)

        XCTAssertEqual(grid.getCoordinates(gridpoint: 0).latitude, 19.228992, accuracy: 0.001)
        XCTAssertEqual(grid.getCoordinates(gridpoint: 0).longitude, -126.27699, accuracy: 0.001)

        XCTAssertEqual(grid.getCoordinates(gridpoint: 10000).latitude, 21.794254, accuracy: 0.001)
        XCTAssertEqual(grid.getCoordinates(gridpoint: 10000).longitude, -111.44652, accuracy: 0.001)

        XCTAssertEqual(grid.getCoordinates(gridpoint: 20000).latitude, 22.806227, accuracy: 0.001)
        XCTAssertEqual(grid.getCoordinates(gridpoint: 20000).longitude, -96.18898, accuracy: 0.001)

        XCTAssertEqual(grid.getCoordinates(gridpoint: 30000).latitude, 22.222015, accuracy: 0.001)
        XCTAssertEqual(grid.getCoordinates(gridpoint: 30000).longitude, -80.87921, accuracy: 0.001)

        XCTAssertEqual(grid.getCoordinates(gridpoint: 40000).latitude, 20.274399, accuracy: 0.001)
        XCTAssertEqual(grid.getCoordinates(gridpoint: 40000).longitude, -123.18192, accuracy: 0.001)
    }

    func testLambertConformal() {
        let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5, ϕ2: 38.5)
        let pos = proj.forward(latitude: 47, longitude: -8)
        XCTAssertEqual(pos.x, 5833.8677)
        XCTAssertEqual(pos.y, 8632.733)
        let coords = proj.inverse(x: pos.x, y: pos.y)
        XCTAssertEqual(coords.latitude, 47, accuracy: 0.0001)
        XCTAssertEqual(coords.longitude, -8, accuracy: 0.0001)

        let nam = ProjectionGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
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

        XCTAssertEqual(nam.findPoint(lat: 21.137999999999987, lon: 237.28 - 360), 0)
        XCTAssertEqual(nam.findPoint(lat: 24.449714395051082, lon: 265.54789437771944 - 360), 10000)
        XCTAssertEqual(nam.findPoint(lat: 22.73382904757237, lon: 242.93190409785294 - 360), 20000)
        XCTAssertEqual(nam.findPoint(lat: 24.37172305316154, lon: 271.6307003393202 - 360), 30000)
        XCTAssertEqual(nam.findPoint(lat: 24.007414634071907, lon: 248.77817290935954 - 360), 40000)

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

    func testLambertAzimuthalEqualAreaProjection() {
        let proj = LambertAzimuthalEqualAreaProjection(λ0: -2.5, ϕ1: 54.9, radius: 6371229)
        let grid = ProjectionGrid(nx: 1042, ny: 970, latitudeProjectionOrigion: -1036000, longitudeProjectionOrigion: -1158000, dx: 2000, dy: 2000, projection: proj)
        // peak north denmark 57.745566, 10.620785
        let coords = proj.forward(latitude: 57.745566, longitude: 10.620785)
        XCTAssertEqual(coords.x, 773650.5, accuracy: 0.0001) // around 774000.0
        XCTAssertEqual(coords.y, 389820.06, accuracy: 0.0001) // around 378000

        let r = proj.inverse(x: 773650.5, y: 389820.06)
        XCTAssertEqual(r.longitude, 10.620785, accuracy: 0.0001)
        XCTAssertEqual(r.latitude, 57.745566, accuracy: 0.0001)

        let coords2 = grid.findPointXy(lat: 57.745566, lon: 10.620785)!
        XCTAssertEqual(coords2.x, 966)
        XCTAssertEqual(coords2.y, 713)

        let r2 = grid.getCoordinates(gridpoint: 966 + 713 * grid.nx)
        XCTAssertEqual(r2.longitude, 10.6271515, accuracy: 0.0001)
        XCTAssertEqual(r2.latitude, 57.746563, accuracy: 0.0001)
    }

    func testLambertCC() {
        let proj = LambertConformalConicProjection(λ0: 352, ϕ0: 55.5, ϕ1: 55.5, ϕ2: 55.5, radius: 6371229)
        let grid = ProjectionGrid(
            nx: 1906,
            ny: 1606,
            latitude: 39.671,
            longitude: -25.421997,
            dx: 2000,
            dy: 2000,
            projection: proj
        )

        let origin = proj.forward(latitude: 39.671, longitude: -25.421997)
        XCTAssertEqual(origin.x, -1527524.9, accuracy: 0.001)
        XCTAssertEqual(origin.y, -1588682.0, accuracy: 0.001)

        let x1 = proj.forward(latitude: 39.675304, longitude: -25.400146)
        XCTAssertEqual(origin.x - x1.x, -1998.125, accuracy: 0.001)
        XCTAssertEqual(origin.y - x1.y, -0.375, accuracy: 0.001)

        var c = grid.getCoordinates(gridpoint: 1)
        XCTAssertEqual(c.latitude, 39.675304, accuracy: 0.001)
        XCTAssertEqual(c.longitude, -25.400146, accuracy: 0.001)
        XCTAssertEqual(grid.findPoint(lat: 39.675304, lon: -25.400146), 1)

        // Coords(i: 122440, x: 456, y: 64, latitude: 42.18604, longitude: -15.30127)
        c = grid.getCoordinates(gridpoint: 122440)
        XCTAssertEqual(c.latitude, 42.18604, accuracy: 0.001)
        XCTAssertEqual(c.longitude, -15.30127, accuracy: 0.001)
        XCTAssertEqual(grid.findPoint(lat: 42.18604, lon: -15.30127), 122440)

        // Coords(i: 2999780, x: 1642, y: 1573, latitude: 64.943695, longitude: 30.711975)
        c = grid.getCoordinates(gridpoint: 2999780)
        XCTAssertEqual(c.latitude, 64.943695, accuracy: 0.001)
        XCTAssertEqual(c.longitude, 30.711975, accuracy: 0.001)
        XCTAssertEqual(grid.findPoint(lat: 64.943695, lon: 30.711975), 2999780)
    }

    func testStereographic() {
        let nx = 935
        let grid = ProjectionGrid(nx: 935, ny: 824, latitude: 18.14503...45.405453, longitude: 217.10745...349.8256, projection: StereograpicProjection(latitude: 90, longitude: 249, radius: 6371229))

        let pos = grid.findPoint(lat: 64.79836, lon: 241.40111)!
        XCTAssertEqual(pos % nx, 420)
        XCTAssertEqual(pos / nx, 468)
    }

    func testHrdpsGrid() {
        let grid = ProjectionGrid(nx: 2540, ny: 1290, latitude: 39.626034...47.876457, longitude: -133.62952...(-40.708557), projection: RotatedLatLonProjection(latitude: -36.0885, longitude: 245.305))

        var pos = grid.findPoint(lat: 39.626034, lon: -133.62952)!
        var (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 0)
        XCTAssertEqual(lat, 39.626034, accuracy: 0.001)
        XCTAssertEqual(lon, -133.62952, accuracy: 0.001)

        pos = grid.findPoint(lat: 27.284597, lon: -66.96642)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 2539) //  x: 2539, y: 0,
        XCTAssertEqual(lat, 27.284597, accuracy: 0.001)
        XCTAssertEqual(lon, -66.96642, accuracy: 0.001)

        // Coords(i: 720852, x: 2032, y: 283, latitude: 38.96126, longitude: -73.63256)
        pos = grid.findPoint(lat: 38.96126, lon: -73.63256)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 720852)
        XCTAssertEqual(lat, 38.96126, accuracy: 0.001)
        XCTAssertEqual(lon, -73.63256, accuracy: 0.001)

        // Coords(i: 3276599, x: 2539, y: 1289, latitude: 47.876457, longitude: -40.708557)
        pos = grid.findPoint(lat: 47.876457, lon: -40.708557)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 3276599)
        XCTAssertEqual(lat, 47.876457, accuracy: 0.001)
        XCTAssertEqual(lon, -40.708557, accuracy: 0.001)
    }

    func testCerraGrid() {
        // 
        let grid = ProjectionGrid(nx: 1069, ny: 1069, latitude: 20.29228...63.769516, longitude: -17.485962...74.10509, projection: LambertConformalConicProjection(λ0: 8, ϕ0: 50, ϕ1: 50, ϕ2: 50))

        var pos = grid.findPoint(lat: 20.29228, lon: -17.485962)!
        var (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 0)
        XCTAssertEqual(lat, 20.29228, accuracy: 0.001)
        XCTAssertEqual(lon, -17.485962, accuracy: 0.001)

        pos = grid.findPoint(lat: 20.292282, lon: 33.485947)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 1068) // x: 1068, y: 0
        XCTAssertEqual(lat, 20.292282, accuracy: 0.001)
        XCTAssertEqual(lon, 33.485947, accuracy: 0.001)

        pos = grid.findPoint(lat: 24.21984, lon: 18.087494)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 11427) // x: 737, y: 10,
        XCTAssertEqual(lat, 24.21984, accuracy: 0.001)
        XCTAssertEqual(lon, 18.087494, accuracy: 0.001)

        pos = grid.findPoint(lat: 54.086716, lon: 50.74211)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 811317) // x: 1015, y: 758)
        XCTAssertEqual(lat, 54.086716, accuracy: 0.001)
        XCTAssertEqual(lon, 50.74211, accuracy: 0.001)

        pos = grid.findPoint(lat: 63.769516, lon: 74.10509)!
        (lat, lon) = grid.getCoordinates(gridpoint: pos)
        XCTAssertEqual(pos, 1142760) // x: 1068, y: 1068,
        XCTAssertEqual(lat, 63.769516, accuracy: 0.001)
        XCTAssertEqual(lon, 74.10509, accuracy: 0.001)

        /**
         Coords(i: 0, x: 0, y: 0, latitude: 20.29228, longitude: -17.485962)
         Coords(i: 0, x: 0, y: 0, latitude: 20.29228, longitude: -17.485962)
         Coords(i: 1068, x: 1068, y: 0, latitude: 20.292282, longitude: 33.485947)
         Coords(i: 11427, x: 737, y: 10, latitude: 24.21984, longitude: 18.087494)
         Coords(i: 22854, x: 405, y: 21, latitude: 25.086115, longitude: 1.5190582)
         Coords(i: 34281, x: 73, y: 32, latitude: 22.660646, longitude: -14.671143)
         Coords(i: 45708, x: 810, y: 42, latitude: 25.122633, longitude: 21.936829)
         Coords(i: 57135, x: 478, y: 53, latitude: 26.754385, longitude: 5.11882)
         Coords(i: 68562, x: 146, y: 64, latitude: 24.96371, longitude: -11.659119)
         Coords(i: 79989, x: 883, y: 74, latitude: 25.845913, longitude: 25.87973)
         Coords(i: 91416, x: 551, y: 85, latitude: 28.276012, longitude: 8.894745)
         Coords(i: 102843, x: 219, y: 96, latitude: 27.183084, longitude: -8.439209)
         Coords(i: 114270, x: 956, y: 106, latitude: 26.380974, longitude: 29.897049)
         Coords(i: 125697, x: 624, y: 117, latitude: 29.634163, longitude: 12.839462)
         Coords(i: 137124, x: 292, y: 128, latitude: 29.299341, longitude: -5.0023804)
         Coords(i: 148551, x: 1029, y: 138, latitude: 26.721214, longitude: 33.967194)
         Coords(i: 159978, x: 697, y: 149, latitude: 30.812912, longitude: 16.941193)
         Coords(i: 171405, x: 365, y: 160, latitude: 31.292252, longitude: -1.34198)
         Coords(i: 182832, x: 33, y: 171, latitude: 28.053232, longitude: -18.852112)
         Coords(i: 194259, x: 770, y: 181, latitude: 31.797712, longitude: 21.183441)
         Coords(i: 205686, x: 438, y: 192, latitude: 33.141113, longitude: 2.5453339)
         Coords(i: 217113, x: 106, y: 203, latitude: 30.590374, longitude: -15.737183)
         Coords(i: 228540, x: 843, y: 213, latitude: 32.57586, longitude: 25.544983)
         Coords(i: 239967, x: 511, y: 224, latitude: 34.825138, longitude: 6.6582947)
         Coords(i: 251394, x: 179, y: 235, latitude: 33.039253, longitude: -12.371216)
         Coords(i: 262821, x: 916, y: 245, latitude: 33.136944, longitude: 30.000198)
         Coords(i: 274248, x: 584, y: 256, latitude: 36.32396, longitude: 10.990143)
         Coords(i: 285675, x: 252, y: 267, latitude: 35.377388, longitude: -8.738037)
         Coords(i: 297102, x: 989, y: 277, latitude: 33.473244, longitude: 34.519714)
         Coords(i: 308529, x: 657, y: 288, latitude: 37.61818, longitude: 15.527496)
         Coords(i: 319956, x: 325, y: 299, latitude: 37.5811, longitude: -4.8237915)
         Coords(i: 331383, x: 1062, y: 309, latitude: 33.58005, longitude: 39.07144)
         Coords(i: 342810, x: 730, y: 320, latitude: 38.690006, longitude: 20.24971)
         Coords(i: 354237, x: 398, y: 331, latitude: 39.625828, longitude: -0.6185913)
         Coords(i: 365664, x: 66, y: 342, latitude: 36.152588, longitude: -20.592163)
         Coords(i: 377091, x: 803, y: 352, latitude: 39.523922, longitude: 25.128601)
         Coords(i: 388518, x: 471, y: 363, latitude: 41.486603, longitude: 3.8817139)
         Coords(i: 399945, x: 139, y: 374, latitude: 38.843052, longitude: -17.110352)
         Coords(i: 411372, x: 876, y: 384, latitude: 40.107327, longitude: 30.1288)
         Coords(i: 422799, x: 544, y: 395, latitude: 43.138622, longitude: 8.673187)
         Coords(i: 434226, x: 212, y: 406, latitude: 41.416862, longitude: -13.29895)
         Coords(i: 445653, x: 949, y: 416, latitude: 40.43111, longitude: 35.208893)
         Coords(i: 457080, x: 617, y: 427, latitude: 44.558006, longitude: 13.742004)
         Coords(i: 468507, x: 285, y: 438, latitude: 43.846596, longitude: -9.131714)
         Coords(i: 479934, x: 1022, y: 448, latitude: 40.490116, longitude: 40.323242)
         Coords(i: 491361, x: 690, y: 459, latitude: 45.722668, longitude: 19.062576)
         Coords(i: 502788, x: 358, y: 470, latitude: 46.10329, longitude: -4.5859985)
         Coords(i: 514215, x: 26, y: 481, latitude: 41.523666, longitude: -26.41455)
         Coords(i: 525642, x: 763, y: 491, latitude: 46.613277, longitude: 24.596619)
         Coords(i: 537069, x: 431, y: 502, latitude: 48.156933, longitude: 0.35375977)
         Coords(i: 548496, x: 99, y: 513, latitude: 44.46388, longitude: -22.881042)
         Coords(i: 559923, x: 836, y: 523, latitude: 47.214256, longitude: 30.293564)
         Coords(i: 571350, x: 504, y: 534, latitude: 49.977108, longitude: 5.6923065)
         Coords(i: 582777, x: 172, y: 545, latitude: 47.284657, longitude: -18.944397)
         Coords(i: 594204, x: 909, y: 555, latitude: 47.51467, longitude: 36.092407)
         Coords(i: 605631, x: 577, y: 566, latitude: 51.533947, longitude: 11.418991)
         Coords(i: 617058, x: 245, y: 577, latitude: 49.954823, longitude: -14.557373)
         Coords(i: 628485, x: 982, y: 587, latitude: 47.508923, longitude: 41.925156)
         Coords(i: 639912, x: 650, y: 598, latitude: 52.799366, longitude: 17.503555)
         Coords(i: 651339, x: 318, y: 609, latitude: 52.440655, longitude: -9.673828)
         Coords(i: 662766, x: 1055, y: 619, latitude: 47.197117, longitude: 47.721375)
         Coords(i: 674193, x: 723, y: 630, latitude: 53.74856, longitude: 23.893204)
         Coords(i: 685620, x: 391, y: 641, latitude: 54.706192, longitude: -4.253784)
         Coords(i: 697047, x: 59, y: 652, latitude: 49.74238, longitude: -29.9646)
         Coords(i: 708474, x: 796, y: 662, latitude: 54.3616, longitude: 30.512268)
         Coords(i: 719901, x: 464, y: 673, latitude: 56.713844, longitude: 1.7296295)
         Coords(i: 731328, x: 132, y: 684, latitude: 52.816505, longitude: -26.019592)
         Coords(i: 742755, x: 869, y: 694, latitude: 54.624943, longitude: 37.265564)
         Coords(i: 754182, x: 537, y: 705, latitude: 58.425495, longitude: 8.280121)
         Coords(i: 765609, x: 205, y: 716, latitude: 55.739014, longitude: -21.5141)
         Coords(i: 777036, x: 942, y: 726, latitude: 54.53261, longitude: 44.045563)
         Coords(i: 788463, x: 610, y: 737, latitude: 59.804222, longitude: 15.367798)
         Coords(i: 799890, x: 278, y: 748, latitude: 58.471645, longitude: -16.36023)
         Coords(i: 811317, x: 1015, y: 758, latitude: 54.086716, longitude: 50.74211)
         Coords(i: 822744, x: 683, y: 769, latitude: 60.81669, longitude: 22.919785)
         Coords(i: 834171, x: 351, y: 780, latitude: 60.97196, longitude: -10.467957)
         Coords(i: 845598, x: 19, y: 791, latitude: 54.48828, longitude: -38.68631)
         Coords(i: 857025, x: 756, y: 801, latitude: 61.435997, longitude: 30.816528)
         Coords(i: 868452, x: 424, y: 812, latitude: 63.19345, longitude: -3.756897)
         Coords(i: 879879, x: 92, y: 823, latitude: 57.81212, longitude: -34.958405)
         Coords(i: 891306, x: 829, y: 833, latitude: 61.644547, longitude: 38.897705)
         Coords(i: 902733, x: 497, y: 844, latitude: 65.086464, longitude: 3.824112)
         Coords(i: 914160, x: 165, y: 855, latitude: 60.991566, longitude: -30.567993)
         Coords(i: 925587, x: 902, y: 865, latitude: 61.436203, longitude: 46.978928)
         Coords(i: 937014, x: 570, y: 876, latitude: 66.60029, longitude: 12.269196)
         Coords(i: 948441, x: 238, y: 887, latitude: 63.98551, longitude: -25.361084)
         Coords(i: 959868, x: 975, y: 897, latitude: 60.817093, longitude: 54.875793)
         Coords(i: 971295, x: 643, y: 908, latitude: 67.6871, longitude: 21.48465)
         Coords(i: 982722, x: 311, y: 919, latitude: 66.74602, longitude: -19.15393)
         Coords(i: 994149, x: 1048, y: 929, latitude: 59.80481, longitude: 62.42798)
         Coords(i: 1005576, x: 716, y: 940, latitude: 68.30752, longitude: 31.268784)
         Coords(i: 1017003, x: 384, y: 951, latitude: 69.216934, longitude: -11.742371)
         Coords(i: 1028430, x: 52, y: 962, latitude: 62.03113, longitude: -46.227905)
         Coords(i: 1039857, x: 789, y: 972, latitude: 68.4368, longitude: 41.320602)
         Coords(i: 1051284, x: 457, y: 983, latitude: 71.33316, longitude: -2.9328613)
         Coords(i: 1062711, x: 125, y: 994, latitude: 65.45346, longitude: -42.41208)
         Coords(i: 1074138, x: 862, y: 1004, latitude: 68.06957, longitude: 51.286194)
         Coords(i: 1085565, x: 530, y: 1015, latitude: 73.0219, longitude: 7.3907166)
         Coords(i: 1096992, x: 198, y: 1026, latitude: 68.708145, longitude: -37.67755)
         Coords(i: 1108419, x: 935, y: 1036, latitude: 67.2209, longitude: 60.829147)
         Coords(i: 1119846, x: 603, y: 1047, latitude: 74.20824, longitude: 19.159607)
         Coords(i: 1131273, x: 271, y: 1058, latitude: 71.74651, longitude: -31.702972)
         Coords(i: 1141692, x: 0, y: 1068, latitude: 63.769512, longitude: -58.105072)
         Coords(i: 1142700, x: 1008, y: 1068, latitude: 65.92331, longitude: 69.69272)
         Coords(i: 1142760, x: 1068, y: 1068, latitude: 63.769516, longitude: 74.10509)
         */
    }

    func testCamsEurope() {
        let grid = CamsDomain.cams_europe.grid
        let pos = grid.getCoordinates(gridpoint: 0)
        XCTAssertEqual(pos.latitude, 71.95)
        XCTAssertEqual(pos.longitude, -24.95)

        let bologna = grid.findPoint(lat: 45.45, lon: 11.35)!
        XCTAssertEqual(bologna % grid.nx, 363) // x
        XCTAssertEqual(bologna / grid.nx, 265) // y        
    }

    /**
     Coords(i: 0, x: 0, y: 0, latitude: 89.94619, longitude: 0.0)
     Coords(i: 65996, x: 65996, y: 0, latitude: 77.50439, longitude: 75.16484)
     Coords(i: 131992, x: 131992, y: 0, latitude: 72.23198, longitude: 156.88715)
     Coords(i: 197988, x: 197988, y: 0, latitude: 68.154655, longitude: 59.428574)
     Coords(i: 263984, x: 263984, y: 0, latitude: 64.78031, longitude: -59.50412)
     Coords(i: 329980, x: 329980, y: 0, latitude: 61.757465, longitude: -102.85715)
     Coords(i: 395976, x: 395976, y: 0, latitude: 59.015816, longitude: 173.1236)
     Coords(i: 461972, x: 461972, y: 0, latitude: 56.48506, longitude: 47.151764)
     Coords(i: 527968, x: 527968, y: 0, latitude: 54.1652, longitude: 112.762634)
     Coords(i: 593964, x: 593964, y: 0, latitude: 51.98594, longitude: 172.40366)
     Coords(i: 659960, x: 659960, y: 0, latitude: 49.947273, longitude: -15.679443)
     Coords(i: 725956, x: 725956, y: 0, latitude: 47.97891, longitude: -2.3920288)
     Coords(i: 791952, x: 791952, y: 0, latitude: 46.08084, longitude: -78.41019)
     Coords(i: 857948, x: 857948, y: 0, latitude: 44.253075, longitude: 171.48093)
     Coords(i: 923944, x: 923944, y: 0, latitude: 42.495605, longitude: 72.0)
     Coords(i: 989940, x: 989940, y: 0, latitude: 40.808434, longitude: 19.943176)
     Coords(i: 5543664, x: 5543664, y: 0, latitude: -39.191563, longitude: -55.955994)
     Coords(i: 5609660, x: 5609660, y: 0, latitude: -40.808434, longitude: -30.17044)
     Coords(i: 5675656, x: 5675656, y: 0, latitude: -42.495605, longitude: -82.58823)
     Coords(i: 5741652, x: 5741652, y: 0, latitude: -44.253075, longitude: 177.5267)
     Coords(i: 5807648, x: 5807648, y: 0, latitude: -46.08084, longitude: 66.96344)
     Coords(i: 5873644, x: 5873644, y: 0, latitude: -47.90861, longitude: -9.552246)
     Coords(i: 5939640, x: 5939640, y: 0, latitude: -49.947273, longitude: 3.1358948)
     Coords(i: 6005636, x: 6005636, y: 0, latitude: -51.98594, longitude: 174.38531)
     Coords(i: 6071632, x: 6071632, y: 0, latitude: -54.1652, longitude: -126.77042)
     Coords(i: 6137628, x: 6137628, y: 0, latitude: -56.48506, longitude: -62.120575)
     Coords(i: 6203624, x: 6203624, y: 0, latitude: -59.015816, longitude: 170.69662)
     Coords(i: 6599679, x: 6599679, y: 0, latitude: -89.94619, longitude: -18.0)
     Coords(i: 6599679, x: 6599679, y: 0, latitude: -89.94619, longitude: -18.0)
     */
    func testEcmwfIfsGrid() {
        let grid = GaussianGrid(type: .o1280)
        XCTAssertEqual(grid.nxOf(y: 0), 20)
        XCTAssertEqual(grid.nxOf(y: 1), 24)
        XCTAssertEqual(grid.nxOf(y: 1280 - 1), 5136)
        XCTAssertEqual(grid.nxOf(y: 1281 - 1), 5136)
        XCTAssertEqual(grid.nxOf(y: 2559 - 1), 24)
        XCTAssertEqual(grid.nxOf(y: 2560 - 1), 20)

        XCTAssertEqual(grid.integral(y: 0), 0)
        XCTAssertEqual(grid.integral(y: 1), 20)
        XCTAssertEqual(grid.integral(y: 2), 44)
        XCTAssertEqual(grid.integral(y: 3), 72)
        XCTAssertEqual(grid.integral(y: 4), 104)
        XCTAssertEqual(grid.integral(y: 1280 - 1), 3294704)
        XCTAssertEqual(grid.integral(y: 1281 - 1), 3299840)
        XCTAssertEqual(grid.integral(y: 2559 - 1), 6599636)
        XCTAssertEqual(grid.integral(y: 2560 - 1), 6599660)

        // All reference points from grib file directly
        var coord = grid.findPoint(lat: 89.94619, lon: 0)!
        var pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 0) // y=0
        // slightly inaccurate at the last 2 lines at the pole
        XCTAssertEqual(pos.latitude, 89.94619, accuracy: 0.005)
        XCTAssertEqual(pos.longitude, 0)
        coord = grid.findPoint(lat: 64.78031, lon: -59.50412)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 263984) // y=358
        XCTAssertEqual(pos.latitude, 64.78031)
        XCTAssertEqual(pos.longitude, -59.50412, accuracy: 0.0001)
        coord = grid.findPoint(lat: -42.495605, lon: -82.58823)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 5675656) // y=1884
        XCTAssertEqual(pos.latitude, -42.495605)
        XCTAssertEqual(pos.longitude, -82.58823)
        coord = grid.findPoint(lat: -51.98594, lon: 174.38531)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 6005636) // y=2019
        XCTAssertEqual(pos.latitude, -51.98594)
        XCTAssertEqual(pos.longitude, 174.38531, accuracy: 0.0001)
        coord = grid.findPoint(lat: -0.035149384, lon: 0)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 3299840) // y=1280
        XCTAssertEqual(pos.latitude, -0.035149384)
        XCTAssertEqual(pos.longitude, 0, accuracy: 0.0001)
        coord = grid.findPoint(lat: -0.52724075, lon: 0)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 3335708)
        XCTAssertEqual(pos.latitude, -0.52724075)
        XCTAssertEqual(pos.longitude, 0, accuracy: 0.0001)
    }

    func testMfWaveGrid() {
        // Note: Grid is moved by dx/2 dy/2
        let grid = MfWaveDomain.mfwave.grid
        var coord = grid.findPoint(lat: 36.16667, lon: -0.83333333)!
        var pos = grid.getCoordinates(gridpoint: coord)
        // i=x (i=2150, j=1394) 0.0292969 (x=-0.8333333, y=36.16667)
        XCTAssertEqual(coord, 1394 * grid.nx + 2150)
        XCTAssertEqual(pos.latitude, 36.208336, accuracy: 0.0005)
        XCTAssertEqual(pos.longitude, -0.7916565, accuracy: 0.0005)

        // (i-3486, j-778) -0.0556641 (x=110.5, y=-15.16667)
        coord = grid.findPoint(lat: -15.16667, lon: 110.5)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 777 * grid.nx + 3485)
        XCTAssertEqual(pos.latitude, -15.208336, accuracy: 0.0005)
        XCTAssertEqual(pos.longitude, 110.45836)

        // (i-714, j-1230) 0.0146484 (x=-120.5, y=22.5)
        coord = grid.findPoint(lat: 22.5, lon: -120.5)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 1230 * grid.nx + 713)
        XCTAssertEqual(pos.latitude, 22.541664, accuracy: 0.0005)
        XCTAssertEqual(pos.longitude, -120.54166)

        // (i=4278, j=1170) -0.321289 (x=176.5, y=17.5)
        coord = grid.findPoint(lat: 17.5, lon: 176.5)!
        pos = grid.getCoordinates(gridpoint: coord)
        XCTAssertEqual(coord, 1170 * grid.nx + 4277)
        XCTAssertEqual(pos.latitude, 17.541664, accuracy: 0.0005)
        XCTAssertEqual(pos.longitude, 176.45836)
    }
}
