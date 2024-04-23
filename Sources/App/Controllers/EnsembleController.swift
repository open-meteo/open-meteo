import Foundation
import Vapor

/**
 API controller to return ensemble models data from ICON, GFS, IFS and GEM ensemble models
 
 Endpoint https://ensemble-api.open-meteo.com/v1/ensemble?latitude=52.52&longitude=13.41&models=icon_seamless&hourly=temperature_2m
 */
public struct EnsembleApiController {
    func query(_ req: Request) async throws -> Response {
        let host = try await req.ensureSubdomain("ensemble-api")
        let numberOfLocationsMaximum = host?.starts(with: "customer-") == true ? 10_000 : 1_000
        let params = req.method == .POST ? try req.content.decode(ApiQueryParameter.self) : try req.query.decode(ApiQueryParameter.self)
        try await req.ensureApiKey("ensemble-api", apikey: params.apikey)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2023, 4, 1) ..< currentTime.add(86400 * 35)
        
        let domains = try EnsembleMultiDomains.load(commaSeparatedOptional: params.models) ?? [.gfs_seamless]
        let prepared = try GenericReaderMulti<EnsembleVariable, EnsembleMultiDomains>.prepareReaders(domains: domains, params: params, currentTime: currentTime, forecastDayDefault: 7, forecastDaysMax: 35, pastDaysMax: 92, allowedRange: allowedRange)
        
        let paramsHourly = try EnsembleVariableWithoutMember.load(commaSeparatedOptional: params.hourly)
        let nVariables = (paramsHourly?.count ?? 0) * domains.reduce(0, {$0 + $1.countEnsembleMember})
        
        let locations: [ForecastapiResult<EnsembleMultiDomains>.PerLocation] = try prepared.map { prepared in
            let timezone = prepared.timezone
            let time = prepared.time
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            
            let readers: [ForecastapiResult<EnsembleMultiDomains>.PerModel] = try prepared.perModel.compactMap { readerAndDomain in
                guard let reader = try readerAndDomain.reader() else {
                    return nil
                }
                let domain = readerAndDomain.domain
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let hourlyVariables = paramsHourly {
                            for variable in hourlyVariables {
                                for member in 0..<reader.domain.countEnsembleMember {
                                    try reader.prefetchData(variable: variable, time: time.hourlyRead.toSettings(ensembleMemberLevel: member))
                                }
                            }
                        }
                    },
                    current: nil,
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
                                    return ApiColumn(variable: variable.resultVariable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.hourlyRead.count)), count: reader.domain.countEnsembleMember))
                                }
                                return .init(variable: variable.resultVariable, unit: unit ?? .undefined, variables: allMembers)
                            })
                        }
                    },
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
        let result = ForecastapiResult<EnsembleMultiDomains>(timeformat: params.timeformatOrDefault, results: locations)
        await req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return try await result.response(format: params.format ?? .json, numberOfLocationsMaximum: numberOfLocationsMaximum)
    }
}

extension EnsembleVariableWithoutMember {
    var resultVariable: ForecastapiResult<EnsembleMultiDomains>.SurfaceAndPressureVariable {
        switch self {
        case .pressure(let p):
            return .pressure(.init(p.variable, p.level))
        case .surface(let s):
            return .surface(s)
        }
    }
}



/**
List of ensemble models. "Seamless" models combine global with local models. A best_match model is not possible, as all models are too different to give any advice
 */
enum EnsembleMultiDomains: String, RawRepresentableString, CaseIterable, MultiDomainMixerDomain {
    case icon_seamless
    case icon_global
    case icon_eu
    case icon_d2
    
    case ecmwf_ifs04
    case ecmwf_ifs025
    
    case gem_global
    
    case bom_access_global_ensemble
    
