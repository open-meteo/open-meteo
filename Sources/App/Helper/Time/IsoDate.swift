import Foundation

/**
 Simple year, month, day container which is decoded to iso dates `2022-01-01`
 */
public struct IsoDate: Codable {
    /// Encoded as integer `20220101`
    public let date: Int32
    
    public init(year: Int, month: Int, day: Int) {
        date = Int32(year * 10000 + month * 100 + day)
    }
    
    /// year like 2022
    public var year: Int {
        Int(date) / 10000
    }
    
    /// month from 1 to 12
    public var month: Int {
        Int(date) / 100 % 100
    }
    
    /// day from 1 to 31
    public var day: Int {
        Int(date) % 100
    }
    
    /// convert to unix timestamp
    public func toTimestamp() -> Timestamp {
        Timestamp(year, month, day)
    }
    
    /// Convert to strideable `YearMonth`
    public func toYearMonth() -> YearMonth {
        return YearMonth(year: year, month: month)
    }
    
    public init(from decoder: Decoder) throws {
        let str = try decoder.singleValueContainer().decode(String.self)
        try self.init(fromIsoString: str)
    }
    
    /// To iso string like `2022-12-23`
    public func toIsoString() -> String {
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))"
    }
    
    /// Init form unxtimestamp
    public init(timeIntervalSince1970: Int) {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        // day of year = Int(t.tm_yday+1)
        // day of week = Int(t.tm_wday)
        self.init(year: Int(t.tm_year+1900), month: Int(t.tm_mon+1), day: Int(t.tm_mday))
    }
    
    /// Decode from `2022-12-23`
    public init(fromIsoString str: String) throws {
        guard str.count == 10, str[4..<5] == "-", str[7..<8] == "-" else {
            throw TimeError.InvalidDateFromat
        }
        guard let year = Int32(str[0..<4]), let month = Int32(str[5..<7]), let day = Int32(str[8..<10]) else {
            throw TimeError.InvalidDateFromat
        }
        guard year >= 1900, year <= 2050, month >= 1, month <= 12, day >= 1, day <= 31 else {
            throw TimeError.InvalidDate
        }
        self.date = year * 10000 + month * 100 + day
    }
}

extension IsoDate {
    static func load(commaSeparated: [String]) throws -> [IsoDate] {
        try commaSeparated.flatMap { s in
            try s.split(separator: ",").map { date in
                return try IsoDate.init(fromIsoString: String(date))
            }
        }
    }
    
    static func loadRange(start: [String], end: [String]) throws -> [ClosedRange<Timestamp>] {
        if start.isEmpty, end.isEmpty {
            return []
        }
        let startDate = try load(commaSeparated: start)
        let endDate = try load(commaSeparated: end)
        guard startDate.count == endDate.count else {
            throw ForecastapiError.startAndEndDateCountMustBeTheSame
        }
        return try zip(startDate, endDate).map { (startDate, endDate) in
            let start = startDate.toTimestamp()
            let includedEnd = endDate.toTimestamp()
            guard includedEnd.timeIntervalSince1970 >= start.timeIntervalSince1970 else {
                throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
            }
            return start...includedEnd
        }
    }
}

extension String {
    subscript(_ range: Range<Int>) -> Substring {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(start, offsetBy: min(self.count - range.lowerBound, range.upperBound - range.lowerBound))
        return self[start..<end]
    }

    subscript(_ range: CountablePartialRangeFrom<Int>) -> Substring {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
         return self[start...]
    }
}
