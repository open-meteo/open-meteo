import Foundation
import Vapor


enum IconWaveDomainApi: String, CaseIterable, RawRepresentableString, MultiDomainMixerDomain {
    case best_match
    case ewam
    case gwam
    case era5_ocean
    
    var countEnsembleMember: Int { return 1 }
    
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            guard let reader: any GenericReaderProtocol = try IconWaveMixer(domains: [.gwam, .ewam], lat: lat, lon: lon, elevation: .nan, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return [reader]
        case .ewam:
            return try IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gwam:
            return try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .era5_ocean:
            return [try Era5Factory.makeReader(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        }
    }
}

struct IconWaveController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("marine-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1940, 1, 1) ..< currentTime.add(86400 * 11)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try IconWaveDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
        let paramsHourly = try IconWaveVariable.load(commaSeparatedOptional: params.hourly)
        let paramsCurrent = try IconWaveVariable.load(commaSeparatedOptional: params.current)
        let paramsDaily = try IconWaveVariableDaily.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.count
        
        let locations: [ForecastapiResult<IconWaveDomainApi>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600), nTime: 1, dtSeconds: 3600)
            
            let readers: [ForecastapiResult<IconWaveDomainApi>.PerModel] = try domains.compactMap { domain in
                guard let reader = try GenericReaderMulti<IconWaveVariable>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .sea) else {
                    return nil
                }
                
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsHourly {
                            try reader.prefetchData(variables: paramsHourly, time: hourlyTime)
                        }
                        if let paramsCurrent {
                            try reader.prefetchData(variables: paramsCurrent, time: currentTimeRange)
                        }
                        if let paramsDaily {
                            try reader.prefetchData(variables: paramsDaily, time: dailyTime)
                        }
                    },
                    current: paramsCurrent.map { variables in
                        return {
                            return .init(name: "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: try variables.compactMap { variable in
                                guard let d = try reader.get(variable: variable, time: currentTimeRange)?.convertAndRound(params: params) else {
                                    return nil
                                }
                                return .init(variable: .surface(variable), unit: d.unit, value: d.data.first ?? .nan)
                            })
                        }
                    },
                    hourly: paramsHourly.map { variables in
                        return {
                            return .init(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: try variables.compactMap { variable in
                                guard let d = try reader.get(variable: variable, time: hourlyTime)?.convertAndRound(params: params) else {
                                    return nil
                                }
                                assert(hourlyTime.count == d.data.count)
                                return .init(variable: .surface(variable), unit: d.unit, variables: [.float(d.data)])
                            })
                        }
                    },
                    daily: paramsDaily.map { paramsDaily in
                        return {
                            return ApiSection(name: "daily", time: dailyTime, columns: try paramsDaily.compactMap { variable in
                                guard let d = try reader.getDaily(variable: variable, params: params, time: dailyTime) else {
                                    return nil
                                }
                                assert(dailyTime.count == d.data.count)
                                return ApiColumn(variable: variable, unit: d.unit, variables: [.float(d.data)])
                            })
                        }
                    },
                    sixHourly: nil,
                    minutely15: nil
                )
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return .init(timezone: timezone, time: time, locationId: coordinates.locationId, results: readers)
        }
        let result = ForecastapiResult<IconWaveDomainApi>(timeformat: params.timeformatOrDefault, results: locations)
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer: GenericReaderMixer {
    let reader: [IconWaveReader]
    
    static func makeReader(domain: IconWaveDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> IconWaveReader? {
        return try IconWaveReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
