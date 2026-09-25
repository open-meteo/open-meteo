// See docs/ncep-rrfs/README.md for RRFS products, GRIB inputs and processing details.

import Foundation

/// GRIB attributes belong to the variable catalog of each RRFS product.
protocol NcepRrfsVariableDownloadable: GenericVariable {
    var gribInput: (parameter: String, level: String) { get }
    var gribStep: NcepRrfsGribStep { get }
    var skipHour0: Bool { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var isSolarRadiation: Bool { get }
    var isCloudHeight: Bool { get }
    var isDewpoint: Bool { get }
    var isFrozenPrecipitationPercent: Bool { get }
    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? { get }
    func gribIndexName(minute: Int) -> String?
}

enum NcepRrfsGribStep {
    case instant, accumulation, hourlyAccumulation, hourlyAverage

    func interval(minute: Int) -> (start: Int, type: String) {
        switch self {
        case .instant: return (minute, "instant")
        case .accumulation: return (0, "accum")
        case .hourlyAccumulation: return (minute - 60, "accum")
        case .hourlyAverage: return minute == 0 ? (0, "instant") : (minute - 60, "avg")
        }
    }
}

extension NcepRrfsVariableDownloadable {
    func gribIndexName(minute: Int) -> String? {
        guard minute > 0 || !skipHour0 else { return nil }
        let interval = gribStep.interval(minute: minute)
        let step: String
        if minute == 0 {
            step = "anl"
        } else {
            let hourly = interval.start % 60 == 0 && minute % 60 == 0
            let unit = hourly ? "hour" : "min"
            let divisor = hourly ? 60 : 1
            switch interval.type {
            case "accum": step = "\(interval.start / divisor)-\(minute / divisor) \(unit) acc fcst"
            case "avg": step = "\(interval.start / divisor)-\(minute / divisor) \(unit) ave fcst"
            default: step = "\(minute / divisor) \(unit) fcst"
            }
        }
        return ":\(gribInput.parameter):\(gribInput.level):\(step):"
    }

    var isCloudHeight: Bool { false }
    var isDewpoint: Bool { false }
    var isFrozenPrecipitationPercent: Bool { false }

    func convertCloudHeightToAboveGround(data: inout [Float], elevation: [Float]) {
        for i in data.indices {
            let terrain = elevation[i] == -999 ? 0 : elevation[i]
            // Preserve missing coverage and the upstream no-cloud sentinel.
            data[i] = data[i].isNaN || data[i] <= -99999 || terrain.isNaN ? .nan : max(data[i] - terrain, 0)
        }
    }

    func convertUnits(data: inout [Float]) {
        if let multiplyAdd {
            data.multiplyAdd(multiply: multiplyAdd.multiply, add: multiplyAdd.add)
        }
    }

}

/// Adds the forecast minute to the variable, like GfsDownloadVariable.
struct NcepRrfsDownloadVariable: CurlIndexedVariable, Sendable {
    let variable: any NcepRrfsVariableDownloadable
    let minute: Int

