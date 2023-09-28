import Foundation
import Vapor

/**
 API controller to return ensemble models data from ICON, GFS, IFS and GEM ensemble models
 
 Endpoint https://ensemble-api.open-meteo.com/v1/ensemble?latitude=52.52&longitude=13.41&models=icon_seamless&hourly=temperature_2m
 */
public struct EnsembleApiController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("ensemble-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2023, 4, 1) ..< currentTime.add(86400 * 35)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try EnsembleMultiDomains.load(commaSeparatedOptional: params.models) ?? [.gfs_seamless]
        let paramsHourly = try EnsembleVariableWithoutMember.load(commaSeparatedOptional: params.hourly)
        let nVariables = (paramsHourly?.count ?? 0) * 20
        
        let locations: [ForecastapiResult<EnsembleMultiDomains>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 35, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            
            let readers: [ForecastapiResult<EnsembleMultiDomains>.PerModel] = try domains.compactMap { domain in
                guard let reader = try GenericReaderMulti<EnsembleVariable>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                    return nil
                }
                return .init(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let hourlyVariables = paramsHourly {
                            let variables = hourlyVariables.flatMap { variable in
                                (0..<reader.domain.countEnsembleMember).map {
                                    EnsembleVariable(variable, $0)
                                }
                            }
                            try reader.prefetchData(variables: variables, time: hourlyTime)
                        }
                    },
                    current: nil,
                    hourly: paramsHourly.map { variables in
                        return {
                            return .init(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: try variables.compactMap { variable in
                                var unit: SiUnit? = nil
                                let allMembers: [ApiArray] = try (0..<reader.domain.countEnsembleMember).compactMap { member in
                                    guard let d = try reader.get(variable: .init(variable, member), time: hourlyTime)?.convertAndRound(params: params) else {
                                        return nil
                                    }
                                    unit = d.unit
                                    assert(hourlyTime.count == d.data.count)
                                    return ApiArray.float(d.data)
                                }
                                guard allMembers.count > 0 else {
                                    return nil
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
            return .init(timezone: timezone, time: time, results: readers)
        }
        let result = ForecastapiResult<EnsembleMultiDomains>(timeformat: params.timeformatOrDefault, results: locations)
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
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
    
    case gem_global
    
    case gfs_seamless
    case gfs025
    case gfs05
    

    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderProtocol] {
        switch self {
        case .icon_seamless:
            return try IconMixer(domains: [.iconEps, .iconEuEps, .iconD2Eps], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .icon_global:
            return try IconReader(domain: .iconEps, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_eu:
            return try IconReader(domain: .iconEuEps, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_d2:
            return try IconReader(domain: .iconD2Eps, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs04:
            return try EcmwfReader(domain: .ifs04_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gfs025:
            return try GfsReader(domain: .gfs025_ens, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gfs05:
            return try GfsReader(domain: .gfs05_ens, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gfs_seamless:
            return try GfsMixer(domains: [.gfs05_ens, .gfs025_ens], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gem_global:
            return try GemReader(domain: .gem_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
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
        case .gfs025:
            return GfsDomain.gfs025_ens.ensembleMembers
        case .gfs05:
            return GfsDomain.gfs05_ens.ensembleMembers
        case .gfs_seamless:
            return GfsDomain.gfs05_ens.ensembleMembers
        case .gem_global:
            return GemDomain.gem_global_ensemble.ensembleMembers
        }
    }
}


/// Define all available surface weather variables
enum EnsembleSurfaceVariable: String, GenericVariableMixable, Equatable, RawRepresentableString {
    case weathercode
    case temperature_2m
    case temperature_80m
    case temperature_120m
    case cloudcover
    case pressure_msl
    case relativehumidity_2m
    case precipitation
    //case showers
    case rain
    case windgusts_10m
    case dewpoint_2m
    case diffuse_radiation
    case direct_radiation
    case apparent_temperature
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    case direct_normal_irradiance
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case shortwave_radiation
    case snowfall
    case snow_depth
    case surface_pressure
    //case terrestrial_radiation
    //case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case is_day
    case visibility
    case freezinglevel_height
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
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        default: return false
        }
    }
}

/// Available pressure level variables
enum EnsemblePressureVariableType: String, GenericVariableMixable {
    case temperature
    case geopotential_height
    case relativehumidity
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
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

typealias EnsembleVariable = VariableAndMemberAndControl<EnsembleVariableWithoutMember>

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
