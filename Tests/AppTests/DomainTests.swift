import Foundation
@testable import App
import XCTest
//import Vapor


final class DomainTests: XCTestCase {
    func testMeteoFrance() {
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 0).map{$0.file}, ["00H12", "13H24", "25H36", "37H48", "49H60", "61H72", "73H84", "85H96", "97H102"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 6).map{$0.file}, ["00H12", "13H24", "25H36", "37H48", "49H60", "61H72"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 12).map{$0.file}, ["00H12", "13H24", "25H36", "37H48", "49H60", "61H72", "73H84", "85H96", "97H102"])
        XCTAssertEqual(MeteoFranceDomain.arpege_europe.getForecastHoursPerFile(run: 18).map{$0.file}, ["00H12", "13H24", "25H36", "37H48", "49H60"])
    }
}
