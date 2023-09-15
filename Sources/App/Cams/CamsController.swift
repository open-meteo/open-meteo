import Foundation
import Vapor

/**
 API for Air quality data
 */
struct CamsController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("air-quality-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 7, 29) ..< currentTime.add(86400 * 6)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let paramsHourly = try VariableOrDerived<CamsVariable, CamsVariableDerived>.load(commaSeparatedOptional: params.hourly)
        let nVariables = (paramsHourly?.count ?? 0)
        
        let domains = (params.domains ?? .auto).camsDomains
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 5, forecastDaysMax: 7, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            
            guard let reader = try CamsMixer(domains: domains, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .nearest) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                    }
                },
                current_weather: nil,
                hourly: paramsHourly.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count)
                        for variable in variables {
                            let d = try reader.get(variable: variable, time: hourlyTime).toApi(name: variable.name)
                            res.append(d)
                        }
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: nil,
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

enum CamsVariableDerived: String, GenericVariableMixable {
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
    
    case is_day
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CamsReader: GenericReaderDerivedSimple, GenericReaderProtocol {
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
            // need to convert from ugm3 to ppb
            let no2 = try get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map({UnitedStatesAirQuality.indexNo2(no2: $0 / 1.88) }), .usaqi)
        case .us_aqi_o3:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let o3 = try get(raw: .ozone, time: timeAhead).data
            let o3avg = o3.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(zip(o3.dropFirst(8), o3avg).map({UnitedStatesAirQuality.indexO3(o3: $0.0 / 1.96, o3_8h_mean: $0.1 / 1.96)}), .usaqi)
        case .us_aqi_so2:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let so2 = try get(raw: .sulphur_dioxide, time: timeAhead).data
            let so2avg = so2.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(zip(so2.dropFirst(24), so2avg).map({UnitedStatesAirQuality.indexSo2(so2: $0.0 / 2.62, so2_24h_mean: $0.1 / 2.62)}), .usaqi)
        case .us_aqi_co:
            // need to convert from ugm3 to ppm
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let co = try get(raw: .carbon_monoxide, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(co.map({UnitedStatesAirQuality.indexCo(co_8h_mean: $0 / 1.15 / 1000)}), .usaqi)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionless_integer)
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
        case .is_day:
            break
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
    
    static func makeReader(domain: CamsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> CamsReader? {
        guard let reader = try GenericReader<CamsDomain, CamsVariable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        return CamsReader(reader: GenericReaderCached(reader: reader))
    }
}

struct CamsQuery {

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