    var gribIndexName: String? { variable.gribIndexName(minute: minute) }
    // Ensemble inventories append ENS=+n after the forecast interval.
    var exactMatch: Bool { false }
    var interval: (start: Int, type: String) { variable.gribStep.interval(minute: minute) }
    var requiresSolarBackwardsConversion: Bool { variable.isSolarRadiation && interval.type == "instant" }
}

extension NcepRrfsDomain {
    func downloadVariables(forecastHour: Int, pressureFile: Bool) -> [NcepRrfsDownloadVariable] {
        let fields: [any NcepRrfsVariableDownloadable]
        if pressureFile {
            switch self {
            case .ncep_rrfs_conus, .ncep_rrfs_conus_15min, .ncep_rrfs_north_america: fields = NcepRrfsConusPressureVariable.allVariables
            case .ncep_rrfs_conus_ensemble: fields = NcepRrfsEnsemblePressureVariable.allVariables
            }
        } else {
            switch self {
            case .ncep_rrfs_conus, .ncep_rrfs_north_america: fields = NcepRrfsSurfaceVariable.allCases
            case .ncep_rrfs_conus_15min: fields = NcepRrfs15MinVariable.allCases
            case .ncep_rrfs_conus_ensemble: fields = NcepRrfsEnsembleSurfaceVariable.allCases
            }
        }
        let minutes = self == .ncep_rrfs_conus_15min
            ? Array(stride(from: forecastHour * 60 - 45, through: forecastHour * 60, by: 15)) : [forecastHour * 60]
        return minutes.flatMap { minute in
            fields.filter { minute > 0 || !$0.skipHour0 }.map { NcepRrfsDownloadVariable(variable: $0, minute: minute) }
        }
    }
}

extension NcepRrfsSurfaceVariable: NcepRrfsVariableDownloadable {
    var gribInput: (parameter: String, level: String) {
        switch self {
        case .freezing_rain: return ("FRZR", "surface")
        case .snow_depth_water_equivalent: return ("WEASD", "surface")
        case .cloud_base: return ("HGT", "cloud base")
        case .cloud_ceiling: return ("HGT", "cloud ceiling")
        case .cloud_top: return ("HGT", "cloud top")
        case .temperature_2m: return ("TMP", "2 m above ground")
        case .relative_humidity_2m: return ("RH", "2 m above ground")
        case .pressure_msl: return ("MSLET", "mean sea level")
        case .surface_pressure: return ("PRES", "surface")
        case .precipitation: return ("APCP", "surface")
        case .snowfall_water_equivalent: return ("TSNOWP", "surface")
        case .snowfall: return ("ASNOW", "surface")
        case .wind_gusts_10m: return ("GUST", "surface")
        case .radar_reflectivity: return ("REFC", "entire atmosphere (considered as a single layer)")
        case .visibility: return ("VIS", "surface")
        case .shortwave_radiation: return ("DSWRF", "surface")
        case .diffuse_radiation: return ("VDDSF", "surface")
        case .categorical_freezing_rain: return ("CFRZR", "surface")
        case .surface_temperature: return ("TMP", "surface")
        case .snow_depth: return ("SNOD", "surface")
        case .cloud_cover: return ("TCDC", "entire atmosphere (considered as a single layer)")
        case .cloud_cover_low: return ("LCDC", "low cloud layer")
        case .cloud_cover_mid: return ("MCDC", "middle cloud layer")
        case .cloud_cover_high: return ("HCDC", "high cloud layer")
        case .cape: return ("CAPE", "surface")
        case .convective_inhibition: return ("CIN", "surface")
        case .boundary_layer_height: return ("HPBL", "surface")
        case .total_column_integrated_water_vapour: return ("PWAT", "entire atmosphere (considered as a single layer)")
        case .freezing_level_height: return ("HGT", "0C isotherm")
        case .sensible_heat_flux: return ("SHTFL", "surface")
        case .latent_heat_flux: return ("LHTFL", "surface")
        case .lifted_index: return ("LFTX", "500-1000 mb")
        case .wind_speed_10m: return ("UGRD", "10 m above ground")
        case .wind_direction_10m: return ("VGRD", "10 m above ground")
        case .wind_speed_30m: return ("UGRD", "30 m above ground")
        case .wind_direction_30m: return ("VGRD", "30 m above ground")
        case .wind_speed_50m: return ("UGRD", "50 m above ground")
        case .wind_direction_50m: return ("VGRD", "50 m above ground")
        case .wind_speed_80m: return ("UGRD", "80 m above ground")
        case .wind_direction_80m: return ("VGRD", "80 m above ground")
        case .wind_speed_100m: return ("UGRD", "100 m above ground")
        case .wind_direction_100m: return ("VGRD", "100 m above ground")
        case .wind_speed_160m: return ("UGRD", "160 m above ground")
        case .wind_direction_160m: return ("VGRD", "160 m above ground")
        case .wind_speed_320m: return ("UGRD", "320 m above ground")
        case .wind_direction_320m: return ("VGRD", "320 m above ground")
        case .temperature_30m: return ("TMP", "30 m above ground")
        case .temperature_50m: return ("TMP", "50 m above ground")
        case .temperature_80m: return ("TMP", "80 m above ground")
        case .temperature_100m: return ("TMP", "100 m above ground")
        case .temperature_160m: return ("TMP", "160 m above ground")
        case .temperature_320m: return ("TMP", "320 m above ground")
        case .temperature_305m: return ("TMP", "305 m above mean sea level")
        case .temperature_457m: return ("TMP", "457 m above mean sea level")
        case .temperature_610m: return ("TMP", "610 m above mean sea level")
        case .temperature_914m: return ("TMP", "914 m above mean sea level")
        case .temperature_1524m: return ("TMP", "1524 m above mean sea level")
        case .temperature_1829m: return ("TMP", "1829 m above mean sea level")
        case .temperature_2134m: return ("TMP", "2134 m above mean sea level")
        case .temperature_2743m: return ("TMP", "2743 m above mean sea level")
        case .temperature_3658m: return ("TMP", "3658 m above mean sea level")
        case .temperature_4572m: return ("TMP", "4572 m above mean sea level")
        case .soil_temperature_0cm: return ("TSOIL", "0-0 m below ground")
        case .soil_moisture_0cm: return ("SOILW", "0-0 m below ground")
        case .soil_temperature_1cm: return ("TSOIL", "0.01-0.01 m below ground")
        case .soil_moisture_1cm: return ("SOILW", "0.01-0.01 m below ground")
        case .soil_temperature_4cm: return ("TSOIL", "0.04-0.04 m below ground")
        case .soil_moisture_4cm: return ("SOILW", "0.04-0.04 m below ground")
        case .soil_temperature_10cm: return ("TSOIL", "0.1-0.1 m below ground")
        case .soil_moisture_10cm: return ("SOILW", "0.1-0.1 m below ground")
        case .soil_temperature_30cm: return ("TSOIL", "0.3-0.3 m below ground")
        case .soil_moisture_30cm: return ("SOILW", "0.3-0.3 m below ground")
        case .soil_temperature_60cm: return ("TSOIL", "0.6-0.6 m below ground")
        case .soil_moisture_60cm: return ("SOILW", "0.6-0.6 m below ground")
        case .soil_temperature_100cm: return ("TSOIL", "1-1 m below ground")
        case .soil_moisture_100cm: return ("SOILW", "1-1 m below ground")
        case .soil_temperature_160cm: return ("TSOIL", "1.6-1.6 m below ground")
        case .soil_moisture_160cm: return ("SOILW", "1.6-1.6 m below ground")
        case .soil_temperature_300cm: return ("TSOIL", "3-3 m below ground")
        case .soil_moisture_300cm: return ("SOILW", "3-3 m below ground")
        }
    }

