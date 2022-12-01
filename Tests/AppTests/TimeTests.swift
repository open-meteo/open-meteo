import Foundation
@testable import App
import XCTest


final class TimeTests: XCTestCase {
    func testIsoTime() throws {
        let date = try IsoDate(fromIsoString: "2021-11-23")
        XCTAssertEqual(date.date, 20211123)
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        XCTAssertEqual(date.day, 23)
        XCTAssertEqual(date.toIsoString(), "2021-11-23")
    }
    
    func testTimeIteration() {
        let range = TimerangeDt(start: Timestamp(2022,7,1), nTime: 5, dtSeconds: 7200)
        XCTAssertEqual(range.range.count, 36000)
        XCTAssertEqual(range.count, 5)
        let expected = ["2022-07-01T00:00", "2022-07-01T02:00", "2022-07-01T04:00", "2022-07-01T06:00", "2022-07-01T08:00"]
        
        XCTAssertEqual(range.prettyString(), "2022-07-01T00:00 to 2022-07-01T08:00 (dt=7200)")
        
        // optimised fast version
        XCTAssertEqual(range.iso8601_YYYYMMddHHmm, expected)
        // slow version
        XCTAssertEqual(range.map({$0.iso8601_YYYY_MM_dd_HH_mm}), expected)
        
        let rangeDaily = TimerangeDt(start: Timestamp(2022,7,1), nTime: 5, dtSeconds: 86400)
        let expectedDaily = ["2022-07-01", "2022-07-02", "2022-07-03", "2022-07-04", "2022-07-05"]
        
        XCTAssertEqual(rangeDaily.prettyString(), "2022-07-01 to 2022-07-05")
        
        // optimised fast version
        XCTAssertEqual(rangeDaily.iso8601_YYYYMMdd, expectedDaily)
        // slow version
        XCTAssertEqual(rangeDaily.map({$0.iso8601_YYYY_MM_dd}), expectedDaily)
    }
    
    func testYearMonth() throws {
        let date = try IsoDate(fromIsoString: "2021-11-23").toYearMonth()
        let date2 = try IsoDate(fromIsoString: "2022-02-23").toYearMonth()
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        let range = date..<date2
        XCTAssertEqual(range.count, 3)
        XCTAssertEqual(range.map{$0.month}, [11, 12, 1])
    }
}
