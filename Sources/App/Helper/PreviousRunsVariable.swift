
/// List of all variables that should be stored as previous runs
/// TODO roughness length
enum PreviousRunsVariable: String {
    case temperature_2m
    case temperature_80m
    case temperature_100m
    case relative_humidity_2m
    case surface_temperature
    case showers
    case precipitation
    case rain
    case snowfall_water_equivalent
    case pressure_msl
    case freezing_level_height
    case cloud_cover
    case cloud_cover_mid
    case cloud_cover_low
    case cloud_cover_high
    case shortwave_radiation
    case diffuse_radiation
    case direct_radiation
    case weather_code
    case cape
    case lifted_index
    case visibility
    
    case wind_gusts_10m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_50m
    case wind_direction_50m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_100m
    case wind_direction_100m
    case wind_speed_120m
    case wind_direction_120m
    case wind_speed_150m
    case wind_direction_150m
    case wind_speed_200m
    case wind_direction_200m
    case wind_speed_250m
    case wind_direction_250m
    case wind_speed_300m
    case wind_direction_300m
    
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_u_component_70m
    case wind_v_component_70m
    case wind_u_component_80m
    case wind_v_component_80m
    case wind_v_component_100m
    case wind_u_component_100m
    case wind_u_component_120m
    case wind_v_component_120m
    case wind_u_component_180m
    case wind_v_component_180m
    
    case geopotential_height_1000hPa
    case wind_u_component_1000hPa
    case wind_v_component_1000hPa
    case temperature_1000hPa
    case cloud_cover_1000hPa
    case relative_humidity_1000hPa
    case dew_point_1000hPa
    
    case geopotential_height_925hPa
    case wind_u_component_925hPa
    case wind_v_component_925hPa
    case temperature_925hPa
    case cloud_cover_925hPa
    case relative_humidity_925hPa
    case dew_point_925hPa
    
    case geopotential_height_850hPa
    case wind_u_component_850hPa
    case wind_v_component_850hPa
    case temperature_850hPa
    case cloud_cover_850hPa
    case relative_humidity_850hPa
    case dew_point_850hPa
    
    case geopotential_height_500hPa
    case wind_u_component_500hPa
    case wind_v_component_500hPa
    case temperature_500hPa
    case cloud_cover_500hPa
    case relative_humidity_500hPa
    case dew_point_500hPa
}


