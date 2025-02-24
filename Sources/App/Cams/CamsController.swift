import Foundation
import Vapor

extension CamsQuery.Domain: GenericDomainProvider {
    var genericDomain: (any GenericDomain)? {
        switch self {
        case .auto:
            return nil
        case .cams_global:
            return CamsDomain.cams_global
        case .cams_europe:
            return CamsDomain.cams_europe
        }
    }
}

extension CamsMixer: GenericReaderProvider {
    init?(domain: CamsQuery.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try Self.init(domains: domain.camsDomains, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self = reader
    }
    
    init?(domain: CamsQuery.Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        switch domain {
        case .auto:
            return nil
        case .cams_global:
            let reader = try GenericReader<CamsDomain, CamsVariable>(domain: .cams_global, position: gridpoint)
            self.reader = [CamsReader(reader: GenericReaderCached(reader: reader))]
        case .cams_europe:
            let reader = try GenericReader<CamsDomain, CamsVariable>(domain: .cams_europe, position: gridpoint)
            self.reader = [CamsReader(reader: GenericReaderCached(reader: reader))]
        }
    }
}

/**
 API for Air quality data
 */
struct CamsController {
    func query(_ req: Request) async throws -> Response {
        _ = try await req.ensureSubdomain("air-quality-api")
        let params = req.method == .POST ? try req.content.decode(ApiQueryParameter.self) : try req.query.decode(ApiQueryParameter.self)
        let numberOfLocationsMaximum = try await req.ensureApiKey("air-quality-api", apikey: params.apikey)
        
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2013, 1, 1) ..< currentTime.add(86400 * 6)
        
        let paramsHourly = try VariableOrDerived<CamsVariable, CamsVariableDerived>.load(commaSeparatedOptional: params.hourly)
        let paramsCurrent = try VariableOrDerived<CamsVariable, CamsVariableDerived>.load(commaSeparatedOptional: params.current)
        let domains = try (params.domains.map({[$0]}) ?? CamsQuery.Domain.load(commaSeparatedOptional: params.models) ?? [.auto])

        let nVariables = (paramsHourly?.count ?? 0) * domains.count
        
        let prepared = try CamsMixer.prepareReaders(domains: domains, params: params, currentTime: currentTime, forecastDayDefault: 5, forecastDaysMax: 7, pastDaysMax: 92, allowedRange: allowedRange)
        
        let locations: [ForecastapiResult<CamsQuery.Domain>.PerLocation] = try prepared.map { prepared in
            let timezone = prepared.timezone
            let time = prepared.time
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600), nTime: 1, dtSeconds: 3600)
            
            let readers: [ForecastapiResult<CamsQuery.Domain>.PerModel] = try prepared.perModel.compactMap { readerAndDomain in
                guard let reader = try readerAndDomain.reader() else {
                    return nil
                }
                let hourlyDt = (params.temporal_resolution ?? .hourly).dtSeconds ?? reader.modelDtSeconds
                let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
                let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
                let domain = readerAndDomain.domain
                
                let hourlyFn: (() throws -> ApiSection<ForecastapiResult<CamsQuery.Domain>.SurfacePressureAndHeightVariable>)? = paramsHourly.map { variables in
                    return {
                        return .init(name: "hourly", time: timeHourlyDisplay, columns: try variables.map { variable in
                            let d = try reader.get(variable: variable, time: timeHourlyRead.toSettings()).convertAndRound(params: params)
                            assert(timeHourlyRead.count == d.data.count)
                            return .init(variable: .surface(variable), unit: d.unit, variables: [.float(d.data)])
                        })
                    }
                }
                
                let currentFn: (() throws -> ApiSectionSingle<ForecastapiResult<CamsQuery.Domain>.SurfacePressureAndHeightVariable>)? = paramsCurrent.map { variables in
                    return {
                        return .init(name: "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: try variables.map { variable in
                            let d = try reader.get(variable: variable, time: currentTimeRange.toSettings()).convertAndRound(params: params)
                            return .init(variable: .surface(variable), unit: d.unit, value: d.data.first ?? .nan)
                        })
                    }
                }
                
                return ForecastapiResult<CamsQuery.Domain>.PerModel.init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsCurrent {
                            try reader.prefetchData(variables: paramsCurrent, time: currentTimeRange.toSettings())
                        }
                        if let paramsHourly {
                            try reader.prefetchData(variables: paramsHourly, time: timeHourlyRead.toSettings())
                        }
                    },
                    current: currentFn,
                    hourly: hourlyFn,
                    daily: nil,
                    sixHourly: nil,
                    minutely15: nil
                )
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return .init(timezone: timezone, time: timeLocal, locationId: prepared.locationId, results: readers)
        }
        let result = ForecastapiResult<CamsQuery.Domain>(timeformat: params.timeformatOrDefault, results: locations)
        await req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return try await result.response(format: params.format ?? .json, numberOfLocationsMaximum: numberOfLocationsMaximum)
    }
}

enum CamsVariableDerived: String, GenericVariableMixable {
    case european_aqi
    case european_aqi_pm2_5
    case european_aqi_pm10
    case european_aqi_no2
    case european_aqi_o3
    case european_aqi_so2
    case european_aqi_nitrogen_dioxide
    case european_aqi_ozone
    case european_aqi_sulphur_dioxide
    
