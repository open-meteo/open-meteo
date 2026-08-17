enum GfsDownloadField: Hashable, Sendable {
    case surface(GfsSurfaceField)
    case pressure(GfsPressureField)
    case wave
}

/// A variable present in the upstream inventory of one GFS-family product.
protocol GfsVariableDownloadable: GenericVariable, Hashable {
    var downloadField: GfsDownloadField { get }
    func gribIndexName(timestep: Int?) -> String?
    var skipHour0: Bool { get }
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)?
}

protocol GfsSurfaceVariableDownloadable: GfsVariableDownloadable, GfsSurfaceVariableMetadataBacked {}

extension GfsSurfaceVariableDownloadable {
    var downloadField: GfsDownloadField { .surface(field) }

    func sharedMultiplyAdd() -> (multiply: Float, add: Float)? {
        switch field {
        case .temperature_2m, .temperature_80m, .temperature_100m,
             .surface_temperature, .soil_temperature_0_to_10cm,
             .soil_temperature_10_to_40cm, .soil_temperature_40_to_100cm,
             .soil_temperature_100_to_200cm:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .uv_index, .uv_index_clear_sky:
            return (18.9 * 0.025, 0)
        case .mass_density_8m:
            return (1e9, 0)
        case .convective_inhibition:
            return (-1, 0)
        default:
            return nil
        }
    }

    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        sharedMultiplyAdd()
    }
}

enum Gfs013DownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
    case temperature_2m, surface_temperature
    case cloud_cover, cloud_cover_low, cloud_cover_mid, cloud_cover_high
    case relative_humidity_2m, pressure_msl, precipitation
    case wind_v_component_10m, wind_u_component_10m
    case soil_temperature_0_to_10cm, soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm, soil_temperature_100_to_200cm
    case soil_moisture_0_to_10cm, soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm, soil_moisture_100_to_200cm
    case snow_depth, sensible_heat_flux, latent_heat_flux, showers
    case frozen_precipitation_percent, shortwave_radiation, diffuse_radiation
    case uv_index, uv_index_clear_sky
    case boundary_layer_height, total_column_integrated_water_vapour

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
        case .showers: return .showers
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
        case .shortwave_radiation: return .shortwave_radiation
        case .diffuse_radiation: return .diffuse_radiation
        case .uv_index: return .uv_index
        case .uv_index_clear_sky: return .uv_index_clear_sky
        case .boundary_layer_height: return .boundary_layer_height
        case .total_column_integrated_water_vapour: return .total_column_integrated_water_vapour
        }
    }

    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .temperature_2m: return ":TMP:2 m above ground:"
        case .surface_temperature: return ":TMP:surface:"
        case .cloud_cover: return ":TCDC:entire atmosphere:"
        case .cloud_cover_low: return ":LCDC:low cloud layer:"
        case .cloud_cover_mid: return ":MCDC:middle cloud layer:"
        case .cloud_cover_high: return ":HCDC:high cloud layer:"
        case .relative_humidity_2m: return ":SPFH:2 m above ground:"
        case .pressure_msl: return ":PRES:surface:"
        case .precipitation: return ":PRATE:surface:"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:"
        case .soil_temperature_0_to_10cm: return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm: return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm: return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm: return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm: return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm: return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm: return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm: return ":SOILW:1-2 m below ground:"
        case .snow_depth: return ":SNOD:surface:"
        case .sensible_heat_flux: return ":SHTFL:surface:"
        case .latent_heat_flux: return ":LHTFL:surface:"
        case .showers: return ":CPRAT:surface:"
        case .frozen_precipitation_percent: return ":CPOFP:surface"
        case .shortwave_radiation: return ":DSWRF:surface:"
        case .diffuse_radiation: return ":VDDSF:surface:"
        case .uv_index: return ":DUVB:surface:"
        case .uv_index_clear_sky: return ":CDUVB:surface:"
        case .boundary_layer_height: return ":HPBL:surface:"
        case .total_column_integrated_water_vapour: return ":PWAT:entire atmosphere (considered as a single layer):"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .sensible_heat_flux, .latent_heat_flux, .showers,
             .shortwave_radiation, .diffuse_radiation, .uv_index, .uv_index_clear_sky,
             .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return true
        default:
            return false
        }
    }

    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .precipitation, .showers: return (Float(dtSeconds), 0)
        default: return sharedMultiplyAdd()
        }
    }
}

