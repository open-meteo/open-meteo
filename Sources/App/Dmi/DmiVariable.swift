import Foundation

/**
 List of all surface Dmi variables
 */
enum DmiSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case cloud_cover_2m
    case pressure_msl
    case relative_humidity_2m
    
    case cloud_base
    case cloud_top

    case wind_speed_10m
    case wind_speed_50m
    case wind_speed_100m
    case wind_speed_150m
    case wind_speed_250m
    case wind_speed_350m
    case wind_speed_450m
    
    /// Wind direction has been corrected due to grid projection
    case wind_direction_10m
    case wind_direction_50m
    case wind_direction_100m
    case wind_direction_150m
    case wind_direction_250m
    case wind_direction_350m
    case wind_direction_450m
    
    case temperature_50m
    case temperature_100m
    case temperature_150m
    case temperature_250m
    
    case snowfall_water_equivalent
    case precipitation
    
    case snow_depth_water_equivalent
    
    case wind_gusts_10m

    case shortwave_radiation
    case direct_radiation
    
    case surface_temperature
    case convective_inhibition
    case cape
    case visibility
    case freezing_level_height
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .snowfall_water_equivalent: return true
        case .wind_speed_10m, .wind_direction_10m: return true
        case .wind_speed_50m, .wind_direction_50m: return true
        case .wind_speed_100m, .wind_direction_100m: return true
        case .wind_speed_150m, .wind_direction_150m: return true
        case .wind_speed_250m, .wind_direction_250m: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation, .direct_radiation: return true
        case .wind_gusts_10m: return true
        case .cape: return true
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
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .cloud_cover_2m:
            return 1
        case .relative_humidity_2m:
            return 1
        case .precipitation:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation, .direct_radiation:
            return 1
        case .snowfall_water_equivalent:
            return 10
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_150m, .wind_direction_250m, .wind_direction_350m, .wind_direction_450m:
            return 1
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_150m, .wind_speed_250m, .wind_speed_350m, .wind_speed_450m:
            return 10
        case .temperature_50m, .temperature_100m, .temperature_150m, .temperature_250m:
            return 20
        case .snow_depth_water_equivalent:
            return 10
        case .convective_inhibition:
            return 1
        case .cape:
            return 0.1
        case .visibility:
            return 0.05 // 20 metre
        case .freezing_level_height:
            return 0.1 // zero height 10 metre resolution
        case .cloud_top, .cloud_base:
            return 0.05 // 20 metre
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .cloud_cover_2m:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .precipitation:
            return .backwards_sum
        case .snowfall_water_equivalent, .snow_depth_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .temperature_50m, .temperature_100m, .temperature_150m, .temperature_250m:
            return .hermite(bounds: nil)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .visibility:
            return .linear
        case .freezing_level_height:
            return .linear
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_150m, .wind_direction_250m, .wind_direction_350m, .wind_direction_450m:
            return .linearDegrees
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_150m, .wind_speed_250m, .wind_speed_350m, .wind_speed_450m:
            return .hermite(bounds: 0...10e9)
        case .cloud_top, .cloud_base:
            return .hermite(bounds: 0...10e9)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .celsius
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .cloud_cover_2m:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation, .snow_depth_water_equivalent:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .temperature_50m, .temperature_100m, .temperature_150m, .temperature_250m:
            return .celsius
        case .convective_inhibition:
            return .joulePerKilogram
        case .cape:
            return .joulePerKilogram
        case .visibility:
            return .metre
        case .freezing_level_height:
            return .metre
        case .wind_direction_10m, .wind_direction_50m, .wind_direction_100m, .wind_direction_150m, .wind_direction_250m, .wind_direction_350m, .wind_direction_450m:
            return .degreeDirection
        case .wind_speed_10m, .wind_speed_50m, .wind_speed_100m, .wind_speed_150m, .wind_speed_250m, .wind_speed_350m, .wind_speed_450m:
            return .metrePerSecond
        case .cloud_top, .cloud_base:
            return .metre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_50m, .temperature_100m, .temperature_150m, .temperature_250m:
            return true
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum DmiPressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case relative_humidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct DmiPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: DmiPressureVariableType
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
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
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
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
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
        case .wind_u_component:
            return .metrePerSecond
        case .wind_v_component:
            return .metrePerSecond
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
typealias DmiVariable = SurfaceAndPressureVariable<DmiSurfaceVariable, DmiPressureVariable>
