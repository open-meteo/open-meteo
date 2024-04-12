import Foundation
import Vapor
import SwiftTimeZoneLookup

struct ApiQueryStartEndRanges {
    let daily: ClosedRange<Timestamp>?
    let hourly: ClosedRange<Timestamp>?
    let minutely_15: ClosedRange<Timestamp>?
}

extension ClosedRange where Element == Timestamp {
    /// Convert closed range to an openrange with delta time in seconds
    func toRange(dt: Int) -> TimerangeDt {
        TimerangeDt(range: lowerBound ..< upperBound.add(dt), dtSeconds: dt)
    }
}

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
    let location_id: [String]?
    let timezone: [String]?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let wind_speed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let length_unit: LengthUnit?
    let timeformat: Timeformat?
    
    let bounding_box: [String]
    
    let past_days: Int?
    let past_hours: Int?
    let past_minutely_15: Int?
    let forecast_days: Int?
    let forecast_hours: Int?
    let forecast_minutely_15: Int?
    
    /// If forecast_hours is set, the default is to start from the current hour. With `initial_hours`, a different hout of the day can be selected
    /// E.g. initial_hours=0 and forecast_hours=12 would return the first 12 hours of the current day.
    let initial_hours: Int?
    let initial_minutely_15: Int?
    
    let format: ForecastResultFormat?
    let models: [String]?
    let cell_selection: GridSelectionMode?
    
    let apikey: String?
    
    /// Tilt of a solar panel for GTI calculation. 0° horizontal, 90° vertical.
    let tilt: Float?
    
    /// Azimuth of a solar panel for GTI calculation. 0° south, -90° east, 90° west
    let azimuth: Float?
    
    /// Used in climate API
    let disable_bias_correction: Bool? // CMIP
    
    // Used in flood API
    let ensemble: Bool // Glofas
    
    /// In Air Quality API
    let domains: CamsQuery.Domain? // sams
    
    /// iso starting date `2022-02-01`
    let start_date: [String]
    /// included end date `2022-06-01`
    let end_date: [String]
    
    /// iso starting date `2022-02-01T00:00`
    let start_hour: [String]
    /// included end date `2022-06-01T23:00`
    let end_hour: [String]
    
    /// iso starting date `2022-02-01T00:00`
    let start_minutely_15: [String]
    /// included end date `2022-06-01T23:45`
    let end_minutely_15: [String]
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
    
    var readerOptions: GenericReaderOptions {
        return GenericReaderOptions(tilt: tilt, azimuth: azimuth)
    }
    
    /// Parse `start_date` and `end_date` parameter to range of timestamps
    func getStartEndDates() throws -> [ApiQueryStartEndRanges] {
        let dates = try IsoDate.loadRange(start: start_date, end: end_date)
        let hourRange = try IsoDateTime.loadRange(start: start_hour, end: end_hour)
        let minutely15Range = try IsoDateTime.loadRange(start: start_minutely_15, end: end_minutely_15)
        
        if dates.isEmpty, hourRange.isEmpty, minutely15Range.isEmpty {
            return []
        }
        if let past_days, past_days != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let forecast_days, forecast_days != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let past_hours, past_hours != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let forecast_hours, forecast_hours != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let past_minutely_15, past_minutely_15 != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        if let forecast_minutely_15, forecast_minutely_15 != 0 {
            throw ForecastapiError.pastDaysParameterNotAllowedWithStartEndRange
        }
        let count = max(max(dates.count, hourRange.count), minutely15Range.count)
        return (0..<count).map {
            ApiQueryStartEndRanges(
                daily: $0 < dates.count ? dates[$0] : nil,
                hourly: $0 < hourRange.count ? hourRange[$0] : nil,
                minutely_15: $0 < minutely15Range.count ? minutely15Range[$0] : nil)
        }
    }
    
    enum ApiRequestGeometry {
        case coordinates([CoordinatesAndTimeZonesAndDates])
        case boundingBox(BoundingBoxWGS84, dates: [ApiQueryStartEndRanges], timezone: TimezoneWithOffset)
    }
    
    /// Reads coordinates, elevation, timezones and start/end dataparameter and prepares an array.
    /// For each element, an API response object will be returned later
    func prepareCoordinates(allowTimezones: Bool) throws -> ApiRequestGeometry {
        let dates = try getStartEndDates()
        if let bb = try getBoundingBox() {
            let timezones = allowTimezones ? try TimeZoneOrAuto.load(commaSeparatedOptional: timezone) ?? [] : []
            guard timezones.count <= 1 else {
                throw ForecastapiError.generic(message: "Only one timezone may be specified with bounding box queries")
            }
            let timezone: TimezoneWithOffset = try timezones.first.map({
                switch $0 {
                case .auto:
                    throw ForecastapiError.generic(message: "Timezone 'auto' not supported with bounding box queries")
                case .timezone(let t):
                    return TimezoneWithOffset(timezone: t)
                }
            }) ?? TimezoneWithOffset.gmt
            return .boundingBox(bb, dates: dates, timezone: timezone)
        }
        
        let coordinates = try getCoordinatesWithTimezone(allowTimezones: allowTimezones)
        
        /// If no start/end dates are set, leav it `nil`
        guard dates.count > 0 else {
            return .coordinates(coordinates.map({
                CoordinatesAndTimeZonesAndDates(coordinate: $0.coordinate, timezone: $0.timezone, startEndDate: nil)
            }))
        }
        /// Multiple coordinates, but one start/end date. Return the same date range for each coordinate
        if dates.count == 1 {
            return .coordinates(coordinates.map({
                CoordinatesAndTimeZonesAndDates(coordinate: $0.coordinate, timezone: $0.timezone, startEndDate: dates[0])
            }))
        }
        /// Single coordinate, but multiple dates. Return different date ranges, but always the same coordinate
        if coordinates.count == 1 {
            return .coordinates(dates.map {
                CoordinatesAndTimeZonesAndDates(coordinate: coordinates[0].coordinate, timezone: coordinates[0].timezone, startEndDate: $0)
            })
        }
        guard dates.count == coordinates.count else {
            throw ForecastapiError.coordinatesAndStartEndDatesCountMustBeTheSame
        }
        return .coordinates(zip(coordinates, dates).map {
            CoordinatesAndTimeZonesAndDates(coordinate: $0.0.coordinate, timezone: $0.0.timezone, startEndDate: $0.1)
        })
    }
    
    /// Parse `&bounding_box=` parameter. Format: lat1, lon1, lat2, lon2
    func getBoundingBox() throws -> BoundingBoxWGS84? {
        let coordinates = try Float.load(commaSeparated: self.bounding_box)
        guard coordinates.count > 0 else {
            return nil
        }
        guard coordinates.count == 4 else {
            throw ForecastapiError.generic(message: "Parameter bounding_box must have 4 values")
        }
        let lat1 = coordinates[0]
        let lon1 = coordinates[1]
        let lat2 = coordinates[2]
        let lon2 = coordinates[3]
        
        guard lat1 < lat2 else {
            throw ForecastapiError.generic(message: "The first latitude must be smaller than the second latitude")
        }
        guard (-90...90).contains(lat1), (-90...90).contains(lat2) else {
            throw ForecastapiError.generic(message: "Latitudes must be between -90 and 90")
        }
        guard lon1 < lon2 else {
            throw ForecastapiError.generic(message: "The first longitude must be smaller than the second longitude")
        }
        guard (-180...180).contains(lon1), (-180...180).contains(lon2) else {
            throw ForecastapiError.generic(message: "Longitudes must be between -180 and 180")
        }
        return BoundingBoxWGS84(latitude: lat1..<lat2, longitude: lon1..<lon2)
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
        let locationIds = try Int.load(commaSeparatedOptional: self.location_id)
        guard latitude.count == longitude.count else {
            throw ForecastapiError.latitudeAndLongitudeCountMustBeTheSame
        }
        if let locationIds {
            guard locationIds.count == longitude.count else {
                throw ForecastapiError.latitudeAndLongitudeCountMustBeTheSame
            }
        }
        if let elevation {
            guard elevation.count == longitude.count else {
                throw ForecastapiError.coordinatesAndElevationCountMustBeTheSame
            }
            return try zip(latitude, zip(longitude, elevation)).enumerated().map({
                try CoordinatesAndElevation(
                    latitude: $0.element.0,
                    longitude: $0.element.1.0,
                    locationId: locationIds?[$0.offset] ?? $0.offset,
                    elevation: $0.element.1.1
                )
            })
        }
        return try zip(latitude, longitude).enumerated().map({
            try CoordinatesAndElevation(
                latitude: $0.element.0,
                longitude: $0.element.1,
                locationId: locationIds?[$0.offset] ?? $0.offset,
                elevation: nil
            )
        })
    }
    
    func getTimerange2(timezone: TimezoneWithOffset, current: Timestamp, forecastDaysDefault: Int, forecastDaysMax: Int, startEndDate: ApiQueryStartEndRanges?, allowedRange: Range<Timestamp>, pastDaysMax: Int) throws -> ForecastApiTimeRange {
        
        let actualUtcOffset = timezone.utcOffsetSeconds
        /// Align data to nearest hour -> E.g. timezones in india may have 15 minutes offsets
        let utcOffset = (actualUtcOffset / 3600) * 3600
        
        if let startEndDate {
            // Start and end data parameter have been set
            let daily = startEndDate.daily?.toRange(dt: 86400) ?? TimerangeDt(start: current, nTime: 0, dtSeconds: 86400)
            let hourly = startEndDate.hourly?.toRange(dt: 3600) ?? daily.with(dtSeconds: 3600)
            let minutely_15 = startEndDate.minutely_15?.toRange(dt: 900) ?? hourly.with(dtSeconds: 900)
            
            guard allowedRange.contains(daily.range.lowerBound) else {
                throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: allowedRange)
            }
            guard allowedRange.contains(daily.range.upperBound.add(-1 * daily.dtSeconds)) else {
                throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: allowedRange)
            }
            guard allowedRange.contains(hourly.range.lowerBound) else {
                throw ForecastapiError.dateOutOfRange(parameter: "start_hourly", allowed: allowedRange)
            }
            guard allowedRange.contains(hourly.range.upperBound.add(-1 * hourly.dtSeconds)) else {
                throw ForecastapiError.dateOutOfRange(parameter: "end_hourly", allowed: allowedRange)
            }
            guard allowedRange.contains(minutely_15.range.lowerBound) else {
                throw ForecastapiError.dateOutOfRange(parameter: "start_minutely_15", allowed: allowedRange)
            }
            guard allowedRange.contains(minutely_15.range.upperBound.add(-1 * minutely_15.dtSeconds)) else {
                throw ForecastapiError.dateOutOfRange(parameter: "end_minutely_15", allowed: allowedRange)
            }
            
            return ForecastApiTimeRange(
                dailyDisplay: daily.add(-1 * actualUtcOffset),
                dailyRead: daily.add(-1 * utcOffset),
                hourlyDisplay: hourly.add(-1 * actualUtcOffset),
                hourlyRead: hourly.add(-1 * utcOffset),
                minutely15: minutely_15.add(-1 * actualUtcOffset)
            )
        }
        
        // Evaluate any forecast_xxx, past_xxx parameter or fallback to default time
        let daily = try Self.forecastTimeRange2(currentTime: current, utcOffset: utcOffset, pastSteps: past_days, forecastSteps: forecast_days, pastStepsMax: pastDaysMax, forecastStepsMax: forecastDaysMax, forecastStepsDefault: forecastDaysDefault, initialStep: nil, dtSeconds: 86400) ?? Self.forecastTimeRange2(currentTime: current, utcOffset: utcOffset, pastSteps: 0, forecastSteps: forecastDaysDefault, initialStep: nil, dtSeconds: 86400)
        
        // Falls back to daily range as well
        let hourly = try Self.forecastTimeRange2(currentTime: current, utcOffset: utcOffset, pastSteps: past_hours, forecastSteps: forecast_hours, pastStepsMax: pastDaysMax * 24, forecastStepsMax: forecastDaysMax * 24, forecastStepsDefault: forecastDaysMax*24, initialStep: initial_hours, dtSeconds: 3600) ?? daily.with(dtSeconds: 3600)
        
        // May default back to 3 day forecast
        let minutely_15 = try Self.forecastTimeRange2(currentTime: current, utcOffset: utcOffset, pastSteps: past_minutely_15, forecastSteps: forecast_minutely_15, pastStepsMax: pastDaysMax * 24 * 4, forecastStepsMax: forecastDaysMax * 24 * 4, forecastStepsDefault: 3 * 24 * 4, initialStep: initial_minutely_15, dtSeconds: 900) ?? Self.forecastTimeRange2(currentTime: current, utcOffset: utcOffset, pastSteps: past_days ?? 0, forecastSteps: forecast_days ?? 3, initialStep: nil, dtSeconds: 86400).with(dtSeconds: 900)
        
        return ForecastApiTimeRange(
            dailyDisplay: daily.add(-1 * actualUtcOffset),
            dailyRead: daily.add(-1 * utcOffset),
            hourlyDisplay: hourly.add(-1 * actualUtcOffset),
            hourlyRead: hourly.add(-1 * utcOffset),
            minutely15: minutely_15.add(-1 * actualUtcOffset)
        )
    }
    
    /// Return an aligned timerange for a local-time 7 day forecast. Timestamps are in UTC time. UTC offset has not been subtracted.
    public static func forecastTimeRange2(currentTime: Timestamp, utcOffset: Int,pastSteps: Int, forecastSteps: Int, initialStep: Int?, dtSeconds: Int) -> TimerangeDt {
        let pastSeconds = pastSteps * dtSeconds
        let start: Int
        if let initialStep {
            // Align start to a specified hour per day
            start = ((currentTime.timeIntervalSince1970 + utcOffset) / 86400) * 86400 + initialStep * dtSeconds
        } else {
            // Align start to current hour or current 15 minutely step (default)
            start = ((currentTime.timeIntervalSince1970 + utcOffset) / dtSeconds) * dtSeconds
        }
        let end = start + forecastSteps * dtSeconds
        
        return TimerangeDt(range: Timestamp(start - pastSeconds) ..< Timestamp(end), dtSeconds: dtSeconds)
    }
    
    /// Return an aligned timerange for a local-time 7 day forecast. Timestamps are in UTC time. UTC offset has not been subtracted.
    public static func forecastTimeRange2(currentTime: Timestamp, utcOffset: Int,pastSteps: Int?, forecastSteps: Int?, pastStepsMax: Int, forecastStepsMax: Int, forecastStepsDefault: Int, initialStep: Int?, dtSeconds: Int) throws -> TimerangeDt? {
        
        if pastSteps == nil && forecastSteps == nil {
            return nil
        }
        let pastSteps = pastSteps ?? 0
        let forecastSteps = forecastSteps ?? forecastStepsDefault
        
        if forecastSteps < 0 || forecastSteps > forecastStepsMax {
            throw ForecastapiError.forecastDaysInvalid(given: forecastStepsMax, allowed: 0...forecastStepsMax)
        }
        if pastSteps < 0 || pastSteps > pastStepsMax {
            throw ForecastapiError.pastDaysInvalid(given: pastSteps, allowed: 0...pastStepsMax)
        }
        return Self.forecastTimeRange2(currentTime: currentTime, utcOffset: utcOffset, pastSteps: pastSteps, forecastSteps: forecastSteps, initialStep: initialStep, dtSeconds: dtSeconds)
    }
}