    var gribStep: NcepRrfsGribStep {
        switch self {
        case .freezing_rain: return .accumulation
        case .precipitation:
            return .hourlyAccumulation
        case .snowfall_water_equivalent,
             .snowfall:
            return .accumulation
        case .shortwave_radiation,
             .sensible_heat_flux,
             .latent_heat_flux:
            return .hourlyAverage
        default:
            return .instant
        }
    }

    var skipHour0: Bool {
        switch self {
        case .freezing_rain: return true
        case .precipitation, .snowfall_water_equivalent, .snowfall, .sensible_heat_flux, .latent_heat_flux: return true
        default: return false
        }
    }
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m,
             .surface_temperature,
             .temperature_30m,
             .temperature_50m,
             .temperature_80m,
             .temperature_100m,
             .temperature_160m,
             .temperature_320m,
             .temperature_305m,
             .temperature_457m,
             .temperature_610m,
             .temperature_914m,
             .temperature_1524m,
             .temperature_1829m,
             .temperature_2134m,
             .temperature_2743m,
             .temperature_3658m,
             .temperature_4572m,
             .soil_temperature_0cm,
             .soil_temperature_1cm,
             .soil_temperature_4cm,
             .soil_temperature_10cm,
             .soil_temperature_30cm,
             .soil_temperature_60cm,
             .soil_temperature_100cm,
             .soil_temperature_160cm,
             .soil_temperature_300cm: return (1, -273.15)
        case .pressure_msl, .surface_pressure: return (0.01, 0)
        case .snowfall: return (100, 0)
        case .convective_inhibition: return (-1, 0)
        default: return nil
        }
    }

    var isCloudHeight: Bool {
        switch self {
        case .cloud_base, .cloud_ceiling, .cloud_top: return true
        default: return false
        }
    }

    var isSolarRadiation: Bool {
        switch self {
        case .shortwave_radiation, .diffuse_radiation: return true
        default: return false
        }
    }

    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? {
        switch self {
        case .wind_speed_10m, .wind_direction_10m: return (.surface(.wind_speed_10m), .surface(.wind_direction_10m))
        case .wind_speed_30m, .wind_direction_30m: return (.surface(.wind_speed_30m), .surface(.wind_direction_30m))
        case .wind_speed_50m, .wind_direction_50m: return (.surface(.wind_speed_50m), .surface(.wind_direction_50m))
        case .wind_speed_80m, .wind_direction_80m: return (.surface(.wind_speed_80m), .surface(.wind_direction_80m))
        case .wind_speed_100m, .wind_direction_100m: return (.surface(.wind_speed_100m), .surface(.wind_direction_100m))
        case .wind_speed_160m, .wind_direction_160m: return (.surface(.wind_speed_160m), .surface(.wind_direction_160m))
        case .wind_speed_320m, .wind_direction_320m: return (.surface(.wind_speed_320m), .surface(.wind_direction_320m))
        default: return nil
        }
    }

}

