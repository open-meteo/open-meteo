import Foundation
@testable import App
import XCTest
//import Vapor
import SwiftNetCDF

final class DomainTests: XCTestCase {
    func testIconGrid() {
        let r2b04 = IcosahedralGrid(n: 2, k: 4)
        let r2b05 = IcosahedralGrid(n: 2, k: 5)
        let r2b06 = IcosahedralGrid(n: 2, k: 6)
        let r3b06 = IcosahedralGrid(n: 3, k: 6)
        let r2b07 = IcosahedralGrid(n: 2, k: 7)
        let r3b07 = IcosahedralGrid(n: 3, k: 7)
        
        XCTAssertEqual(r2b04.gridResolutionMeters, 157_812.5)
        XCTAssertEqual(r2b05.gridResolutionMeters, 78_906.25)
        XCTAssertEqual(r2b06.gridResolutionMeters, 39_453.125)
        XCTAssertEqual(r3b06.gridResolutionMeters, 26_302.084)
        XCTAssertEqual(r2b07.gridResolutionMeters, 19_726.562)
        XCTAssertEqual(r3b07.gridResolutionMeters, 13_151.042)
        
        XCTAssertEqual(r2b04.count, 20480)
        XCTAssertEqual(r2b05.count, 81920)
        XCTAssertEqual(r2b06.count, 327680)
        XCTAssertEqual(r3b06.count, 737280)
        XCTAssertEqual(r2b07.count, 1310720)
        XCTAssertEqual(r3b07.count, 2949120)
        
        //XCTAssertEqual(r3b07.findPoint(latitude: -85, longitude: 44.9688), 10)
        
        let lats = try! NetCDF.open(path: "/Users/patrick/Downloads/icon_global_icosahedral_time-invariant_2023041500_CLAT.grib2.nc", allowUpdate: false)!.getVariable(name: "tlat")!.asType(Float.self)!.read()
        let lons = try! NetCDF.open(path: "/Users/patrick/Downloads/icon_global_icosahedral_time-invariant_2023041500_CLON.grib2.nc", allowUpdate: false)!.getVariable(name: "tlon")!.asType(Float.self)!.read()
        
        //print(lats[r3b07.count / 20 - 1], lons[r3b07.count / 20 - 1])
        
        r3b07.test()
        
        for a in 0..<4 {
            for b in 0..<4 {
                for c in 0..<4 {
                    let lat = lats[a*4*4+b*4+c]
                    let lon = lons[a*4*4+b*4+c]
                    let pos = r3b07.p(t_: 0, n_: 0, k_: [0,0,0,0,a,b,c]).centeroid.getLatLon()
                    let d = sqrt(pow(lat-Float(pos.latitude), 2) + pow(lon-Float(pos.longitude), 2))
                    print(lat, lon, pos, "delta=\(d)")
                }
            }
        }
    }
    
    func testMeteoFrance() {
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: false).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H", "73H84H", "85H96H", "97H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 6, hourlyForArpegeEurope: false).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 12, hourlyForArpegeEurope: false).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H", "73H84H", "85H96H", "97H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 18, hourlyForArpegeEurope: false).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H"])
        
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: false).map{$0.file}, ["00H24H", "27H48H", "51H72H", "75H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 6, hourlyForArpegeEurope: false).map{$0.file}, ["00H24H", "27H48H", "51H72H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 12, hourlyForArpegeEurope: false).map{$0.file}, ["00H24H", "27H48H", "51H72H", "75H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 18, hourlyForArpegeEurope: false).map{$0.file}, ["00H24H", "27H48H", "51H72H"])
        
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: false).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H", "37H42H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 6, hourlyForArpegeEurope: false).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 12, hourlyForArpegeEurope: false).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H", "37H42H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 18, hourlyForArpegeEurope: false).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H"])
        
        XCTAssertEqual(MeteoFranceDomain.arome_france_hd.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: false).map{$0.file}, ["00H", "01H", "02H", "03H", "04H", "05H", "06H", "07H", "08H", "09H", "10H", "11H", "12H", "13H", "14H", "15H", "16H", "17H", "18H", "19H", "20H", "21H", "22H", "23H", "24H", "25H", "26H", "27H", "28H", "29H", "30H", "31H", "32H", "33H", "34H", "35H", "36H", "37H", "38H", "39H", "40H", "41H", "42H"])
        
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: false).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72]), ArraySlice([78, 84]), ArraySlice([90, 96]), ArraySlice([102])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 6, hourlyForArpegeEurope: false).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 12, hourlyForArpegeEurope: false).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72]), ArraySlice([78, 84]), ArraySlice([90, 96]), ArraySlice([102])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 18, hourlyForArpegeEurope: false).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60])])
        
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0, hourlyForArpegeEurope: true).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]), ArraySlice([25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]), ArraySlice([37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48]), ArraySlice([49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60]), ArraySlice([61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72]), ArraySlice([73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84]), ArraySlice([85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96]), ArraySlice([97, 98, 99, 100, 101, 102])])
    }
}
