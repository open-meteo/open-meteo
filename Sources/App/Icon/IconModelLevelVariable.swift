import Foundation

/// Variables available on ICON native model (full) levels.
/// Currently only geometric height, derived on read from the static HHL stack.
enum IconModelLevelVariableType: String, CaseIterable, Sendable {
    /// Geometric height of the full level, above sea level (m)
    case height
    /// Geometric height of the full level, above the model surface (m)
    case height_agl
    case wind_u_component
    case wind_v_component
    case temperature
    case specific_humidity
    case relative_humidity
    case pressure
}

/// A variable on a native ICON model full level, named `<variable>_level<N>`
/// where `N` is the DWD-native full-level index (1 = model top, N = lowest layer near surface).
///
/// These are not stored as time-series `.om` files; `IconReader` intercepts them and computes
/// the value from the static `hhl.om` half-level stack (see `fullLevelHeightASL/AGL`).
struct IconModelLevelVariable: ModelLevelVariableRespresentable, IconVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: IconModelLevelVariableType
    let level: Int

    /// Placeholder — model-level height is computed, never read from a per-variable file.
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch variable {
        case .height, .height_agl: return 1
        case .wind_u_component, .wind_v_component: return 10
        case .temperature: return 10
        case .specific_humidity: return 1000
        case .relative_humidity: return 1
        case .pressure: return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .height, .height_agl: return .linear
        case .wind_u_component, .wind_v_component, .temperature, .pressure: return .hermite(bounds: nil)
        case .specific_humidity: return .linear
        case .relative_humidity: return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .height, .height_agl: return .metre
        case .wind_u_component, .wind_v_component: return .metrePerSecond
        case .temperature: return .celsius
        case .specific_humidity: return .gramPerKilogram
        case .relative_humidity: return .percentage
        case .pressure: return .hectopascal
        }
    }

    var isElevationCorrectable: Bool { false }

    var storePreviousForecast: Bool { false }

    func skipHour(hour: Int, domain: IconDomains, forDownload: Bool, run: Timestamp) -> Bool { false }

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case .specific_humidity:
            return (1000, 0)
        case .pressure:
            return (0.01, 0)
        default:
            return nil
        }
    }

    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?)? {
        switch variable {
        case .height, .height_agl:
            return nil
        case .wind_u_component:
            return ("u", "model-level", level)
        case .wind_v_component:
            return ("v", "model-level", level)
        case .temperature:
            return ("t", "model-level", level)
        case .specific_humidity:
            return ("qv", "model-level", level)
        case .relative_humidity:
            return nil  // derived on read from specific_humidity_levelN + temperature_levelN + pressure_levelN
        case .pressure:
            return ("p", "model-level", level)
        }
    }
}
