import Foundation
@testable import App
import XCTest
//import Vapor


final class DomainTests: XCTestCase {
    func testMeteoFrance() {
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H", "73H84H", "85H96H", "97H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 6).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 12).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H", "61H72H", "73H84H", "85H96H", "97H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 18).map{$0.file}, ["00H12H", "13H24H", "25H36H", "37H48H", "49H60H"])
        
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 0).map{$0.file}, ["00H24H", "27H48H", "51H72H", "75H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 6).map{$0.file}, ["00H24H", "27H48H", "51H72H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 12).map{$0.file}, ["00H24H", "27H48H", "51H72H", "75H102H"])
        XCTAssertEqual(MeteoFranceDomain.arpege_world.getForecastHoursPerFile(run: 18).map{$0.file}, ["00H24H", "27H48H", "51H72H"])
        
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 0).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H", "37H42H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 6).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 12).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H", "37H42H"])
        XCTAssertEqual(MeteoFranceDomain.arome_france.getForecastHoursPerFile(run: 18).map{$0.file}, ["00H06H", "07H12H", "13H18H", "19H24H", "25H30H", "31H36H"])
        
        XCTAssertEqual(MeteoFranceDomain.arome_france_hd.getForecastHoursPerFile(run: 0).map{$0.file}, ["00H", "01H", "02H", "03H", "04H", "05H", "06H", "07H", "08H", "09H", "10H", "11H", "12H", "13H", "14H", "15H", "16H", "17H", "18H", "19H", "20H", "21H", "22H", "23H", "24H", "25H", "26H", "27H", "28H", "29H", "30H", "31H", "32H", "33H", "34H", "35H", "36H", "37H", "38H", "39H", "40H", "41H", "42H"])
        
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72]), ArraySlice([78, 84]), ArraySlice([90, 96]), ArraySlice([102])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 6).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 12).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60]), ArraySlice([63, 66, 69, 72]), ArraySlice([78, 84]), ArraySlice([90, 96]), ArraySlice([102])])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 18).map{$0.steps}, [ArraySlice([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), ArraySlice([15, 18, 21, 24]), ArraySlice([27, 30, 33, 36]), ArraySlice([39, 42, 45, 48]), ArraySlice([51, 54, 57, 60])])
    }
}
