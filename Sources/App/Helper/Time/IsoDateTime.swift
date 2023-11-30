import Foundation

/**
 Simple year, month, day container which is decoded to iso dates `2022-01-01T00:00:00`
 */
public struct IsoDateTime {
    /// Encoded as integer `20220101235959`
    public let date: Int
    
    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        date = year * 10000000000 + month * 100000000 + day * 1000000 + hour * 10000 + minute * 100 + second
    }
    
    /// year like 2022
    public var year: Int {
        date / 10000000000
    }
    
    /// month from 1 to 12
    public var month: Int {
        date / 100000000 % 100
    }
    
    /// day from 1 to 31
    public var day: Int {
        date / 1000000 % 100
    }
    
    /// hour from 0 to 23
    public var hour: Int {
        date / 10000 % 100
    }
    
    /// minute from 0 to 59
    public var minute: Int {
        date / 100 % 100
    }
    
    /// second from 0 to 59
    public var second: Int {
        date % 100
    }
    
    /// convert to unix timestamp
    public func toTimestamp() -> Timestamp {
        Timestamp(year, month, day, hour, minute, second)
    }
    
    /// Convert to strideable `YearMonth`
    public func toYearMonth() -> YearMonth {
        return YearMonth(year: year, month: month)
    }
    
    /*public init(from decoder: Decoder) throws {
        let str = try decoder.singleValueContainer().decode(String.self)
        try self.init(fromIsoString: str)
    }*/
    
    /// To iso string like `2022-12-23T00:00:00`
    public func toIsoString() -> String {
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2)):\(second.zeroPadded(len: 2))"
    }
    
    /// Init form unxtimestamp
    public init(timeIntervalSince1970: Int) {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        // day of year = Int(t.tm_yday+1)
        // day of week = Int(t.tm_wday)
        self.init(year: Int(t.tm_year+1900), month: Int(t.tm_mon+1), day: Int(t.tm_mday), hour: Int(t.tm_hour), minute: Int(t.tm_min), second: Int(t.tm_sec))
    }
    
    /// Decode from `2022-12-23` or `2022-12-23T00:00` or `2022-12-23T00:00:00`
    public init(fromIsoString str: String) throws {
        guard str.count >= 10, str.count <= 19, str[4..<5] == "-", str[7..<8] == "-" else {
            throw TimeError.InvalidDateFromat
        }
        guard let year = Int(str[0..<4]), let month = Int(str[5..<7]), let day = Int(str[8..<10]) else {
            throw TimeError.InvalidDateFromat
        }
        guard year >= 1900, year <= 2050,
                month >= 1, month <= 12,
                day >= 1, day <= 31
        else {
            throw TimeError.InvalidDate
        }
        if str.count <= 10 {
            self.init(year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
            return
        }
        
        guard str.count >= 13, str[10..<11] == "T", let hour = Int(str[11..<13]) else {
            throw TimeError.InvalidDateFromat
        }
        guard hour >= 0, hour <= 23 else {
            throw TimeError.InvalidDate
        }
        if str.count <= 13 {
            self.init(year: year, month: month, day: day, hour: hour, minute: 0, second: 0)
            return
        }
        guard str.count >= 16, str[13..<14] == ":", let minute = Int(str[14..<16]) else {
            throw TimeError.InvalidDateFromat
        }
        guard minute >= 0, minute <= 59 else {
            throw TimeError.InvalidDate
        }
        if str.count <= 16 {
            self.init(year: year, month: month, day: day, hour: hour, minute: minute, second: 0)
            return
        }
        guard str.count >= 19, str[16..<17] == ":", let second = Int(str[17..<19]) else {
            throw TimeError.InvalidDateFromat
        }
        guard second >= 0, second <= 59 else {
            throw TimeError.InvalidDate
        }
        self.init(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    }
}

extension IsoDateTime {
    static func load(commaSeparated: [String]) throws -> [IsoDateTime] {
        try commaSeparated.flatMap { s in
            try s.split(separator: ",").map { date in
                return try IsoDateTime.init(fromIsoString: String(date))
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

