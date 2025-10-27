enum SeasonalVariableMonthly: String, GenericVariableMixable, RawRepresentableString, FlatBuffersVariable {
    case wind_gusts_10m_anomaly
    
    case wind_speed_10m_mean
    case wind_speed_10m_anomaly
    
    case albedo_mean
    case albedo_anomaly
    
    case cloud_cover_low_mean
    case cloud_cover_low_anomaly
    
    case showers_mean
    case showers_anomaly
    
    case runoff_mean
    case runoff_anomaly
    
    case snow_density_mean
    case snow_density_anomaly
    case snow_depth_water_equivalent_mean
    case snow_depth_water_equivalent_anomaly
    
    case total_column_integrated_water_vapour_mean
    case total_column_integrated_water_vapour_anomaly
    
    case temperature_2m_mean
    case temperature_2m_anomaly
    
    case dew_point_2m_mean
    case dew_point_2m_anomaly
    
    case pressure_msl_mean
    case pressure_msl_anomaly
    
    case sea_surface_temperature_mean
    case sea_surface_temperature_anomaly
    
    case wind_u_component_10m_mean
    case wind_u_component_10m_anomaly
    
    case wind_v_component_10m_mean
    case wind_v_component_10m_anomaly
    
    case snowfall_water_equivalent_mean
    case snowfall_water_equivalent_anomaly
    
    case precipitation_mean
    case precipitation_anomaly
    
    case shortwave_radiation_mean
    case shortwave_radiation_anomaly
    
    case longwave_radiation_mean
    case longwave_radiation_anomaly
    
    case cloud_cover_mean
    case cloud_cover_anomaly
    
    case sunshine_duration_mean
    case sunshine_duration_anomaly
    
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_0_to_7cm_anomaly
    case soil_temperature_7_to_28cm_mean
    case soil_temperature_7_to_28cm_anomaly
    case soil_temperature_28_to_100cm_mean
    case soil_temperature_28_to_100cm_anomaly
    case soil_temperature_100_to_255cm_mean
    case soil_temperature_100_to_255cm_anomaly
    
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_0_to_7cm_anomaly
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_7_to_28cm_anomaly
    
    case soil_moisture_28_to_100cm_mean
    case soil_moisture_28_to_100cm_anomaly
    
    case soil_moisture_100_to_255cm_mean
    case soil_moisture_100_to_255cm_anomaly
    
    case temperature_max24h_2m_mean
    case temperature_max24h_2m_anomaly
    case temperature_min24h_2m_mean
    case temperature_min24h_2m_anomaly
    
    case sea_ice_cover_mean
    case sea_ice_cover_anomaly
    
    case latent_heat_flux_mean
    case latent_heat_flux_anomaly
    
    case sensible_heat_flux_mean
    case sensible_heat_flux_anomaly
    
    case evapotranspiration_mean
    case evapotranspiration_anomaly
    
    case snowfall_mean
    case snowfall_anomaly
    case snow_depth_mean
    case snow_depth_anomaly
    
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
        case .wind_gusts_10m_anomaly:
            return .init(variable: .windGusts, aggregation: .anomaly, altitude: 10)
        case .wind_speed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .wind_speed_10m_anomaly:
            return .init(variable: .windSpeed, aggregation: .anomaly, altitude: 10)
        case .albedo_mean:
            return .init(variable: .albedo, aggregation: .mean)
        case .albedo_anomaly:
            return .init(variable: .albedo, aggregation: .anomaly)
        case .cloud_cover_low_mean:
            return .init(variable: .cloudCoverLow, aggregation: .mean)
        case .cloud_cover_low_anomaly:
            return .init(variable: .cloudCoverLow, aggregation: .anomaly)
        case .showers_mean:
            return .init(variable: .showers, aggregation: .mean)
        case .showers_anomaly:
            return .init(variable: .showers, aggregation: .anomaly)
        case .runoff_mean:
            return .init(variable: .runoff, aggregation: .mean)
        case .runoff_anomaly:
            return .init(variable: .runoff, aggregation: .anomaly)
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
        case .snowfall_water_equivalent_mean:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .mean)
        case .snowfall_water_equivalent_anomaly:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .anomaly)
        case .precipitation_mean:
            return .init(variable: .precipitation, aggregation: .mean)
        case .precipitation_anomaly:
            return .init(variable: .precipitation, aggregation: .anomaly)
        case .shortwave_radiation_mean:
            return .init(variable: .shortwaveRadiation, aggregation: .mean)
        case .shortwave_radiation_anomaly:
            return .init(variable: .shortwaveRadiation, aggregation: .anomaly)
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
        case .soil_temperature_7_to_28cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_temperature_7_to_28cm_anomaly:
            return .init(variable: .soilTemperature, aggregation: .anomaly, depth: 7, depthTo: 28)
        case .soil_temperature_28_to_100cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_temperature_28_to_100cm_anomaly:
            return .init(variable: .soilTemperature, aggregation: .anomaly, depth: 28, depthTo: 100)
        case .soil_temperature_100_to_255cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 100, depthTo: 255)
        case .soil_temperature_100_to_255cm_anomaly:
            return .init(variable: .soilTemperature, aggregation: .anomaly, depth: 100, depthTo: 255)
        case .soil_moisture_0_to_7cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_moisture_0_to_7cm_anomaly:
            return .init(variable: .soilMoisture, aggregation: .anomaly, depth: 0, depthTo: 7)
        case .soil_moisture_7_to_28cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_moisture_7_to_28cm_anomaly:
            return .init(variable: .soilMoisture, aggregation: .anomaly, depth: 7, depthTo: 28)
        case .soil_moisture_28_to_100cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_moisture_28_to_100cm_anomaly:
            return .init(variable: .soilMoisture, aggregation: .anomaly, depth: 28, depthTo: 100)
        case .soil_moisture_100_to_255cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 100, depthTo: 255)
        case .soil_moisture_100_to_255cm_anomaly:
            return .init(variable: .soilMoisture, aggregation: .anomaly, depth: 100, depthTo: 255)
        case .temperature_max24h_2m_mean:
            return .init(variable: .temperatureMax24h, aggregation: .mean, altitude: 2)
        case .temperature_max24h_2m_anomaly:
            return .init(variable: .temperatureMax24h, aggregation: .anomaly, altitude: 2)
        case .temperature_min24h_2m_mean:
            return .init(variable: .temperatureMin24h, aggregation: .mean, altitude: 2)
        case .temperature_min24h_2m_anomaly:
            return .init(variable: .temperatureMin24h, aggregation: .anomaly, altitude: 2)
        case .longwave_radiation_mean:
            return .init(variable: .longwaveRadiation, aggregation: .mean)
        case .longwave_radiation_anomaly:
            return .init(variable: .longwaveRadiation, aggregation: .anomaly)
        case .sea_ice_cover_mean:
            return .init(variable: .seaIceCover, aggregation: .mean)
        case .sea_ice_cover_anomaly:
            return .init(variable: .seaIceCover, aggregation: .anomaly)
        case .latent_heat_flux_mean:
            return .init(variable: .latentHeatFlux, aggregation: .mean)
        case .latent_heat_flux_anomaly:
            return .init(variable: .latentHeatFlux, aggregation: .anomaly)
        case .sensible_heat_flux_mean:
            return .init(variable: .sensibleHeatFlux, aggregation: .mean)
        case .sensible_heat_flux_anomaly:
            return .init(variable: .sensibleHeatFlux, aggregation: .anomaly)
        case .evapotranspiration_mean:
            return .init(variable: .evapotranspiration, aggregation: .mean)
        case .evapotranspiration_anomaly:
            return .init(variable: .evapotranspiration, aggregation: .anomaly)
        }
    }
}


struct SeasonalForecastDeriverMonthly<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias VariableOpt = SeasonalVariableMonthly
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: SeasonalVariableMonthly) -> DerivedMapping<Reader.MixingVar>? {
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
        default:
            return nil
        }
    }
}
