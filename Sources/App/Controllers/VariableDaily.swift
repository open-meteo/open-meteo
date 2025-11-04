/// Available daily aggregations
enum ForecastVariableDaily: String, DailyVariableCalculatable, GenericVariableMixable {
    case apparent_temperature_max
    case apparent_temperature_mean
    case apparent_temperature_min
    case cape_max
    case cape_mean
    case cape_min
    case cloudcover_max
    case cloudcover_mean
    case cloudcover_min
    case cloud_cover_max
    case cloud_cover_mean
    case cloud_cover_min
    case dewpoint_2m_max
    case dewpoint_2m_mean
    case dewpoint_2m_min
    case dew_point_2m_max
    case dew_point_2m_mean
    case dew_point_2m_min
    case et0_fao_evapotranspiration
    case et0_fao_evapotranspiration_sum
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability_mean
    case precipitation_hours
    case precipitation_probability_max
    case precipitation_probability_mean
    case precipitation_probability_min
    case precipitation_sum
    case pressure_msl_max
    case pressure_msl_mean
    case pressure_msl_min
    case rain_sum
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case relative_humidity_2m_min
    case shortwave_radiation_sum
    case showers_sum
    case snowfall_sum
    case snowfall_water_equivalent_sum
    case snow_depth_min
    case snow_depth_mean
    case snow_depth_max
    case soil_moisture_0_to_100cm_mean
    case soil_moisture_0_to_10cm_mean
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_28_to_100cm_mean
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_index_0_to_100cm_mean
    case soil_moisture_index_0_to_7cm_mean
    case soil_moisture_index_100_to_255cm_mean
    case soil_moisture_index_28_to_100cm_mean
    case soil_moisture_index_7_to_28cm_mean
    case soil_temperature_0_to_100cm_mean
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_28_to_100cm_mean
    case soil_temperature_7_to_28cm_mean
    case sunrise
    case sunset
    case daylight_duration
    case sunshine_duration
    case surface_pressure_max
    case surface_pressure_mean
    case surface_pressure_min
    case temperature_2m_max
    case temperature_2m_mean
    case temperature_2m_min
    case updraft_max
    case uv_index_clear_sky_max
    case uv_index_max
    case vapor_pressure_deficit_max
    case vapour_pressure_deficit_max
    case visibility_max
    case visibility_mean
    case visibility_min
    case weathercode
    case weather_code
    case winddirection_10m_dominant
    case windgusts_10m_max
    case windgusts_10m_mean
    case windgusts_10m_min
    case windspeed_10m_max
    case windspeed_10m_mean
    case windspeed_10m_min
    case wind_direction_10m_dominant
    case wind_gusts_10m_max
    case wind_gusts_10m_mean
    case wind_gusts_10m_min
    case wind_speed_10m_max
    case wind_speed_10m_mean
    case wind_speed_10m_min
    case wet_bulb_temperature_2m_max
    case wet_bulb_temperature_2m_mean
    case wet_bulb_temperature_2m_min
    
    
    
    case wind_direction_100m_dominant
    case wind_direction_200m_dominant
    case wind_speed_100m_max
    case wind_speed_100m_mean
    case wind_speed_100m_min
    case wind_speed_200m_max
    case wind_speed_200m_mean
    case wind_speed_200m_min
    case sea_surface_temperature_min
    case sea_surface_temperature_max
    case sea_surface_temperature_mean
    case soil_temperature_100_to_255cm_mean
    case soil_moisture_100_to_255cm_mean
    
    case river_discharge
    case river_discharge_mean
    case river_discharge_min
    case river_discharge_max
    case river_discharge_median
    case river_discharge_p25
    case river_discharge_p75
    
    case wave_height_max
    case wind_wave_height_max
    case swell_wave_height_max

    case wave_direction_dominant
    case wind_wave_direction_dominant
    case swell_wave_direction_dominant

    case wave_period_max
    case wind_wave_period_max
    case wind_wave_peak_period_max
    case swell_wave_period_max
    case swell_wave_peak_period_max
    

