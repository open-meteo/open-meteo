import Foundation
import SwiftPFor2D
import Vapor



typealias Era5HourlyVariable = VariableOrDerived<Era5Variable, Era5VariableDerived>

enum Era5VariableDerived: String, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case relative_humidity_2m
    case windspeed_10m
    case wind_speed_10m
    case winddirection_10m
    case wind_direction_10m
    case windspeed_100m
    case wind_speed_100m
    case winddirection_100m
    case wind_direction_100m
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case cloud_cover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case direct_normal_irradiance
    case weathercode
    case weather_code
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
    case wet_bulb_temperature_2m
    case windgusts_10m
    case dewpoint_2m
    case sunshine_duration
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
