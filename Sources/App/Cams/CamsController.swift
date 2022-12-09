import Foundation
import Vapor

/**
 API for Air quality data
 */
struct CamsController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "air-quality-api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(CamsQuery.self)
            try params.validate()
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 7, 29) ..< currentTime.add(86400 * 6)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 5, allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: 3600)
            //let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = (params.domains ?? .auto).camsDomains
            
            guard let reader = try CamsMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: .nan, mode: .nearest) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
            /*if let dailyVariables = params.daily {
                try reader.prefetchData(variables: dailyVariables)
            }*/
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count)
                for variable in variables {
                    let d = try reader.get(variable: variable, time: hourlyTime).toApi(name: variable.name)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            
            /*let daily: ApiSection? = try params.daily.map { dailyVariables in
                return ApiSection(name: "daily", time: dailyTime, columns: try dailyVariables.map { variable in
                    let d = try reader.getDaily(variable: variable).toApi(name: variable.rawValue)
                    assert(dailyTime.count == d.data.count)
                    return d
                })
            }*/
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: nil,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly /*, daily*/].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

enum CamsVariableDerived: String, Codable, GenericVariableMixable {
    case european_aqi
    case european_aqi_pm2_5
    case european_aqi_pm10
    case european_aqi_no2
    case european_aqi_o3
    case european_aqi_so2
    
