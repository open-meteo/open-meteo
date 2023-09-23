import Foundation
@testable import App
import XCTest


final class ApiTests: XCTestCase {
    func testVariableDecode() {
        XCTAssertEqual(com_openmeteo_api_result_VariableType.startsWith(s: "cloudcover_low_123")?.0, .cloudcoverLow)
    }
}
