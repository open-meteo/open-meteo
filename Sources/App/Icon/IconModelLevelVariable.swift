import Foundation
import OmFileFormat

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
    case wind_speed
    case wind_direction
    case dew_point
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
        // Stored logarithmically (see omFileCompression): scalefactor multiplies log10(1+g/kg).
        // Max ~30 g/kg → log10≈1.5 → ~14900 (< INT16_MAX 32767, reserved for NaN); ~0.02% relative steps.
        case .specific_humidity: return 10000
        case .relative_humidity: return 1
        case .pressure: return 10
        case .wind_speed, .wind_direction, .dew_point: return 10
        }
    }

    /// Specific humidity spans ~4–5 orders of magnitude (surface ~20 g/kg → stratosphere ~10⁻³ g/kg).
    /// Linear int16 (`pfor_delta2d_int16`, scalefactor 1000) loses dry-layer precision and rounds tiny
    /// values to 0 — which makes the derived dew point NaN above ~200 hPa. Logarithmic int16
    /// (`log10(1+x)` before packing) fixes that: tiny values stay non-zero and the mid-level dry range
    /// (qv ≳ 0.05 g/kg) gets ~0.1–1 % relative precision at the same size. Note `log10(1+x)` is
    /// near-linear for x≪1, so it is not truly constant-relative below ~0.05 g/kg, but it degrades
    /// gracefully instead of truncating. (Precedent: GloFas river_discharge.)
    var omFileCompression: OmCompressionType {
        switch variable {
        case .specific_humidity: return .pfor_delta2d_int16_logarithmic
        default: return .pfor_delta2d_int16
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .height, .height_agl: return .linear
        case .wind_u_component, .wind_v_component, .temperature, .pressure: return .hermite(bounds: nil)
        case .specific_humidity: return .linear
        case .relative_humidity: return .hermite(bounds: 0...100)
        case .wind_speed, .dew_point: return .hermite(bounds: nil)
        case .wind_direction: return .linearDegrees
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
        case .wind_speed: return .metrePerSecond
        case .wind_direction: return .degreeDirection
        case .dew_point: return .celsius
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
        case .wind_speed, .wind_direction, .dew_point:
            return nil  // derived on read
        }
    }
}