    case us_aqi
    case us_aqi_pm2_5
    case us_aqi_pm10
    case us_aqi_no2
    case us_aqi_o3
    case us_aqi_so2
    case us_aqi_co
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CamsReader: GenericReaderDerivedSimple, GenericReaderMixable {
    typealias MixingVar = VariableOrDerived<CamsVariable, CamsVariableDerived>
    
    typealias Domain = CamsDomain
    
    typealias Variable = CamsVariable
    
    typealias Derived = CamsVariableDerived
    
    var reader: GenericReaderCached<CamsDomain, CamsVariable>
    
    func get(derived: CamsVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .european_aqi:
            let pm2_5 = try get(derived: .european_aqi_pm2_5, time: time).data
            let pm10 = try get(derived: .european_aqi_pm10, time: time).data
            let no2 = try get(derived: .european_aqi_no2, time: time).data
            let o3 = try get(derived: .european_aqi_o3, time: time).data
            let so2 = try get(derived: .european_aqi_so2, time: time).data
            let max = pm2_5.indices.map({ i -> Float in
                return Swift.max(Swift.max(Swift.max(Swift.max(pm2_5[i], pm10[i]), no2[i]), o3[i]), so2[i])
            })
            return DataAndUnit(max, .eaqi)
        case .european_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm2_5 = try get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm2_5.map(EuropeanAirQuality.indexPm2_5), .eaqi)
        case .european_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm10avg = try get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm10avg.map(EuropeanAirQuality.indexPm10), .eaqi)
        case .european_aqi_no2:
            let no2 = try get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map(EuropeanAirQuality.indexNo2), .eaqi)
        case .european_aqi_o3:
            let o3 = try get(raw: .ozone, time: time).data
            return DataAndUnit(o3.map(EuropeanAirQuality.indexO3), .eaqi)
        case .european_aqi_so2:
            let so2 = try get(raw: .sulphur_dioxide, time: time).data
            return DataAndUnit(so2.map(EuropeanAirQuality.indexSo2), .eaqi)
        case .us_aqi:
            let pm2_5 = try get(derived: .us_aqi_pm2_5, time: time).data
            let pm10 = try get(derived: .us_aqi_pm10, time: time).data
            let no2 = try get(derived: .us_aqi_no2, time: time).data
            let o3 = try get(derived: .us_aqi_o3, time: time).data
            let so2 = try get(derived: .us_aqi_so2, time: time).data
            let co = try get(derived: .us_aqi_co, time: time).data
            let max = pm2_5.indices.map({ i -> Float in
                return Swift.max(Swift.max(Swift.max(Swift.max(pm2_5[i], Swift.max(pm10[i], co[i])), no2[i]), o3[i]), so2[i])
            })
            return DataAndUnit(max, .usaqi)
        case .us_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm2_5 = try get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm2_5.map(UnitedStatesAirQuality.indexPm2_5), .usaqi)
        case .us_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm10avg = try get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm10avg.map(UnitedStatesAirQuality.indexPm10), .usaqi)
        case .us_aqi_no2:
            let no2 = try get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map(UnitedStatesAirQuality.indexNo2), .usaqi)
        case .us_aqi_o3:
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let o3 = try get(raw: .ozone, time: timeAhead).data
            let o3avg = o3.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(zip(o3.dropFirst(8), o3avg).map(UnitedStatesAirQuality.indexO3), .usaqi)
        case .us_aqi_so2:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let so2 = try get(raw: .sulphur_dioxide, time: timeAhead).data
            let so2avg = so2.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(zip(so2.dropFirst(24), so2avg).map(UnitedStatesAirQuality.indexSo2), .usaqi)
        case .us_aqi_co:
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let co = try get(raw: .carbon_monoxide, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(co.map(UnitedStatesAirQuality.indexCo), .usaqi)
        }
    }
    
    func prefetchData(derived: CamsVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .european_aqi:
            try prefetchData(derived: .european_aqi_pm2_5, time: time)
            try prefetchData(derived: .european_aqi_pm10, time: time)
            try prefetchData(derived: .european_aqi_no2, time: time)
            try prefetchData(derived: .european_aqi_o3, time: time)
            try prefetchData(derived: .european_aqi_so2, time: time)
        case .european_aqi_pm2_5:
            try prefetchData(raw: .pm2_5, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .european_aqi_pm10:
            try prefetchData(raw: .pm10, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .european_aqi_no2:
            try prefetchData(raw: .nitrogen_dioxide, time: time)
        case .european_aqi_o3:
            try prefetchData(raw: .ozone, time: time)
        case .european_aqi_so2:
            try prefetchData(raw: .sulphur_dioxide, time: time)
        case .us_aqi:
            try prefetchData(derived: .us_aqi_pm2_5, time: time)
            try prefetchData(derived: .us_aqi_pm10, time: time)
            try prefetchData(derived: .us_aqi_no2, time: time)
            try prefetchData(derived: .us_aqi_o3, time: time)
            try prefetchData(derived: .us_aqi_so2, time: time)
            try prefetchData(derived: .us_aqi_co, time: time)
        case .us_aqi_pm2_5:
            try prefetchData(raw: .pm2_5, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .us_aqi_pm10:
            try prefetchData(raw: .pm10, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .us_aqi_no2:
            try prefetchData(raw: .nitrogen_dioxide, time: time)
        case .us_aqi_o3:
            try prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-8*3600)))
        case .us_aqi_so2:
            try prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .us_aqi_co:
            try prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-8*3600)))
        }
    }
}

extension TimerangeDt {
    func with(start: Timestamp) -> TimerangeDt {
        TimerangeDt(start: start, to: range.upperBound, dtSeconds: dtSeconds)
    }
}

extension Array where Element == Float {
    /// Resulting array will be `dt` elements shorter
    func slidingAverageDroppingFirstDt(dt: Int) -> [Float] {
        return (0 ..< self.count - dt).map { i in
            return self[i..<i+dt].reduce(0, +) / 24
        }
    }
}

struct CamsMixer: GenericReaderMixer {
    let reader: [CamsReader]
}

struct CamsQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let hourly: [VariableOrDerived<CamsVariable, CamsVariableDerived>]?
    //let daily: [CamsVariableDaily]?
    //let temperature_unit: TemperatureUnit?
    //let windspeed_unit: WindspeedUnit?
    //let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    let domains: Domain?
    
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
        /*if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }*/
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}

extension CamsQuery {
    enum Domain: String, Codable {
        case auto
        case cams_global
        case cams_europe
        
        var camsDomains: [CamsDomain] {
            switch self {
            case .auto:
                return CamsDomain.allCases
            case .cams_global:
                return [.cams_global]
            case .cams_europe:
                return [.cams_europe]
            }
        }
    }
}
