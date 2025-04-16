import Foundation

/**
 List of all surface Knmi variables
 */
enum KnmiSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case relative_humidity_2m

    case wind_speed_10m
    case wind_speed_50m
    case wind_speed_100m
    case wind_speed_200m
    case wind_speed_300m

    /// Wind direction has been corrected due to grid projection
    case wind_direction_10m
    case wind_direction_50m
    case wind_direction_100m
    case wind_direction_200m
    case wind_direction_300m

    case temperature_50m
    case temperature_100m
    case temperature_200m
    case temperature_300m

    case snowfall_water_equivalent
    case rain
    case precipitation

    case surface_temperature
    case visibility
    case snow_depth_water_equivalent

    case wind_gusts_10m

    case shortwave_radiation

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .rain, .snowfall_water_equivalent: return true
        case .wind_speed_10m, .wind_direction_10m: return true
        case .wind_speed_50m, .wind_direction_50m: return true
        case .wind_speed_100m, .wind_direction_100m: return true
        case .wind_speed_200m, .wind_direction_200m: return true
        case .wind_speed_300m, .wind_direction_300m: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m: return true
        case .visibility: return true
        default: return false
        }
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m, .surface_temperature:
            return 20
        case .cloud_cover:
            return 1
        case .cloud_cover_low:
            return 1
        case .cloud_cover_mid:
            return 1
        case .cloud_cover_high:
            return 1
        case .relative_humidity_2m:
            return 1
        case .rain, .precipitation:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .snowfall_water_equivalent:
            return 10
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_200m, .wind_speed_300m:
            return 10
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return 20
        case .snow_depth_water_equivalent:
            return 10
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_200m, .wind_direction_300m:
            return 1
        case .visibility:
            return 0.05 // 50 meter
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...10)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_200m, .wind_speed_300m:
            return .hermite(bounds: 0...1000)
        case .rain, .precipitation:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .snow_depth_water_equivalent:
            return .linear
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return .hermite(bounds: nil)
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_200m, .wind_direction_300m:
            return .linearDegrees
        case .visibility:
            return .linear
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .celsius
        case .cloud_cover:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .rain, .precipitation, .snow_depth_water_equivalent:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_200m, .wind_speed_300m:
            return .metrePerSecond
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return .celsius
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_200m, .wind_direction_300m:
            return .degreeDirection
        case .visibility:
            return .metre
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m, .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return true
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum KnmiPressureVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case geopotential_height
    case relative_humidity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct KnmiPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: KnmiPressureVariableType
    let level: Int

    var storePreviousForecast: Bool {
        return false
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
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
        case .wind_speed:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .wind_direction:
            return (0.2..<0.5).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_speed:
            return .hermite(bounds: 0...1000)
        case .wind_direction:
            return .linearDegrees
        case .geopotential_height:
            return .hermite(bounds: nil)
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_speed:
            return .metrePerSecond
        case .wind_direction:
            return .degreeDirection
        case .geopotential_height:
            return .metre
        case .relative_humidity:
            return .percentage
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }
}
/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias KnmiVariable = SurfaceAndPressureVariable<KnmiSurfaceVariable, KnmiPressureVariable>
