import Foundation
import Vapor

enum IconWaveDomainApi: String, CaseIterable, RawRepresentableString, MultiDomainMixerDomain, Sendable {
    var genericDomain: (any GenericDomain)? {
        return nil
    }

    func getReader(gridpoint: Int, options: GenericReaderOptions) throws -> (any GenericReaderProtocol)? {
        return nil
    }

    case best_match
    case ewam
    case gwam
    case era5
    case era5_ocean
    case ecmwf_wam025
    case ecmwf_wam025_ensemble
    case ncep_gfswave025
    case ncep_gfswave016
    case ncep_gefswave025
    case meteofrance_wave
    case meteofrance_currents

    var countEnsembleMember: Int {
        switch self {
        case .ecmwf_wam025_ensemble:
            return EcmwfDomain.wam025_ensemble.ensembleMembers
        case .ncep_gefswave025:
            return GfsDomain.gfswave025_ens.ensembleMembers
        default:
            return 1
        }
    }

    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            // let gwam = try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ewam = try await IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfcurrents = try await GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }
            let mfsst = try await GenericReader<MfWaveDomain, MfSSTVariable>(domain: .mfsst, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfwave = try await GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfWaveReader(reader: reader)
            }
            let waveModel: [(any GenericReaderProtocol)?]
            if let update = try MfWaveDomain.mfwave.getMetaJson()?.lastRunAvailabilityTime, update <= Timestamp.now().subtract(hours: 26) {
                // mf model outdated, use ECMWF
                waveModel = [mfwave, try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
            } else {
                // use mf wave
                waveModel = [mfwave]
            }
            let readers: [(any GenericReaderProtocol)?] = [mfcurrents, mfsst, ewam] + waveModel
            return readers.compactMap({ $0 })
            /*
            let ecmwfWam025 = try GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let readers: [(any GenericReaderProtocol)?] = [ewam, ecmwfWam025, gwam]
            return readers.compactMap({$0})*/
        case .ewam:
            return try await IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gwam:
            return try await IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .era5_ocean:
            return [try await Era5Factory.makeReader(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .ecmwf_wam025:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_wam025_ensemble:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteofrance_wave:
            return try await GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [MfWaveReader(reader: $0)] }) ?? []
        case .meteofrance_currents:
            let mfsst = try await GenericReader<MfWaveDomain, MfSSTVariable>(domain: .mfsst, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfcurrents = try await GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }
            return [mfsst, mfcurrents].compactMap({ $0 })
        case .ncep_gfswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gefswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025_ens, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gfswave016:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave016, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .era5:
            return [try await Era5Factory.makeReader(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        }
    }
}

enum MarineVariable: String, GenericVariableMixable {
    case wave_height
    case wave_period
    case wave_direction
    case wave_peak_period
    case wind_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    case secondary_swell_wave_height
    case secondary_swell_wave_period
    case secondary_swell_wave_direction
    case tertiary_swell_wave_height
    case tertiary_swell_wave_period
    case tertiary_swell_wave_direction
    case ocean_current_velocity
    case ocean_current_direction
    case sea_level_height_msl
    case invert_barometer_height
    case sea_surface_temperature

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct IconWaveController {
    func query(_ req: Request) async throws -> Response {
        try await req.withApiParameter("marine-api") { _, params in
            let currentTime = Timestamp.now()
            let allowedRange = Timestamp(1940, 1, 1) ..< currentTime.add(86400 * 17)
            let logger = req.logger
            let httpClient = req.application.http.client.shared

            let prepared = try await params.prepareCoordinates(allowTimezones: false, logger: logger, httpClient: httpClient)
            guard case .coordinates(let prepared) = prepared else {
                throw ForecastapiError.generic(message: "Bounding box not supported")
            }
            let domains = try IconWaveDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
            let paramsHourly = try MarineVariable.load(commaSeparatedOptional: params.hourly)
            let paramsCurrent = try MarineVariable.load(commaSeparatedOptional: params.current)
            let paramsDaily = try IconWaveVariableDaily.load(commaSeparatedOptional: params.daily)
            let paramsMinutely = try MarineVariable.load(commaSeparatedOptional: params.minutely_15)

            let nParamsMinutely = paramsMinutely?.count ?? 0
            let nVariables = ((paramsHourly?.count ?? 0) + (paramsDaily?.count ?? 0) + nParamsMinutely) * domains.reduce(0, { $0 + $1.countEnsembleMember })
            let options = try params.readerOptions(logger: logger, httpClient: httpClient)
            
            let locations: [ForecastapiResult<IconWaveDomainApi>.PerLocation] = try await prepared.asyncMap { prepared in
                let coordinates = prepared.coordinate
                let timezone = prepared.timezone
                let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 7, forecastDaysMax: 16, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92, forecastDaysMinutely15Default: 7)
                let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600), nTime: 1, dtSeconds: 3600)

                let readers: [ForecastapiResult<IconWaveDomainApi>.PerModel] = try await domains.asyncCompactMap { domain in
                    guard let reader = try await GenericReaderMulti<MarineVariable, IconWaveDomainApi>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .sea, options: options) else {
                        return nil
                    }
                    let hourlyDt = (params.temporal_resolution ?? .hourly).dtSeconds ?? reader.modelDtSeconds
                    let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
                    let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)

