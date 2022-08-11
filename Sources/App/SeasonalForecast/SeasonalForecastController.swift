import Foundation
import Vapor

/// Combine weather variable and member to be used in `GenericReader`
struct VariableAndMember<Variable: GenericVariable>: GenericVariable {
    let variable: Variable
    let member: Int
    
    var omFileName: String {
        return "\(variable.omFileName)_\(member)"
    }
    
    var scalefactor: Float {
        variable.scalefactor
    }
    
    var interpolation: ReaderInterpolation {
        variable.interpolation
    }
    
    var unit: SiUnit {
        variable.unit
    }
    
    var isElevationCorrectable: Bool {
        variable.isElevationCorrectable
    }
    
    var name: String {
        return "\(variable.omFileName)_member\(member.zeroPadded(len: 2))"
    }
}

typealias SeasonalForecastReader = GenericReader<SeasonalForecastDomain, VariableAndMember<CfsVariable>>

/**
 TODO:
 - integrate more providers
 - derive weather code
 - daily data
 */
struct SeasonalForecastController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0 == "open-meteo.com"}) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(SeasonalQuery.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            let currentTime = Timestamp.now()
            
            /// Will be configurable by API later
            let domain = SeasonalForecastDomain.ncep
            let members = 1..<domain.nMembers+1
            
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 400)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 45, allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: domain.dtSeconds)
            
            guard let reader = try SeasonalForecastReader(domain: domain, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised, time: hourlyTime) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            /// Combine variables with members
            let hourlyVariables = params.six_hourly.map {
                $0.flatMap { variable in
                    members.map {
                        VariableAndMember(variable: variable, member: $0)
                    }
                }
            }
            
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = hourlyVariables {
                for varible in hourlyVariables {
                    try reader.prefetchData(variable: varible)
                }
            }
            
            let hourly: ApiSection? = try hourlyVariables.map { variables in
                let res = try variables.map { variable in
                    try reader.get(variable: variable).convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit).toApi(name: variable.name)
                }
                return ApiSection(name: "six_hourly", time: hourlyTime, columns: res)
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: elevationOrDem,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

struct SeasonalQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let six_hourly: [CfsVariable]?
    //let current_weather: Bool?
    let elevation: Float?
    //let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    
    /// iso starting date `2022-02-01`
    let start_date: IsoDate?
    /// included end date `2022-06-01`
    let end_date: IsoDate?
    
    
    func validate() throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        if let timezone = timezone, !timezone.isEmpty {
            throw ForecastapiError.timezoneNotSupported
        }
        /*if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }*/
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}
