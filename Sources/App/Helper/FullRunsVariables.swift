

fileprivate struct FullRunsPressureVariable: PressureVariableRespresentable {
    let variable: FullRunsPressureVariableType
    let level: Int
}

fileprivate enum FullRunsPressureVariableType: String {
    case temperature
    case geopotential_height
    case wind_v_component
    case wind_u_component
    case vertical_velocity
    case relative_humidity
    case wind_speed
    case wind_direction
    case cloud_cover
    case dew_point
}

/// List of all variables that should be stored as full run data in `./data_run`
enum FullRunsVariables: String {
    static func includes(_ variable: String) -> Bool {
        if let pres = FullRunsPressureVariable(rawValue: variable) {
            return FullRunsVariables.levelsToKeep.contains(pres.level)
        }
        return FullRunsVariables.init(rawValue: variable) != nil
    }
    
    static let levelsToKeep = [1000, 925, 850, 700, 600, 500, 400, 300, 250, 200, 150, 100, 50]
    
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
    case wind_speed_180m
    case wind_direction_180m
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
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_35cm
    case soil_temperature_35_to_100cm
    case soil_temperature_100_to_300cm

    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_35cm
    case soil_moisture_35_to_100cm
    case soil_moisture_100_to_300cm
    
    case soil_temperature_0cm
    case soil_temperature_6cm
    case soil_temperature_18cm
    case soil_temperature_54cm

    case soil_moisture_0_to_1cm
    case soil_moisture_1_to_3cm
    case soil_moisture_3_to_9cm
    case soil_moisture_9_to_27cm
    case soil_moisture_27_to_81cm
}


