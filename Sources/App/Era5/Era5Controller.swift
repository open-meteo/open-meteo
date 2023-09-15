import Foundation
import SwiftPFor2D
import Vapor


/**
 TODO time arrays in large history responses are very inefficient
 */
struct Era5Controller {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("archive-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1940, 1, 1) ..< Timestamp.now()
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try CdsDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
        let paramsHourly = try CdsVariable.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try Era5DailyWeatherVariable.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.count
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let readers = try domains.compactMap {
                try GenericReaderMulti<CdsVariable>(domain: $0, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land)
            }
            
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: readers[0].modelLat,
                longitude: readers[0].modelLon,
                elevation: readers[0].targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        for reader in readers {
                            try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                        }
                    }
                    if let dailyVariables = paramsDaily {
                        for reader in readers {
                            try reader.prefetchData(variables: dailyVariables, time: dailyTime)
                        }
                    }
                },
                current_weather: nil,
                hourly: paramsHourly.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count * readers.count)
                        for reader in readers {
                            for variable in variables {
                                let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                                guard let d = try reader.get(variable: variable, time: hourlyTime)?.convertAndRound(params: params).toApi(name: name) else {
                                    continue
                                }
                                assert(hourlyTime.count == d.data.count)
                                res.append(d)
                            }
                        }
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: paramsDaily.map { dailyVariables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(dailyVariables.count * readers.count)
                        var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                        
                        for reader in readers {
                            for variable in dailyVariables {
                                if variable == .sunrise || variable == .sunset {
                                    // only calculate sunrise/set once
                                    let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.range, lat: coordinates.latitude, lon: coordinates.longitude, utcOffsetSeconds: time.utcOffsetSeconds)
                                    riseSet = times
                                    if variable == .sunset {
                                        res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.set)))
                                    } else {
                                        res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.rise)))
                                    }
                                    continue
                                }
                                let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                                guard let d = try reader.getDaily(variable: variable, params: params, time: dailyTime)?.toApi(name: name) else {
                                    continue
                                }
                                assert(dailyTime.count == d.data.count)
                                res.append(d)
                            }
                        }
                        
                        return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: res)
                    }
                },
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

