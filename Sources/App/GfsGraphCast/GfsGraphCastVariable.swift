import Foundation

/// Required additions to a GFS variable to make it downloadable
protocol GfsGraphCastVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
}

enum GfsGraphCastSurfaceVariable: String, CaseIterable, GenericVariableMixable, GfsGraphCastVariableDownloadable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high

    case pressure_msl

    case wind_v_component_10m
    case wind_u_component_10m

    case precipitation

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m: return true
        case .precipitation: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .wind_u_component_10m, .wind_v_component_10m: return true
        default: return false
        }
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        default:
            return nil
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .cloud_cover: return 1
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .pressure_msl: return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .linear
        case .cloud_cover_low:
            return .linear
        case .cloud_cover_mid:
            return .linear
        case .cloud_cover_high:
            return .linear
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloud_cover: return .percentage
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .precipitation: return .millimetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .pressure_msl: return .hectopascal
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m:
            return true
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum GfsGraphCastPressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case vertical_velocity
    case relative_humidity
    case specific_humdity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsGraphCastPressureVariable: PressureVariableRespresentable, Hashable, GenericVariableMixable, GfsGraphCastVariableDownloadable {
    let variable: GfsGraphCastPressureVariableType
    let level: Int

    var storePreviousForecast: Bool {
        return false
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case .specific_humdity:
            return (1000, 0)
        default:
            return nil
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .wind_u_component, .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .vertical_velocity:
            return (20..<100).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .specific_humdity:
            fatalError("should never be written to disk")
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
        case .geopotential_height:
            return .linear
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        case .vertical_velocity:
            return .hermite(bounds: nil)
        case .specific_humdity:
            return .hermite(bounds: nil)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .metrePerSecond
        case .wind_v_component:
            return .metrePerSecond
        case .geopotential_height:
            return .metre
        case .relative_humidity:
            return .percentage
        case .vertical_velocity:
            return .metrePerSecondNotUnitConverted
        case .specific_humdity:
            return .gramPerKilogram
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias GfsGraphCastVariable = SurfaceAndPressureVariable<GfsGraphCastSurfaceVariable, GfsGraphCastPressureVariable>
