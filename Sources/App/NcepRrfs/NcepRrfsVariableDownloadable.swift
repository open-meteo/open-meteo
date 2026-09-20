import Foundation

/// A required input field and its exact forecast interval. The shared downloader
/// fetches the inventory and selects these fields through CurlIndexedVariable.
struct NcepRrfsIndexedVariable: CurlIndexedVariable, Sendable {
    let record: NcepRrfsRecord
    let gribIndexName: String?
    private let level: String
    private let fallbackToInstant: Bool

    var gribIndexFallback: Self? {
        if record.parameter == "TSNOWP" {
            return Self(variable: "frozen_precipitation_percent", parameter: "CPOFP", level: "surface",
                        startMinute: record.endMinute, endMinute: record.endMinute, stepType: "instant")
        }
        guard fallbackToInstant else { return nil }
        return Self(variable: record.variable, parameter: record.parameter, level: level,
                    startMinute: record.endMinute, endMinute: record.endMinute, stepType: "instant")
    }
    // Ensemble inventories append ENS=+n after the forecast interval.
    var exactMatch: Bool { false }

    init(variable: String, parameter: String, level: String, startMinute: Int, endMinute: Int, stepType: String, fallbackToInstant: Bool = false) {
        self.level = level
        self.fallbackToInstant = fallbackToInstant
        record = NcepRrfsRecord(variable: variable, parameter: parameter, startMinute: startMinute, endMinute: endMinute, stepType: stepType)
        let step: String
        if endMinute == 0 {
            step = "anl"
        } else {
            let hourly = startMinute % 60 == 0 && endMinute % 60 == 0
            let unit = hourly ? "hour" : "min"
            let divisor = hourly ? 60 : 1
            switch stepType {
            case "accum": step = "\(startMinute / divisor)-\(endMinute / divisor) \(unit) acc fcst"
            case "avg": step = "\(startMinute / divisor)-\(endMinute / divisor) \(unit) ave fcst"
            default: step = "\(endMinute / divisor) \(unit) fcst"
            }
        }
        gribIndexName = ":\(parameter):\(level):\(step):"
    }

    static func variables(domain: NcepRrfsDomain, forecastHour: Int, pressureFile: Bool) -> [Self] {
        if pressureFile {
            let fields = domain == .ncep_rrfs_conus_ensemble
                ? NcepRrfsEnsemblePressureVariable.allVariables.map { NcepRrfsPressureField(variable: $0.variable, level: $0.level) }
                : NcepRrfsConusPressureVariable.allVariables.map { NcepRrfsPressureField(variable: $0.variable, level: $0.level) }
            return fields.flatMap { field -> [Self] in
                let parameters: [String]
                switch field.variable {
                case .temperature: parameters = ["TMP"]
                case .relative_humidity: parameters = ["RH"]
                case .geopotential_height: parameters = ["HGT"]
                case .wind_speed: parameters = ["UGRD", "VGRD"]
                case .wind_direction: return []
                case .vertical_velocity: parameters = ["DZDT"]
                }
                return parameters.map { Self(variable: field.rawValue, parameter: $0, level: "\(field.level) mb",
                                             startMinute: forecastHour * 60, endMinute: forecastHour * 60, stepType: "instant") }
            }
        }
        let fields: [NcepRrfsSurfaceVariable]
        switch domain {
        case .ncep_rrfs_conus: fields = NcepRrfsSurfaceVariable.allCases
        case .ncep_rrfs_conus_15min: fields = NcepRrfs15MinVariable.allCases.compactMap { NcepRrfsSurfaceVariable(rawValue: $0.rawValue) }
        case .ncep_rrfs_conus_ensemble: fields = NcepRrfsEnsembleSurfaceVariable.allCases.compactMap { NcepRrfsSurfaceVariable(rawValue: $0.rawValue) }
        }
        let subhourly = domain == .ncep_rrfs_conus_15min
        let minutes = subhourly ? Array(stride(from: forecastHour * 60 - 45, through: forecastHour * 60, by: 15)) : [forecastHour * 60]
        return minutes.flatMap { minute in
            var inputs = fields.flatMap { field -> [Self] in
                if subhourly && field == .relative_humidity_2m { return [] }
                guard let (parameter, level) = field.gribInput else { return [] }
                let stepType: String
                let start: Int
                switch field {
                case .precipitation:
                    stepType = "accum"; start = subhourly ? 0 : minute - 60
                case .snowfall, .snowfall_water_equivalent:
                    stepType = "accum"; start = 0
                case .shortwave_radiation, .diffuse_radiation:
                    stepType = minute >= 60 ? "avg" : "instant"
                    start = minute >= 60 ? minute - 60 : minute
                case .sensible_heat_flux, .latent_heat_flux:
                    stepType = "avg"; start = minute - 60
                default:
                    stepType = "instant"; start = minute
                }
                guard minute > 0 || stepType == "instant" else { return [] }
                return (parameter == "UGRD" ? ["UGRD", "VGRD"] : [parameter]).map {
                    Self(variable: field.rawValue, parameter: $0, level: level, startMinute: start, endMinute: minute, stepType: stepType,
                         fallbackToInstant: stepType == "avg" && (field == .shortwave_radiation || field == .diffuse_radiation))
                }
            }
            if subhourly {
                inputs.append(Self(variable: "dewpoint_2m", parameter: "DPT", level: "2 m above ground", startMinute: minute, endMinute: minute, stepType: "instant"))
            }
            return inputs
        }
    }
}

