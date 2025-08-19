

/// 6-hourly variables in O320 grid
enum EcmwfSeasVariableSingleLevel: String {
    // 10U/10V/2D/2T/MSL/SF/SSRD/SST/STL1/TCC/TP
    
    case temperature_2m
    case dew_point_2m
    case pressure_msl
    case sea_surface_temperature
    case wind_u_component_10m
    case wind_v_component_10m
    case snowfall_water_equivalent
    case precipitation
    case shortwave_radiation
    case soil_temperature_0_to_7cm
    case cloud_cover
}

/// 24 hourly variables in O320 grid
/// STL1/STL2/STL3/STL4/SUND/SWVL1/SWVL2/SWVL3/SWVL4
/// MEAN2T24/MN2T24/MX2T24
enum EcmwfSeasVariable24HourlySingleLevel: String {
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    
    case temperature_2m_max24h
    case temperature_2m_min24h
    case temperature_2m_mean24h
}

/// Only available as 6-hourly data in N160 grid
/// Model levels 85/87/89 https://confluence.ecmwf.int/display/UDOC/L91+model+level+definitions
/// 85=309.04m, 87=167.39m, 89=67.88m
enum EcmwfSeasVariableUpperLevel: String {
    case temperature_850hPa
    case temperature_500hPa
    case geopotential_height_500hPa
    case geopotential_height_850hPa
    
    case relative_humidity_70m
    case relative_humidity_170m
    case relative_humidity_310m
    case temperature_70m
    case temperature_170m
    case temperature_310m
    case wind_u_component_70m
    case wind_u_component_170m
    case wind_u_component_310m
    case wind_v_component_70m
    case wind_v_component_170m
    case wind_v_component_310m
}

