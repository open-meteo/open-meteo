import Foundation

/**
 AICON surface/single-level output variables.

 Available variables (from the opendata.dwd.de directory listing):
   PMSL      - pressure reduced to mean sea level
   PS        - surface pressure (not reduced)
   RELHUM_2M - 2 m relative humidity
   T_2M      - 2 m temperature
   TOT_PREC  - total precipitation (3-hourly accumulation)
   U_10M     - 10 m zonal wind component
   V_10M     - 10 m meridional wind component
 */
enum AiconSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable, Sendable {
    case temperature_2m
    case relative_humidity_2m
    case pressure_msl
    case surface_pressure
    case precipitation
    case wind_u_component_10m
    case wind_v_component_10m

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m, .pressure_msl, .precipitation:
            return true
        default:
            return false
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .relative_humidity_2m:
            return 1
        case .pressure_msl, .surface_pressure:
            return 10
        case .precipitation:
            return 10
        case .wind_u_component_10m, .wind_v_component_10m:
            return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .pressure_msl, .surface_pressure:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .wind_u_component_10m, .wind_v_component_10m:
            return .hermite(bounds: nil)
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .pressure_msl, .surface_pressure:
            return .hectopascal
        case .precipitation:
            return .millimetre
        case .wind_u_component_10m, .wind_v_component_10m:
            return .metrePerSecond
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }

    /// Name of the variable directory on the AICON open-data server
    var gribVariableName: String {
        switch self {
        case .temperature_2m:       return "T_2M"
        case .relative_humidity_2m: return "RELHUM_2M"
        case .pressure_msl:         return "PMSL"
        case .surface_pressure:     return "PS"
        case .precipitation:        return "TOT_PREC"
        case .wind_u_component_10m: return "U_10M"
        case .wind_v_component_10m: return "V_10M"
        }
    }

    /// Unit-conversion multiplier/offset applied after GRIB decoding.
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)   // Kelvin → °C
        case .pressure_msl, .surface_pressure:
            return (1 / 100, 0)  // Pa → hPa
        default:
            return nil
        }
    }
}

// MARK: - Model-level variable types

/**
 AICON 3-D variable types, available on all 13 AICON model levels.

 The opendata server places each field under an upper-case short name:
   P  - air pressure
   QV - specific humidity
   T  - air temperature
   U  - zonal wind component
   V  - meridional wind component

 AICON level → ICON global level → approx. height above sea level (m):
   1 → 49  → 21115,   2 → 57  → 16694,   3 → 64  → 14088,
   4 → 70  → 12283,   5 → 75  → 10783,   6 → 79  →  9583,
   7 → 86  →  7483,   8 → 91  →  5983,   9 → 96  →  4483,
  10 → 101 →  3037,  11 → 108 →  1421,  12 → 112 →   739,
  13 → 119 →    42
 */
enum AiconModelLevelVariableType: String, CaseIterable, Sendable {
    case pressure        = "P"
    case specificHumidity = "QV"
    case temperature     = "T"
    case windU           = "U"
    case windV           = "V"
}

/**
 A concrete AICON model-level variable: variable type + AICON level index (1–13).

 Conforms to `HeightVariableRespresentable` so that `rawValue` is derived automatically
 as e.g. `"T_13m"`, giving free `init?(rawValue:)` and `Codable` support consistent with
 the rest of the codebase.
 */
struct AiconModelLevelVariable: HeightVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable, Sendable {
    let variable: AiconModelLevelVariableType
    /// AICON level index, 1-based (1–13)
    let level: Int

    var storePreviousForecast: Bool { return false }

    var omFileName: (file: String, level: Int) {
        return (variable.rawValue.lowercased(), level)
    }

    var scalefactor: Float {
        switch variable {
        case .temperature:      return 20
        case .pressure:         return 0.1
        case .specificHumidity: return 1000  // kg/kg → g/kg
        case .windU, .windV:    return 10
        }
    }

    var interpolation: ReaderInterpolation {
        return .hermite(bounds: nil)
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:      return .celsius
        case .pressure:         return .hectopascal
        case .specificHumidity: return .gramPerKilogram
        case .windU, .windV:    return .metrePerSecond
        }
    }

    var isElevationCorrectable: Bool {
        return variable == .temperature
    }

    /// Upper-case directory name used on the opendata server: "P", "QV", "T", "U", "V"
    var gribVariableName: String {
        return variable.rawValue
    }

    /// Unit-conversion multiplier/offset applied after GRIB decoding.
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)  // Kelvin → °C
        case .pressure:
            return (1 / 100, 0)  // Pa → hPa
        default:
            return nil
        }
    }
}