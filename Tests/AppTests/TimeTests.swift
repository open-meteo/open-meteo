import Foundation
@testable import App
import Testing

@Suite struct TimeTests {
    @Test func isoTime() throws {
        let date = try IsoDate(fromIsoString: "2021-11-23")
        #expect(date.date == 20211123)
        #expect(date.year == 2021)
        #expect(date.month == 11)
        #expect(date.day == 23)
        #expect(date.toIsoString() == "2021-11-23")
    }

    @Test func timeFormats() throws {
        #expect(try Timestamp.from(yyyymmdd: "20211123").format_YYYYMMddHH == "2021112300")
        #expect(try Timestamp.from(yyyymmdd: "2021112323").format_YYYYMMddHH == "2021112323")
        #expect(try Timestamp.from(yyyymmdd: "20211123235958").iso8601_YYYY_MM_dd_HH_mm == "2021-11-23T23:59")
    }

    @Test func timeIteration() {
        let range = TimerangeDt(start: Timestamp(2022, 7, 1), nTime: 5, dtSeconds: 7200)
        #expect(range.range.count == 36000)
        #expect(range.count == 5)
        let expected = ["2022-07-01T00:00", "2022-07-01T02:00", "2022-07-01T04:00", "2022-07-01T06:00", "2022-07-01T08:00"]

        #expect(range.prettyString() == "2022-07-01T00:00 to 2022-07-01T08:00 (dt=7200)")

        // optimised fast version
        #expect(range.iso8601_YYYYMMddHHmm == expected)
        // slow version
        #expect(range.map({ $0.iso8601_YYYY_MM_dd_HH_mm }) == expected)

        let rangeDaily = TimerangeDt(start: Timestamp(2022, 7, 1), nTime: 5, dtSeconds: 86400)
        let expectedDaily = ["2022-07-01", "2022-07-02", "2022-07-03", "2022-07-04", "2022-07-05"]

        #expect(rangeDaily.prettyString() == "2022-07-01 to 2022-07-05")

        // optimised fast version
        #expect(rangeDaily.iso8601_YYYYMMdd == expectedDaily)
        // slow version
        #expect(rangeDaily.map({ $0.iso8601_YYYY_MM_dd }) == expectedDaily)

        let range2 = TimerangeDt(start: Timestamp(1969, 7, 1), nTime: 5, dtSeconds: 7200)
        #expect(range2.range.count == 36000)
        #expect(range2.count == 5)
        let expected2 = ["1969-07-01T00:00", "1969-07-01T02:00", "1969-07-01T04:00", "1969-07-01T06:00", "1969-07-01T08:00"]
        // optimised fast version
        #expect(range2.iso8601_YYYYMMddHHmm == expected2)
        // slow version
        #expect(range2.map({ $0.iso8601_YYYY_MM_dd_HH_mm }) == expected2)
    }

    @Test func yearMonth() throws {
        let date = try IsoDate(fromIsoString: "2021-11-23").toYearMonth()
        let date2 = try IsoDate(fromIsoString: "2022-02-23").toYearMonth()
        #expect(date.year == 2021)
        #expect(date.month == 11)
        let range = date..<date2
        #expect(range.count == 3)
        #expect(range.map { $0.month } == [11, 12, 1])
    }

    @Test func isoDateTime() throws {
        var date = try IsoDateTime(fromIsoString: "2021-11-23T10:15:34")
        #expect(date.year == 2021)
        #expect(date.month == 11)
        #expect(date.day == 23)
        #expect(date.hour == 10)
        #expect(date.minute == 15)
        #expect(date.second == 34)

        date = try IsoDateTime(fromIsoString: "2021-11-23T10:15")
        #expect(date.year == 2021)
        #expect(date.month == 11)
        #expect(date.day == 23)
        #expect(date.hour == 10)
        #expect(date.minute == 15)
        #expect(date.second == 0)

        date = try IsoDateTime(fromIsoString: "2021-11-23T10")
        #expect(date.year == 2021)
        #expect(date.month == 11)
        #expect(date.day == 23)
        #expect(date.hour == 10)
        #expect(date.minute == 0)
        #expect(date.second == 0)

        date = try IsoDateTime(fromIsoString: "2021-11-23")
        #expect(date.year == 2021)
        #expect(date.month == 11)
        #expect(date.day == 23)
        #expect(date.hour == 0)
        #expect(date.minute == 0)
        #expect(date.second == 0)
    }
}
