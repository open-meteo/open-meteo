import Foundation


public enum TimeError: Error {
    case InvalidDateFromat
    case InvalidDate
}


public struct Timestamp: Hashable {
    public let timeIntervalSince1970: Int
    
    /// Hour in 0-23
    @inlinable public var hour: Int {
        (timeIntervalSince1970 % 86400) / 3600
    }
    /// Minute in 0-59
    @inlinable public var minute: Int {
        (timeIntervalSince1970 % 3600) / 60
    }
    /// Second in 0-59
    @inlinable public var second: Int {
        timeIntervalSince1970 % 60
    }
    
    public static func now() -> Timestamp {
        return Timestamp(Int(Date().timeIntervalSince1970))
    }
    
    /// month 1-12, day 1-31
    public init(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) {
        assert(month > 0)
        assert(day > 0)
        assert(year > 1900)
        assert(month <= 12)
        assert(day <= 31)
        var t = tm(tm_sec: Int32(second), tm_min: Int32(minute), tm_hour: Int32(hour), tm_mday: Int32(day), tm_mon: Int32(month-1), tm_year: Int32(year-1900), tm_wday: 0, tm_yday: 0, tm_isdst: 0, tm_gmtoff: 0, tm_zone: nil)
        self.timeIntervalSince1970 = timegm(&t)
    }
    
    public init(_ timeIntervalSince1970: Int) {
        self.timeIntervalSince1970 = timeIntervalSince1970
    }
    
    public func add(_ secounds: Int) -> Timestamp {
        Timestamp(timeIntervalSince1970 + secounds)
    }
    
    public func floor(toNearest: Int) -> Timestamp {
        Timestamp(timeIntervalSince1970 - timeIntervalSince1970 % toNearest)
    }
    
    public func ceil(toNearest: Int) -> Timestamp {
        Timestamp(timeIntervalSince1970.ceil(to: toNearest))
    }
    
    public func toComponents() -> IsoDate {
        return IsoDate(timeIntervalSince1970: timeIntervalSince1970)
    }
    
    /// With format `yyyy-MM-dd'T'HH:mm'`
    var iso8601_YYYY_MM_dd_HH_mm: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year+1900)
        let month = Int(t.tm_mon+1)
        let day = Int(t.tm_mday)
        let hour = Int(t.tm_hour)
        let minute = Int(t.tm_min)
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2))"
    }
    
    /// With format `yyyy-MM-dd`
    var iso8601_YYYY_MM_dd: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year+1900)
        let month = Int(t.tm_mon+1)
        let day = Int(t.tm_mday)
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))"
    }
    
    /// With format `yyyyMMdd`
    var format_YYYYMMdd: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year+1900)
        let month = Int(t.tm_mon+1)
        let day = Int(t.tm_mday)
        return "\(year)\(month.zeroPadded(len: 2))\(day.zeroPadded(len: 2))"
    }
    
    /// With format `yyyyMMddHH`
    var format_YYYYMMddHH: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year+1900)
        let month = Int(t.tm_mon+1)
        let day = Int(t.tm_mday)
        let hour = Int(t.tm_hour)
        return "\(year)\(month.zeroPadded(len: 2))\(day.zeroPadded(len: 2))\(hour.zeroPadded(len: 2))"
    }
    
    // Return hour string as 2 character
    var hh: String {
        hour.zeroPadded(len: 2)
    }
    
    /// Return a new timestamp with setting the hour
    func with(hour: Int) -> Timestamp {
        return Timestamp(timeIntervalSince1970 / 86400 * 86400 + hour * 3600)
    }
    
    /// Return a new timestamp with setting the day and hour
    func with(year: Int? = nil, month: Int? = nil, day: Int? = nil) -> Timestamp {
        let date = toComponents()
        return Timestamp(year ?? date.year, month ?? date.month, day ?? date.day)
    }
}

extension Timestamp: Comparable {
    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.timeIntervalSince1970 < rhs.timeIntervalSince1970
    }
}

extension Timestamp: Strideable {
    public func distance(to other: Timestamp) -> Int {
        return other.timeIntervalSince1970 - timeIntervalSince1970
    }
    
    public func advanced(by n: Int) -> Timestamp {
        return add(n)
    }
}

extension Range where Bound == Timestamp {
    @inlinable public func add(_ offset: Int) -> Range<Timestamp> {
        return lowerBound.add(offset) ..< upperBound.add(offset)
    }
    
    @inlinable public func stride(dtSeconds: Int) -> StrideTo<Timestamp> {
        return Swift.stride(from: lowerBound, to: upperBound, by: dtSeconds)
    }
    