                    return .init(
                        model: domain,
                        latitude: reader.modelLat,
                        longitude: reader.modelLon,
                        elevation: reader.targetElevation,
                        prefetch: {
                            if let paramsHourly {
                                for member in 0..<reader.domain.countEnsembleMember {
                                    try await reader.prefetchData(variables: paramsHourly, time: timeHourlyRead.toSettings(ensembleMember: member))
                                }
                            }
                            if let paramsCurrent {
                                try await reader.prefetchData(variables: paramsCurrent, time: currentTimeRange.toSettings())
                            }
                            if let paramsDaily {
                                for member in 0..<reader.domain.countEnsembleMember {
                                    try await reader.prefetchData(variables: paramsDaily, time: time.dailyRead.toSettings(ensembleMember: member))
                                }
                            }
                        },
                        current: paramsCurrent.map { variables in
                            return {
                                return .init(name: "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: try await variables.asyncCompactMap { variable in
                                    guard let d = try await reader.get(variable: variable, time: currentTimeRange.toSettings())?.convertAndRound(params: params) else {
                                        return nil
                                    }
                                    return .init(variable: .surface(variable), unit: d.unit, value: d.data.first ?? .nan)
                                })
                            }
                        },
                        hourly: paramsHourly.map { variables in
                            return {
                                return .init(name: "hourly", time: timeHourlyDisplay, columns: try await variables.asyncMap { variable in
                                    var unit: SiUnit?
                                    let allMembers: [ApiArray] = try await (0..<reader.domain.countEnsembleMember).asyncCompactMap { member in
                                        guard let d = try await reader.get(variable: variable, time: timeHourlyRead.toSettings(ensembleMemberLevel: member))?.convertAndRound(params: params) else {
                                            return nil
                                        }
                                        unit = d.unit
                                        assert(timeHourlyRead.count == d.data.count)
                                        return ApiArray.float(d.data)
                                    }
                                    guard allMembers.count > 0 else {
                                        return ApiColumn(variable: .surface(variable), unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: timeHourlyRead.count)), count: reader.domain.countEnsembleMember))
                                    }
                                    return .init(variable: .surface(variable), unit: unit ?? .undefined, variables: allMembers)
                                })
                            }
                        },
                        daily: paramsDaily.map { paramsDaily in
                            return {
                                return ApiSection(name: "daily", time: time.dailyDisplay, columns: try await paramsDaily.asyncMap { variable -> ApiColumn<IconWaveVariableDaily> in
                                    var unit: SiUnit?
                                    let allMembers: [ApiArray] = try await (0..<reader.domain.countEnsembleMember).asyncCompactMap { member -> ApiArray? in
                                        guard let d = try await reader.getDaily(variable: variable, params: params, time: time.dailyRead.toSettings(ensembleMemberLevel: member))?.convertAndRound(params: params) else {
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
                        minutely15: paramsMinutely.map { variables in
                            return {
                                return .init(name: "minutely_15", time: time.minutely15, columns: try await variables.asyncMap { variable in
                                    var unit: SiUnit?
                                    let allMembers: [ApiArray] = try await (0..<reader.domain.countEnsembleMember).asyncCompactMap { member in
                                        guard let d = try await reader.get(variable: variable, time: time.minutely15.toSettings(ensembleMemberLevel: member))?.convertAndRound(params: params) else {
                                            return nil
                                        }
                                        unit = d.unit
                                        assert(time.minutely15.count == d.data.count)
                                        return ApiArray.float(d.data)
                                    }
                                    guard allMembers.count > 0 else {
                                        return ApiColumn(variable: .surface(variable), unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.minutely15.count)), count: reader.domain.countEnsembleMember))
                                    }
                                    return .init(variable: .surface(variable), unit: unit ?? .undefined, variables: allMembers)
                                })
                            }
                        }
                    )
                }
                guard !readers.isEmpty else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
            }
            return ForecastapiResult<IconWaveDomainApi>(timeformat: params.timeformatOrDefault, results: locations, nVariablesTimesDomains: nVariables)
        }
    }
}

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer: GenericReaderMixer {
    let reader: [IconWaveReader]

    static func makeReader(domain: IconWaveDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> IconWaveReader? {
        return try await IconWaveReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
