import Foundation
import FlatBuffers
import OpenMeteoSdk

extension VariableAndPreviousDay: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        let previousDay = Int16(previousDay)
        switch variable {
        case .temperature:
            return .init(variable: .temperature, altitude: 2, previousDay: previousDay)
        case .windspeed:
            return .init(variable: .windSpeed, altitude: 10, previousDay: previousDay)
        case .winddirection:
            return .init(variable: .windDirection, altitude: 10, previousDay: previousDay)
        case .wet_bulb_temperature_2m:
            return .init(variable: .wetBulbTemperature, altitude: 2, previousDay: previousDay)
        case .apparent_temperature:
            return .init(variable: .apparentTemperature, altitude: 2, previousDay: previousDay)
        case .cape:
            return .init(variable: .cape, previousDay: previousDay)
        case .cloudcover, .cloud_cover:
            return .init(variable: .cloudCover, previousDay: previousDay)
        case .cloud_cover_2m:
            return .init(variable: .cloudCover, altitude: 2, previousDay: previousDay)
        case .cloudcover_high, .cloud_cover_high:
            return .init(variable: .cloudCoverHigh, previousDay: previousDay)
        case .cloudcover_low, .cloud_cover_low:
            return .init(variable: .cloudCoverLow, previousDay: previousDay)
        case .cloudcover_mid, .cloud_cover_mid:
            return .init(variable: .cloudCoverMid, previousDay: previousDay)
        case .dewpoint_2m, .dew_point_2m:
            return .init(variable: .dewPoint, altitude: 2, previousDay: previousDay)
        case .diffuse_radiation:
            return .init(variable: .diffuseRadiation, previousDay: previousDay)
        case .diffuse_radiation_instant:
            return .init(variable: .diffuseRadiationInstant, previousDay: previousDay)
        case .direct_normal_irradiance:
            return .init(variable: .directNormalIrradiance, previousDay: previousDay)
        case .direct_normal_irradiance_instant:
            return .init(variable: .directNormalIrradianceInstant, previousDay: previousDay)
        case .direct_radiation:
            return .init(variable: .directRadiation, previousDay: previousDay)
        case .direct_radiation_instant:
            return .init(variable: .directRadiationInstant, previousDay: previousDay)
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration, previousDay: previousDay)
        case .evapotranspiration:
            return .init(variable: .evapotranspiration, previousDay: previousDay)
        case .freezinglevel_height, .freezing_level_height:
            return .init(variable: .freezingLevelHeight, previousDay: previousDay)
        case .growing_degree_days_base_0_limit_50:
            return .init(variable: .growingDegreeDays, previousDay: previousDay)
        case .is_day:
            return .init(variable: .isDay, previousDay: previousDay)
        case .latent_heatflux, .latent_heat_flux:
            return .init(variable: .latentHeatFlux, previousDay: previousDay)
        case .lifted_index:
            return .init(variable: .liftedIndex, previousDay: previousDay)
        case .leaf_wetness_probability:
            return .init(variable: .leafWetnessProbability, previousDay: previousDay)
        case .lightning_potential:
            return .init(variable: .lightningPotential, previousDay: previousDay)
        case .precipitation:
            return .init(variable: .precipitation, previousDay: previousDay)
        case .precipitation_probability:
            return .init(variable: .precipitationProbability, previousDay: previousDay)
        case .pressure_msl:
            return .init(variable: .pressureMsl, previousDay: previousDay)
        case .rain:
            return .init(variable: .rain, previousDay: previousDay)
        case .relativehumidity_2m, .relative_humidity_2m:
            return .init(variable: .relativeHumidity, altitude: 2, previousDay: previousDay)
        case .runoff:
            return .init(variable: .runoff, previousDay: previousDay)
        case .sensible_heatflux, .sensible_heat_flux:
            return .init(variable: .sensibleHeatFlux, previousDay: previousDay)
        case .shortwave_radiation:
            return .init(variable: .shortwaveRadiation, previousDay: previousDay)
        case .shortwave_radiation_instant:
            return .init(variable: .shortwaveRadiationInstant, previousDay: previousDay)
        case .showers:
            return .init(variable: .showers, previousDay: previousDay)
        case .skin_temperature:
            return .init(variable: .surfaceTemperature, previousDay: previousDay)
        case .snow_depth:
            return .init(variable: .snowDepth, previousDay: previousDay)
        case .snow_height:
            return .init(variable: .snowHeight, previousDay: previousDay)
        case .snowfall:
            return .init(variable: .snowfall, previousDay: previousDay)
        case .snowfall_water_equivalent:
            return .init(variable: .snowfallWaterEquivalent, previousDay: previousDay)
        case .soil_moisture_0_1cm, .soil_moisture_0_to_1cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 1, previousDay: previousDay)
        case .soil_moisture_0_to_100cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_0_to_10cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 10, previousDay: previousDay)
        case .soil_moisture_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7, previousDay: previousDay)
        case .soil_moisture_100_to_200cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 200, previousDay: previousDay)
        case .soil_moisture_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255, previousDay: previousDay)
        case .soil_moisture_10_to_40cm:
            return .init(variable: .soilMoisture, depth: 10, depthTo: 40, previousDay: previousDay)
        case .soil_moisture_1_3cm, .soil_moisture_1_to_3cm:
            return .init(variable: .soilMoisture, depth: 1, depthTo: 3, previousDay: previousDay)
        case .soil_moisture_27_81cm, .soil_moisture_27_to_81cm:
            return .init(variable: .soilMoisture, depth: 27, depthTo: 81, previousDay: previousDay)
        case .soil_moisture_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_3_9cm, .soil_moisture_3_to_9cm:
            return .init(variable: .soilMoisture, depth: 3, depthTo: 9, previousDay: previousDay)
        case .soil_moisture_40_to_100cm:
            return .init(variable: .soilMoisture, depth: 40, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28, previousDay: previousDay)
        case .soil_moisture_9_27cm:
            return .init(variable: .soilMoisture, depth: 9, depthTo: 27, previousDay: previousDay)
        case .soil_moisture_9_to_27cm:
            return .init(variable: .soilMoisture, depth: 9, depthTo: 27, previousDay: previousDay)
        case .soil_moisture_index_0_to_100cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_index_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7, previousDay: previousDay)
        case .soil_moisture_index_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255, previousDay: previousDay)
        case .soil_moisture_index_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_index_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28, previousDay: previousDay)
        case .soil_temperature_0_to_100cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 100, previousDay: previousDay)
        case .soil_temperature_0_to_10cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 10, previousDay: previousDay)
        case .soil_temperature_0_to_7cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 7, previousDay: previousDay)
        case .soil_temperature_0cm:
            return .init(variable: .soilTemperature, depth: 0, previousDay: previousDay)
        case .soil_temperature_100_to_200cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 200, previousDay: previousDay)
        case .soil_temperature_100_to_255cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 255, previousDay: previousDay)
        case .soil_temperature_10_to_40cm:
            return .init(variable: .soilTemperature, depth: 10, depthTo: 40, previousDay: previousDay)
        case .soil_temperature_18cm:
            return .init(variable: .soilTemperature, depth: 18, previousDay: previousDay)
        case .soil_temperature_28_to_100cm:
            return .init(variable: .soilTemperature, depth: 28, depthTo: 100, previousDay: previousDay)
        case .soil_temperature_40_to_100cm:
            return .init(variable: .soilTemperature, depth: 40, depthTo: 100, previousDay: previousDay)
        case .soil_temperature_54cm:
            return .init(variable: .soilTemperature, depth: 54, previousDay: previousDay)
        case .soil_temperature_6cm:
            return .init(variable: .soilTemperature, depth: 6, previousDay: previousDay)
        case .soil_temperature_7_to_28cm:
            return .init(variable: .soilTemperature, depth: 7, depthTo: 28, previousDay: previousDay)
        case .surface_air_pressure:
            return .init(variable: .surfacePressure, previousDay: previousDay)
        case .snowfall_height:
            return .init(variable: .snowfallHeight, previousDay: previousDay)
        case .surface_pressure:
            return .init(variable: .surfacePressure, previousDay: previousDay)
        case .surface_temperature:
            return .init(variable: .surfaceTemperature, previousDay: previousDay)
        case .temperature_100m:
            return .init(variable: .temperature, altitude: 100, previousDay: previousDay)
        case .temperature_120m:
            return .init(variable: .temperature, altitude: 120, previousDay: previousDay)
        case .temperature_150m:
            return .init(variable: .temperature, altitude: 150, previousDay: previousDay)
        case .temperature_180m:
            return .init(variable: .temperature, altitude: 180, previousDay: previousDay)
        case .temperature_2m:
            return .init(variable: .temperature, altitude: 2, previousDay: previousDay)
        case .temperature_20m:
            return .init(variable: .temperature, altitude: 20, previousDay: previousDay)
        case .temperature_200m:
            return .init(variable: .temperature, altitude: 200, previousDay: previousDay)
        case .temperature_50m:
            return .init(variable: .temperature, altitude: 50, previousDay: previousDay)
        case .temperature_40m:
            return .init(variable: .temperature, altitude: 40, previousDay: previousDay)
        case .temperature_80m:
            return .init(variable: .temperature, altitude: 80, previousDay: previousDay)
        case .terrestrial_radiation:
            return .init(variable: .terrestrialRadiation, previousDay: previousDay)
        case .terrestrial_radiation_instant:
            return .init(variable: .terrestrialRadiationInstant, previousDay: previousDay)
        case .total_column_integrated_water_vapour:
            return .init(variable: .totalColumnIntegratedWaterVapour, previousDay: previousDay)
        case .updraft:
            return .init(variable: .updraft, previousDay: previousDay)
        case .uv_index:
            return .init(variable: .uvIndex, previousDay: previousDay)
        case .uv_index_clear_sky:
            return .init(variable: .uvIndexClearSky, previousDay: previousDay)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            return .init(variable: .vapourPressureDeficit, previousDay: previousDay)
        case .visibility:
            return .init(variable: .visibility, previousDay: previousDay)
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode, previousDay: previousDay)
        case .winddirection_100m, .wind_direction_100m:
            return .init(variable: .windDirection, altitude: 100, previousDay: previousDay)
        case .winddirection_10m, .wind_direction_10m:
            return .init(variable: .windDirection, altitude: 10, previousDay: previousDay)
        case .winddirection_120m, .wind_direction_120m:
            return .init(variable: .windDirection, altitude: 120, previousDay: previousDay)
        case .winddirection_150m, .wind_direction_150m:
            return .init(variable: .windDirection, altitude: 150, previousDay: previousDay)
        case .winddirection_180m, .wind_direction_180m:
            return .init(variable: .windDirection, altitude: 180, previousDay: previousDay)
        case .winddirection_200m, .wind_direction_200m:
            return .init(variable: .windDirection, altitude: 200, previousDay: previousDay)
        case .winddirection_20m, .wind_direction_20m:
            return .init(variable: .windDirection, altitude: 20, previousDay: previousDay)
        case .winddirection_40m, .wind_direction_40m:
            return .init(variable: .windDirection, altitude: 40, previousDay: previousDay)
        case .winddirection_50m, .wind_direction_50m:
            return .init(variable: .windDirection, altitude: 50, previousDay: previousDay)
        case .winddirection_80m, .wind_direction_80m:
            return .init(variable: .windDirection, altitude: 80, previousDay: previousDay)
        case .wind_direction_250m:
            return .init(variable: .windDirection, altitude: 250, previousDay: previousDay)
        case .wind_direction_300m:
            return .init(variable: .windDirection, altitude: 300, previousDay: previousDay)
        case .wind_direction_350m:
            return .init(variable: .windDirection, altitude: 350, previousDay: previousDay)
        case .wind_direction_450m:
            return .init(variable: .windDirection, altitude: 450, previousDay: previousDay)
        case .windgusts_10m, .wind_gusts_10m:
            return .init(variable: .windGusts, altitude: 10, previousDay: previousDay)
        case .windspeed_100m, .wind_speed_100m:
            return .init(variable: .windSpeed, altitude: 100, previousDay: previousDay)
        case .windspeed_10m, .wind_speed_10m:
            return .init(variable: .windSpeed, altitude: 10, previousDay: previousDay)
        case .windspeed_120m, .wind_speed_120m:
            return .init(variable: .windSpeed, altitude: 120, previousDay: previousDay)
        case .windspeed_150m, .wind_speed_150m:
            return .init(variable: .windSpeed, altitude: 150, previousDay: previousDay)
        case .windspeed_180m, .wind_speed_180m:
            return .init(variable: .windSpeed, altitude: 180, previousDay: previousDay)
        case .windspeed_200m, .wind_speed_200m:
            return .init(variable: .windSpeed, altitude: 200, previousDay: previousDay)
        case .windspeed_20m, .wind_speed_20m:
            return .init(variable: .windSpeed, altitude: 20, previousDay: previousDay)
        case .windspeed_40m, .wind_speed_40m:
            return .init(variable: .windSpeed, altitude: 40, previousDay: previousDay)
        case .windspeed_50m, .wind_speed_50m:
            return .init(variable: .windSpeed, altitude: 50, previousDay: previousDay)
        case .windspeed_80m, .wind_speed_80m:
            return .init(variable: .windSpeed, altitude: 80, previousDay: previousDay)
        case .wind_speed_250m:
            return .init(variable: .windSpeed, altitude: 250, previousDay: previousDay)
        case .wind_speed_300m:
            return .init(variable: .windSpeed, altitude: 300, previousDay: previousDay)
        case .wind_speed_350m:
            return .init(variable: .windSpeed, altitude: 350, previousDay: previousDay)
        case .wind_speed_450m:
            return .init(variable: .windSpeed, altitude: 450, previousDay: previousDay)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration, previousDay: previousDay)
        case .convective_inhibition:
            return .init(variable: .convectiveInhibition, previousDay: previousDay)
        case .soil_temperature_10_to_35cm:
            return .init(variable: .soilTemperature, depth: 10, depthTo: 35, previousDay: previousDay)
        case .soil_temperature_35_to_100cm:
            return .init(variable: .soilTemperature, depth: 35, depthTo: 100, previousDay: previousDay)
        case .soil_temperature_100_to_300cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 300, previousDay: previousDay)
        case .soil_moisture_10_to_35cm:
            return .init(variable: .soilMoisture, depth: 10, depthTo: 35, previousDay: previousDay)
        case .soil_moisture_35_to_100cm:
            return .init(variable: .soilMoisture, depth: 35, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_100_to_300cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 300, previousDay: previousDay)
        case .shortwave_radiation_clear_sky:
            return .init(variable: .shortwaveRadiationClearSky, previousDay: previousDay)
        case .wind_direction_140m:
            return .init(variable: .windDirection, altitude: 140, previousDay: previousDay)
        case .wind_direction_160m:
            return .init(variable: .windDirection, altitude: 160, previousDay: previousDay)
        case .wind_direction_30m:
            return .init(variable: .windDirection, altitude: 30, previousDay: previousDay)
        case .wind_direction_70m:
            return .init(variable: .windDirection, altitude: 70, previousDay: previousDay)
        case .wind_speed_140m:
            return .init(variable: .windSpeed, altitude: 140, previousDay: previousDay)
        case .wind_speed_160m:
            return .init(variable: .windSpeed, altitude: 160, previousDay: previousDay)
        case .wind_speed_30m:
            return .init(variable: .windSpeed, altitude: 30, previousDay: previousDay)
        case .wind_speed_70m:
            return .init(variable: .windSpeed, altitude: 70, previousDay: previousDay)
        case .global_tilted_irradiance:
            return .init(variable: .globalTiltedIrradiance, previousDay: previousDay)
        case .global_tilted_irradiance_instant:
            return .init(variable: .globalTiltedIrradianceInstant, previousDay: previousDay)
        case .cloud_base:
            return .init(variable: .cloudBase, previousDay: previousDay)
        case .cloud_top:
            return .init(variable: .cloudTop, previousDay: previousDay)
        case .mass_density_8m:
            return .init(variable: .massDensity, altitude: 8, previousDay: previousDay)
        case .wind_speed_10m_spread:
            return .init(variable: .windSpeed, aggregation: .spread, altitude: 10, previousDay: previousDay)
        case .wind_speed_100m_spread:
            return .init(variable: .windSpeed, aggregation: .spread, altitude: 100, previousDay: previousDay)
        case .wind_direction_10m_spread:
            return .init(variable: .windDirection, aggregation: .spread, altitude: 10, previousDay: previousDay)
        case .wind_direction_100m_spread:
            return .init(variable: .windDirection, aggregation: .spread, altitude: 100, previousDay: previousDay)
        case .snowfall_spread:
            return .init(variable: .snowfall, aggregation: .spread, previousDay: previousDay)
        case .temperature_2m_spread:
            return .init(variable: .temperature, aggregation: .spread, altitude: 2, previousDay: previousDay)
        case .wind_gusts_10m_spread:
            return .init(variable: .windGusts, aggregation: .spread, altitude: 10, previousDay: previousDay)
        case .dew_point_2m_spread:
            return .init(variable: .dewPoint, aggregation: .spread, altitude: 2, previousDay: previousDay)
        case .cloud_cover_low_spread:
            return .init(variable: .cloudCoverLow, aggregation: .spread, previousDay: previousDay)
        case .cloud_cover_mid_spread:
            return .init(variable: .cloudCoverMid, aggregation: .spread, previousDay: previousDay)
        case .cloud_cover_high_spread:
            return .init(variable: .cloudCoverHigh, aggregation: .spread, previousDay: previousDay)
        case .pressure_msl_spread:
            return .init(variable: .pressureMsl, aggregation: .spread, previousDay: previousDay)
        case .snowfall_water_equivalent_spread:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .spread, previousDay: previousDay)
        case .snow_depth_spread:
            return .init(variable: .snowDepth, aggregation: .spread, previousDay: previousDay)
        case .soil_temperature_0_to_7cm_spread:
            return .init(variable: .soilTemperature, aggregation: .spread, depth: 0, depthTo: 7, previousDay: previousDay)
        case .soil_temperature_7_to_28cm_spread:
            return .init(variable: .soilTemperature, aggregation: .spread, depth: 7, depthTo: 28, previousDay: previousDay)
        case .soil_temperature_28_to_100cm_spread:
            return .init(variable: .soilTemperature, aggregation: .spread, depth: 28, depthTo: 100, previousDay: previousDay)
        case .soil_temperature_100_to_255cm_spread:
            return .init(variable: .soilTemperature, aggregation: .spread, depth: 100, depthTo: 255, previousDay: previousDay)
        case .soil_moisture_0_to_7cm_spread:
            return .init(variable: .soilMoisture, aggregation: .spread, depth: 0, depthTo: 7, previousDay: previousDay)
        case .soil_moisture_7_to_28cm_spread:
            return .init(variable: .soilMoisture, aggregation: .spread, depth: 7, depthTo: 28, previousDay: previousDay)
        case .soil_moisture_28_to_100cm_spread:
            return .init(variable: .soilMoisture, aggregation: .spread, depth: 28, depthTo: 100, previousDay: previousDay)
        case .soil_moisture_100_to_255cm_spread:
            return .init(variable: .soilMoisture, aggregation: .spread, depth: 100, depthTo: 255, previousDay: previousDay)
        case .shortwave_radiation_spread:
            return .init(variable: .shortwaveRadiation, aggregation: .spread, previousDay: previousDay)
        case .precipitation_spread:
            return .init(variable: .precipitation, aggregation: .spread, previousDay: previousDay)
        case .direct_radiation_spread:
            return .init(variable: .directRadiation, aggregation: .spread, previousDay: previousDay)
        case .boundary_layer_height:
            return .init(variable: .boundaryLayerHeight, previousDay: previousDay)
        case .boundary_layer_height_spread:
            return .init(variable: .boundaryLayerHeight, aggregation: .spread, previousDay: previousDay)
        case .thunderstorm_probability:
            return .init(variable: .thunderstormProbability, previousDay: previousDay)
        case .rain_probability:
            return .init(variable: .rainProbability, previousDay: previousDay)
        case .freezing_rain_probability:
            return .init(variable: .freezingRainProbability, previousDay: previousDay)
        case .ice_pellets_probability:
            return .init(variable: .icePelletsProbability, previousDay: previousDay)
        case .snowfall_probability:
            return .init(variable: .snowfallProbability, previousDay: previousDay)
        case .hail:
            return .init(variable: .hail, previousDay: previousDay)
        case .albedo:
            return .init(variable: .albedo, previousDay: previousDay)
        case .precipitation_type:
            return .init(variable: .precipitationType, previousDay: previousDay)
        case .convective_cloud_base:
            return .init(variable: .convectiveCloudBase, previousDay: previousDay)
        case .convective_cloud_top:
            return .init(variable: .convectiveCloudTop, previousDay: previousDay)
        case .snow_depth_water_equivalent:
            return .init(variable: .snowDepthWaterEquivalent, previousDay: previousDay)
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .max, altitude: 2, previousDay: previousDay)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .min, altitude: 2, previousDay: previousDay)
        case .soil_moisture_81_to_243cm:
            return .init(variable: .soilMoisture, depth: 81, depthTo: 243, previousDay: previousDay)
        case .soil_moisture_243_to_729cm:
            return .init(variable: .soilMoisture, depth: 243, depthTo: 729, previousDay: previousDay)
        case .soil_moisture_729_to_2187cm:
            return .init(variable: .soilMoisture, depth: 729, depthTo: 2187, previousDay: previousDay)
        case .soil_temperature_162cm:
            return .init(variable: .soilTemperature, depth: 162, previousDay: previousDay)
        case .soil_temperature_486cm:
            return .init(variable: .soilTemperature, depth: 486, previousDay: previousDay)
        case .soil_temperature_1458cm:
            return .init(variable: .soilTemperature, depth: 1458, previousDay: previousDay)
        case .sea_surface_temperature:
            return .init(variable: .seaSurfaceTemperature, previousDay: previousDay)
        }
    }
}