enum CdsDomainApi: String, RawRepresentableString, CaseIterable, MultiDomainMixerDomain {
    case best_match
    case era5
    case cerra
    case era5_land
    case ecmwf_ifs
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            return [try Era5Factory.makeEra5CombinedLand(lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .era5:
            return [try Era5Factory.makeReader(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .era5_land:
            return [try Era5Factory.makeReader(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .cerra:
            return try CerraReader(domain: .cerra, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs:
            return [try Era5Factory.makeReader(domain: .ecmwf_ifs, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        }
    }
    
    var countEnsembleMember: Int {
        return 1
    }
}

enum CdsVariable: String, GenericVariableMixable {
    case temperature_2m
    case windgusts_10m
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
    case snow_depth
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_temperature_0_to_100cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case soil_moisture_0_to_100cm
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    case weathercode
    case apparent_temperature
    case relativehumidity_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case vapor_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case direct_normal_irradiance
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_7_to_28cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_0_to_100cm
    case is_day
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_7cm:
            fallthrough
        case .soil_moisture_7_to_28cm:
            fallthrough
        case .soil_moisture_28_to_100cm:
            fallthrough
        case .soil_moisture_100_to_255cm:
            return true
        default:
            return false
        }
    }
}

typealias Era5HourlyVariable = VariableOrDerived<Era5Variable, Era5VariableDerived>

enum Era5VariableDerived: String, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case vapor_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case direct_normal_irradiance
    case weathercode
    case soil_moisture_0_to_100cm
    case soil_temperature_0_to_100cm
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_7_to_28cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_0_to_100cm
    case is_day
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

enum Era5DailyWeatherVariable: String, RawRepresentableString, DailyVariableCalculatable {
    case weathercode
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    case dewpoint_2m_max
    case dewpoint_2m_min
    case dewpoint_2m_mean
    case apparent_temperature_max
    case apparent_temperature_min
    case apparent_temperature_mean
    case relative_humidity_2m_min
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case precipitation_sum
    case snowfall_sum
    case snowfall_water_equivalent_sum
    case rain_sum
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
    case et0_fao_evapotranspiration_sum
    case pressure_msl_max
    case pressure_msl_min
    case pressure_msl_mean
    case surface_pressure_max
    case surface_pressure_min
    case surface_pressure_mean
    case cloudcover_max
    case cloudcover_min
    case cloudcover_mean
    /// only for CMIP6 reference
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_28_to_100cm_mean
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_7_to_28cm_mean
    case soil_temperature_28_to_100cm_mean
    case soil_moisture_0_to_10cm_mean
    case soil_moisture_0_to_100cm_mean
    case soil_moisture_index_0_to_7cm_mean
    case soil_moisture_index_7_to_28cm_mean
    case soil_moisture_index_28_to_100cm_mean
    case soil_moisture_index_100_to_255cm_mean
    case soil_moisture_index_0_to_100cm_mean
    case soil_temperature_0_to_100cm_mean
    case vapor_pressure_deficit_max
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability_mean
    
    var aggregation: DailyAggregation<CdsVariable> {
        switch self {
        case .weathercode:
            return .max(.weathercode)
        case .temperature_2m_max:
            return .max(.temperature_2m)
        case .temperature_2m_min:
            return .min(.temperature_2m)
        case .temperature_2m_mean:
            return .mean(.temperature_2m)
        case .dewpoint_2m_max:
            return .max(.dewpoint_2m)
        case .dewpoint_2m_min:
            return .min(.dewpoint_2m)
        case .dewpoint_2m_mean:
            return .mean(.dewpoint_2m)
        case .apparent_temperature_mean:
            return .mean(.apparent_temperature)
        case .apparent_temperature_max:
            return .max(.apparent_temperature)
        case .apparent_temperature_min:
            return .min(.apparent_temperature)
        case .precipitation_sum:
            return .sum(.precipitation)
        case .snowfall_sum:
            return .sum(.snowfall)
        case .rain_sum:
            return .sum(.rain)
        case .shortwave_radiation_sum:
            return .radiationSum(.shortwave_radiation)
        case .windspeed_10m_max:
            return .max(.windspeed_10m)
        case .windspeed_10m_min:
            return .min(.windspeed_10m)
        case .windspeed_10m_mean:
            return .mean(.windspeed_10m)
        case .windgusts_10m_max:
            return .max(.windgusts_10m)
        case .windgusts_10m_min:
            return .min(.windgusts_10m)
        case .windgusts_10m_mean:
            return .mean(.windgusts_10m)
        case .winddirection_10m_dominant:
            return .dominantDirection(velocity: .windspeed_10m, direction: .winddirection_10m)
        case .precipitation_hours:
            return .precipitationHours(.precipitation)
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .et0_fao_evapotranspiration_sum:
            fallthrough
        case .et0_fao_evapotranspiration:
            return .sum(.et0_fao_evapotranspiration)
        case .pressure_msl_max:
            return .max(.pressure_msl)
        case .pressure_msl_min:
            return .min(.pressure_msl)
        case .pressure_msl_mean:
            return .mean(.pressure_msl)
        case .surface_pressure_max:
            return .max(.surface_pressure)
        case .surface_pressure_min:
            return .min(.surface_pressure)
        case .surface_pressure_mean:
            return .mean(.surface_pressure)
        case .cloudcover_max:
            return .max(.cloudcover)
        case .cloudcover_min:
            return .min(.cloudcover)
        case .cloudcover_mean:
            return .mean(.cloudcover)
        case .relative_humidity_2m_min:
            return .min(.relativehumidity_2m)
        case .relative_humidity_2m_max:
            return .max(.relativehumidity_2m)
        case .relative_humidity_2m_mean:
            return .mean(.relativehumidity_2m)
        case .snowfall_water_equivalent_sum:
            return .sum(.snowfall_water_equivalent)
        case .soil_moisture_0_to_10cm_mean:
            return .mean(.soil_moisture_0_to_7cm)
        case .soil_moisture_0_to_100cm_mean:
            return .mean(.soil_moisture_0_to_100cm)
        case .soil_temperature_0_to_100cm_mean:
            return .mean(.soil_temperature_0_to_100cm)
        case .vapor_pressure_deficit_max:
            return .max(.vapor_pressure_deficit)
        case .growing_degree_days_base_0_limit_50:
            return .sum(.growing_degree_days_base_0_limit_50)
        case .leaf_wetness_probability_mean:
            return .mean(.leaf_wetness_probability)
        case .soil_moisture_index_0_to_7cm_mean:
            return .mean(.soil_moisture_index_0_to_7cm)
        case .soil_moisture_index_7_to_28cm_mean:
            return .mean(.soil_moisture_index_7_to_28cm)
        case .soil_moisture_index_28_to_100cm_mean:
            return .mean(.soil_moisture_index_28_to_100cm)
        case .soil_moisture_index_100_to_255cm_mean:
            return .mean(.soil_moisture_index_100_to_255cm)
        case .soil_moisture_index_0_to_100cm_mean:
            return .mean(.soil_moisture_index_0_to_100cm)
        case .soil_moisture_0_to_7cm_mean:
            return .mean(.soil_moisture_0_to_7cm)
        case .soil_moisture_7_to_28cm_mean:
            return .mean(.soil_moisture_7_to_28cm)
        case .soil_moisture_28_to_100cm_mean:
            return .mean(.soil_moisture_28_to_100cm)
        case .soil_temperature_0_to_7cm_mean:
            return .mean(.soil_temperature_0_to_7cm)
        case .soil_temperature_7_to_28cm_mean:
            return .mean(.soil_temperature_7_to_28cm)
        case .soil_temperature_28_to_100cm_mean:
            return .mean(.soil_temperature_28_to_100cm)
        }
    }
}
