import Foundation
import Vapor


/// one value 6-18h and then 18-6h
/*enum DayNightWeatherVariable: String {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case weathercode
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
}

/// overnight 0-6, morning 6-12, afternoon 12-18, evening 18-24
enum OvernightMorningAfternoonEveningWeatherVariable: String {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case weathercode
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
    case cloudcover_total_average
    case relative_humidity_max
}*/

typealias IconApiVariable = VariableOrDerived<IconVariable, IconVariableDerived>

/**
 Types of pressure level variables
 */
enum IconPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
    case wind_speed
    case wind_direction
    case dew_point
    case cloud_cover
    case relativehumidity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct IconPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: IconPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias IconVariableDerived = SurfaceAndPressureVariable<IconSurfaceVariableDerived, IconPressureVariableDerived>

enum IconSurfaceVariableDerived: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    case windspeed_180m
    case winddirection_180m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_120m
    case wind_direction_120m
    case wind_speed_180m
    case wind_direction_180m
    case direct_normal_irradiance
    case evapotranspiration
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case shortwave_radiation
    case snow_height
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case is_day
    case soil_moisture_0_1cm
    case soil_moisture_1_3cm
    case soil_moisture_3_9cm
    case soil_moisture_9_27cm
    case soil_moisture_27_81cm
    case wet_bulb_temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case weathercode
    case sensible_heatflux
    case latent_heatflux
    case windgusts_10m
    case freezinglevel_height
    case sunshine_duration
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    
    var requiresOffsetCorrectionForMixing: Bool {
        return self == .snow_height
    }
}