extension NcepRrfs15MinVariable: NcepRrfsVariableDownloadable {
    var gribInput: (parameter: String, level: String) {
        switch self {
        case .freezing_rain: return ("FRZR", "surface")
        case .cloud_base: return ("HGT", "cloud base")
        case .cloud_ceiling: return ("HGT", "cloud ceiling")
        case .cloud_top: return ("HGT", "cloud top")
        case .temperature_2m: return ("TMP", "2 m above ground")
        case .relative_humidity_2m: return ("DPT", "2 m above ground")
        case .pressure_msl: return ("MSLET", "mean sea level")
        case .surface_pressure: return ("PRES", "surface")
        case .precipitation: return ("APCP", "surface")
        case .snowfall_water_equivalent: return ("TSNOWP", "surface")
        case .snowfall: return ("ASNOW", "surface")
        case .wind_gusts_10m: return ("GUST", "surface")
        case .radar_reflectivity: return ("REFC", "entire atmosphere (considered as a single layer)")
        case .visibility: return ("VIS", "surface")
        case .shortwave_radiation: return ("DSWRF", "surface")
        case .diffuse_radiation: return ("VDDSF", "surface")
        case .categorical_freezing_rain: return ("CFRZR", "surface")
        case .wind_speed_10m: return ("UGRD", "10 m above ground")
        case .wind_direction_10m: return ("VGRD", "10 m above ground")
        case .wind_speed_80m: return ("UGRD", "80 m above ground")
        case .wind_direction_80m: return ("VGRD", "80 m above ground")
        }
    }

    var gribStep: NcepRrfsGribStep {
        switch self {
        case .freezing_rain: return .accumulation
        case .precipitation,
             .snowfall_water_equivalent,
             .snowfall:
            return .accumulation
        default:
            return .instant
        }
    }

    var skipHour0: Bool {
        switch self {
        case .freezing_rain: return true
        case .precipitation, .snowfall_water_equivalent, .snowfall: return true
        default: return false
        }
    }
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m,
             .relative_humidity_2m: return (1, -273.15)
        case .pressure_msl, .surface_pressure: return (0.01, 0)
        case .snowfall: return (100, 0)
        default: return nil
        }
    }

    var isCloudHeight: Bool {
        switch self {
        case .cloud_base, .cloud_ceiling, .cloud_top: return true
        default: return false
        }
    }

    var isSolarRadiation: Bool {
        switch self {
        case .shortwave_radiation, .diffuse_radiation: return true
        default: return false
        }
    }

    var isDewpoint: Bool { self == .relative_humidity_2m }

    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? {
        switch self {
        case .wind_speed_10m, .wind_direction_10m: return (.surface(.wind_speed_10m), .surface(.wind_direction_10m))
        case .wind_speed_80m, .wind_direction_80m: return (.surface(.wind_speed_80m), .surface(.wind_direction_80m))
        default: return nil
        }
    }

}

extension NcepRrfsEnsembleSurfaceVariable: NcepRrfsVariableDownloadable {
    var gribInput: (parameter: String, level: String) {
        switch self {
        case .freezing_rain: return ("FRZR", "surface")
        case .temperature_2m: return ("TMP", "2 m above ground")
        case .relative_humidity_2m: return ("RH", "2 m above ground")
        case .pressure_msl: return ("MSLET", "mean sea level")
        case .surface_pressure: return ("PRES", "surface")
        case .precipitation: return ("APCP", "surface")
        case .snowfall_water_equivalent: return ("CPOFP", "surface")
        case .snowfall: return ("ASNOW", "surface")
        case .wind_gusts_10m: return ("GUST", "surface")
        case .radar_reflectivity: return ("REFC", "entire atmosphere (considered as a single layer)")
        case .visibility: return ("VIS", "surface")
        case .shortwave_radiation: return ("DSWRF", "surface")
        case .categorical_freezing_rain: return ("CFRZR", "surface")
        case .cloud_cover: return ("TCDC", "entire atmosphere (considered as a single layer)")
        case .cloud_cover_low: return ("LCDC", "low cloud layer")
        case .cloud_cover_mid: return ("MCDC", "middle cloud layer")
        case .cloud_cover_high: return ("HCDC", "high cloud layer")
        case .cape: return ("CAPE", "surface")
        case .convective_inhibition: return ("CIN", "surface")
        case .total_column_integrated_water_vapour: return ("PWAT", "entire atmosphere (considered as a single layer)")
        case .wind_speed_10m: return ("UGRD", "10 m above ground")
        case .wind_direction_10m: return ("VGRD", "10 m above ground")
        case .wind_speed_80m: return ("UGRD", "80 m above ground")
        case .wind_direction_80m: return ("VGRD", "80 m above ground")
        case .wind_speed_160m: return ("UGRD", "160 m above ground")
        case .wind_direction_160m: return ("VGRD", "160 m above ground")
        case .wind_speed_320m: return ("UGRD", "320 m above ground")
        case .wind_direction_320m: return ("VGRD", "320 m above ground")
        }
    }