    var aggregation: DailyAggregation<ForecastVariable> {
        switch self {
        case .temperature_2m_max:
            return .max(.surface(.init(.temperature_2m, 0)))
            // Note: some models like best_match may not provide hourly temperature_2m_max correctly, because some models to not provide it
            //return .maxTwo(intervalMax: .surface(.init(.temperature_2m_max, 0)), hourly: .surface(.init(.temperature_2m, 0)))
        case .temperature_2m_min:
            return .min(.surface(.init(.temperature_2m, 0)))
            //return .minTwo(intervalMin: .surface(.init(.temperature_2m_min, 0)), hourly: .surface(.init(.temperature_2m, 0)))
        case .temperature_2m_mean:
            return .mean(.surface(.init(.temperature_2m, 0)))
        case .apparent_temperature_max:
            return .max(.surface(.init(.apparent_temperature, 0)))
        case .apparent_temperature_mean:
            return .mean(.surface(.init(.apparent_temperature, 0)))
        case .apparent_temperature_min:
            return .min(.surface(.init(.apparent_temperature, 0)))
        case .precipitation_sum:
            return .sum(.surface(.init(.precipitation, 0)))
        case .snowfall_sum:
            return .sum(.surface(.init(.snowfall, 0)))
        case .rain_sum:
            return .sum(.surface(.init(.rain, 0)))
        case .showers_sum:
            return .sum(.surface(.init(.showers, 0)))
        case .weathercode, .weather_code:
            return .max(.surface(.init(.weathercode, 0)))
        case .shortwave_radiation_sum:
            return .radiationSum(.surface(.init(.shortwave_radiation, 0)))
        case .windspeed_10m_max, .wind_speed_10m_max:
            return .max(.surface(.init(.wind_speed_10m, 0)))
        case .windspeed_10m_min, .wind_speed_10m_min:
            return .min(.surface(.init(.wind_speed_10m, 0)))
        case .windspeed_10m_mean, .wind_speed_10m_mean:
            return .mean(.surface(.init(.wind_speed_10m, 0)))
        case .windgusts_10m_max, .wind_gusts_10m_max:
            return .max(.surface(.init(.wind_gusts_10m, 0)))
        case .windgusts_10m_min, .wind_gusts_10m_min:
            return .min(.surface(.init(.wind_gusts_10m, 0)))
        case .windgusts_10m_mean, .wind_gusts_10m_mean:
            return .mean(.surface(.init(.wind_gusts_10m, 0)))
        case .winddirection_10m_dominant, .wind_direction_10m_dominant:
            return .dominantDirection(velocity: .surface(.init(.wind_speed_10m, 0)), direction: .surface(.init(.wind_direction_10m, 0)))
        case .precipitation_hours:
            return .precipitationHours(.surface(.init(.precipitation, 0)))
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .et0_fao_evapotranspiration:
            return .sum(.surface(.init(.et0_fao_evapotranspiration, 0)))
        case .visibility_max:
            return .max(.surface(.init(.visibility, 0)))
        case .visibility_min:
            return .min(.surface(.init(.visibility, 0)))
        case .visibility_mean:
            return .mean(.surface(.init(.visibility, 0)))
        case .pressure_msl_max:
            return .max(.surface(.init(.pressure_msl, 0)))
        case .pressure_msl_min:
            return .min(.surface(.init(.pressure_msl, 0)))
        case .pressure_msl_mean:
            return .mean(.surface(.init(.pressure_msl, 0)))
        case .surface_pressure_max:
            return .max(.surface(.init(.surface_pressure, 0)))
        case .surface_pressure_min:
            return .min(.surface(.init(.surface_pressure, 0)))
        case .surface_pressure_mean:
            return .mean(.surface(.init(.surface_pressure, 0)))
        case .cape_max:
            return .max(.surface(.init(.cape, 0)))
        case .cape_min:
            return .min(.surface(.init(.cape, 0)))
        case .cape_mean:
            return .mean(.surface(.init(.cape, 0)))
        case .cloudcover_max, .cloud_cover_max:
            return .max(.surface(.init(.cloudcover, 0)))
        case .cloudcover_min, .cloud_cover_min:
            return .min(.surface(.init(.cloudcover, 0)))
        case .cloudcover_mean, .cloud_cover_mean:
            return .mean(.surface(.init(.cloudcover, 0)))
        case .uv_index_max:
            return .max(.surface(.init(.uv_index, 0)))
        case .uv_index_clear_sky_max:
            return .max(.surface(.init(.uv_index_clear_sky, 0)))
        case .precipitation_probability_max:
            return .max(.surface(.init(.precipitation_probability, 0)))
        case .precipitation_probability_min:
            return .min(.surface(.init(.precipitation_probability, 0)))
        case .precipitation_probability_mean:
            return .mean(.surface(.init(.precipitation_probability, 0)))
        case .dewpoint_2m_max, .dew_point_2m_max:
            return .max(.surface(.init(.dewpoint_2m, 0)))
        case .dewpoint_2m_mean, .dew_point_2m_mean:
            return .mean(.surface(.init(.dewpoint_2m, 0)))
        case .dewpoint_2m_min, .dew_point_2m_min:
            return .min(.surface(.init(.dewpoint_2m, 0)))
        case .et0_fao_evapotranspiration_sum:
            return .sum(.surface(.init(.et0_fao_evapotranspiration, 0)))
        case .growing_degree_days_base_0_limit_50:
            return .sum(.surface(.init(.growing_degree_days_base_0_limit_50, 0)))
        case .leaf_wetness_probability_mean:
            return .mean(.surface(.init(.leaf_wetness_probability, 0)))
        case .relative_humidity_2m_max:
            return .max(.surface(.init(.relativehumidity_2m, 0)))
        case .relative_humidity_2m_mean:
            return .mean(.surface(.init(.relativehumidity_2m, 0)))
        case .relative_humidity_2m_min:
            return .min(.surface(.init(.relativehumidity_2m, 0)))
        case .snowfall_water_equivalent_sum:
            return .sum(.surface(.init(.snowfall_water_equivalent, 0)))
        case .soil_moisture_0_to_100cm_mean:
            return .mean(.surface(.init(.soil_moisture_0_to_100cm, 0)))
        case .soil_moisture_0_to_10cm_mean:
            return .mean(.surface(.init(.soil_moisture_0_to_10cm, 0)))
        case .soil_moisture_0_to_7cm_mean:
            return .mean(.surface(.init(.soil_moisture_0_to_7cm, 0)))
        case .soil_moisture_28_to_100cm_mean:
            return .mean(.surface(.init(.soil_moisture_28_to_100cm, 0)))
        case .soil_moisture_7_to_28cm_mean:
            return .mean(.surface(.init(.soil_moisture_7_to_28cm, 0)))
        case .soil_moisture_index_0_to_100cm_mean:
            return .mean(.surface(.init(.soil_moisture_index_0_to_100cm, 0)))
        case .soil_moisture_index_0_to_7cm_mean:
            return .mean(.surface(.init(.soil_moisture_index_0_to_7cm, 0)))
        case .soil_moisture_index_100_to_255cm_mean:
            return .mean(.surface(.init(.soil_moisture_index_100_to_255cm, 0)))
        case .soil_moisture_index_28_to_100cm_mean:
            return .mean(.surface(.init(.soil_moisture_index_28_to_100cm, 0)))
        case .soil_moisture_index_7_to_28cm_mean:
            return .mean(.surface(.init(.soil_moisture_index_7_to_28cm, 0)))
        case .soil_temperature_0_to_100cm_mean:
            return .mean(.surface(.init(.soil_temperature_0_to_100cm, 0)))
        case .soil_temperature_0_to_7cm_mean:
            return .mean(.surface(.init(.soil_temperature_0_to_7cm, 0)))
        case .soil_temperature_28_to_100cm_mean:
            return .mean(.surface(.init(.soil_temperature_28_to_100cm, 0)))
        case .soil_temperature_7_to_28cm_mean:
            return .mean(.surface(.init(.soil_temperature_7_to_28cm, 0)))
        case .updraft_max:
            return .max(.surface(.init(.updraft, 0)))
        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
            return .max(.surface(.init(.vapor_pressure_deficit, 0)))
        case .wet_bulb_temperature_2m_max:
            return .max(.surface(.init(.wet_bulb_temperature_2m, 0)))
        case .wet_bulb_temperature_2m_min:
            return .min(.surface(.init(.wet_bulb_temperature_2m, 0)))
        case .wet_bulb_temperature_2m_mean:
            return .mean(.surface(.init(.wet_bulb_temperature_2m, 0)))
        case .daylight_duration:
            return .none
        case .sunshine_duration:
            return .sum(.surface(.init(.sunshine_duration, 0)))
        case .snow_depth_min:
            return .min(.surface(.init(.snow_depth, 0)))
        case .snow_depth_mean:
            return .mean(.surface(.init(.snow_depth, 0)))
        case .snow_depth_max:
            return .max(.surface(.init(.snow_depth, 0)))
        case .wind_direction_100m_dominant:
            return .dominantDirection(velocity: .surface(.init(.wind_speed_100m, 0)), direction: .surface(.init(.wind_direction_100m, 0)))
        case .wind_direction_200m_dominant:
            return .dominantDirection(velocity: .surface(.init(.wind_speed_200m, 0)), direction: .surface(.init(.wind_direction_200m, 0)))
        case .wind_speed_100m_max:
            return .max(.surface(.init(.wind_speed_100m, 0)))
        case .wind_speed_100m_mean:
            return .mean(.surface(.init(.wind_speed_100m, 0)))
        case .wind_speed_100m_min:
            return .min(.surface(.init(.wind_speed_100m, 0)))
        case .wind_speed_200m_max:
            return .max(.surface(.init(.wind_speed_200m, 0)))
        case .wind_speed_200m_mean:
            return .mean(.surface(.init(.wind_speed_200m, 0)))
        case .wind_speed_200m_min:
            return .min(.surface(.init(.wind_speed_200m, 0)))
        case .sea_surface_temperature_min:
            return .min(.surface(.init(.sea_surface_temperature, 0)))
        case .sea_surface_temperature_max:
            return .max(.surface(.init(.sea_surface_temperature, 0)))
        case .sea_surface_temperature_mean:
            return .mean(.surface(.init(.sea_surface_temperature, 0)))
        case .soil_temperature_100_to_255cm_mean:
            return .mean(.surface(.init(.soil_temperature_100_to_255cm, 0)))
        case .soil_moisture_100_to_255cm_mean:
            return .mean(.surface(.init(.soil_moisture_100_to_255cm, 0)))
        case .river_discharge:
            return .none
        case .river_discharge_mean:
            return .none
        case .river_discharge_min:
            return .none
        case .river_discharge_max:
            return .none
        case .river_discharge_median:
            return .none
        case .river_discharge_p25:
            return .none
        case .river_discharge_p75:
            return .none
        case .wave_height_max:
            return .max(.surface(.init(.wave_height, 0)))
        case .wind_wave_height_max:
            return .max(.surface(.init(.wind_wave_height, 0)))
        case .swell_wave_height_max:
            return .max(.surface(.init(.swell_wave_height, 0)))
        case .wave_direction_dominant:
            return .dominantDirection(velocity: .surface(.init(.wave_height, 0)), direction: .surface(.init(.wave_direction, 0)))
        case .wind_wave_direction_dominant:
            return .dominantDirection(velocity: .surface(.init(.wind_wave_height, 0)), direction: .surface(.init(.wind_wave_direction, 0)))
        case .swell_wave_direction_dominant:
            return .dominantDirection(velocity: .surface(.init(.swell_wave_height, 0)), direction: .surface(.init(.swell_wave_direction, 0)))
        case .wave_period_max:
            return .max(.surface(.init(.wave_period, 0)))
        case .wind_wave_period_max:
            return .max(.surface(.init(.wind_wave_period, 0)))
        case .wind_wave_peak_period_max:
            return .max(.surface(.init(.wind_wave_peak_period, 0)))
        case .swell_wave_period_max:
            return .max(.surface(.init(.swell_wave_period, 0)))
        case .swell_wave_peak_period_max:
            return .max(.surface(.init(.swell_wave_peak_period, 0)))
        }
    }
}


struct VariableDailyDeriver<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias VariableOpt = ForecastVariableDaily
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: VariableOpt) -> DerivedMapping<Reader.MixingVar>? {
        if let variable = Reader.variableFromString(variable.rawValue) {
            return .direct(variable)
        }
        switch variable {
        /*case .temperature_2m_max:
            guard let v = Reader.variableFromString("temperature_max24h_2m") else {
                return nil
            }
            return .directShift24Hour(v)
        case .temperature_2m_min:
            guard let v = Reader.variableFromString("temperature_min24h_2m") else {
                return nil
            }
            return .directShift24Hour(v)
        case .temperature_2m_mean:
            guard let v = Reader.variableFromString("temperature_mean24h_2m") else {
                return nil
            }
            return .directShift24Hour(v)*/
        default:
            return nil
        }
    }
}
