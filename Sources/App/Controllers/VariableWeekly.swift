enum SeasonalVariableWeekly: String, GenericVariableMixable, RawRepresentableString, FlatBuffersVariable {
    case wind_speed_10m_mean
    case wind_speed_10m_anomaly
    case wind_speed_100m_mean
    case wind_speed_100m_anomaly
    case wind_direction_10m_mean
    case wind_direction_10m_anomaly
    case wind_direction_100m_mean
    case wind_direction_100m_anomaly
    case snow_depth_mean
    case snow_depth_anomaly
    case snowfall_mean
    case snowfall_anomaly
    
    case temperature_2m_anomaly_gt1
    case temperature_2m_anomaly_gt2
    case temperature_2m_anomaly_gt0
    case temperature_2m_anomaly_ltm1
    case temperature_2m_anomaly_ltm2
    case pressure_msl_anomaly_gt0
    case surface_temperature_anomaly_gt0
    case precipitation_anomaly_gt0
    case precipitation_anomaly_gt10
    case precipitation_anomaly_gt20
    
    
    case temperature_2m_sot10
    case temperature_2m_sot90
    case temperature_2m_efi
    
    case precipitation_efi
    case precipitation_sot90
    case showers_mean // OK
    //case showers_anomaly // missing
    case snow_density_mean // OK
    case snow_density_anomaly
    case snow_depth_water_equivalent_mean
    case snow_depth_water_equivalent_anomaly
    
    case total_column_integrated_water_vapour_mean // ok
    case total_column_integrated_water_vapour_anomaly
    
    case temperature_2m_mean // OK
    case temperature_2m_anomaly
    
    case dew_point_2m_mean //OK
    case dew_point_2m_anomaly
    
    case pressure_msl_mean // OK
    case pressure_msl_anomaly
    
    case sea_surface_temperature_mean // OK
    case sea_surface_temperature_anomaly
    
    case wind_u_component_10m_mean // OK
    case wind_u_component_10m_anomaly
    case wind_v_component_10m_mean
    case wind_v_component_10m_anomaly
    
    case wind_u_component_100m_mean // OK
    case wind_u_component_100m_anomaly
    case wind_v_component_100m_mean
    case wind_v_component_100m_anomaly
    
    case snowfall_water_equivalent_mean // OK
    case snowfall_water_equivalent_anomaly
    
    case precipitation_mean // OK
    case precipitation_anomaly
    
    case cloud_cover_mean // ok
    case cloud_cover_anomaly
    
    case sunshine_duration_mean // ok
    case sunshine_duration_anomaly
    
    case soil_temperature_0_to_7cm_mean // OK
    case soil_temperature_0_to_7cm_anomaly
    
    // there is a "6h" version and "last post processing" -> both contain exactly the same data
    // a 24h min/max would be way better
    case temperature_max6h_2m_mean
    case temperature_max6h_2m_anomaly
    case temperature_min6h_2m_mean
    case temperature_min6h_2m_anomaly
    
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .snowfall_mean:
            return .init(variable: .snowfall, aggregation: .mean)
        case .snowfall_anomaly:
            return .init(variable: .snowfall, aggregation: .anomaly)
        case .snow_depth_mean:
            return .init(variable: .snowDepth, aggregation: .mean)
        case .snow_depth_anomaly:
            return .init(variable: .snowDepth, aggregation: .anomaly)
        case .wind_speed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .wind_speed_10m_anomaly:
            return .init(variable: .windSpeed, aggregation: .anomaly, altitude: 10)
        case .wind_speed_100m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 100)
        case .wind_speed_100m_anomaly:
            return .init(variable: .windSpeed, aggregation: .anomaly, altitude: 100)
        case .wind_direction_10m_mean:
            return .init(variable: .windDirection, aggregation: .mean, altitude: 10)
        case .wind_direction_10m_anomaly:
            return .init(variable: .windDirection, aggregation: .anomaly, altitude: 10)
        case .wind_direction_100m_mean:
            return .init(variable: .windDirection, aggregation: .mean, altitude: 100)
        case .wind_direction_100m_anomaly:
            return .init(variable: .windDirection, aggregation: .anomaly, altitude: 100)
        case .showers_mean:
            return .init(variable: .showers, aggregation: .mean)
        case .snow_density_mean:
            return .init(variable: .snowDensity, aggregation: .mean)
        case .snow_density_anomaly:
            return .init(variable: .snowDensity, aggregation: .anomaly)
        case .snow_depth_water_equivalent_mean:
            return .init(variable: .snowDepthWaterEquivalent, aggregation: .mean)
        case .snow_depth_water_equivalent_anomaly:
            return .init(variable: .snowDepthWaterEquivalent, aggregation: .anomaly)
        case .total_column_integrated_water_vapour_mean:
            return .init(variable: .totalColumnIntegratedWaterVapour, aggregation: .mean)
        case .total_column_integrated_water_vapour_anomaly:
            return .init(variable: .totalColumnIntegratedWaterVapour, aggregation: .anomaly)
        case .temperature_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .temperature_2m_anomaly:
            return .init(variable: .temperature, aggregation: .anomaly, altitude: 2)
        case .dew_point_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .dew_point_2m_anomaly:
            return .init(variable: .dewPoint, aggregation: .anomaly, altitude: 2)
        case .pressure_msl_mean:
            return .init(variable: .pressureMsl, aggregation: .mean)
        case .pressure_msl_anomaly:
            return .init(variable: .pressureMsl, aggregation: .anomaly)
        case .sea_surface_temperature_mean:
            return .init(variable: .seaSurfaceTemperature, aggregation: .mean)
        case .sea_surface_temperature_anomaly:
            return .init(variable: .seaSurfaceTemperature, aggregation: .anomaly)
        case .wind_u_component_10m_mean:
            return .init(variable: .windUComponent, aggregation: .mean, altitude: 10)
        case .wind_u_component_10m_anomaly:
            return .init(variable: .windUComponent, aggregation: .anomaly, altitude: 10)
        case .wind_v_component_10m_mean:
            return .init(variable: .windVComponent, aggregation: .mean, altitude: 10)
        case .wind_v_component_10m_anomaly:
            return .init(variable: .windVComponent, aggregation: .anomaly, altitude: 10)
        case .wind_u_component_100m_mean:
            return .init(variable: .windUComponent, aggregation: .mean, altitude: 100)
        case .wind_u_component_100m_anomaly:
            return .init(variable: .windUComponent, aggregation: .anomaly, altitude: 100)
        case .wind_v_component_100m_mean:
            return .init(variable: .windVComponent, aggregation: .mean, altitude: 100)
        case .wind_v_component_100m_anomaly:
            return .init(variable: .windVComponent, aggregation: .anomaly, altitude: 100)
        case .snowfall_water_equivalent_mean:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .mean)
        case .snowfall_water_equivalent_anomaly:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .anomaly)
        case .precipitation_mean:
            return .init(variable: .precipitation, aggregation: .mean)
        case .precipitation_anomaly:
            return .init(variable: .precipitation, aggregation: .anomaly)
        case .cloud_cover_mean:
            return .init(variable: .cloudCover, aggregation: .mean)
        case .cloud_cover_anomaly:
            return .init(variable: .cloudCover, aggregation: .anomaly)
        case .sunshine_duration_mean:
            return .init(variable: .sunshineDuration, aggregation: .mean)
        case .sunshine_duration_anomaly:
            return .init(variable: .sunshineDuration, aggregation: .anomaly)
        case .soil_temperature_0_to_7cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_temperature_0_to_7cm_anomaly:
            return .init(variable: .soilTemperature, aggregation: .anomaly, depth: 0, depthTo: 7)
        case .temperature_max6h_2m_mean:
            return .init(variable: .temperatureMax6h, aggregation: .mean, altitude: 2)
        case .temperature_max6h_2m_anomaly:
            return .init(variable: .temperatureMax6h, aggregation: .anomaly, altitude: 2)
        case .temperature_min6h_2m_mean:
            return .init(variable: .temperatureMin6h, aggregation: .mean, altitude: 2)
        case .temperature_min6h_2m_anomaly:
            return .init(variable: .temperatureMin6h, aggregation: .anomaly, altitude: 2)
        case .temperature_2m_anomaly_gt1:
            return .init(variable: .temperature, aggregation: .anomaly, probability: .gt1, altitude: 2)
        case .temperature_2m_anomaly_gt2:
            return .init(variable: .temperature, aggregation: .anomaly, probability: .gt2, altitude: 2)
        case .temperature_2m_anomaly_gt0:
            return .init(variable: .temperature, aggregation: .anomaly, probability: .gt0, altitude: 2)
        case .temperature_2m_anomaly_ltm1:
            return .init(variable: .temperature, aggregation: .anomaly, probability: .ltm1, altitude: 2)
        case .temperature_2m_anomaly_ltm2:
            return .init(variable: .temperature, aggregation: .anomaly, probability: .ltm2, altitude: 2)
        case .pressure_msl_anomaly_gt0:
            return .init(variable: .pressureMsl, aggregation: .anomaly, probability: .gt0)
        case .surface_temperature_anomaly_gt0:
            return .init(variable: .surfacePressure, aggregation: .anomaly, probability: .gt0)
        case .precipitation_anomaly_gt0:
            return .init(variable: .precipitation, aggregation: .anomaly, probability: .gt0)
        case .precipitation_anomaly_gt10:
            return .init(variable: .precipitation, aggregation: .anomaly, probability: .gt10)
        case .precipitation_anomaly_gt20:
            return .init(variable: .precipitation, aggregation: .anomaly, probability: .gt20)
        case .temperature_2m_sot10:
            return .init(variable: .temperature, aggregation: .sot10, altitude: 2)
        case .temperature_2m_sot90:
            return .init(variable: .temperature, aggregation: .sot90, altitude: 2)
        case .temperature_2m_efi:
            return .init(variable: .temperature, aggregation: .efi, altitude: 2)
        case .precipitation_efi:
            return .init(variable: .precipitation, aggregation: .efi)
        case .precipitation_sot90:
            return .init(variable: .precipitation, aggregation: .sot10)
        }
    }
}