    case us_aqi
    case us_aqi_pm2_5
    case us_aqi_pm10
    case us_aqi_no2
    case us_aqi_o3
    case us_aqi_so2
    case us_aqi_co
    case us_aqi_nitrogen_dioxide
    case us_aqi_ozone
    case us_aqi_sulphur_dioxide
    case us_aqi_carbon_monoxide
    
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
    
    let reader: GenericReaderCached<CamsDomain, CamsVariable>
    
    func get(derived: CamsVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
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
            return DataAndUnit(max, .europeanAirQualityIndex)
        case .european_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm2_5 = try get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm2_5.map(EuropeanAirQuality.indexPm2_5), .europeanAirQualityIndex)
        case .european_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm10avg = try get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm10avg.map(EuropeanAirQuality.indexPm10), .europeanAirQualityIndex)
        case .european_aqi_nitrogen_dioxide:
            fallthrough
        case .european_aqi_no2:
            let no2 = try get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map(EuropeanAirQuality.indexNo2), .europeanAirQualityIndex)
        case .european_aqi_ozone:
            fallthrough
        case .european_aqi_o3:
            let o3 = try get(raw: .ozone, time: time).data
            return DataAndUnit(o3.map(EuropeanAirQuality.indexO3), .europeanAirQualityIndex)
        case .european_aqi_sulphur_dioxide:
            fallthrough
        case .european_aqi_so2:
            let so2 = try get(raw: .sulphur_dioxide, time: time).data
            return DataAndUnit(so2.map(EuropeanAirQuality.indexSo2), .europeanAirQualityIndex)
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
            return DataAndUnit(max, .usAirQualityIndex)
        case .us_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm2_5 = try get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm2_5.map(UnitedStatesAirQuality.indexPm2_5), .usAirQualityIndex)
        case .us_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let pm10avg = try get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(pm10avg.map(UnitedStatesAirQuality.indexPm10), .usAirQualityIndex)
        case .us_aqi_nitrogen_dioxide:
            fallthrough
        case .us_aqi_no2:
            // need to convert from ugm3 to ppb
            let no2 = try get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map({UnitedStatesAirQuality.indexNo2(no2: $0 / 1.88) }), .usAirQualityIndex)
        case .us_aqi_ozone:
            fallthrough
        case .us_aqi_o3:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let o3 = try get(raw: .ozone, time: timeAhead).data
            let o3avg = o3.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(zip(o3.dropFirst(8), o3avg).map({UnitedStatesAirQuality.indexO3(o3: $0.0 / 1.96, o3_8h_mean: $0.1 / 1.96)}), .usAirQualityIndex)
        case .us_aqi_sulphur_dioxide:
            fallthrough
        case .us_aqi_so2:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-24*3600))
            let so2 = try get(raw: .sulphur_dioxide, time: timeAhead).data
            let so2avg = so2.slidingAverageDroppingFirstDt(dt: 24)
            return DataAndUnit(zip(so2.dropFirst(24), so2avg).map({UnitedStatesAirQuality.indexSo2(so2: $0.0 / 2.62, so2_24h_mean: $0.1 / 2.62)}), .usAirQualityIndex)
        case .us_aqi_carbon_monoxide:
            fallthrough
        case .us_aqi_co:
            // need to convert from ugm3 to ppm
            let timeAhead = time.with(start: time.range.lowerBound.add(-8*3600))
            let co = try get(raw: .carbon_monoxide, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 8)
            return DataAndUnit(co.map({UnitedStatesAirQuality.indexCo(co_8h_mean: $0 / 1.15 / 1000)}), .usAirQualityIndex)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        }
    }
    
    func prefetchData(derived: CamsVariableDerived, time: TimerangeDtAndSettings) throws {
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
        case .european_aqi_nitrogen_dioxide:
            fallthrough
        case .european_aqi_no2:
            try prefetchData(raw: .nitrogen_dioxide, time: time)
        case .european_aqi_ozone:
            fallthrough
        case .european_aqi_o3:
            try prefetchData(raw: .ozone, time: time)
        case .european_aqi_sulphur_dioxide:
            fallthrough
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
        case .us_aqi_nitrogen_dioxide:
            fallthrough
        case .us_aqi_no2:
            try prefetchData(raw: .nitrogen_dioxide, time: time)
        case .us_aqi_ozone:
            fallthrough
        case .us_aqi_o3:
            try prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-8*3600)))
        case .us_aqi_sulphur_dioxide:
            fallthrough
        case .us_aqi_so2:
            try prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-24*3600)))
        case .us_aqi_carbon_monoxide:
            fallthrough
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
        return (0 ..< Swift.max(self.count - dt, 0)).map { i in
            return self[i..<Swift.min(i+dt, self.count)].reduce(0, +) / Float(dt)
        }
    }
}

struct CamsMixer: GenericReaderMixer {
    let reader: [CamsReader]
    
    static func makeReader(domain: CamsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> CamsReader? {
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
                return [.cams_global, .cams_global_greenhouse_gases, .cams_europe, .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated, .cams_europe_reanalysis_validated_pre2020, .cams_europe_reanalysis_validated_pre2018]
            case .cams_global:
                return [.cams_global, .cams_global_greenhouse_gases]
            case .cams_europe:
                return [.cams_europe, .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated, .cams_europe_reanalysis_validated_pre2020, .cams_europe_reanalysis_validated_pre2018]
            }
        }
    }
}
