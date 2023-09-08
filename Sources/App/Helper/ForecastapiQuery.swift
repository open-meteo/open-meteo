import Foundation
import Vapor
import SwiftTimeZoneLookup

enum ForecastapiError: Error {
    case latitudeMustBeInRangeOfMinus90to90(given: Float)
    case longitudeMustBeInRangeOfMinus180to180(given: Float)
    case pastDaysInvalid(given: Int, allowed: ClosedRange<Int>)
    case forecastDaysInvalid(given: Int, allowed: ClosedRange<Int>)
    case enddateMustBeLargerEqualsThanStartdate
    case dateOutOfRange(parameter: String, allowed: Range<Timestamp>)
    case startAndEnddataMustBeSpecified
    case invalidTimezone
    case timezoneNotSupported
    case noDataAvilableForThisLocation
    case timezoneRequired
    case pastDaysParameterNotAllowedWithStartEndRange
    case latitudeAndLongitudeSameCount
    case latitudeAndLongitudeNotEmpty
    case latitudeAndLongitudeMaximum(max: Int)
    case latitudeAndLongitudeCountMustBeTheSame
    case generic(message: String)
}

extension ForecastapiError: AbortError {
    var status: HTTPResponseStatus {
        return .badRequest
    }
    
    var reason: String {
        switch self {
        case .latitudeMustBeInRangeOfMinus90to90(given: let given):
            return "Latitude must be in range of -90 to 90°. Given: \(given)."
        case .longitudeMustBeInRangeOfMinus180to180(given: let given):
            return "Longitude must be in range of -180 to 180°. Given: \(given)."
        case .pastDaysInvalid(given: let given, allowed: let allowed):
            return "Past days is invalid. Allowed range \(allowed.lowerBound) to \(allowed.upperBound). Given \(given)."
        case .forecastDaysInvalid(given: let given, allowed: let allowed):
            return "Forecast days is invalid. Allowed range \(allowed.lowerBound) to \(allowed.upperBound). Given \(given)."
        case .invalidTimezone:
            return "Invalid timezone"
        case .timezoneRequired:
            return "Timezone is required"
        case .enddateMustBeLargerEqualsThanStartdate:
            return "End-date must be larger or equals than start-date"
        case .dateOutOfRange(let paramater, let allowed):
            return "Parameter '\(paramater)' is out of allowed range from \(allowed.lowerBound.iso8601_YYYY_MM_dd) to \(allowed.upperBound.add(-86400).iso8601_YYYY_MM_dd)"
        case .startAndEnddataMustBeSpecified:
            return "Both 'start_date' and 'end_date' must be set in the url"
        case .pastDaysParameterNotAllowedWithStartEndRange:
            return "Parameter 'past_days' is mutually exclusive with 'start_date' and 'end_date'"
        case .timezoneNotSupported:
            return "This API does not yet support timezones"
        case .latitudeAndLongitudeSameCount:
            return "Parameter 'latitude' and 'longitude' must have the same amount of elements"
        case .latitudeAndLongitudeNotEmpty:
            return "Parameter 'latitude' and 'longitude' must not be empty"
        case .latitudeAndLongitudeMaximum(max: let max):
            return "Parameter 'latitude' and 'longitude' must not exceed \(max) coordinates."
        case .latitudeAndLongitudeCountMustBeTheSame:
            return "Parameter 'latitude' and 'longitude' must have the same number of elements"
        case .noDataAvilableForThisLocation:
            return "No data is available for this location"
        case .generic(message: let message):
            return message
        }
    }
}

enum Timeformat: String, Codable {
    case iso8601
    case unixtime
    
    var unit: SiUnit {
        switch self {
        case .iso8601:
            return .iso8601
        case .unixtime:
            return .unixtime
        }
    }
}

protocol QueryWithStartEndDateTimeZone: QueryWithTimezone {
    var past_days: Int? { get }
    
    /// iso starting date `2022-02-01`
    var start_date: IsoDate? { get }
    
    /// included end date `2022-06-01`
    var end_date: IsoDate? { get }
}

extension QueryWithStartEndDateTimeZone {
    func getTimerange(timezone: TimeZone, current: Timestamp, forecastDays: Int, allowedRange: Range<Timestamp>, past_days_max: Int = 92) throws -> (actualUtcOffset: Int, time: TimerangeLocal) {
        let actualUtcOffset = timezone.secondsFromGMT()
        let utcOffset = (actualUtcOffset / 3600) * 3600
        if let startEnd = try getStartEndDateLocal(allowedRange: allowedRange, utcOffsetSeconds: utcOffset) {
            return (actualUtcOffset, startEnd)
        }
        if let past_days = past_days, past_days < 0 || past_days > past_days_max {
            throw ForecastapiError.pastDaysInvalid(given: past_days, allowed: 0...past_days_max)
        }
        let time = Self.forecastTimeRange(currentTime: current, utcOffsetSeconds: utcOffset, pastDays: past_days, forecastDays: forecastDays)
        return (actualUtcOffset, time)
    }
    
    /// Return an aligned timerange for a local-time 7 day forecast. Timestamps are in UTC time.
    public static func forecastTimeRange(currentTime: Timestamp, utcOffsetSeconds: Int, pastDays: Int?, forecastDays: Int) -> TimerangeLocal {
        /// aligin starttime to localtime 0:00
        let pastDaysSeconds = (pastDays ?? 0) * 3600*24
        let starttimeUtc = ((currentTime.timeIntervalSince1970 + utcOffsetSeconds) / (3600*24)) * (3600*24) - utcOffsetSeconds - pastDaysSeconds
        let endtimeUtc = starttimeUtc + forecastDays*24*3600 + pastDaysSeconds
        let time = Timestamp(starttimeUtc) ..< Timestamp(endtimeUtc)
        return TimerangeLocal(range: time, utcOffsetSeconds: utcOffsetSeconds)
    }
    
