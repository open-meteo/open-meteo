import Foundation
@testable import App
import XCTest

final class ApiTests: XCTestCase {
    /*func testVariableDecode() {
        XCTAssertEqual(api_result_VariableType.startsWith(s: "cloudcover_low_123")?.0, .cloudcoverLow)
    }*/
    func testTimeSelection() throws {
        let current = Timestamp(2024, 02, 03, 12, 24)
        let a = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: nil, dtSeconds: 3600)
        XCTAssertEqual(a?.prettyString(), "2024-02-03T13:00 to 2024-02-03T16:00 (1-hourly)")

        let b = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: 0, dtSeconds: 3600)
        XCTAssertEqual(b?.prettyString(), "2024-02-03T00:00 to 2024-02-03T03:00 (1-hourly)")
    }
}
