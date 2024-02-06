import Foundation
import Vapor


enum IconWaveDomainApi: String, CaseIterable, RawRepresentableString, MultiDomainMixerDomain {
    case best_match
    case ewam
    case gwam
    case era5_ocean
    
    var countEnsembleMember: Int { return 1 }
    
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            guard let reader: any GenericReaderProtocol = try IconWaveMixer(domains: [.gwam, .ewam], lat: lat, lon: lon, elevation: .nan, mode: mode, options: options) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return [reader]
        case .ewam:
            return try IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gwam:
            return try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .era5_ocean:
            return [try Era5Factory.makeReader(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        }
    }
}

struct IconWaveController {
    func query(_ req: Request) async throws -> Response {
        try await req.ensureSubdomain("marine-api")
        let params = req.method == .POST ? try req.content.decode(ApiQueryParameter.self) : try req.query.decode(ApiQueryParameter.self)
        try req.ensureApiKey("marine-api", apikey: params.apikey)
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
            let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600), nTime: 1, dtSeconds: 3600)
            
            let readers: [ForecastapiResult<IconWaveDomainApi>.PerModel] = try domains.compactMap { domain in
                guard let reader = try GenericReaderMulti<IconWaveVariable>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .sea, options: params.readerOptions) else {
                    return nil
                }
                
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsHourly {
                            try reader.prefetchData(variables: paramsHourly, time: time.hourlyRead.toSettings())
                        }
                        if let paramsCurrent {
                            try reader.prefetchData(variables: paramsCurrent, time: currentTimeRange.toSettings())
                        }
                        if let paramsDaily {
                            try reader.prefetchData(variables: paramsDaily, time: time.dailyRead.toSettings())
                        }
                    },
                    current: paramsCurrent.map { variables in
                        return {
                            return .init(name: "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: try variables.compactMap { variable in
                                guard let d = try reader.get(variable: variable, time: currentTimeRange.toSettings())?.convertAndRound(params: params) else {
                                    return nil
                                }
                                return .init(variable: .surface(variable), unit: d.unit, value: d.data.first ?? .nan)
                            })
                        }
                    },
                    hourly: paramsHourly.map { variables in
                        return {
                            return .init(name: "hourly", time: time.hourlyDisplay, columns: try variables.compactMap { variable in
                                guard let d = try reader.get(variable: variable, time: time.hourlyRead.toSettings())?.convertAndRound(params: params) else {
                                    return nil
                                }
                                assert(time.hourlyRead.count == d.data.count)
                                return .init(variable: .surface(variable), unit: d.unit, variables: [.float(d.data)])
                            })
                        }
                    },
                    daily: paramsDaily.map { paramsDaily in
                        return {
                            return ApiSection(name: "daily", time: time.dailyDisplay, columns: try paramsDaily.compactMap { variable in
                                guard let d = try reader.getDaily(variable: variable, params: params, time: time.dailyRead.toSettings()) else {
                                    return nil
                                }
                                assert(time.dailyRead.count == d.data.count)
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
            return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
        }
        let result = ForecastapiResult<IconWaveDomainApi>(timeformat: params.timeformatOrDefault, results: locations)
        await req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return try await result.response(format: params.format ?? .json)
    }
}

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer: GenericReaderMixer {
    let reader: [IconWaveReader]
    
    static func makeReader(domain: IconWaveDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> IconWaveReader? {
        return try IconWaveReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
