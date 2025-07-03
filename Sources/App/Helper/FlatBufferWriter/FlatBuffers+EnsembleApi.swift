import Foundation
import FlatBuffers
import OpenMeteoSdk

extension EnsembleSurfaceVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode)
        case .temperature_2m:
            return .init(variable: .temperature, altitude: 2)
        case .temperature_80m:
            return .init(variable: .temperature, altitude: 80)
        case .temperature_120m:
            return .init(variable: .temperature, altitude: 120)
        case .cloudcover, .cloud_cover:
            return .init(variable: .cloudCover)
        case .pressure_msl:
            return .init(variable: .pressureMsl)
        case .relativehumidity_2m, .relative_humidity_2m:
            return .init(variable: .relativeHumidity, altitude: 2)
        case .precipitation:
            return .init(variable: .precipitation)
        case .rain:
            return .init(variable: .rain)
        case .windgusts_10m, .wind_gusts_10m:
            return .init(variable: .windGusts, altitude: 10)
        case .dewpoint_2m, .dew_point_2m:
            return .init(variable: .dewPoint, altitude: 2)
        case .diffuse_radiation:
            return .init(variable: .diffuseRadiation)
        case .direct_radiation:
            return .init(variable: .directRadiation)
        case .apparent_temperature:
            return .init(variable: .apparentTemperature, altitude: 2)
        case .windspeed_10m, .wind_speed_10m:
            return .init(variable: .windSpeed, altitude: 10)
        case .winddirection_10m, .wind_direction_10m:
            return .init(variable: .windDirection, altitude: 10)
        case .windspeed_80m, .wind_speed_80m:
            return .init(variable: .windSpeed, altitude: 80)
        case .winddirection_80m, .wind_direction_80m:
            return .init(variable: .windDirection, altitude: 80)
        case .windspeed_120m, .wind_speed_120m:
            return .init(variable: .windSpeed, altitude: 120)
        case .winddirection_120m, .wind_direction_120m:
            return .init(variable: .windDirection, altitude: 120)
        case .direct_normal_irradiance:
            return .init(variable: .directNormalIrradiance)
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            return .init(variable: .vapourPressureDeficit)
        case .shortwave_radiation:
            return .init(variable: .shortwaveRadiation)
        case .snowfall:
            return .init(variable: .snowfall)
        case .snow_depth:
            return .init(variable: .snowDepth)
        case .surface_pressure:
            return .init(variable: .surfacePressure)
        case .shortwave_radiation_instant:
            return .init(variable: .shortwaveRadiationInstant)
        case .diffuse_radiation_instant:
            return .init(variable: .diffuseRadiationInstant)
        case .direct_radiation_instant:
            return .init(variable: .directRadiationInstant)
        case .direct_normal_irradiance_instant:
            return .init(variable: .directNormalIrradianceInstant)
        case .is_day:
            return .init(variable: .isDay)
        case .visibility:
            return .init(variable: .visibility)
        case .freezinglevel_height, .freezing_level_height:
            return .init(variable: .freezingLevelHeight)
        case .uv_index:
            return .init(variable: .uvIndex)
        case .uv_index_clear_sky:
            return .init(variable: .uvIndexClearSky)
        case .cape:
            return .init(variable: .cape)
        case .surface_temperature:
            return .init(variable: .surfaceTemperature)
        case .soil_temperature_0_to_10cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 10)
        case .soil_temperature_10_to_40cm:
            return .init(variable: .soilTemperature, depth: 10, depthTo: 40)
        case .soil_temperature_40_to_100cm:
            return .init(variable: .soilTemperature, depth: 40, depthTo: 100)
        case .soil_temperature_100_to_200cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 200)
        case .soil_moisture_0_to_10cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 10)
        case .soil_moisture_10_to_40cm:
            return .init(variable: .soilMoisture, depth: 10, depthTo: 40)
        case .soil_moisture_40_to_100cm:
            return .init(variable: .soilMoisture, depth: 40, depthTo: 100)
        case .soil_moisture_100_to_200cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 200)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
        case .global_tilted_irradiance:
            return .init(variable: .globalTiltedIrradiance)
        case .global_tilted_irradiance_instant:
            return .init(variable: .globalTiltedIrradianceInstant)
        case .wind_speed_100m:
            return .init(variable: .windSpeed, altitude: 100)
        case .wind_direction_100m:
            return .init(variable: .windDirection, altitude: 100)
        }
    }
}

extension EnsemblePressureVariableType: FlatBuffersVariable {
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

extension EnsembleVariableDaily: FlatBuffersVariable {
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
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration)
        case .precipitation_hours:
            return .init(variable: .precipitationHours)
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
        case .snowfall_sum:
            return .init(variable: .snowfall, aggregation: .sum)
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
        case .wind_direction_10m_dominant:
            return .init(variable: .windDirection, aggregation: .dominant, altitude: 10)
        case .wind_gusts_10m_max:
            return .init(variable: .windGusts, aggregation: .maximum, altitude: 10)
        case .wind_gusts_10m_mean:
            return .init(variable: .windGusts, aggregation: .mean, altitude: 10)
        case .wind_gusts_10m_min:
            return .init(variable: .windGusts, aggregation: .minimum, altitude: 10)
        case .wind_speed_10m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 10)
        case .wind_speed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .wind_speed_10m_min:
            return .init(variable: .windSpeed, aggregation: .minimum, altitude: 10)
        case .wind_speed_100m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 100)
        case .wind_speed_100m_min:
            return .init(variable: .windSpeed, aggregation: .minimum, altitude: 100)
        case .wind_speed_100m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 100)
        case .wind_direction_100m_dominant:
            return .init(variable: .windDirection, aggregation: .dominant, altitude: 100)
        }
    }
}

extension EnsembleMultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable

    typealias HourlyPressureType = EnsemblePressureVariableType

    typealias HourlyHeightType = ForecastHeightVariableType

    typealias DailyVariable = EnsembleVariableDaily

    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
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
        case .ecmwf_ifs025:
            return .ecmwfIfs025
        case .gem_global:
            return .gemGlobal
        case .gfs_seamless:
            return .gfsSeamless
        case .gfs025:
            return .gfs025
        case .gfs05:
            return .gfs025
        case .bom_access_global_ensemble:
            return .bomAccessGlobalEnsemble
        case .ukmo_global_ensemble_20km:
            return .ukmoGlobalEnsemble20km
        case .ukmo_uk_ensemble_2km:
            // TODO register in SDK
            return .ukmoGlobalEnsemble20km
        case .ecmwf_aifs025:
            return .ecmwfAifs025
        case .meteoswiss_icon_ch1:
            // todo register
            return .iconD2
        case .meteoswiss_icon_ch2:
            // todo register
            return .iconD2
        }
    }
}
