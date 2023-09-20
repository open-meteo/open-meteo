import Foundation
import Vapor
import SwiftTimeZoneLookup

/// All API parameter that are accepted and decoded via GET
struct ApiQueryParameter: Content, ApiUnitsSelectable {
    let latitude: [String]
    let longitude: [String]
    let minutely_15: [String]?
    /// Select individual variables for current weather
    let current: [String]?
    let hourly: [String]?
    let daily: [String]?
    /// For seasonal forecast
    let six_hourly: [String]?
    let current_weather: Bool?
    let elevation: [String]?
    let timezone: [String]?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let length_unit: LengthUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let forecast_days: Int?
    let format: ForecastResultFormat?
    let models: [String]?
    let cell_selection: GridSelectionMode?
    
    /// Used in climate API
    let disable_bias_correction: Bool? // CMIP
    
    // Used in flood API
    let ensemble: Bool // Glofas
    
    /// In Air Quality API
    let domains: CamsQuery.Domain? // sams
    
    // TODO: Extend to include time for single hour data calls
    /// iso starting date `2022-02-01`
    let start_date: [String]?
    /// included end date `2022-06-01`
    let end_date: [String]?
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
    
    /// Parse `start_date` and `end_date` parameter to range of timestamps
    func getStartEndDates() throws -> [ClosedRange<Timestamp>]? {
        let startDate = try IsoDate.load(commaSeparatedOptional: start_date)
        let endDate = try IsoDate.load(commaSeparatedOptional: end_date)
        if start_date == nil, end_date == nil {
            return nil
        }
        guard let startDate, let endDate else {
            // BOTH parameters must be present
            throw ForecastapiError.startAndEnddataMustBeSpecified
        }
        if let past_days, past_days != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let forecast_days, forecast_days != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
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
    
    /// Reads coordinates, elevation, timezones and start/end dataparameter and prepares an array.
    /// For each element, an API response object will be returned later
    func prepareCoordinates(allowTimezones: Bool) throws -> [CoordinatesAndTimeZonesAndDates] {
        if !allowTimezones && daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }
        
        let dates = try getStartEndDates()
        let coordinates = try getCoordinatesWithTimezone(allowTimezones: allowTimezones)
        
        /// If no start/end dates are set, leav it `nil`
        guard let dates else {
            return coordinates.map({
                CoordinatesAndTimeZonesAndDates(coordinate: $0.coordinate, timezone: $0.timezone, startEndDate: nil)
            })
        }
        /// Multiple coordinates, but one start/end date. Return the same date range for each coordinate
        if dates.count == 1 {
            return coordinates.map({
                CoordinatesAndTimeZonesAndDates(coordinate: $0.coordinate, timezone: $0.timezone, startEndDate: dates[0])
            })
        }
        /// Single coordinate, but multiple dates. Return different date ranges, but always the same coordinate
        if coordinates.count == 1 {
            return dates.map {
                CoordinatesAndTimeZonesAndDates(coordinate: coordinates[0].coordinate, timezone: coordinates[0].timezone, startEndDate: $0)
            }
        }
        guard dates.count == coordinates.count else {
            throw ForecastapiError.coordinatesAndStartEndDatesCountMustBeTheSame
        }
        return zip(coordinates, dates).map {
            CoordinatesAndTimeZonesAndDates(coordinate: $0.0.coordinate, timezone: $0.0.timezone, startEndDate: $0.1)
        }
    }
    
    /// Reads coordinates and timezone fields
    /// If only one timezone is given, use the same timezone for all coordinates
    /// Throws errors on invalid coordinates, timezones or invalid counts
    private func getCoordinatesWithTimezone(allowTimezones: Bool) throws -> [(coordinate: CoordinatesAndElevation, timezone: TimezoneWithOffset)] {
        let coordinates = try getCoordinates()
        let timezones = allowTimezones ? try TimeZoneOrAuto.load(commaSeparatedOptional: timezone) : nil
        
        guard let timezones else {
            // if no timezone is specified, use GMT for all locations
            return coordinates.map {
                ($0, .gmt)
            }
        }
        if timezones.count == 1 {
            return try coordinates.map {
                ($0, try timezones[0].resolve(coordinate: $0))
            }
        }
        guard timezones.count == coordinates.count else {
            throw ForecastapiError.latitudeAndLongitudeCountMustBeTheSame
        }
        return try zip(coordinates, timezones).map {
            ($0, try $1.resolve(coordinate: $0))
        }
    }
    
    /// Parse latitude, longitude and elevation arrays to an array of coordinates
    /// If no elevation is provided, a DEM is used to resolve the elevation
    /// Throws errors on invalid coordinate ranges
    private func getCoordinates() throws -> [CoordinatesAndElevation] {
        let latitude = try Float.load(commaSeparated: self.latitude)
        let longitude = try Float.load(commaSeparated: self.longitude)
        let elevation = try Float.load(commaSeparatedOptional: self.elevation)
        guard latitude.count == longitude.count else {
            throw ForecastapiError.latitudeAndLongitudeCountMustBeTheSame
        }
        if let elevation {
            guard elevation.count == longitude.count else {
                throw ForecastapiError.coordinatesAndElevationCountMustBeTheSame
            }
            return try zip(latitude, zip(longitude, elevation)).map({
                try CoordinatesAndElevation(latitude: $0.0, longitude: $0.1.0, elevation: $0.1.1)
            })
        }
        return try zip(latitude, longitude).map({
            try CoordinatesAndElevation(latitude: $0.0, longitude: $0.1, elevation: nil)
        })
    }
    
