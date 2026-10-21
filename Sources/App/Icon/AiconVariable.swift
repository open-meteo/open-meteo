/// AICON surface and single-level output variables.
enum AiconSurfaceVariable: String, CaseIterable, IconVariableDownloadable {
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
        case .pressure_msl, .surface_pressure, .precipitation, .wind_u_component_10m, .wind_v_component_10m:
            return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .precipitation:
            return .backwards_sum
        case .temperature_2m, .pressure_msl, .surface_pressure, .wind_u_component_10m, .wind_v_component_10m:
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
