import Foundation

public struct YearMonth: Strideable, Comparable {
    private let monthsSince0: Int

    var year: Int { monthsSince0 / 12 }

    /// Range 1-12
    var month: Int { (monthsSince0 % 12) + 1}

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
        let components = timestamp.toComponents()
        self.init(year: components.year, month: components.month)
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