private extension NcepRrfsSurfaceVariable {
    var gribInput: (parameter: String, level: String)? {
        switch self {
        case .temperature_2m: return ("TMP", "2 m above ground")
        case .relative_humidity_2m: return ("RH", "2 m above ground")
        case .pressure_msl: return ("MSLET", "mean sea level")
        case .surface_pressure: return ("PRES", "surface")
        case .precipitation: return ("APCP", "surface")
        case .snowfall: return ("ASNOW", "surface")
        case .snowfall_water_equivalent: return ("TSNOWP", "surface")
        case .wind_gusts_10m: return ("GUST", "surface")
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
        case .wind_speed_30m: return ("UGRD", "30 m above ground")
        case .wind_speed_50m: return ("UGRD", "50 m above ground")
        case .wind_speed_80m: return ("UGRD", "80 m above ground")
        case .wind_speed_100m: return ("UGRD", "100 m above ground")
        case .wind_speed_160m: return ("UGRD", "160 m above ground")
        case .wind_speed_320m: return ("UGRD", "320 m above ground")
        case .wind_speed_305m: return ("UGRD", "305 m above mean sea level")
        case .wind_speed_457m: return ("UGRD", "457 m above mean sea level")
        case .wind_speed_610m: return ("UGRD", "610 m above mean sea level")
        case .wind_speed_914m: return ("UGRD", "914 m above mean sea level")
        case .wind_speed_1524m: return ("UGRD", "1524 m above mean sea level")
        case .wind_speed_1829m: return ("UGRD", "1829 m above mean sea level")
        case .wind_speed_2134m: return ("UGRD", "2134 m above mean sea level")
        case .wind_speed_2743m: return ("UGRD", "2743 m above mean sea level")
        case .wind_speed_3658m: return ("UGRD", "3658 m above mean sea level")
        case .wind_speed_4572m: return ("UGRD", "4572 m above mean sea level")
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
        case .wind_direction_10m,
             .wind_direction_30m,
             .wind_direction_50m,
             .wind_direction_80m,
             .wind_direction_100m,
             .wind_direction_160m,
             .wind_direction_320m,
             .wind_direction_305m,
             .wind_direction_457m,
             .wind_direction_610m,
             .wind_direction_914m,
             .wind_direction_1524m,
             .wind_direction_1829m,
             .wind_direction_2134m,
             .wind_direction_2743m,
             .wind_direction_3658m,
             .wind_direction_4572m:
            return nil
        }
    }
}
