import Foundation
import FlatBuffers
import OpenMeteoSdk


extension ForecastSurfaceVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature:
            return .init(variable: .temperature, altitude: 2)
        case .windspeed:
            return .init(variable: .windSpeed, altitude: 10)
        case .winddirection:
            return .init(variable: .windDirection, altitude: 10)
        case .wet_bulb_temperature_2m:
            return .init(variable: .wetBulbTemperature, altitude: 2)
        case .apparent_temperature:
            return .init(variable: .apparentTemperature, altitude: 2)
        case .cape:
            return .init(variable: .cape)
        case .cloudcover, .cloud_cover:
            return .init(variable: .cloudCover)
        case .cloudcover_high, .cloud_cover_high:
            return .init(variable: .cloudCoverHigh)
        case .cloudcover_low, .cloud_cover_low:
            return .init(variable: .cloudCoverLow)
        case .cloudcover_mid, .cloud_cover_mid:
            return .init(variable: .cloudCoverMid)
        case .dewpoint_2m, .dew_point_2m:
            return .init(variable: .dewPoint, altitude: 2)
        case .diffuse_radiation:
            return .init(variable: .diffuseRadiation)
        case .diffuse_radiation_instant:
            return .init(variable: .diffuseRadiationInstant)
        case .direct_normal_irradiance:
            return .init(variable: .directNormalIrradiance)
        case .direct_normal_irradiance_instant:
            return .init(variable: .directNormalIrradianceInstant)
        case .direct_radiation:
            return .init(variable: .directRadiation)
        case .direct_radiation_instant:
            return .init(variable: .directRadiationInstant)
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration)
        case .evapotranspiration:
            return .init(variable: .evapotranspiration)
        case .freezinglevel_height, .freezing_level_height:
            return .init(variable: .freezingLevelHeight)
        case .growing_degree_days_base_0_limit_50:
            return .init(variable: .growingDegreeDays)
        case .is_day:
            return .init(variable: .isDay)
        case .latent_heatflux, .latent_heat_flux:
            return .init(variable: .latentHeatFlux)
        case .lifted_index:
            return .init(variable: .liftedIndex)
        case .leaf_wetness_probability:
            return .init(variable: .leafWetnessProbability)
        case .lightning_potential:
            return .init(variable: .lightningPotential)
        case .precipitation:
            return .init(variable: .precipitation)
        case .precipitation_probability:
            return .init(variable: .precipitationProbability)
        case .pressure_msl:
            return .init(variable: .pressureMsl)
        case .rain:
            return .init(variable: .rain)
        case .relativehumidity_2m, .relative_humidity_2m:
            return .init(variable: .relativeHumidity, altitude: 2)
        case .runoff:
            return .init(variable: .runoff)
        case .sensible_heatflux, .sensible_heat_flux:
            return .init(variable: .sensibleHeatFlux)
        case .shortwave_radiation:
            return .init(variable: .shortwaveRadiation)
        case .shortwave_radiation_instant:
            return .init(variable: .shortwaveRadiationInstant)
        case .showers:
            return .init(variable: .showers)
        case .skin_temperature:
            return .init(variable: .surfaceTemperature)
        case .snow_depth:
            return .init(variable: .snowDepth)
        case .snow_height:
            return .init(variable: .snowHeight)
        case .snowfall:
            return .init(variable: .snowfall)
        case .snowfall_water_equivalent:
            return .init(variable: .snowfallWaterEquivalent)
        case .soil_moisture_0_1cm:
            fallthrough
        case .soil_moisture_0_to_1cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 1)
        case .soil_moisture_0_to_100cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 100)
        case .soil_moisture_0_to_10cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 10)
        case .soil_moisture_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7)
        case .soil_moisture_100_to_200cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 200)
        case .soil_moisture_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255)
        case .soil_moisture_10_to_40cm:
            return .init(variable: .soilMoisture, depth: 10, depthTo: 40)
        case .soil_moisture_1_3cm:
            fallthrough
        case .soil_moisture_1_to_3cm:
            return .init(variable: .soilMoisture, depth: 1, depthTo: 3)
        case .soil_moisture_27_81cm:
            fallthrough
        case .soil_moisture_27_to_81cm:
            return .init(variable: .soilMoisture, depth: 27, depthTo: 81)
        case .soil_moisture_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100)
        case .soil_moisture_3_9cm:
            fallthrough
        case .soil_moisture_3_to_9cm:
            return .init(variable: .soilMoisture, depth: 3, depthTo: 9)
        case .soil_moisture_40_to_100cm:
            return .init(variable: .soilMoisture, depth: 40, depthTo: 100)
        case .soil_moisture_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28)
        case .soil_moisture_9_27cm:
            return .init(variable: .soilMoisture, depth: 9, depthTo: 27)
        case .soil_moisture_9_to_27cm:
            return .init(variable: .soilMoisture, depth: 9, depthTo: 27)
        case .soil_moisture_index_0_to_100cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 100)
        case .soil_moisture_index_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7)
        case .soil_moisture_index_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255)
        case .soil_moisture_index_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100)
        case .soil_moisture_index_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28)
        case .soil_temperature_0_to_100cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 100)
        case .soil_temperature_0_to_10cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 10)
        case .soil_temperature_0_to_7cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 7)
        case .soil_temperature_0cm:
            return .init(variable: .soilTemperature, depth: 0)
        case .soil_temperature_100_to_200cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 200)
        case .soil_temperature_100_to_255cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 255)
        case .soil_temperature_10_to_40cm:
            return .init(variable: .soilTemperature, depth: 10, depthTo: 40)
        case .soil_temperature_18cm:
            return .init(variable: .soilTemperature, depth: 18)
        case .soil_temperature_28_to_100cm:
            return .init(variable: .soilTemperature, depth: 28, depthTo: 100)
        case .soil_temperature_40_to_100cm:
            return .init(variable: .soilTemperature, depth: 40, depthTo: 100)
        case .soil_temperature_54cm:
            return .init(variable: .soilTemperature, depth: 54)
        case .soil_temperature_6cm:
            return .init(variable: .soilTemperature, depth: 6)
        case .soil_temperature_7_to_28cm:
            return .init(variable: .soilTemperature, depth: 7, depthTo: 28)
        case .surface_air_pressure:
            return .init(variable: .surfacePressure)
        case .snowfall_height:
            return .init(variable: .snowfallHeight)
        case .surface_pressure:
            return .init(variable: .surfacePressure)
        case .surface_temperature:
            return .init(variable: .surfaceTemperature)
        case .temperature_100m:
            return .init(variable: .temperature, altitude: 100)
        case .temperature_120m:
            return .init(variable: .temperature, altitude: 120)
        case .temperature_150m:
            return .init(variable: .temperature, altitude: 150)
        case .temperature_180m:
            return .init(variable: .temperature, altitude: 180)
        case .temperature_2m:
            return .init(variable: .temperature, altitude: 2)
        case .temperature_20m:
            return .init(variable: .temperature, altitude: 20)
        case .temperature_200m:
            return .init(variable: .temperature, altitude: 200)
        case .temperature_50m:
            return .init(variable: .temperature, altitude: 50)
        case .temperature_40m:
            return .init(variable: .temperature, altitude: 40)
        case .temperature_80m:
            return .init(variable: .temperature, altitude: 80)
        case .terrestrial_radiation:
            return .init(variable: .terrestrialRadiation)
        case .terrestrial_radiation_instant:
            return .init(variable: .terrestrialRadiationInstant)
        case .total_column_integrated_water_vapour:
            return .init(variable: .totalColumnIntegratedWaterVapour)
        case .updraft:
            return .init(variable: .updraft)
        case .uv_index:
            return .init(variable: .uvIndex)
        case .uv_index_clear_sky:
            return .init(variable: .uvIndexClearSky)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            return .init(variable: .vapourPressureDeficit)
        case .visibility:
            return .init(variable: .visibility)
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode)
        case .winddirection_100m, .wind_direction_100m:
            return .init(variable: .windDirection, altitude: 100)
        case .winddirection_10m, .wind_direction_10m:
            return .init(variable: .windDirection, altitude: 10)
        case .winddirection_120m, .wind_direction_120m:
            return .init(variable: .windDirection, altitude: 120)
        case .winddirection_150m, .wind_direction_150m:
            return .init(variable: .windDirection, altitude: 150)
        case .winddirection_180m, .wind_direction_180m:
            return .init(variable: .windDirection, altitude: 180)
        case .winddirection_200m, .wind_direction_200m:
            return .init(variable: .windDirection, altitude: 200)
        case .winddirection_20m, .wind_direction_20m:
            return .init(variable: .windDirection, altitude: 20)
        case .winddirection_40m, .wind_direction_40m:
            return .init(variable: .windDirection, altitude: 40)
        case .winddirection_50m, .wind_direction_50m:
            return .init(variable: .windDirection, altitude: 50)
        case .winddirection_80m, .wind_direction_80m:
            return .init(variable: .windDirection, altitude: 80)
        case .windgusts_10m, .wind_gusts_10m:
            return .init(variable: .windGusts, altitude: 10)
        case .windspeed_100m, .wind_speed_100m:
            return .init(variable: .windSpeed, altitude: 100)
        case .windspeed_10m, .wind_speed_10m:
            return .init(variable: .windSpeed, altitude: 10)
        case .windspeed_120m, .wind_speed_120m:
            return .init(variable: .windSpeed, altitude: 120)
        case .windspeed_150m, .wind_speed_150m:
            return .init(variable: .windSpeed, altitude: 150)
        case .windspeed_180m, .wind_speed_180m:
            return .init(variable: .windSpeed, altitude: 180)
        case .windspeed_200m, .wind_speed_200m:
            return .init(variable: .windSpeed, altitude: 200)
        case .windspeed_20m, .wind_speed_20m:
            return .init(variable: .windSpeed, altitude: 20)
        case .windspeed_40m, .wind_speed_40m:
            return .init(variable: .windSpeed, altitude: 40)
        case .windspeed_50m, .wind_speed_50m:
            return .init(variable: .windSpeed, altitude: 50)
        case .windspeed_80m, .wind_speed_80m:
            return .init(variable: .windSpeed, altitude: 80)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
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
        }
    }
}



extension MultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case .best_match:
            return .bestMatch
        case .gfs_seamless:
            return .gfsSeamless
        case .gfs_mix:
            fallthrough
        case .gfs_global:
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
        case .jma_seamless:
           fallthrough
        case .jma_mix:
            return .jmaSeamless
        case .jma_msm:
            return .jmaMsm
        case .jms_gsm:
            fallthrough
        case .jma_gsm:
            return .jmaGsm
        case .gem_seamless:
            return .gemSeamless
        case .gem_global:
            return .gemGlobal
        case .gem_regional:
            return .gemGlobal
        case .gem_hrdps_continental:
            return .gemHrdpsContinental
        case .icon_mix:
            fallthrough
        case .icon_seamless:
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
        }
    }
}