    /// Get a timerange based on `start_date` and `end_date` parameters from the url, if both are set. Nil otherwise
    private func getStartEndDateLocal(allowedRange: Range<Timestamp>, utcOffsetSeconds: Int) throws -> TimerangeLocal? {
        if start_date == nil, end_date == nil {
            return nil
        }
        guard let start_date = start_date, let end_date = end_date else {
            // BOTH parameters must be present
            throw ForecastapiError.startAndEnddataMustBeSpecified
        }
        if let past_days = past_days, past_days != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        
        let start = start_date.toTimestamp()
        let includedEnd = end_date.toTimestamp()
        guard includedEnd.timeIntervalSince1970 >= start.timeIntervalSince1970 else {
            throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
        }
        guard allowedRange.contains(start) else {
            throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: allowedRange)
        }
        guard allowedRange.contains(includedEnd) else {
            throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: allowedRange)
        }
        return TimerangeLocal(range: start.add(-1 * utcOffsetSeconds) ..< includedEnd.add(86400 - utcOffsetSeconds), utcOffsetSeconds: utcOffsetSeconds)
    }
}

protocol QueryWithTimezone {
    var timezone: String? { get }
    
    var latitude: Float { get }
    
    var longitude: Float { get }
    
    var cell_selection: GridSelectionMode? { get }
}

fileprivate let timezoneDatabase = try! SwiftTimeZoneLookup(databasePath: "./Resources/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources/")

extension QueryWithTimezone {
    /// Get user specified timezone. It `auto` is specified, resolve via coordinates
    func resolveTimezone() throws -> TimeZone {
        return try TimeZone.resolveApiParams(timezone: timezone, latitude: latitude, longitude: longitude)
    }
}

extension TimeZone {
    /// Get user specified timezone. It `auto` is specified, resolve via coordinates
    static func resolveApiParams(timezone: String?, latitude: Float, longitude: Float) throws -> TimeZone {
        guard var timezone = timezone else {
            return TimeZone(identifier: "GMT")!
        }
        if timezone == "auto" {
            if let res = timezoneDatabase.simple(latitude: latitude, longitude: longitude) {
                timezone = res
            }
        }
        // Some older tz databases my still use the old name for Kyiv
        if timezone == "Europe/Kyiv", let tz = TimeZone(identifier: "Europe/Kiev") {
            return tz
        }
        guard let tz = TimeZone(identifier: timezone) else {
            throw ForecastapiError.invalidTimezone
        }
        return tz
    }
}

/// Differentiate between a user defined timezone or `auto` which is later resolved using coordinates
enum TimeZoneOrAuto {
    /// User specified `auto`
    case auto
    
    /// User specified valid timezone
    case timezone(TimeZone)
    
    /// Take a string array which contains timezones or `auto`. Does an additional decoding step to split coma separated timezones.
    /// Throws errors on invalid timezones
    static func load(commaSeparatedOptional: [String]?) throws -> [TimeZoneOrAuto]? {
        return try commaSeparatedOptional.map {
            try $0.flatMap { s in
                try s.split(separator: ",").map { timezone in
                    if timezone == "auto" {
                        return .auto
                    }
                    // Some older timezone databases may still use the old name for Kyiv
                    if timezone == "Europe/Kyiv", let tz = TimeZone(identifier: "Europe/Kiev") {
                        return .timezone(tz)
                    }
                    guard let tz = TimeZone(identifier: String(timezone)) else {
                        throw ForecastapiError.invalidTimezone
                    }
                    return .timezone(tz)
                }
            }
        }
    }
    
    /// Given a coordinate, resolve auto timezone if required
    func resolve(coordinate: CoordinatesAndElevation) throws -> CoordinatesAndTimeZones {
        switch self {
        case .auto:
            return CoordinatesAndTimeZones(coordinate: coordinate, timezone: .gmt)
        case .timezone(_):
            return CoordinatesAndTimeZones(
                coordinate: coordinate,
                timezone: try .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
        }
    }
}

struct TimezoneWithOffset {
    /// The actual utc offset. Not adjusted to the next full hour.
    let utcOffsetSeconds: Int
    
    /// Identifier like `Europe/Berlin`
    let identifier: String
    
    /// Abbreviation like `CEST`
    let abbreviation: String
    
    public init(utcOffsetSeconds: Int, identifier: String, abbreviation: String) {
        self.utcOffsetSeconds = utcOffsetSeconds
        self.identifier = identifier
        self.abbreviation = abbreviation
    }
    
    public init(latitude: Float, longitude: Float) throws {
        guard let identifier = timezoneDatabase.simple(latitude: latitude, longitude: longitude) else {
            throw ForecastapiError.invalidTimezone
        }
        guard let timezone = TimeZone(identifier: identifier) else {
            throw ForecastapiError.invalidTimezone
        }
        self.utcOffsetSeconds = timezone.secondsFromGMT()
        self.identifier = timezone.identifier
        self.abbreviation = timezone.abbreviation() ?? ""
    }
    
    static let gmt = TimezoneWithOffset(utcOffsetSeconds: 0, identifier: "GMT", abbreviation: "GMT")
}