extension Gfs025SurfaceVariable: GfsSurfaceVariableDownloadable {
    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .pressure_msl: return ":MSLET:mean sea level:"
        case .categorical_freezing_rain: return ":CFRZR:"
        case .temperature_80m: return ":TMP:80 m above ground:"
        case .temperature_100m: return ":TMP:100 m above ground:"
        case .wind_v_component_80m: return ":VGRD:80 m above ground:"
        case .wind_u_component_80m: return ":UGRD:80 m above ground:"
        case .wind_v_component_100m: return ":VGRD:100 m above ground:"
        case .wind_u_component_100m: return ":UGRD:100 m above ground:"
        case .wind_gusts_10m: return ":GUST:surface:"
        case .freezing_level_height: return ":HGT:0C isotherm:"
        case .cape: return ":CAPE:surface:"
        case .lifted_index: return ":LFTX:surface:"
        case .convective_inhibition: return ":CIN:surface:"
        case .visibility: return ":VIS:surface:"
        }
    }

    var skipHour0: Bool { self == .categorical_freezing_rain }
}

enum NamDownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
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
    case shortwave_radiation, frozen_precipitation_percent
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
        case .shortwave_radiation: return .shortwave_radiation
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
        case .boundary_layer_height: return .boundary_layer_height
        case .total_column_integrated_water_vapour: return .total_column_integrated_water_vapour
        case .visibility: return .visibility
        case .wind_gusts_10m: return .wind_gusts_10m
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .convective_inhibition: return .convective_inhibition
        case .cape: return .cape
        }
    }

    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .temperature_2m: return ":TMP:2 m above ground:"
        case .surface_temperature: return ":TMP:surface:"
        case .cloud_cover: return ":TCDC:entire atmosphere (considered as a single layer):"
        case .cloud_cover_low: return ":LCDC:low cloud layer:"
        case .cloud_cover_mid: return ":MCDC:middle cloud layer:"
        case .cloud_cover_high: return ":HCDC:high cloud layer:"
        case .relative_humidity_2m: return ":RH:2 m above ground:"
        case .pressure_msl: return ":PRMSL:mean sea level:"
        case .precipitation: return ":APCP:surface:"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:"
        case .wind_v_component_80m: return ":VGRD:80 m above ground:"
        case .wind_u_component_80m: return ":UGRD:80 m above ground:"
        case .soil_temperature_0_to_10cm: return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm: return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm: return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm: return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm: return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm: return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm: return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm: return ":SOILW:1-2 m below ground:"
        case .snow_depth: return ":SNOD:surface:"
        case .sensible_heat_flux: return ":SHTFL:surface:"
        case .latent_heat_flux: return ":LHTFL:surface:"
        case .shortwave_radiation: return ":DSWRF:surface:"
        case .frozen_precipitation_percent: return ":CPOFP:surface"
        case .boundary_layer_height: return ":HPBL:surface:"
        case .total_column_integrated_water_vapour: return ":PWAT:entire atmosphere (considered as a single layer):"
        case .visibility: return ":VIS:surface:"
        case .wind_gusts_10m: return ":GUST:surface:"
        case .categorical_freezing_rain: return ":CFRZR:surface:"
        case .convective_inhibition: return ":CIN:surface:"
        case .cape: return ":CAPE:surface:"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .categorical_freezing_rain, .sensible_heat_flux,
             .latent_heat_flux, .shortwave_radiation:
            return true
        default:
            return false
        }
    }
}