extension ForecastPressureVariableType: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature:
            return .init(variable: .temperature)
        case .geopotential_height:
            return .init(variable: .geopotentialHeight)
        case .relativehumidity, .relative_humidity:
            return .init(variable: .relativeHumidity)
        case .windspeed, .wind_speed:
            return .init(variable: .windSpeed)
        case .winddirection, .wind_direction:
            return .init(variable: .windDirection)
        case .dewpoint, .dew_point:
            return .init(variable: .dewPoint)
        case .cloudcover, .cloud_cover:
            return .init(variable: .cloudCover)
        case .vertical_velocity:
            return .init(variable: .verticalVelocity)
        }
    }
}

extension ForecastHeightVariableType: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature:
            return .init(variable: .temperature)
        case .relativehumidity, .relative_humidity:
            return .init(variable: .relativeHumidity)
        case .windspeed, .wind_speed:
            return .init(variable: .windSpeed)
        case .winddirection, .wind_direction:
            return .init(variable: .windDirection)
        case .dewpoint, .dew_point:
            return .init(variable: .dewPoint)
        case .cloudcover, .cloud_cover:
            return .init(variable: .cloudCover)
        case .vertical_velocity:
            return .init(variable: .verticalVelocity)
        }
    }
}

extension ForecastVariableDaily: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .apparent_temperature_max:
            return .init(variable: .apparentTemperature, aggregation: .maximum, altitude: 2)
        case .apparent_temperature_mean:
            return .init(variable: .apparentTemperature, aggregation: .mean, altitude: 2)
        case .apparent_temperature_min:
            return .init(variable: .apparentTemperature, aggregation: .minimum, altitude: 2)
        case .cape_max:
            return .init(variable: .cape, aggregation: .maximum)
        case .cape_mean:
            return .init(variable: .cape, aggregation: .mean)
        case .cape_min:
            return .init(variable: .cape, aggregation: .minimum)
        case .cloudcover_max, .cloud_cover_max:
            return .init(variable: .cloudCover, aggregation: .maximum)
        case .cloudcover_mean, .cloud_cover_mean:
            return .init(variable: .cloudCover, aggregation: .mean)
        case .cloudcover_min, .cloud_cover_min:
            return .init(variable: .cloudCover, aggregation: .minimum)
        case .dewpoint_2m_max, .dew_point_2m_max:
            return .init(variable: .dewPoint, aggregation: .maximum, altitude: 2)
        case .dewpoint_2m_mean, .dew_point_2m_mean:
            return .init(variable: .dewPoint, aggregation: .mean, altitude: 2)
        case .dewpoint_2m_min, .dew_point_2m_min:
            return .init(variable: .dewPoint, aggregation: .minimum, altitude: 2)
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration)
        case .et0_fao_evapotranspiration_sum:
            return .init(variable: .et0FaoEvapotranspiration, aggregation: .sum)
        case .growing_degree_days_base_0_limit_50:
            return .init(variable: .growingDegreeDays)
        case .leaf_wetness_probability_mean:
            return .init(variable: .leafWetnessProbability, aggregation: .mean)
        case .precipitation_hours:
            return .init(variable: .precipitationHours)
        case .precipitation_probability_max:
            return .init(variable: .precipitationProbability, aggregation: .maximum)
        case .precipitation_probability_mean:
            return .init(variable: .precipitationProbability, aggregation: .mean)
        case .precipitation_probability_min:
            return .init(variable: .precipitationProbability, aggregation: .minimum)
        case .precipitation_sum:
            return .init(variable: .precipitation, aggregation: .sum)
        case .pressure_msl_max:
            return .init(variable: .pressureMsl, aggregation: .maximum)
        case .pressure_msl_mean:
            return .init(variable: .pressureMsl, aggregation: .mean)
        case .pressure_msl_min:
            return .init(variable: .pressureMsl, aggregation: .minimum)
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
        case .showers_sum:
            return .init(variable: .showers, aggregation: .sum)
        case .snowfall_sum:
            return .init(variable: .snowfall, aggregation: .sum)
        case .snowfall_water_equivalent_sum:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .sum)
        case .soil_moisture_0_to_100cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 100)
        case .soil_moisture_0_to_10cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 10)
        case .soil_moisture_0_to_7cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_moisture_28_to_100cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_moisture_7_to_28cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_moisture_index_0_to_100cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 0, depthTo: 100)
        case .soil_moisture_index_0_to_7cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_moisture_index_100_to_255cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 100, depthTo: 255)
        case .soil_moisture_index_28_to_100cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_moisture_index_7_to_28cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_temperature_0_to_100cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 100)
        case .soil_temperature_0_to_7cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_temperature_28_to_100cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_temperature_7_to_28cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 7, depthTo: 28)
        case .sunrise:
            return .init(variable: .sunrise)
        case .sunset:
            return .init(variable: .sunset)
        case .surface_pressure_max:
            return .init(variable: .surfacePressure, aggregation: .maximum)
        case .surface_pressure_mean:
            return .init(variable: .surfacePressure, aggregation: .mean)
        case .surface_pressure_min:
            return .init(variable: .surfacePressure, aggregation: .minimum)
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .updraft_max:
            return .init(variable: .updraft, aggregation: .maximum)
        case .uv_index_clear_sky_max:
            return .init(variable: .uvIndexClearSky, aggregation: .maximum)
        case .uv_index_max:
            return .init(variable: .uvIndex, aggregation: .maximum)
        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
            return .init(variable: .vapourPressureDeficit, aggregation: .maximum)
        case .visibility_max:
            return .init(variable: .visibility, aggregation: .maximum)
        case .visibility_mean:
            return .init(variable: .visibility, aggregation: .mean)
        case .visibility_min:
            return .init(variable: .visibility, aggregation: .minimum)
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode)
        case .winddirection_10m_dominant, .wind_direction_10m_dominant:
            return .init(variable: .windDirection, aggregation: .dominant, altitude: 10)
        case .windgusts_10m_max, .wind_gusts_10m_max:
            return .init(variable: .windGusts, aggregation: .maximum, altitude: 10)
        case .windgusts_10m_mean, .wind_gusts_10m_mean:
            return .init(variable: .windGusts, aggregation: .mean, altitude: 10)
        case .windgusts_10m_min, .wind_gusts_10m_min:
            return .init(variable: .windGusts, aggregation: .minimum, altitude: 10)
        case .windspeed_10m_max, .wind_speed_10m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 10)
        case .windspeed_10m_mean, .wind_speed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .windspeed_10m_min, .wind_speed_10m_min:
            return .init(variable: .windSpeed, aggregation: .minimum, altitude: 10)
        case .wet_bulb_temperature_2m_max:
            return .init(variable: .wetBulbTemperature, aggregation: .maximum, altitude: 2)
        case .wet_bulb_temperature_2m_mean:
            return .init(variable: .wetBulbTemperature, aggregation: .mean, altitude: 2)
        case .wet_bulb_temperature_2m_min:
            return .init(variable: .wetBulbTemperature, aggregation: .minimum, altitude: 2)
        case .daylight_duration:
            return .init(variable: .daylightDuration)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
        case .snow_depth_min:
            return .init(variable: .snowDepth, aggregation: .minimum)
        case .snow_depth_mean:
            return .init(variable: .snowDepth, aggregation: .mean)
        case .snow_depth_max:
            return .init(variable: .snowDepth, aggregation: .maximum)
        }
    }
}

