import Foundation
import Vapor

typealias SeasonalForecastVariable = VariableOrDerived<CfsVariable, CfsVariableDerived>

typealias SeasonalForecastReader = GenericReader<SeasonalForecastDomain, VariableAndMember<CfsVariable>>

enum SeasonalForecastDomainApi: String, RawRepresentableString, CaseIterable {
    case cfsv2
    
    var forecastDomain: SeasonalForecastDomain {
        switch self {
        case .cfsv2:
            return .ncep
        }
    }
}

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
    
    func getDaily(variable: DailyCfsVariable, member: Int, params: ApiQueryParameter, time timeDaily: TimerangeDt) throws -> DataAndUnit {
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
 - more daily data
 */
struct SeasonalForecastController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("seasonal-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 400)
        
        let prepared = try params.prepareCoordinates(allowTimezones: false)
        /// Will be configurable by API later
        let domains = [SeasonalForecastDomainApi.cfsv2]
        
        let paramsSixHourly = try SeasonalForecastVariable.load(commaSeparatedOptional: params.six_hourly)
        let paramsDaily = try DailyCfsVariable.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsSixHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.reduce(0, {$0 + $1.forecastDomain.nMembers})
        
        let locations: [ForecastapiResult<SeasonalForecastDomainApi>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 92, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            let sixHourlyTime = time.range.range(dtSeconds: 3600*6)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let readers: [ForecastapiResult<SeasonalForecastDomainApi>.PerModel] = try domains.compactMap { domain in
                guard let reader = try SeasonalForecastReader(domain: domain.forecastDomain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                    return nil
                }
                let members = 1..<domain.forecastDomain.nMembers+1
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsSixHourly {
                            for varible in paramsSixHourly {
                                for member in members {
                                    try reader.prefetchData(variable: varible, member: member, time: sixHourlyTime)
                                }
                            }
                        }
                        if let paramsDaily {
                            for varible in paramsDaily {
                                for member in members {
                                    try reader.prefetchData(variable: varible, member: member, time: dailyTime)
                                }
                            }
                        }
                    },
                    current: nil,
                    hourly: nil,
                    daily: paramsDaily.map { variables in
                        return {
                            return ApiSection<DailyCfsVariable>(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try variables.compactMap { variable in
                                var unit: SiUnit? = nil
                                let allMembers: [ApiArray] = try (0..<domain.forecastDomain.nMembers).compactMap { member in
                                    let d = try reader.getDaily(variable: variable, member: member, params: params, time: dailyTime)
                                    unit = d.unit
                                    assert(dailyTime.count == d.data.count)
                                    return ApiArray.float(d.data)
                                }
                                guard allMembers.count > 0 else {
                                    return nil
                                }
                                return ApiColumn<DailyCfsVariable>(variable: variable, unit: unit ?? .undefined, variables: allMembers)
                            })
                        }
                    },
                    sixHourly: paramsSixHourly.map { variables in
                        return {
                            return .init(name: "six_hourly", time: sixHourlyTime.add(utcOffsetShift), columns: try variables.compactMap { variable in
                                var unit: SiUnit? = nil
                                let allMembers: [ApiArray] = try (0..<domain.forecastDomain.nMembers).compactMap { member in
                                    let d = try reader.get(variable: variable, member: member, time: sixHourlyTime).convertAndRound(params: params)
                                    unit = d.unit
                                    assert(sixHourlyTime.count == d.data.count)
                                    return ApiArray.float(d.data)
                                }
                                guard allMembers.count > 0 else {
                                    return nil
                                }
                                return .init(variable: .surface(variable), unit: unit ?? .undefined, variables: allMembers)
                            })
                        }
                    },
                    minutely15: nil
                )
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return .init(timezone: timezone, time: time, results: readers)
        }
        let result = ForecastapiResult<SeasonalForecastDomainApi>(timeformat: params.timeformatOrDefault, results: locations)
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