enum HrrrDownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
    case pressure_msl, lifted_index, temperature_2m
    case cloud_cover, cloud_cover_low, cloud_cover_mid, cloud_cover_high
    case relative_humidity_2m, precipitation
    case wind_v_component_10m, wind_u_component_10m
    case wind_v_component_80m, wind_u_component_80m
    case surface_temperature, snow_depth
    case sensible_heat_flux, latent_heat_flux, convective_inhibition
    case frozen_precipitation_percent, categorical_freezing_rain
    case wind_gusts_10m, freezing_level_height
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
        case .convective_inhibition: return .convective_inhibition
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
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

    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .pressure_msl: return ":MSLMA:mean sea level:"
        case .lifted_index: return ":LFTX:500-1000 mb:"
        case .temperature_2m: return ":TMP:2 m above ground:"
        case .cloud_cover: return ":TCDC:entire atmosphere:"
        case .cloud_cover_low: return ":LCDC:low cloud layer:"
        case .cloud_cover_mid: return ":MCDC:middle cloud layer:"
        case .cloud_cover_high: return ":HCDC:high cloud layer:"
        case .relative_humidity_2m: return ":RH:2 m above ground:"
        case .precipitation: return ":PRATE:surface:"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:"
        case .wind_v_component_80m: return ":VGRD:80 m above ground:"
        case .wind_u_component_80m: return ":UGRD:80 m above ground:"
        case .surface_temperature: return ":TMP:surface:"
        case .snow_depth: return ":SNOD:surface:"
        case .sensible_heat_flux: return ":SHTFL:surface:"
        case .latent_heat_flux: return ":LHTFL:surface:"
        case .convective_inhibition: return ":CIN:surface:"
        case .frozen_precipitation_percent: return ":CPOFP:surface"
        case .categorical_freezing_rain: return ":CFRZR:surface:"
        case .wind_gusts_10m: return ":GUST:surface:"
        case .freezing_level_height: return ":HGT:0C isotherm:"
        case .shortwave_radiation: return ":DSWRF:surface:"
        case .diffuse_radiation: return ":VDDSF:surface:"
        case .cape: return ":CAPE:surface:"
        case .visibility: return ":VIS:surface:"
        case .boundary_layer_height: return ":HPBL:surface:"
        case .total_column_integrated_water_vapour: return ":PWAT:entire atmosphere (considered as a single layer):"
        case .mass_density_8m: return ":MASSDEN:8 m above ground:"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .categorical_freezing_rain, .sensible_heat_flux,
             .latent_heat_flux, .shortwave_radiation, .diffuse_radiation:
            return true
        default:
            return false
        }
    }

    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        field == .precipitation ? (Float(dtSeconds), 0) : sharedMultiplyAdd()
    }
}

enum Hrrr15MinDownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
    case temperature_2m, precipitation, frozen_precipitation_percent
    case categorical_freezing_rain, wind_gusts_10m
    case wind_v_component_10m, wind_u_component_10m
    case wind_v_component_80m, wind_u_component_80m
    case shortwave_radiation, diffuse_radiation, visibility

    var field: GfsSurfaceField {
        switch self {
        case .temperature_2m: return .temperature_2m
        case .precipitation: return .precipitation
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .wind_gusts_10m: return .wind_gusts_10m
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .shortwave_radiation: return .shortwave_radiation
        case .diffuse_radiation: return .diffuse_radiation
        case .visibility: return .visibility
        }
    }

    func gribIndexName(timestep: Int?) -> String? {
        guard let timestep else { return nil }
        let average = timestep == 0 ? "anl" : "\(timestep - 15)-\(timestep) min ave fcst"
        let forecast = timestep == 0 ? "anl" : "\(timestep) min fcst"
        switch self {
        case .temperature_2m: return ":TMP:2 m above ground:\(forecast):"
        case .precipitation: return ":PRATE:surface:\(forecast):"
        case .frozen_precipitation_percent: return ":CPOFP:surface:\(forecast):"
        case .categorical_freezing_rain: return ":CFRZR:surface:\(forecast):"
        case .wind_gusts_10m: return ":GUST:surface:\(forecast):"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:\(forecast):"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:\(forecast):"
        case .wind_v_component_80m: return ":VGRD:80 m above ground:\(forecast):"
        case .wind_u_component_80m: return ":UGRD:80 m above ground:\(forecast):"
        case .shortwave_radiation: return ":DSWRF:surface:\(average):"
        case .diffuse_radiation: return ":VDDSF:surface:\(forecast):"
        case .visibility: return ":VIS:surface:\(forecast):"
        }
    }

    var skipHour0: Bool {
        self == .shortwave_radiation || self == .diffuse_radiation
    }

    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        field == .precipitation ? (Float(dtSeconds), 0) : sharedMultiplyAdd()
    }
}