extension MultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = VariableAndPreviousDay

    typealias HourlyPressureType = ForecastPressureVariableType

    typealias HourlyHeightType = ForecastHeightVariableType

    typealias DailyVariable = ForecastVariableDaily

    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case .best_match:
            return .bestMatch
        case .gfs_seamless:
            return .gfsSeamless
        case .gfs_mix, .gfs_global:
            return .gfsGlobal
        case .gfs_hrrr:
            return .gfsHrrr
        case .meteofrance_seamless:
            return .meteofranceSeamless
        case .meteofrance_mix:
            return .meteofranceSeamless
        case .meteofrance_arpege_world:
            return .meteofranceArpegeWorld
        case .meteofrance_arpege_europe:
            return .meteofranceArpegeEurope
        case .meteofrance_arome_france:
            return .meteofranceAromeFrance
        case .meteofrance_arome_france_hd:
            return .meteofranceAromeFranceHd
        case .jma_seamless, .jma_mix:
            return .jmaSeamless
        case .jma_msm:
            return .jmaMsm
        case .jms_gsm, .jma_gsm:
            return .jmaGsm
        case .gem_seamless:
            return .gemSeamless
        case .gem_global:
            return .gemGlobal
        case .gem_regional:
            return .gemRegional
        case .gem_hrdps_continental:
            return .gemHrdpsContinental
        case .icon_mix, .icon_seamless:
            return .iconSeamless
        case .icon_global:
            return .iconGlobal
        case .icon_eu:
            return .iconEu
        case .icon_d2:
            return .iconD2
        case .ecmwf_ifs04:
            return .ecmwfIfs04
        case .metno_nordic:
            return .metnoNordic
        case .era5_seamless:
            return .era5Seamless
        case .era5:
            return .era5
        case .cerra:
            return .cerra
        case .era5_land:
            return .era5Land
        case .ecmwf_ifs:
            return .ecmwfIfs
        case .meteofrance_arpege_seamless:
            return .meteofranceArpegeSeamless
        case .meteofrance_arome_seamless:
            return .meteofranceAromeSeamless
        case .arpege_seamless:
            return .meteofranceArpegeSeamless
        case .arpege_world:
            return .meteofranceArpegeEurope
        case .arpege_europe:
            return .meteofranceArpegeEurope
        case .arome_seamless:
            return .meteofranceAromeSeamless
        case .arome_france:
            return .meteofranceAromeFrance
        case .arome_france_hd:
            return .meteofranceAromeFranceHd
        case .archive_best_match:
            return .bestMatch
        case .cma_grapes_global:
            return .cmaGrapesGlobal
        case .bom_access_global:
            return .bomAccessGlobal
        case .arpae_cosmo_seamless:
            return .arpaeCosmoSeamless
        case .arpae_cosmo_2i:
            return .arpaeCosmo2i
        case .arpae_cosmo_2i_ruc:
            return .arpaeCosmo2iRuc
        case .arpae_cosmo_5m:
            return .arpaeCosmo5m
        case .ecmwf_ifs025:
            return .ecmwfIfs025
        case .ecmwf_aifs025:
            return .ecmwfAifs025
        case .gfs_graphcast025:
            return .gfsGraphcast025
        case .gfs025:
            return .gfs025
        case .gfs013:
            return .gfs013
        case .knmi_harmonie_arome_europe:
            return .knmiHarmonieAromeEurope
        case .knmi_harmonie_arome_netherlands:
            return .knmiHarmonieAromeNetherlands
        case .dmi_harmonie_arome_europe:
            return .dmiHarmonieAromeEurope
        case .knmi_seamless:
            return .knmiSeamless
        case .dmi_seamless:
            return .dmiSeamless
        case .metno_seamless:
            return .metnoSeamless
        case .ecmwf_ifs_analysis_long_window:
            return .ecmwfIfsAnalysisLongWindow
        case .ecmwf_ifs_analysis:
            return .ecmwfIfsAnalysis
        case .ecmwf_ifs_long_window:
            return .ecmwfIfsLongWindow
        case .era5_ensemble:
            return .era5Ensemble
        case .ukmo_seamless:
            return .ukmoSeamless
        case .ukmo_global_deterministic_10km:
            return .ukmoGlobalDeterministic10km
        case .ukmo_uk_deterministic_2km:
            return .ukmoUkDeterministic2km
        case .ncep_nbm_conus:
            return .ncepNbmConus
        case .ecmwf_aifs025_single:
            return .ecmwfAifs025Single
        case .eumetsat_sarah3:
            return .eumetsatSarah3
        case .jma_jaxa_himawari:
            return .jmaJaxaHimawari
        case .eumetsat_lsa_saf_msg:
            return .eumetsatLsaSafMsg
        case .eumetsat_lsa_saf_iodc:
            return .eumetsatLsaSafIodc
        case .satellite_radiation_seamless:
            return .satelliteRadiationSeamless
        case .kma_seamless:
            return .kmaSeamless
        case .kma_gdps:
            return .kmaGdps
        case .kma_ldps:
            return .kmaLdps
        case .italia_meteo_arpae_icon_2i:
            return .italiaMeteoArpaeIcon2i
        case .meteofrance_arome_france_hd_15min:
            // TODO add 15min entry to SDK
            return .meteofranceAromeFranceHd
        case .meteofrance_arome_france_15min:
            // TODO add 15min entry to SDK
            return .meteofranceAromeFranceHd
        case .meteoswiss_icon_ch1:
            // TODO register
            return .iconSeamless
        case .meteoswiss_icon_ch2:
            // TODO register
            return .iconSeamless
        case .meteoswiss_icon_seamless:
            // TODO register
            return .iconSeamless
        }
    }
}