    var gribStep: NcepRrfsGribStep {
        switch self {
        case .freezing_rain: return .accumulation
        case .precipitation:
            return .hourlyAccumulation
        case .snowfall:
            return .accumulation
        case .shortwave_radiation:
            return .hourlyAverage
        default:
            return .instant
        }
    }

    var skipHour0: Bool {
        switch self {
        case .freezing_rain: return true
        case .precipitation, .snowfall_water_equivalent, .snowfall: return true
        default: return false
        }
    }
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m: return (1, -273.15)
        case .pressure_msl, .surface_pressure: return (0.01, 0)
        case .snowfall: return (100, 0)
        case .convective_inhibition: return (-1, 0)
        default: return nil
        }
    }

    var isSolarRadiation: Bool {
        switch self {
        case .shortwave_radiation: return true
        default: return false
        }
    }

    var isFrozenPrecipitationPercent: Bool { self == .snowfall_water_equivalent }

    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? {
        switch self {
        case .wind_speed_10m, .wind_direction_10m: return (.surface(.wind_speed_10m), .surface(.wind_direction_10m))
        case .wind_speed_80m, .wind_direction_80m: return (.surface(.wind_speed_80m), .surface(.wind_direction_80m))
        case .wind_speed_160m, .wind_direction_160m: return (.surface(.wind_speed_160m), .surface(.wind_direction_160m))
        case .wind_speed_320m, .wind_direction_320m: return (.surface(.wind_speed_320m), .surface(.wind_direction_320m))
        default: return nil
        }
    }

}

extension NcepRrfsPressureVariable: NcepRrfsVariableDownloadable {
    var gribInput: (parameter: String, level: String) {
        let parameter: String
        switch variable {
        case .temperature: parameter = "TMP"
        case .relative_humidity: parameter = "RH"
        case .geopotential_height: parameter = "HGT"
        case .wind_speed: parameter = "UGRD"
        case .wind_direction: parameter = "VGRD"
        case .vertical_velocity: parameter = "DZDT"
        }
        return (parameter, "\(level) mb")
    }
    var gribStep: NcepRrfsGribStep { .instant }
    var skipHour0: Bool { false }
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature: return (1, -273.15)
        default: return nil
        }
    }
    var isSolarRadiation: Bool { false }
    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? {
        switch variable {
        case .wind_speed, .wind_direction:
            return (.pressure(.init(variable: .wind_speed, level: level)), .pressure(.init(variable: .wind_direction, level: level)))
        default: return nil
        }
    }

}

extension SurfaceAndPressureVariable: NcepRrfsVariableDownloadable where Surface: NcepRrfsVariableDownloadable, Pressure: NcepRrfsVariableDownloadable {
    var gribInput: (parameter: String, level: String) {
        switch self {
        case .surface(let variable): return variable.gribInput
        case .pressure(let variable): return variable.gribInput
        }
    }
    var gribStep: NcepRrfsGribStep {
        switch self {
        case .surface(let variable): return variable.gribStep
        case .pressure(let variable): return variable.gribStep
        }
    }
    var skipHour0: Bool {
        switch self {
        case .surface(let variable): return variable.skipHour0
        case .pressure(let variable): return variable.skipHour0
        }
    }
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .surface(let variable): return variable.multiplyAdd
        case .pressure(let variable): return variable.multiplyAdd
        }
    }

    var isCloudHeight: Bool {
        switch self {
        case .surface(let variable): return variable.isCloudHeight
        case .pressure(let variable): return variable.isCloudHeight
        }
    }

    var isSolarRadiation: Bool {
        switch self {
        case .surface(let variable): return variable.isSolarRadiation
        case .pressure(let variable): return variable.isSolarRadiation
        }
    }

    var isDewpoint: Bool {
        switch self {
        case .surface(let variable): return variable.isDewpoint
        case .pressure(let variable): return variable.isDewpoint
        }
    }

    var isFrozenPrecipitationPercent: Bool {
        switch self {
        case .surface(let variable): return variable.isFrozenPrecipitationPercent
        case .pressure(let variable): return variable.isFrozenPrecipitationPercent
        }
    }

    var windComponents: (speed: NcepRrfsVariable, direction: NcepRrfsVariable)? {
        switch self {
        case .surface(let variable): return variable.windComponents
        case .pressure(let variable): return variable.windComponents
        }
    }

}
