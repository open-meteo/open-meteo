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
    case pressure_msl
    case relative_humidity_2m
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    case wind_v_component_50m
    case wind_u_component_50m
    case wind_v_component_100m
    case wind_u_component_100m
    case wind_v_component_200m
    case wind_u_component_200m
    case wind_v_component_300m
    case wind_u_component_300m
    
    case temperature_50m
    case temperature_100m
    case temperature_200m
    case temperature_300m
    
    case snowfall_water_equivalent
    case rain
    
    case snow_depth_water_equivalent
    
    case wind_gusts_10m

    case shortwave_radiation
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .rain, .snowfall_water_equivalent: return true
        case .wind_u_component_10m, .wind_v_component_10m: return true
        case .wind_u_component_100m, .wind_v_component_100m: return true
        case .wind_u_component_200m, .wind_v_component_200m: return true
        case .wind_u_component_300m, .wind_v_component_300m: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m: return true
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
        case .temperature_2m:
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
        case .rain:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .snowfall_water_equivalent:
            return 10
        case .wind_v_component_10m:
            return 10
        case .wind_u_component_10m:
            return 10
        case .wind_v_component_50m, .wind_u_component_50m, .wind_v_component_100m, .wind_u_component_100m, .wind_v_component_200m,  .wind_u_component_200m, .wind_v_component_300m, .wind_u_component_300m:
            return 10
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return 20
        case .snow_depth_water_equivalent:
            return 10
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
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
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .rain:
            return .backwards_sum
        case .snowfall_water_equivalent, .snow_depth_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .wind_v_component_50m, .wind_u_component_50m, .wind_v_component_100m, .wind_u_component_100m, .wind_v_component_200m,  .wind_u_component_200m, .wind_v_component_300m, .wind_u_component_300m:
            return .hermite(bounds: nil)
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
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
        case .rain, .snow_depth_water_equivalent:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_v_component_10m:
            return .metrePerSecond
        case .wind_u_component_10m:
            return .metrePerSecond
        case .wind_v_component_50m, .wind_u_component_50m, .wind_v_component_100m, .wind_u_component_100m, .wind_v_component_200m,  .wind_u_component_200m, .wind_v_component_300m, .wind_u_component_300m:
            return .metrePerSecond
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
            return .celsius
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_50m, .temperature_100m, .temperature_200m, .temperature_300m:
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