struct ForecastApiTimeRange {
    /// Time displayed in output. May contains 15 shifts due to 15 minute timezone offsets
    let dailyDisplay: TimerangeDt
    
    /// Time actually read in data
    let dailyRead: TimerangeDt
    
    /// Time displayed in output. May contains 15 shifts due to 15 minute timezone offsets
    let hourlyDisplay: TimerangeDt
    
    /// Time actually read in data
    let hourlyRead: TimerangeDt
    
    let minutely15: TimerangeDt
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
    case pastDaysParameterNotAllowedWithStartEndRange
    case forecastDaysParameterNotAllowedWithStartEndRange
    case latitudeAndLongitudeSameCount
    case latitudeAndLongitudeNotEmpty
    case latitudeAndLongitudeMaximum(max: Int)
    case latitudeAndLongitudeCountMustBeTheSame
    case locationIdCountMustBeTheSame
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
        case .locationIdCountMustBeTheSame:
            return "Parameter 'location_id' and coordinates must have the same number of elements"
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
    let locationId: Int
    
    /// If elevation is `nil` it will resolve it from DEM. If `NaN` it stays `NaN`.
    init(latitude: Float, longitude: Float, locationId: Int, elevation: Float? = .nan) throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = try elevation ?? Dem90.read(lat: latitude, lon: longitude)
        self.locationId = locationId
    }
}

struct CoordinatesAndTimeZonesAndDates {
    let coordinate: CoordinatesAndElevation
    let timezone: TimezoneWithOffset
    let startEndDate: ApiQueryStartEndRanges?
}

enum Timeformat: String, Codable {
    case iso8601
    case unixtime
    
    var unit: SiUnit {
        switch self {
        case .iso8601:
            return .iso8601
        case .unixtime:
            return .unixTime
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
            if identifier == "America/Ciudad_Juarez", let tz = TimeZone(identifier: "America/Mexico_City") {
                return tz
            }
            throw ForecastapiError.invalidTimezone
        }
        return tz
    }
}
