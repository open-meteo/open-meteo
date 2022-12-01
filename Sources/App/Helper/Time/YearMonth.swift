import Foundation


public struct YearMonth: Strideable, Comparable {
    private let monthsSince1970: Int
    
    var year: Int { monthsSince1970 / 12 }
    
    /// Range 1-12
    var month: Int { (monthsSince1970 % 12) + 1}
    
    public init(year: Int, month: Int) {
        assert(year > 1800)
        assert(year < 2200)
        assert(month >= 1)
        assert(month <= 12)
        self.monthsSince1970 = year * 12 + month - 1
    }
    
    private init(monthSince1970: Int) {
        self.monthsSince1970 = monthSince1970
    }
    
    public func distance(to other: YearMonth) -> Int {
        other.monthsSince1970 - monthsSince1970
    }
    
    public func advanced(by n: Int) -> YearMonth {
        YearMonth(monthSince1970: monthsSince1970 + n)
    }
}