    /// Form a timerange with dt seconds
    @inlinable public func range(dtSeconds: Int) -> TimerangeDt {
        TimerangeDt(start: lowerBound, to: upperBound, dtSeconds: dtSeconds)
    }
    
    /// Convert to a striable year month range
    @inlinable public func toYearMonth() -> Range<YearMonth> {
        lowerBound.toComponents().toYearMonth() ..< upperBound.toComponents().toYearMonth()
    }
}


/// Time with utc offset seconds
public struct TimerangeLocal {
    /// utc timestamp
    public let range: Range<Timestamp>
    
    /// seconds offset to get to local time
    public let utcOffsetSeconds: Int
}


public struct TimerangeDt: Hashable {
    public let range: Range<Timestamp>
    public let dtSeconds: Int
    
    @inlinable public var count: Int {
        return (range.upperBound.timeIntervalSince1970 - range.lowerBound.timeIntervalSince1970) / dtSeconds
    }
    
    public init(start: Timestamp, to: Timestamp, dtSeconds: Int) {
        self.range = start ..< to
        self.dtSeconds = dtSeconds
    }
    
    public init(range: Range<Timestamp>, dtSeconds: Int) {
        self.range = range
        self.dtSeconds = dtSeconds
    }
    
    public init(start: Timestamp, nTime: Int, dtSeconds: Int) {
        self.range = start ..< start.add(nTime * dtSeconds)
        self.dtSeconds = dtSeconds
    }
    
    /// devide time by dtSeconds
    @inlinable public func toIndexTime() -> Range<Int> {
        return range.lowerBound.timeIntervalSince1970 / dtSeconds ..< range.upperBound.timeIntervalSince1970 / dtSeconds
    }
    
    @inlinable public func add(_ seconds: Int) -> TimerangeDt {
        return range.add(seconds).range(dtSeconds: dtSeconds)
    }
    
    func with(dtSeconds: Int) -> TimerangeDt {
        return TimerangeDt(range: range, dtSeconds: dtSeconds)
    }
    
    /// Format to a nice string like `2022-06-30 to 2022-07-13`
    func prettyString() -> String {
        /// Closed range end
        let end = range.upperBound.add(-1 * dtSeconds)
        if dtSeconds == 86400 {
            return "\(range.lowerBound.iso8601_YYYY_MM_dd) to \(end.iso8601_YYYY_MM_dd)"
        }
        if dtSeconds == 3600 {
            return "\(range.lowerBound.iso8601_YYYY_MM_dd_HH_mm) to \(end.iso8601_YYYY_MM_dd_HH_mm) (1-hourly)"
        }
        if dtSeconds == 3 * 3600 {
            return "\(range.lowerBound.iso8601_YYYY_MM_dd_HH_mm) to \(end.iso8601_YYYY_MM_dd_HH_mm) (3-hourly)"
        }
        return "\(range.lowerBound.iso8601_YYYY_MM_dd_HH_mm) to \(end.iso8601_YYYY_MM_dd_HH_mm) (dt=\(dtSeconds))"
    }
    
    /// Convert to a striable year month range
    @inlinable public func toYearMonth() -> Range<YearMonth> {
        return range.toYearMonth()
    }
}

extension TimerangeDt: Sequence {
    public func makeIterator() -> StrideToIterator<Timestamp> {
        range.stride(dtSeconds: dtSeconds).makeIterator()
    }
}


public extension Sequence where Element == Timestamp {
    /// With format `yyyy-MM-dd'T'HH:mm'`
    var iso8601_YYYYMMddHHmm: [String] {
        var time = 0
        var t = tm()
        var dateCalculated = 0
        return map {
            // only do date calculation if the actual date changes
            if dateCalculated != $0.timeIntervalSince1970 / 86400 {
                time = $0.timeIntervalSince1970
                dateCalculated = $0.timeIntervalSince1970 / 86400
                gmtime_r(&time, &t)
            }
            let year = Int(t.tm_year+1900)
            let month = Int(t.tm_mon+1)
            let day = Int(t.tm_mday)
            
            let hour = $0.hour
            let minute = $0.minute
            return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2))"
        }
    }
    
    /// With format `yyyy-MM-dd`
    var iso8601_YYYYMMdd: [String] {
        var time = 0
        var t = tm()
        return map {
            time = $0.timeIntervalSince1970
            gmtime_r(&time, &t)
            let year = Int(t.tm_year+1900)
            let month = Int(t.tm_mon+1)
            let day = Int(t.tm_mday)
            return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))"
        }
    }
}
