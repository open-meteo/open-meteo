import Foundation
import Vapor


struct EcmwfController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let generationTimeStart = Date()
        let params = try req.query.decode(EcmwfQuery.self)
        try params.validate()
        let currentTime = Timestamp.now()
        
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 11)
        let timezone = try params.resolveTimezone()
        let (utcOffsetSecondsActual, time) = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 10, allowedRange: allowedRange)
        /// For fractional timezones, shift data to show only for full timestamps
        let utcOffsetShift = time.utcOffsetSeconds - utcOffsetSecondsActual
        let hourlyTime = time.range.range(dtSeconds: 3600 * 3)
        
        guard let reader = try EcmwfReader(domain: EcmwfDomain.ifs04, lat: params.latitude, lon: params.longitude, elevation: .nan, mode: params.cell_selection ?? .nearest) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        // Start data prefetch to boooooooost API speed :D
        let paramsHourly = try EcmwfHourlyVariable.load(commaSeparatedOptional: params.hourly)
        if let hourlyVariables = paramsHourly {
            try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
        }
        
        let hourly: ApiSection? = try paramsHourly.map { variables in
            var res = [ApiColumn]()
            res.reserveCapacity(variables.count)
            for variable in variables {
                let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name)
                res.append(d)
            }
            return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
        }
        
        let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
        let out = ForecastapiResult(
            latitude: reader.reader.modelLat,
            longitude: reader.reader.modelLon,
            elevation: nil,
            generationtime_ms: generationTimeMs,
            utc_offset_seconds: utcOffsetSecondsActual,
            timezone: timezone,
            current_weather: nil,
            sections: [hourly].compactMap({$0}),
            timeformat: params.timeformatOrDefault
        )
        return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
    }
}

typealias EcmwfHourlyVariable = VariableOrDerived<EcmwfVariable, EcmwfVariableDerived>

struct EcmwfQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let hourly: [String]?
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
    let cell_selection: GridSelectionMode?
    
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
