import Foundation

public struct YearMonth: Strideable, Comparable {
    private let monthsSince0: Int

    public var year: Int { monthsSince0 / 12 }

    /// Range 1-12
    public var month: Int { (monthsSince0 % 12) + 1}

    public init(year: Int, month: Int) {
        assert(year > 1800)
        assert(year < 2200)
        assert(month >= 1)
        assert(month <= 12)
        self.monthsSince0 = year * 12 + month - 1
    }

    private init(monthSince1970: Int) {
        self.monthsSince0 = monthSince1970
    }

    public init(timestamp: Timestamp) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month], from: Date(timeIntervalSince1970: TimeInterval(timestamp.timeIntervalSince1970)))
        self.init(year: components.year!, month: components.month!)
    }

    public func distance(to other: YearMonth) -> Int {
        other.monthsSince0 - monthsSince0
    }

    public func advanced(by n: Int) -> YearMonth {
        YearMonth(monthSince1970: monthsSince0 + n)
    }

    public var timestamp: Timestamp {
        Timestamp(year, month, 1)
    }
}

extension YearMonth: Hashable {
}

public extension Range where Bound == Timestamp {
    func toYearMonth() -> Range<YearMonth> {
        YearMonth(timestamp: lowerBound) ..< YearMonth(timestamp: upperBound)
    }
}

public extension TimerangeDt {
    func toYearMonth() -> Range<YearMonth> {
        range.toYearMonth()
    }
}

public extension Timestamp {
    func toYearMonth() -> YearMonth {
        YearMonth(timestamp: self)
    }
}