enum Gefs025DownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
    case visibility, wind_gusts_10m, pressure_msl
    case soil_temperature_0_to_10cm, soil_moisture_0_to_10cm
    case snow_depth, temperature_2m, relative_humidity_2m
    case wind_u_component_10m, wind_v_component_10m
    case frozen_precipitation_percent, precipitation, categorical_freezing_rain
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
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
        case .precipitation: return .precipitation
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .latent_heat_flux: return .latent_heat_flux
        case .sensible_heat_flux: return .sensible_heat_flux
        case .convective_inhibition: return .convective_inhibition
        case .cape: return .cape
        case .cloud_cover: return .cloud_cover
        case .shortwave_radiation: return .shortwave_radiation
        }
    }

    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .visibility: return ":VIS:surface:"
        case .wind_gusts_10m: return ":GUST:surface:"
        case .pressure_msl: return ":MSLET:mean sea level:"
        case .soil_temperature_0_to_10cm: return ":TSOIL:0-0.1 m below ground:"
        case .soil_moisture_0_to_10cm: return ":SOILW:0-0.1 m below ground:"
        case .snow_depth: return ":SNOD:surface:"
        case .temperature_2m: return ":TMP:2 m above ground:"
        case .relative_humidity_2m: return ":RH:2 m above ground:"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:"
        case .frozen_precipitation_percent: return ":CPOFP:surface:"
        case .precipitation: return ":APCP:surface:"
        case .categorical_freezing_rain: return ":CFRZR:surface:"
        case .latent_heat_flux: return ":LHTFL:surface:"
        case .sensible_heat_flux: return ":SHTFL:surface:"
        case .convective_inhibition: return ":CIN:surface:"
        case .cape: return ":CAPE:surface:"
        case .cloud_cover: return ":TCDC:entire atmosphere:"
        case .shortwave_radiation: return ":DSWRF:surface:"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .categorical_freezing_rain, .latent_heat_flux,
             .sensible_heat_flux, .cloud_cover, .shortwave_radiation:
            return true
        default:
            return false
        }
    }
}

enum Gefs05DownloadSurfaceVariable: String, CaseIterable, GfsSurfaceVariableDownloadable {
    case visibility, wind_gusts_10m, pressure_msl, snow_depth
    case temperature_2m, temperature_80m, temperature_100m
    case relative_humidity_2m
    case wind_u_component_10m, wind_v_component_10m
    case wind_u_component_80m, wind_v_component_80m
    case wind_u_component_100m, wind_v_component_100m
    case frozen_precipitation_percent, precipitation, categorical_freezing_rain
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
        case .frozen_precipitation_percent: return .frozen_precipitation_percent
        case .precipitation: return .precipitation
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