    case gfs_seamless
    case gfs025
    case gfs05
    

    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> [any GenericReaderProtocol] {
        switch self {
        case .icon_seamless:
            return try IconMixer(domains: [.iconEps, .iconEuEps, .iconD2Eps], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .icon_global:
            return try IconReader(domain: .iconEps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .icon_eu:
            return try IconReader(domain: .iconEuEps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .icon_d2:
            return try IconReader(domain: .iconD2Eps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .ecmwf_ifs04:
            return try EcmwfReader(domain: .ifs04_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .ecmwf_ifs025:
            return try EcmwfReader(domain: .ifs025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .gfs025:
            return try GfsReader(domains: [.gfs025_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .gfs05:
            return try GfsReader(domains: [.gfs05_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .gfs_seamless:
            return try GfsReader(domains: [.gfs05_ens, .gfs025_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .gem_global:
            return try GemReader(domain: .gem_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        case .bom_access_global_ensemble:
            return try BomReader(domain: .access_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({[$0]}) ?? []
        }
    }
    
    /// Number of ensenble members including control
    var countEnsembleMember: Int {
        switch self {
        case .icon_seamless:
            return IconDomains.iconEps.ensembleMembers
        case .icon_global:
            return IconDomains.iconEps.ensembleMembers
        case .icon_eu:
            return IconDomains.iconEuEps.ensembleMembers
        case .icon_d2:
            return IconDomains.iconD2Eps.ensembleMembers
        case .ecmwf_ifs04:
            return EcmwfDomain.ifs04_ensemble.ensembleMembers
        case .ecmwf_ifs025:
            return EcmwfDomain.ifs025_ensemble.ensembleMembers
        case .gfs025:
            return GfsDomain.gfs025_ens.ensembleMembers
        case .gfs05:
            return GfsDomain.gfs05_ens.ensembleMembers
        case .gfs_seamless:
            return GfsDomain.gfs05_ens.ensembleMembers
        case .gem_global:
            return GemDomain.gem_global_ensemble.ensembleMembers
        case .bom_access_global_ensemble:
            return BomDomain.access_global_ensemble.ensembleMembers
        }
    }
    
    var genericDomain: (any GenericDomain)? {
        return nil
    }
    
    func getReader(gridpoint: Int, options: GenericReaderOptions) throws -> (any GenericReaderProtocol)? {
        return nil
    }
}


/// Define all available surface weather variables
enum EnsembleSurfaceVariable: String, GenericVariableMixable, Equatable, RawRepresentableString {
    case weathercode
    case weather_code
    case temperature_2m
    case temperature_80m
    case temperature_120m
    case cloudcover
    case cloud_cover
    case pressure_msl
    case relativehumidity_2m
    case relative_humidity_2m
    case precipitation
    //case showers
    case rain
    case windgusts_10m
    case wind_gusts_10m
    case dewpoint_2m
    case dew_point_2m
    case diffuse_radiation
    case direct_radiation
    case apparent_temperature
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_120m
    case wind_direction_120m
    case direct_normal_irradiance
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case shortwave_radiation
    case snowfall
    case snow_depth
    case surface_pressure
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case is_day
    case visibility
    case freezinglevel_height
    case freezing_level_height
    case uv_index
    case uv_index_clear_sky
    case cape
    
    case surface_temperature
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    case sunshine_duration
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm, .soil_moisture_10_to_40cm, .soil_moisture_40_to_100cm, .soil_moisture_100_to_200cm:
            return true
        case .snow_depth:
            return true
        default:
            return false
        }
    }
}

/// Available pressure level variables
enum EnsemblePressureVariableType: String, GenericVariableMixable {
    case temperature
    case geopotential_height
    case relativehumidity
    case relative_humidity
    case windspeed
    case wind_speed
    case winddirection
    case wind_direction
    case dewpoint
    case dew_point
    case cloudcover
    case cloud_cover
    case vertical_velocity
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct EnsemblePressureVariable: PressureVariableRespresentable, GenericVariableMixable {
    let variable: EnsemblePressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias EnsembleVariableWithoutMember = SurfaceAndPressureVariable<EnsembleSurfaceVariable, EnsemblePressureVariable>

typealias EnsembleVariable = EnsembleVariableWithoutMember

/// Available daily aggregations
/*enum EnsembleVariableDaily: String, DailyVariableCalculatable, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    case apparent_temperature_max
    case apparent_temperature_min
    case apparent_temperature_mean
    case precipitation_sum
    /*case precipitation_probability_max
    case precipitation_probability_min
    case precipitation_probability_mean*/
    case snowfall_sum
    case rain_sum
    case showers_sum
    //case weathercode
    case shortwave_radiation_sum
    case windspeed_10m_max
    case windspeed_10m_min
    case windspeed_10m_mean
    case windgusts_10m_max
    case windgusts_10m_min
    case windgusts_10m_mean
    case winddirection_10m_dominant
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
    /*case visibility_max
    case visibility_min
    case visibility_mean*/
    case pressure_msl_max
    case pressure_msl_min
    case pressure_msl_mean
    case surface_pressure_max
    case surface_pressure_min
    case surface_pressure_mean
    case cloudcover_max
    case cloudcover_min
    case cloudcover_mean
    /*case uv_index_max
    case uv_index_clear_sky_max*/
    
    var aggregation: DailyAggregation<EnsembleVariable> {
        switch self {
        case .temperature_2m_max:
            return .max(.surface(.temperature_2m))
        case .temperature_2m_min:
            return .min(.surface(.temperature_2m))
        case .temperature_2m_mean:
            return .mean(.surface(.temperature_2m))
        case .apparent_temperature_max:
            return .max(.surface(.apparent_temperature))
        case .apparent_temperature_mean:
            return .mean(.surface(.apparent_temperature))
        case .apparent_temperature_min:
            return .min(.surface(.apparent_temperature))
        case .precipitation_sum:
            return .sum(.surface(.precipitation))
        case .snowfall_sum:
            return .sum(.surface(.snowfall))
        case .rain_sum:
            return .sum(.surface(.rain))
        case .showers_sum:
            return .sum(.surface(.showers))
        /*case .weathercode:
            return .max(.surface(.weathercode))*/
        case .shortwave_radiation_sum:
            return .radiationSum(.surface(.shortwave_radiation))
        case .windspeed_10m_max:
            return .max(.surface(.windspeed_10m))
        case .windspeed_10m_min:
            return .min(.surface(.windspeed_10m))
        case .windspeed_10m_mean:
            return .mean(.surface(.windspeed_10m))
        case .windgusts_10m_max:
            return .max(.surface(.windgusts_10m))
        case .windgusts_10m_min:
            return .min(.surface(.windgusts_10m))
        case .windgusts_10m_mean:
            return .mean(.surface(.windgusts_10m))
        case .winddirection_10m_dominant:
            return .dominantDirection(velocity: .surface(.windspeed_10m), direction: .surface(.winddirection_10m))
        case .precipitation_hours:
            return .precipitationHours(.surface(.precipitation))
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .et0_fao_evapotranspiration:
            return .sum(.surface(.et0_fao_evapotranspiration))
        /*case .visibility_max:
            return .max(.surface(.visibility))
        case .visibility_min:
            return .min(.surface(.visibility))
        case .visibility_mean:
            return .mean(.surface(.visibility))*/
        case .pressure_msl_max:
            return .max(.surface(.pressure_msl))
        case .pressure_msl_min:
            return .min(.surface(.pressure_msl))
        case .pressure_msl_mean:
            return .mean(.surface(.pressure_msl))
        case .surface_pressure_max:
            return .max(.surface(.surface_pressure))
        case .surface_pressure_min:
            return .min(.surface(.surface_pressure))
        case .surface_pressure_mean:
            return .mean(.surface(.surface_pressure))
        /*case .cape_max:
            return .max(.surface(.cape))
        case .cape_min:
            return .min(.surface(.cape))
        case .cape_mean:
            return .mean(.surface(.cape))*/
        case .cloudcover_max:
            return .max(.surface(.cloudcover))
        case .cloudcover_min:
            return .min(.surface(.cloudcover))
        case .cloudcover_mean:
            return .mean(.surface(.cloudcover))
        /*case .uv_index_max:
            return .max(.surface(.uv_index))
        case .uv_index_clear_sky_max:
            return .max(.surface(.uv_index_clear_sky))
        case .precipitation_probability_max:
            return .max(.surface(.precipitation_probability))
        case .precipitation_probability_min:
            return .max(.surface(.precipitation_probability))
        case .precipitation_probability_mean:
            return .max(.surface(.precipitation_probability))*/
        }
    }
}
*/
