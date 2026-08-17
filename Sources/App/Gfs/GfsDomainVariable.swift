/// Stored surface fields for NAM CONUS.
enum NamSurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case temperature_2m, surface_temperature
    case cloud_cover, cloud_cover_low, cloud_cover_mid, cloud_cover_high
    case relative_humidity_2m, pressure_msl, precipitation
    case wind_v_component_10m, wind_u_component_10m
    case wind_v_component_80m, wind_u_component_80m
    case soil_temperature_0_to_10cm, soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm, soil_temperature_100_to_200cm
    case soil_moisture_0_to_10cm, soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm, soil_moisture_100_to_200cm
    case snow_depth, sensible_heat_flux, latent_heat_flux
    case snowfall_water_equivalent, shortwave_radiation
    case boundary_layer_height, total_column_integrated_water_vapour
    case visibility, wind_gusts_10m, categorical_freezing_rain
    case convective_inhibition, cape

    var field: GfsSurfaceField {
        switch self {
        case .temperature_2m: return .temperature_2m
        case .surface_temperature: return .surface_temperature
        case .cloud_cover: return .cloud_cover
        case .cloud_cover_low: return .cloud_cover_low
        case .cloud_cover_mid: return .cloud_cover_mid
        case .cloud_cover_high: return .cloud_cover_high
        case .relative_humidity_2m: return .relative_humidity_2m
        case .pressure_msl: return .pressure_msl
        case .precipitation: return .precipitation
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .soil_temperature_0_to_10cm: return .soil_temperature_0_to_10cm
        case .soil_temperature_10_to_40cm: return .soil_temperature_10_to_40cm
        case .soil_temperature_40_to_100cm: return .soil_temperature_40_to_100cm
        case .soil_temperature_100_to_200cm: return .soil_temperature_100_to_200cm
        case .soil_moisture_0_to_10cm: return .soil_moisture_0_to_10cm
        case .soil_moisture_10_to_40cm: return .soil_moisture_10_to_40cm
        case .soil_moisture_40_to_100cm: return .soil_moisture_40_to_100cm
        case .soil_moisture_100_to_200cm: return .soil_moisture_100_to_200cm
        case .snow_depth: return .snow_depth
        case .sensible_heat_flux: return .sensible_heat_flux
        case .latent_heat_flux: return .latent_heat_flux
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        case .shortwave_radiation: return .shortwave_radiation
        case .boundary_layer_height: return .boundary_layer_height
        case .total_column_integrated_water_vapour: return .total_column_integrated_water_vapour
        case .visibility: return .visibility
        case .wind_gusts_10m: return .wind_gusts_10m
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .convective_inhibition: return .convective_inhibition
        case .cape: return .cape
        }
    }
}

/// Stored hourly HRRR fields. This is also the intentional union used to mix hourly and 15-minute HRRR data.
enum HrrrSurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case pressure_msl, lifted_index, temperature_2m
    case cloud_cover, cloud_cover_low, cloud_cover_mid, cloud_cover_high
    case relative_humidity_2m, precipitation
    case wind_v_component_10m, wind_u_component_10m
    case wind_v_component_80m, wind_u_component_80m
    case surface_temperature, snow_depth
    case sensible_heat_flux, latent_heat_flux
    case snowfall_water_equivalent, convective_inhibition
    case categorical_freezing_rain, wind_gusts_10m, freezing_level_height
    case shortwave_radiation, diffuse_radiation, cape, visibility
    case boundary_layer_height, total_column_integrated_water_vapour
    case mass_density_8m

    var field: GfsSurfaceField {
        switch self {
        case .pressure_msl: return .pressure_msl
        case .lifted_index: return .lifted_index
        case .temperature_2m: return .temperature_2m
        case .cloud_cover: return .cloud_cover
        case .cloud_cover_low: return .cloud_cover_low
        case .cloud_cover_mid: return .cloud_cover_mid
        case .cloud_cover_high: return .cloud_cover_high
        case .relative_humidity_2m: return .relative_humidity_2m
        case .precipitation: return .precipitation
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .surface_temperature: return .surface_temperature
        case .snow_depth: return .snow_depth
        case .sensible_heat_flux: return .sensible_heat_flux
        case .latent_heat_flux: return .latent_heat_flux
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        case .convective_inhibition: return .convective_inhibition
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .wind_gusts_10m: return .wind_gusts_10m
        case .freezing_level_height: return .freezing_level_height
        case .shortwave_radiation: return .shortwave_radiation
        case .diffuse_radiation: return .diffuse_radiation
        case .cape: return .cape
        case .visibility: return .visibility
        case .boundary_layer_height: return .boundary_layer_height
        case .total_column_integrated_water_vapour: return .total_column_integrated_water_vapour
        case .mass_density_8m: return .mass_density_8m
        }
    }
}

