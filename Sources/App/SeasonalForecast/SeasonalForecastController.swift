import Foundation
import Vapor

typealias SeasonalForecastVariable = VariableOrDerived<CfsVariable, CfsVariableDerived>

typealias SeasonalForecastReader = GenericReader<SeasonalForecastDomain, VariableAndMember<CfsVariable>>


enum CfsVariableDerived: String, RawRepresentableString {
    case windspeed_10m
    case winddirection_10m
}

enum DailyCfsVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case precipitation_sum
    //case rain_sum
    case showers_sum
    case shortwave_radiation_sum
    case windspeed_10m_max
    case winddirection_10m_dominant
    case precipitation_hours
}

extension SeasonalForecastReader {
    func prefetchData(variable: SeasonalForecastVariable, member: Int, time: TimerangeDt) throws {
        switch variable {
        case .raw(let variable):
            try prefetchData(variable: VariableAndMember(variable, member), time: time)
        case .derived(let variable):
            switch variable {
            case .windspeed_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(variable: VariableAndMember(.wind_u_component_10m, member), time: time)
                try prefetchData(variable: VariableAndMember(.wind_v_component_10m, member), time: time)
            }
        }
    }
    
    func get(variable: SeasonalForecastVariable, member: Int, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(variable: VariableAndMember(variable, member), time: time)
        case .derived(let variable):
            switch variable {
            case .windspeed_10m:
                let u = try get(variable: VariableAndMember(.wind_u_component_10m, member), time: time)
                let v = try get(variable: VariableAndMember(.wind_v_component_10m, member), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection_10m:
                let u = try get(variable: VariableAndMember(.wind_u_component_10m, member), time: time)
                let v = try get(variable: VariableAndMember(.wind_v_component_10m, member), time: time)
                let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                return DataAndUnit(direction, .degreeDirection)
            }
        }
    }
    
    func prefetchData(variable: DailyCfsVariable, member: Int, time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        switch variable {
        case .temperature_2m_max:
            try prefetchData(variable: VariableAndMember(.temperature_2m_max, member), time: time)
        case .temperature_2m_min:
            try prefetchData(variable: VariableAndMember(.temperature_2m_min, member), time: time)
        case .precipitation_sum:
            try prefetchData(variable: VariableAndMember(.precipitation, member), time: time)
        case .showers_sum:
            try prefetchData(variable: VariableAndMember(.showers, member), time: time)
        case .shortwave_radiation_sum:
            try prefetchData(variable: VariableAndMember(.shortwave_radiation, member), time: time)
        case .windspeed_10m_max:
            fallthrough
        case .winddirection_10m_dominant:
            try prefetchData(variable: VariableAndMember(.wind_u_component_10m, member), time: time)
            try prefetchData(variable: VariableAndMember(.wind_v_component_10m, member), time: time)
        case .precipitation_hours:
            try prefetchData(variable: VariableAndMember(.precipitation, member), time: time)
        }
    }
    
    func getDaily(variable: DailyCfsVariable, member: Int, params: SeasonalQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        switch variable {
        case .temperature_2m_max:
            let data = try get(variable: VariableAndMember(.temperature_2m_max, member), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 4), data.unit)
        case .temperature_2m_min:
            let data = try get(variable: VariableAndMember(.temperature_2m_min, member), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 4), data.unit)
        case .precipitation_sum:
            let data = try get(variable: VariableAndMember(.precipitation, member), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 4), data.unit)
        case .showers_sum:
            let data = try get(variable: VariableAndMember(.showers, member), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 4), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: VariableAndMember(.shortwave_radiation, member), time: time).convertAndRound(params: params)
            // for 6h data
            return DataAndUnit(data.data.sum(by: 4).map({$0*0.0036 * 6}).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(variable: .derived(.windspeed_10m), member: member, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 4), data.unit)
        case .winddirection_10m_dominant:
            let u = try get(variable: VariableAndMember(.wind_u_component_10m, member), time: time).data.sum(by: 4)
            let v = try get(variable: VariableAndMember(.wind_v_component_10m, member), time: time).data.sum(by: 4)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .precipitation_hours:
            let data = try get(variable: VariableAndMember(.precipitation, member), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 4), .hours)
        }
    }
}


/**
 TODO:
 - integrate more providers
 - daily data
 */
struct SeasonalForecastController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("seasonal-api")
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
        let (utcOffsetSecondsActual, time) = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 92, allowedRange: allowedRange)
        /// For fractional timezones, shift data to show only for full timestamps
        let utcOffsetShift = time.utcOffsetSeconds - utcOffsetSecondsActual
        let hourlyTime = time.range.range(dtSeconds: domain.dtSeconds)
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        
        guard let reader = try SeasonalForecastReader(domain: domain, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        
        let paramsSixHourly = try SeasonalForecastVariable.load(commaSeparatedOptional: params.six_hourly)
        let paramsDaily = try DailyCfsVariable.load(commaSeparatedOptional: params.daily)
        
        // Run query on separat thread pool to not block the main pool
        return ForecastapiController.runLoop.next().submit({
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = paramsSixHourly {
                for varible in hourlyVariables {
                    for member in members {
                        try reader.prefetchData(variable: varible, member: member, time: hourlyTime)
                    }
                }
            }
            
            // Start data prefetch to boooooooost API speed :D
            if let dailyVariables = paramsDaily {
                for varible in dailyVariables {
                    for member in members {
                        try reader.prefetchData(variable: varible, member: member, time: dailyTime)
                    }
                }
            }
            
            let hourly: ApiSection? = try paramsSixHourly.map { variables in
                return ApiSection(name: "six_hourly", time: hourlyTime.add(utcOffsetShift), columns: try variables.flatMap { variable in
                    try members.map { member in
                        let d = try reader.get(variable: variable, member: member, time: hourlyTime).convertAndRound(params: params).toApi(name: "\(variable.name)_member\(member.zeroPadded(len: 2))")
                        assert(hourlyTime.count == d.data.count, "hours \(hourlyTime.count), values \(d.data.count)")
                        return d
                    }
                })
            }
            
            let daily: ApiSection? = try paramsDaily.map { dailyVariables in
                return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try dailyVariables.flatMap { variable in
                    try members.map { member in
                        let d = try reader.getDaily(variable: variable, member: member, params: params, time: dailyTime).convertAndRound(params: params).toApi(name: "\(variable.rawValue)_member\(member.zeroPadded(len: 2))")
                        assert(dailyTime.count == d.data.count, "days \(dailyTime.count), values \(d.data.count)")
                        return d
                    }
                })
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.targetElevation,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: utcOffsetSecondsActual,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly, daily].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return try out.response(format: params.format ?? .json)
        })
    }
}

struct SeasonalQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let six_hourly: [String]?
    let daily: [String]?
    //let current_weather: Bool?
    let elevation: Float?
    //let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let length_unit: LengthUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let forecast_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    var cell_selection: GridSelectionMode?
    
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
        if let forecast_days = forecast_days, forecast_days < 0 || forecast_days >= 367 {
            throw ForecastapiError.forecastDaysInvalid(given: forecast_days, allowed: 0...366)
        }
        /*if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }*/
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}
