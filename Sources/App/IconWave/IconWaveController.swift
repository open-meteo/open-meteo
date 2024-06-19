import Foundation
import Vapor


enum IconWaveDomainApi: String, CaseIterable, RawRepresentableString, MultiDomainMixerDomain {
    var genericDomain: (any GenericDomain)? {
        return nil
    }
    
    func getReader(gridpoint: Int, options: GenericReaderOptions) throws -> (any GenericReaderProtocol)? {
        return nil
    }
    
    case best_match
    case ewam
    case gwam
    case era5_ocean
    case ecmwf_wam025
    case ecmwf_wam025_ensemble
    case meteofrance_wave
    case meteofrance_currents
    
    var countEnsembleMember: Int {
        switch self {
        case .ecmwf_wam025_ensemble:
            return EcmwfDomain.wam025_ensemble.ensembleMembers
        default:
            return 1
        }
    }
    
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            let gwam = try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode)
            let ewam = try IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode)
            let mfcurrents = try GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }
            let mfwave = try GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode).map { reader -> any GenericReaderProtocol in
                MfWaveReader(reader: reader)
            }
            let readers: [(any GenericReaderProtocol)?] = [mfwave, mfcurrents, ewam, gwam]
            return readers.compactMap({$0})
            /*
            let ecmwfWam025 = try GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode)
            let readers: [(any GenericReaderProtocol)?] = [ewam, ecmwfWam025, gwam]
            return readers.compactMap({$0})*/
        case .ewam:
            return try IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gwam:
            return try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .era5_ocean:
            return [try Era5Factory.makeReader(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .ecmwf_wam025:
            return try GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_wam025_ensemble:
            return try GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_wave:
            return try GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[MfWaveReader(reader: $0)]}) ?? []
        case .meteofrance_currents:
            return try GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }.flatMap({[$0]}) ?? []
        }
    }
}

enum MarineVariable: String, GenericVariableMixable {
    case wave_height
    case wave_period
    case wave_direction
    case wind_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    case ocean_current_velocity
    case ocean_current_direction
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct IconWaveController {
    func query(_ req: Request) async throws -> Response {
        let host = try await req.ensureSubdomain("marine-api")
        let numberOfLocationsMaximum = host?.starts(with: "customer-") == true ? 10_000 : 1_000
        let params = req.method == .POST ? try req.content.decode(ApiQueryParameter.self) : try req.query.decode(ApiQueryParameter.self)
        try await req.ensureApiKey("marine-api", apikey: params.apikey)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1940, 1, 1) ..< currentTime.add(86400 * 11)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        guard case .coordinates(let prepared) = prepared else {
            throw ForecastapiError.generic(message: "Bounding box not supported")
        }
        let domains = try IconWaveDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
        let paramsHourly = try MarineVariable.load(commaSeparatedOptional: params.hourly)
        let paramsCurrent = try MarineVariable.load(commaSeparatedOptional: params.current)
        let paramsDaily = try IconWaveVariableDaily.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.reduce(0, {$0 + $1.countEnsembleMember})
        
        let locations: [ForecastapiResult<IconWaveDomainApi>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600), nTime: 1, dtSeconds: 3600)
            
            let readers: [ForecastapiResult<IconWaveDomainApi>.PerModel] = try domains.compactMap { domain in
                guard let reader = try GenericReaderMulti<MarineVariable, IconWaveDomainApi>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .sea, options: params.readerOptions) else {
                    return nil
                }
                
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsHourly {
                            for member in 0..<reader.domain.countEnsembleMember {
                                try reader.prefetchData(variables: paramsHourly, time: time.hourlyRead.toSettings(ensembleMember: member))
                            }
                        }
                        if let paramsCurrent {
                            try reader.prefetchData(variables: paramsCurrent, time: currentTimeRange.toSettings())
                        }
                        if let paramsDaily {
                            for member in 0..<reader.domain.countEnsembleMember {
                                try reader.prefetchData(variables: paramsDaily, time: time.dailyRead.toSettings(ensembleMember: member))
                            }
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
                            return .init(name: "hourly", time: time.hourlyDisplay, columns: try variables.map { variable in
                                var unit: SiUnit? = nil
                                let allMembers: [ApiArray] = try (0..<reader.domain.countEnsembleMember).compactMap { member in
                                    guard let d = try reader.get(variable: variable, time: time.hourlyRead.toSettings(ensembleMemberLevel: member))?.convertAndRound(params: params) else {
                                        return nil
                                    }
                                    unit = d.unit
                                    assert(time.hourlyRead.count == d.data.count)
                                    return ApiArray.float(d.data)
                                }
                                guard allMembers.count > 0 else {
                                    return ApiColumn(variable: .surface(variable), unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.hourlyRead.count)), count: reader.domain.countEnsembleMember))
                                }
                                return .init(variable: .surface(variable), unit: unit ?? .undefined, variables: allMembers)
                            })
                        }
                    },
                    daily: paramsDaily.map { paramsDaily in
                        return {
                            return ApiSection(name: "daily", time: time.dailyDisplay, columns: try paramsDaily.map { variable -> ApiColumn<IconWaveVariableDaily> in
                                var unit: SiUnit? = nil
                                let allMembers: [ApiArray] = try (0..<reader.domain.countEnsembleMember).compactMap { member -> ApiArray? in
                                    guard let d = try reader.getDaily(variable: variable, params: params, time: time.dailyRead.toSettings(ensembleMemberLevel: member))?.convertAndRound(params: params) else {
                                        return nil
                                    }
                                    unit = d.unit
                                    assert(time.dailyRead.count == d.data.count)
                                    return ApiArray.float(d.data)
                                }
                                guard allMembers.count > 0 else {
                                    return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.dailyRead.count)), count: reader.domain.countEnsembleMember))
                                }
                                return ApiColumn<IconWaveVariableDaily>(variable: variable, unit: unit ?? .undefined, variables: allMembers)
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
        return try await result.response(format: params.format ?? .json, numberOfLocationsMaximum: numberOfLocationsMaximum)
    }
}

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer: GenericReaderMixer {
    let reader: [IconWaveReader]
    
    static func makeReader(domain: IconWaveDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> IconWaveReader? {
        return try IconWaveReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
