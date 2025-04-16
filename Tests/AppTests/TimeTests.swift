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

    func testTimeFormats() throws {
        XCTAssertEqual(try Timestamp.from(yyyymmdd: "20211123").format_YYYYMMddHH, "2021112300")
        XCTAssertEqual(try Timestamp.from(yyyymmdd: "2021112323").format_YYYYMMddHH, "2021112323")
        XCTAssertEqual(try Timestamp.from(yyyymmdd: "20211123235958").iso8601_YYYY_MM_dd_HH_mm, "2021-11-23T23:59")
    }

    func testTimeIteration() {
        let range = TimerangeDt(start: Timestamp(2022, 7, 1), nTime: 5, dtSeconds: 7200)
        XCTAssertEqual(range.range.count, 36000)
        XCTAssertEqual(range.count, 5)
        let expected = ["2022-07-01T00:00", "2022-07-01T02:00", "2022-07-01T04:00", "2022-07-01T06:00", "2022-07-01T08:00"]

        XCTAssertEqual(range.prettyString(), "2022-07-01T00:00 to 2022-07-01T08:00 (dt=7200)")

        // optimised fast version
        XCTAssertEqual(range.iso8601_YYYYMMddHHmm, expected)
        // slow version
        XCTAssertEqual(range.map({ $0.iso8601_YYYY_MM_dd_HH_mm }), expected)

        let rangeDaily = TimerangeDt(start: Timestamp(2022, 7, 1), nTime: 5, dtSeconds: 86400)
        let expectedDaily = ["2022-07-01", "2022-07-02", "2022-07-03", "2022-07-04", "2022-07-05"]

        XCTAssertEqual(rangeDaily.prettyString(), "2022-07-01 to 2022-07-05")

        // optimised fast version
        XCTAssertEqual(rangeDaily.iso8601_YYYYMMdd, expectedDaily)
        // slow version
        XCTAssertEqual(rangeDaily.map({ $0.iso8601_YYYY_MM_dd }), expectedDaily)

        let range2 = TimerangeDt(start: Timestamp(1969, 7, 1), nTime: 5, dtSeconds: 7200)
        XCTAssertEqual(range2.range.count, 36000)
        XCTAssertEqual(range2.count, 5)
        let expected2 = ["1969-07-01T00:00", "1969-07-01T02:00", "1969-07-01T04:00", "1969-07-01T06:00", "1969-07-01T08:00"]
        // optimised fast version
        XCTAssertEqual(range2.iso8601_YYYYMMddHHmm, expected2)
        // slow version
        XCTAssertEqual(range2.map({ $0.iso8601_YYYY_MM_dd_HH_mm }), expected2)
    }

    func testYearMonth() throws {
        let date = try IsoDate(fromIsoString: "2021-11-23").toYearMonth()
        let date2 = try IsoDate(fromIsoString: "2022-02-23").toYearMonth()
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        let range = date..<date2
        XCTAssertEqual(range.count, 3)
        XCTAssertEqual(range.map { $0.month }, [11, 12, 1])
    }

    func testIsoDateTime() throws {
        var date = try IsoDateTime(fromIsoString: "2021-11-23T10:15:34")
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        XCTAssertEqual(date.day, 23)
        XCTAssertEqual(date.hour, 10)
        XCTAssertEqual(date.minute, 15)
        XCTAssertEqual(date.second, 34)

        date = try IsoDateTime(fromIsoString: "2021-11-23T10:15")
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        XCTAssertEqual(date.day, 23)
        XCTAssertEqual(date.hour, 10)
        XCTAssertEqual(date.minute, 15)
        XCTAssertEqual(date.second, 0)

        date = try IsoDateTime(fromIsoString: "2021-11-23T10")
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        XCTAssertEqual(date.day, 23)
        XCTAssertEqual(date.hour, 10)
        XCTAssertEqual(date.minute, 0)
        XCTAssertEqual(date.second, 0)

        date = try IsoDateTime(fromIsoString: "2021-11-23")
        XCTAssertEqual(date.year, 2021)
        XCTAssertEqual(date.month, 11)
        XCTAssertEqual(date.day, 23)
        XCTAssertEqual(date.hour, 0)
        XCTAssertEqual(date.minute, 0)
        XCTAssertEqual(date.second, 0)
    }
}