/// Stored HRRR 15-minute fields, excluding download-only snowfall inputs.
enum Hrrr15MinSurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case temperature_2m, precipitation, categorical_freezing_rain
    case wind_gusts_10m
    case wind_v_component_10m, wind_u_component_10m
    case wind_v_component_80m, wind_u_component_80m
    case shortwave_radiation, diffuse_radiation, visibility
    case snowfall_water_equivalent

    var field: GfsSurfaceField {
        switch self {
        case .temperature_2m: return .temperature_2m
        case .precipitation: return .precipitation
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .wind_gusts_10m: return .wind_gusts_10m
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .shortwave_radiation: return .shortwave_radiation
        case .diffuse_radiation: return .diffuse_radiation
        case .visibility: return .visibility
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        }
    }
}

enum Gefs025SurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case visibility, wind_gusts_10m, pressure_msl
    case soil_temperature_0_to_10cm, soil_moisture_0_to_10cm
    case snow_depth, temperature_2m, relative_humidity_2m
    case wind_u_component_10m, wind_v_component_10m
    case precipitation, snowfall_water_equivalent, categorical_freezing_rain
    case latent_heat_flux, sensible_heat_flux, convective_inhibition, cape
    case cloud_cover, shortwave_radiation

    var field: GfsSurfaceField {
        switch self {
        case .visibility: return .visibility
        case .wind_gusts_10m: return .wind_gusts_10m
        case .pressure_msl: return .pressure_msl
        case .soil_temperature_0_to_10cm: return .soil_temperature_0_to_10cm
        case .soil_moisture_0_to_10cm: return .soil_moisture_0_to_10cm
        case .snow_depth: return .snow_depth
        case .temperature_2m: return .temperature_2m
        case .relative_humidity_2m: return .relative_humidity_2m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_10m: return .wind_v_component_10m
        case .precipitation: return .precipitation
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .latent_heat_flux: return .latent_heat_flux
        case .sensible_heat_flux: return .sensible_heat_flux
        case .convective_inhibition: return .convective_inhibition
        case .cape: return .cape
        case .cloud_cover: return .cloud_cover
        case .shortwave_radiation: return .shortwave_radiation
        }
    }
}

enum Gefs05SurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case visibility, wind_gusts_10m, pressure_msl, snow_depth
    case temperature_2m, temperature_80m, temperature_100m
    case relative_humidity_2m
    case wind_u_component_10m, wind_v_component_10m
    case wind_u_component_80m, wind_v_component_80m
    case wind_u_component_100m, wind_v_component_100m
    case precipitation, snowfall_water_equivalent, categorical_freezing_rain
    case latent_heat_flux, sensible_heat_flux, cape, cloud_cover
    case shortwave_radiation, lifted_index, convective_inhibition
    case freezing_level_height, surface_temperature
    case soil_temperature_0_to_10cm, soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm, soil_temperature_100_to_200cm
    case soil_moisture_0_to_10cm, soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm, soil_moisture_100_to_200cm
    case uv_index, uv_index_clear_sky

    var field: GfsSurfaceField {
        switch self {
        case .visibility: return .visibility
        case .wind_gusts_10m: return .wind_gusts_10m
        case .pressure_msl: return .pressure_msl
        case .snow_depth: return .snow_depth
        case .temperature_2m: return .temperature_2m
        case .temperature_80m: return .temperature_80m
        case .temperature_100m: return .temperature_100m
        case .relative_humidity_2m: return .relative_humidity_2m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_100m: return .wind_u_component_100m
        case .wind_v_component_100m: return .wind_v_component_100m
        case .precipitation: return .precipitation
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .latent_heat_flux: return .latent_heat_flux
        case .sensible_heat_flux: return .sensible_heat_flux
        case .cape: return .cape
        case .cloud_cover: return .cloud_cover
        case .shortwave_radiation: return .shortwave_radiation
        case .lifted_index: return .lifted_index
        case .convective_inhibition: return .convective_inhibition
        case .freezing_level_height: return .freezing_level_height
        case .surface_temperature: return .surface_temperature
        case .soil_temperature_0_to_10cm: return .soil_temperature_0_to_10cm
        case .soil_temperature_10_to_40cm: return .soil_temperature_10_to_40cm
        case .soil_temperature_40_to_100cm: return .soil_temperature_40_to_100cm
        case .soil_temperature_100_to_200cm: return .soil_temperature_100_to_200cm
        case .soil_moisture_0_to_10cm: return .soil_moisture_0_to_10cm
        case .soil_moisture_10_to_40cm: return .soil_moisture_10_to_40cm
        case .soil_moisture_40_to_100cm: return .soil_moisture_40_to_100cm
        case .soil_moisture_100_to_200cm: return .soil_moisture_100_to_200cm
        case .uv_index: return .uv_index
        case .uv_index_clear_sky: return .uv_index_clear_sky
        }
    }
}

typealias NamVariable = NamSurfaceVariable
typealias HrrrVariable = SurfaceAndPressureVariable<HrrrSurfaceVariable, HrrrPressureVariable>
typealias Hrrr15MinVariable = Hrrr15MinSurfaceVariable
typealias Gefs025Variable = Gefs025SurfaceVariable
typealias Gefs05Variable = SurfaceAndPressureVariable<Gefs05SurfaceVariable, Gefs05PressureVariable>
typealias GfsGlobalVariable = VariableUnion<Gfs013Variable, Gfs025Variable>