    func getTimerange(timezone: TimezoneWithOffset, current: Timestamp, forecastDays: Int, forecastDaysMax: Int, startEndDate: ClosedRange<Timestamp>?, allowedRange: Range<Timestamp>, pastDaysMax: Int) throws -> TimerangeLocal {
        let actualUtcOffset = timezone.utcOffsetSeconds
        let utcOffset = (actualUtcOffset / 3600) * 3600
        if let startEndDate {
            let start = startEndDate.lowerBound
            let includedEnd = startEndDate.upperBound
            guard allowedRange.contains(start) else {
                throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: allowedRange)
            }
            guard allowedRange.contains(includedEnd) else {
                throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: allowedRange)
            }
            /// TODO: If a single hour is requested, this range needs to be adjusted
            return TimerangeLocal(range: start.add(-1 * utcOffset) ..< includedEnd.add(86400 - utcOffset), utcOffsetSeconds: utcOffset)
        }
        if forecastDays < 0 || forecastDays > forecastDaysMax {
            throw ForecastapiError.forecastDaysInvalid(given: forecastDays, allowed: 0...forecastDaysMax)
        }
        if let past_days = past_days, past_days < 0 || past_days > pastDaysMax {
            throw ForecastapiError.pastDaysInvalid(given: past_days, allowed: 0...pastDaysMax)
        }
        let time = Self.forecastTimeRange(currentTime: current, utcOffsetSeconds: utcOffset, pastDays: past_days, forecastDays: forecastDays)
        return time
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
}


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
    case forecastDaysParameterNotAllowedWithStartEndRange
    case latitudeAndLongitudeSameCount
    case latitudeAndLongitudeNotEmpty
    case latitudeAndLongitudeMaximum(max: Int)
    case latitudeAndLongitudeCountMustBeTheSame
    case startAndEndDateCountMustBeTheSame
    case coordinatesAndStartEndDatesCountMustBeTheSame
    case coordinatesAndElevationCountMustBeTheSame
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
        case .forecastDaysParameterNotAllowedWithStartEndRange:
            return "Parameter 'forecast_days' is mutually exclusive with 'start_date' and 'end_date'"
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
        case .startAndEndDateCountMustBeTheSame:
            return "Parameter 'start_date' and 'end_date' must have the same number of elements"
        case .coordinatesAndStartEndDatesCountMustBeTheSame:
            return "Parameter 'start_date' and 'end_date' must have the same number of elements as coordinates"
        case .coordinatesAndElevationCountMustBeTheSame:
            return "Parameter 'elevation' must have the same number of elements as coordinates"
        case .generic(message: let message):
            return message
        }
    }
}


/// Resolve coordinates and timezone
struct CoordinatesAndElevation {
    let latitude: Float
    let longitude: Float
    let elevation: Float
    
    /// If elevation is `nil` it will resolve it from DEM. If `NaN` it stays `NaN`.
    init(latitude: Float, longitude: Float, elevation: Float? = .nan) throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = try elevation ?? Dem90.read(lat: latitude, lon: longitude)
    }
}

struct CoordinatesAndTimeZonesAndDates {
    let coordinate: CoordinatesAndElevation
    let timezone: TimezoneWithOffset
    let startEndDate: ClosedRange<Timestamp>?
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
                    return .timezone(try TimeZone.initWithFallback(String(timezone)))
                }
            }
        }
    }
    
    /// Given a coordinate, resolve auto timezone if required
    func resolve(coordinate: CoordinatesAndElevation) throws -> TimezoneWithOffset {
        switch self {
        case .auto:
            return try .init(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        case .timezone(let timezone):
            return .init(timezone: timezone)
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
    
    fileprivate static let timezoneDatabase = try! SwiftTimeZoneLookup(databasePath: "./Resources/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources/")
    
    public init(utcOffsetSeconds: Int, identifier: String, abbreviation: String) {
        self.utcOffsetSeconds = utcOffsetSeconds
        self.identifier = identifier
        self.abbreviation = abbreviation
    }
    
    public init(timezone: TimeZone) {
        self.utcOffsetSeconds = timezone.secondsFromGMT()
        self.identifier = timezone.identifier
        self.abbreviation = timezone.abbreviation() ?? ""
    }
    
    public init(latitude: Float, longitude: Float) throws {
        guard let identifier = TimezoneWithOffset.timezoneDatabase.simple(latitude: latitude, longitude: longitude) else {
            throw ForecastapiError.invalidTimezone
        }
        self.init(timezone: try TimeZone.initWithFallback(identifier))
    }
    static let gmt = TimezoneWithOffset(utcOffsetSeconds: 0, identifier: "GMT", abbreviation: "GMT")
}

extension TimeZone {
    static func initWithFallback(_ identifier: String) throws -> TimeZone {
        // Some older timezone databases may still use the old name for Kyiv
        if identifier == "Europe/Kyiv", let tz = TimeZone(identifier: "Europe/Kiev") {
            return tz
        }
        if identifier == "America/Nuuk", let tz = TimeZone(identifier: "America/Godthab") {
            return tz
        }
        guard let tz = TimeZone(identifier: identifier) else {
            throw ForecastapiError.invalidTimezone
        }
        return tz
    }
}
