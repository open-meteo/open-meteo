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
            return .init(variable: .surfacePressure)
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
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
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


extension EnsembleMultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
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
        }
    }
}