struct SeasonalForecastDeriverWeekly<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias VariableOpt = SeasonalVariableWeekly
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: SeasonalVariableWeekly) -> DerivedMapping<Reader.MixingVar>? {
        if let variable = Reader.variableFromString(variable.rawValue) {
            return .direct(variable)
        }
        switch variable {
        case .snowfall_mean:
            guard let v = Reader.variableFromString("snowfall_water_equivalent_mean") else {
                return nil
            }
            return .one(.raw(v)) { snow, time in
                return DataAndUnit(snow.data.map{$0 * 0.7}, .centimetre)
            }
        case .snowfall_anomaly:
            guard let v = Reader.variableFromString("snowfall_water_equivalent_anomaly") else {
                return nil
            }
            return .one(.raw(v)) { snow, time in
                return DataAndUnit(snow.data.map{$0 * 0.7}, .centimetre)
            }
        case .snow_depth_mean:
            // water equivalent in millimetre, density in kg/m3
            guard
                let water = Reader.variableFromString("snow_depth_water_equivalent_mean"),
                let density = Reader.variableFromString("snow_density_mean")
            else {
                return nil
            }
            return .two(.raw(water), .raw(density)) { water, density, time in
                return DataAndUnit(zip(water.data, density.data).map({$0/$1}), .metre)
            }
        case .snow_depth_anomaly:
            guard
                let water = Reader.variableFromString("snow_depth_water_equivalent_anomaly"),
                let density = Reader.variableFromString("snow_density_mean")
            else {
                return nil
            }
            return .two(.raw(water), .raw(density)) { water, density, time in
                return DataAndUnit(zip(water.data, density.data).map({$0/$1}), .metre)
            }
        case .wind_speed_10m_mean:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_10m_mean"), v: Reader.variableFromString("wind_v_component_10m_mean"))
        case .wind_speed_100m_mean:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_100m_mean"), v: Reader.variableFromString("wind_v_component_100m_mean"))
        case .wind_direction_10m_mean:
            return .windDirection(u: Reader.variableFromString("wind_u_component_10m_mean"), v: Reader.variableFromString("wind_v_component_10m_mean"))
        case .wind_direction_100m_mean:
            return .windDirection(u: Reader.variableFromString("wind_u_component_100m_mean"), v: Reader.variableFromString("wind_v_component_100m_mean"))
        case .wind_speed_10m_anomaly:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_10m_anomaly"), v: Reader.variableFromString("wind_v_component_10m_anomaly"))
        case .wind_speed_100m_anomaly:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_100m_anomaly"), v: Reader.variableFromString("wind_v_component_100m_anomaly"))
        case .wind_direction_10m_anomaly:
            return .windDirection(u: Reader.variableFromString("wind_u_component_10m_anomaly"), v: Reader.variableFromString("wind_v_component_10m_anomaly"))
        case .wind_direction_100m_anomaly:
            return .windDirection(u: Reader.variableFromString("wind_u_component_100m_anomaly"), v: Reader.variableFromString("wind_v_component_100m_anomaly"))
        default:
            return nil
        }
    }
}
