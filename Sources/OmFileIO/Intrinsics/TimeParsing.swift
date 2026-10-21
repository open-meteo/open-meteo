import OmTime
import Foundation

public extension StringProtocol {
    /// Formats from: "EEE, dd MMM yyyy HH:mm:ss GMT".. like `Wed, 19 Aug 2026 09:38:00 GMT`
    func parseLastModifiedDate() throws -> Timestamp {
        guard self.count == 29 else {
            throw TimeError.InvalidDateFromat
        }
        guard let day = Int(self[5..<7]), day >= 1, day <= 31 else {
            throw TimeError.InvalidDate
        }
        let month: Int
        switch self[8..<11] {
        case "Jan": month = 1
        case "Feb": month = 2
        case "Mar": month = 3
        case "Apr": month = 4
        case "May": month = 5
        case "Jun": month = 6
        case "Jul": month = 7
        case "Aug": month = 8
        case "Sep": month = 9
        case "Oct": month = 10
        case "Nov": month = 11
        case "Dec": month = 12
        default: throw TimeError.InvalidDate
        }
        guard let year = Int(self[12..<16]), year >= 1900, year <= 2200 else {
            throw TimeError.InvalidDate
        }
        guard let hour = Int(self[17..<19]), hour >= 0, hour <= 23 else {
            throw TimeError.InvalidDate
        }
        guard let minute = Int(self[20..<22]), minute >= 0, minute <= 59 else {
            throw TimeError.InvalidDate
        }
        guard let second = Int(self[23..<25]), second >= 0, second <= 59 else {
            throw TimeError.InvalidDate
        }
        guard self[25..<29] == " GMT" else {
            throw TimeError.InvalidDate
        }
        return Timestamp(year, month, day, hour, minute, second)
    }
    
    /// Formats from: "EEE, dd MMM yyyy HH:mm:ss GMT".. like `2026-08-19T09:38:00.000Z`
    func parseXmlS3Date() throws -> Timestamp {
        let str = self
        guard str.count == 24 else {
            throw TimeError.InvalidDateFromat
        }
        guard let year = Int(str[0..<4]), year >= 1900, year <= 2200 else {
            throw TimeError.InvalidDate
        }
        guard let month = Int(str[5..<7]), month >= 1, month <= 12 else {
            throw TimeError.InvalidDate
        }
        guard let day = Int(str[8..<10]), day >= 1, day <= 31 else {
            throw TimeError.InvalidDate
        }
        guard let hour = Int(str[11..<13]), hour >= 0, hour <= 23 else {
            throw TimeError.InvalidDate
        }
        guard let minute = Int(str[14..<16]), minute >= 0, minute <= 59 else {
            throw TimeError.InvalidDate
        }
        guard let second = Int(str[17..<19]), second >= 0, second <= 59 else {
            throw TimeError.InvalidDate
        }
        return Timestamp(year, month, day, hour, minute, second)
    }
}

public extension Timestamp {
    var lastModifiedHttpDateFormat: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        
        // HTTP days of the week (0 = Sunday)
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let wdayStr = days[Int(t.tm_wday)]
        
        // HTTP months (0 = January)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthStr = months[Int(t.tm_mon)]
        
        let day = Int(t.tm_mday).zeroPadded(len: 2)
        let year = Int(t.tm_year + 1900)
        let hour = Int(t.tm_hour).zeroPadded(len: 2)
        let minute = Int(t.tm_min).zeroPadded(len: 2)
        let second = Int(t.tm_sec).zeroPadded(len: 2)
        
        // Formats to: "EEE, dd MMM yyyy HH:mm:ss GMT"
        return "\(wdayStr), \(day) \(monthStr) \(year) \(hour):\(minute):\(second) GMT"
    }
    
    /// Format dates like `2023-11-14T04:32:17.000Z`
    var s3ListXmlDateFormat: String {
        var time = timeIntervalSince1970
        var t = tm()
        gmtime_r(&time, &t)
        let year = Int(t.tm_year + 1900)
        let month = Int(t.tm_mon + 1)
        let day = Int(t.tm_mday)
        let hour = Int(t.tm_hour)
        let minute = Int(t.tm_min)
        let second = Int(t.tm_sec)
        return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2)):\(second.zeroPadded(len: 2)).000Z"
    }
}