    func gribIndexName(timestep: Int?) -> String? {
        switch self {
        case .visibility: return ":VIS:surface:"
        case .wind_gusts_10m: return ":GUST:surface:"
        case .pressure_msl: return ":MSLET:mean sea level:"
        case .snow_depth: return ":SNOD:surface:"
        case .temperature_2m: return ":TMP:2 m above ground:"
        case .temperature_80m: return ":TMP:80 m above ground:"
        case .temperature_100m: return ":TMP:100 m above ground:"
        case .relative_humidity_2m: return ":RH:2 m above ground:"
        case .wind_u_component_10m: return ":UGRD:10 m above ground:"
        case .wind_v_component_10m: return ":VGRD:10 m above ground:"
        case .wind_u_component_80m: return ":UGRD:80 m above ground:"
        case .wind_v_component_80m: return ":VGRD:80 m above ground:"
        case .wind_u_component_100m: return ":UGRD:100 m above ground:"
        case .wind_v_component_100m: return ":VGRD:100 m above ground:"
        case .frozen_precipitation_percent: return ":CPOFP:surface:"
        case .precipitation: return ":APCP:surface:"
        case .categorical_freezing_rain: return ":CFRZR:surface:"
        case .latent_heat_flux: return ":LHTFL:surface:"
        case .sensible_heat_flux: return ":SHTFL:surface:"
        case .cape: return ":CAPE:surface:"
        case .cloud_cover: return ":TCDC:entire atmosphere:"
        case .shortwave_radiation: return ":DSWRF:surface:"
        case .lifted_index: return ":LFTX:surface:"
        case .convective_inhibition: return ":CIN:surface:"
        case .freezing_level_height: return ":HGT:0C isotherm:"
        case .surface_temperature: return ":TMP:surface:"
        case .soil_temperature_0_to_10cm: return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm: return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm: return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm: return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm: return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm: return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm: return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm: return ":SOILW:1-2 m below ground:"
        case .uv_index: return ":DUVB:surface:"
        case .uv_index_clear_sky: return ":CDUVB:surface:"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .categorical_freezing_rain, .latent_heat_flux,
             .sensible_heat_flux, .cloud_cover, .shortwave_radiation,
             .uv_index, .uv_index_clear_sky:
            return true
        default:
            return false
        }
    }
}

private func pressureGribIndexName(_ field: GfsPressureField, verticalVelocityName: String) -> String {
    switch field.variable {
    case .temperature: return ":TMP:\(field.level) mb:"
    case .wind_u_component: return ":UGRD:\(field.level) mb:"
    case .wind_v_component: return ":VGRD:\(field.level) mb:"
    case .geopotential_height: return ":HGT:\(field.level) mb:"
    case .cloud_cover: return ":TCDC:\(field.level) mb:"
    case .relative_humidity: return ":RH:\(field.level) mb:"
    case .vertical_velocity: return ":\(verticalVelocityName):\(field.level) mb:"
    }
}

extension Gfs025PressureVariable: GfsVariableDownloadable {
    var downloadField: GfsDownloadField { .pressure(.init(variable: variable, level: level)) }
    func gribIndexName(timestep: Int?) -> String? { pressureGribIndexName(.init(variable: variable, level: level), verticalVelocityName: "DZDT") }
    var skipHour0: Bool { false }
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? { variable == .temperature ? (1, -273.15) : nil }
}

extension HrrrPressureVariable: GfsVariableDownloadable {
    var downloadField: GfsDownloadField { .pressure(.init(variable: variable, level: level)) }
    func gribIndexName(timestep: Int?) -> String? { pressureGribIndexName(.init(variable: variable, level: level), verticalVelocityName: "VVEL") }
    var skipHour0: Bool { false }
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? { variable == .temperature ? (1, -273.15) : nil }
}

extension Gefs05PressureVariable: GfsVariableDownloadable {
    var downloadField: GfsDownloadField { .pressure(.init(variable: variable, level: level)) }
    func gribIndexName(timestep: Int?) -> String? { pressureGribIndexName(.init(variable: variable, level: level), verticalVelocityName: "VVEL") }
    var skipHour0: Bool { false }
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? { variable == .temperature ? (1, -273.15) : nil }
}
