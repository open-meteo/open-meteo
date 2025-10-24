enum SeasonalVariableDaily: String, DailyVariableCalculatable, GenericVariableMixable, RawRepresentableString, FlatBuffersVariable {
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    
    case apparent_temperature_max
    case apparent_temperature_mean
    case apparent_temperature_min
    case cloud_cover_max
    case cloud_cover_mean
    case cloud_cover_min
    case dew_point_2m_max
    case dew_point_2m_mean
    case dew_point_2m_min
    case et0_fao_evapotranspiration
    case et0_fao_evapotranspiration_sum
    case pressure_msl_max
    case pressure_msl_mean
    case pressure_msl_min
    case precipitation_sum
    case rain_sum
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case relative_humidity_2m_min
    case shortwave_radiation_sum
    case snowfall_sum
    case snowfall_water_equivalent_sum

    case sunrise
    case sunset
    case daylight_duration

    case surface_pressure_max
    case surface_pressure_mean
    case surface_pressure_min

    case vapor_pressure_deficit_max
    case vapour_pressure_deficit_max

    case weathercode
    case weather_code
    
    case wind_direction_10m_dominant
    case wind_speed_10m_max
    case wind_speed_10m_mean
    case wind_speed_10m_min
    case wet_bulb_temperature_2m_max
    case wet_bulb_temperature_2m_mean
    case wet_bulb_temperature_2m_min
    
    case sea_surface_temperature_min
    case sea_surface_temperature_max
    case sea_surface_temperature_mean
    
    case soil_temperature_0_to_7cm_mean
    
    // TODO rename to mean
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    
    case temperature_max24h_2m
    case temperature_min24h_2m
    case temperature_mean24h_2m
    
    case sunshine_duration
    

    var aggregation: DailyAggregation<SeasonalVariableHourly> {
        switch self {
        case .apparent_temperature_max:
            return .max(.apparent_temperature)
        case .apparent_temperature_mean:
            return .mean(.apparent_temperature)
        case .apparent_temperature_min:
            return .min(.apparent_temperature)
        case .cloud_cover_max:
            return .max(.cloud_cover)
        case .cloud_cover_mean:
            return .mean(.cloud_cover)
        case .cloud_cover_min:
            return .min(.cloud_cover)
        case .dew_point_2m_max:
            return .max(.dew_point_2m)
        case .dew_point_2m_mean:
            return .mean(.dew_point_2m)
        case .dew_point_2m_min:
            return .min(.dew_point_2m)
        case .et0_fao_evapotranspiration, .et0_fao_evapotranspiration_sum:
            return .sum(.et0_fao_evapotranspiration)
        case .pressure_msl_max:
            return .max(.pressure_msl)
        case .pressure_msl_mean:
            return .mean(.pressure_msl)
        case .pressure_msl_min:
            return .min(.pressure_msl)
        case .rain_sum:
            return .sum(.rain)
        case .relative_humidity_2m_max:
            return .max(.relative_humidity_2m)
        case .relative_humidity_2m_mean:
            return .mean(.relative_humidity_2m)
        case .relative_humidity_2m_min:
            return .min(.relative_humidity_2m)
        case .shortwave_radiation_sum:
            return .radiationSum(.shortwave_radiation)
        case .snowfall_sum:
            return .sum(.snowfall)
        case .snowfall_water_equivalent_sum:
            return .sum(.snowfall_water_equivalent)
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .daylight_duration:
            return .none
        case .surface_pressure_max:
            return .max(.surface_pressure)
        case .surface_pressure_mean:
            return .mean(.surface_pressure)
        case .surface_pressure_min:
            return .min(.surface_pressure)
        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
            return .max(.vapor_pressure_deficit)
        case .weathercode, .weather_code:
            return .max(.weathercode)
        case .wind_direction_10m_dominant:
            return .dominantDirectionComponents(u: .wind_u_component_10m, v: .wind_v_component_10m)
        case .wind_speed_10m_max:
            return .max(.wind_speed_10m)
        case .wind_speed_10m_mean:
            return .mean(.wind_speed_10m)
        case .wind_speed_10m_min:
            return .min(.wind_speed_10m)
        case .wet_bulb_temperature_2m_max:
            return .max(.wet_bulb_temperature_2m)
        case .wet_bulb_temperature_2m_mean:
            return .mean(.wet_bulb_temperature_2m)
        case .wet_bulb_temperature_2m_min:
            return .min(.wet_bulb_temperature_2m)
        case .precipitation_sum:
            return .sum(.precipitation)
        case .sea_surface_temperature_min:
            return .min(.sea_surface_temperature)
        case .sea_surface_temperature_max:
            return .max(.sea_surface_temperature)
        case .sea_surface_temperature_mean:
            return .mean(.sea_surface_temperature)
        case .soil_temperature_0_to_7cm_mean:
            return .mean(.soil_temperature_0_to_7cm)
        case .temperature_2m_max:
            // TODO also use temperature_2m_max from hourly
            return .max(.temperature_2m)
        case .temperature_2m_min:
            return .max(.temperature_2m)
        case .temperature_2m_mean:
            return .mean(.temperature_2m)
        default:
            return .none
        }
    }
    
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .temperature_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .apparent_temperature_max:
            return .init(variable: .apparentTemperature, aggregation: .maximum)
        case .apparent_temperature_mean:
            return .init(variable: .apparentTemperature, aggregation: .mean)
        case .apparent_temperature_min:
            return .init(variable: .apparentTemperature, aggregation: .minimum)
        case .cloud_cover_max:
            return .init(variable: .cloudCover, aggregation: .maximum)
        case .cloud_cover_mean:
            return .init(variable: .cloudCover, aggregation: .mean)
        case .cloud_cover_min:
            return .init(variable: .cloudCover, aggregation: .minimum)
        case .dew_point_2m_max:
            return .init(variable: .dewPoint, aggregation: .maximum, altitude: 2)
        case .dew_point_2m_mean:
            return .init(variable: .dewPoint, aggregation: .mean, altitude: 2)
        case .dew_point_2m_min:
            return .init(variable: .dewPoint, aggregation: .minimum, altitude: 2)
        case .et0_fao_evapotranspiration, .et0_fao_evapotranspiration_sum:
            return .init(variable: .et0FaoEvapotranspiration, aggregation: .sum)
        case .pressure_msl_max:
            return .init(variable: .pressureMsl, aggregation: .maximum)
        case .pressure_msl_mean:
            return .init(variable: .pressureMsl, aggregation: .mean)
        case .pressure_msl_min:
            return .init(variable: .pressureMsl, aggregation: .minimum)
        case .precipitation_sum:
            return .init(variable: .precipitation, aggregation: .sum)
        case .rain_sum:
            return .init(variable: .rain, aggregation: .sum)
        case .relative_humidity_2m_max:
            return .init(variable: .relativeHumidity, aggregation: .maximum, altitude: 2)
        case .relative_humidity_2m_mean:
            return .init(variable: .relativeHumidity, aggregation: .mean, altitude: 2)
        case .relative_humidity_2m_min:
            return .init(variable: .relativeHumidity, aggregation: .minimum, altitude: 2)
        case .shortwave_radiation_sum:
            return .init(variable: .shortwaveRadiation, aggregation: .sum)
        case .snowfall_sum:
            return .init(variable: .snowfall, aggregation: .sum)
        case .snowfall_water_equivalent_sum:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .sum)
        case .sunrise:
            return .init(variable: .sunrise)
        case .sunset:
            return .init(variable: .sunset)
        case .daylight_duration:
            return .init(variable: .daylightDuration)
        case .surface_pressure_max:
            return .init(variable: .surfacePressure, aggregation: .maximum)
        case .surface_pressure_mean:
            return .init(variable: .surfacePressure, aggregation: .mean)
        case .surface_pressure_min:
            return .init(variable: .surfacePressure, aggregation: .minimum)
        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
            return .init(variable: .vapourPressureDeficit, aggregation: .maximum)
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode)
        case .wind_direction_10m_dominant:
            return .init(variable: .windDirection, aggregation: .dominant, altitude: 10)
        case .wind_speed_10m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 10)
        case .wind_speed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .wind_speed_10m_min:
            return .init(variable: .windSpeed, aggregation: .minimum, altitude: 10)
        case .wet_bulb_temperature_2m_max:
            return .init(variable: .wetBulbTemperature, aggregation: .maximum, altitude: 2)
        case .wet_bulb_temperature_2m_mean:
            return .init(variable: .wetBulbTemperature, aggregation: .mean, altitude: 2)
        case .wet_bulb_temperature_2m_min:
            return .init(variable: .wetBulbTemperature, aggregation: .minimum, altitude: 2)
        case .sea_surface_temperature_min:
            return .init(variable: .seaSurfaceTemperature, aggregation: .minimum)
        case .sea_surface_temperature_max:
            return .init(variable: .seaSurfaceTemperature, aggregation: .maximum)
        case .sea_surface_temperature_mean:
            return .init(variable: .seaSurfaceTemperature, aggregation: .mean)
        case .soil_temperature_0_to_7cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_temperature_0_to_7cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 7)
        case .soil_temperature_7_to_28cm:
            return .init(variable: .soilTemperature, depth: 7, depthTo: 28)
        case .soil_temperature_28_to_100cm:
            return .init(variable: .soilTemperature, depth: 28, depthTo: 100)
        case .soil_temperature_100_to_255cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 255)
        case .soil_moisture_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7)
        case .soil_moisture_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28)
        case .soil_moisture_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100)
        case .soil_moisture_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255)
        case .temperature_max24h_2m:
            return .init(variable: .temperatureMax24h, altitude: 2)
        case .temperature_min24h_2m:
                return .init(variable: .temperatureMin24h, altitude: 2)
        case .temperature_mean24h_2m:
            return .init(variable: .temperatureMean24h, altitude: 2)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
        }
    }
}

struct SeasonalForecastDeriverDaily<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias VariableOpt = SeasonalVariableDaily
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: VariableOpt) -> DerivedMapping<Reader.MixingVar>? {
        if let variable = Reader.variableFromString(variable.rawValue) {
            return .direct(variable)
        }
        switch variable {
        case .temperature_2m_max:
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
            return .directShift24Hour(v)
        default:
            return nil
        }
    }
}
