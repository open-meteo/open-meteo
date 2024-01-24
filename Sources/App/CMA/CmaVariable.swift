import Foundation

/// Required additions to a GFS variable to make it downloadable
protocol CmaVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
}

enum CmaSurfaceVariable: String, CaseIterable, GenericVariableMixable, CmaVariableDownloadable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case relative_humidity_2m
    
    case shortwave_radiation
    case shortwave_radiation_clear_sky
    
    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_30m
    case wind_u_component_30m
    case wind_v_component_50m
    case wind_u_component_50m
    case wind_v_component_70m
    case wind_u_component_70m
    case wind_v_component_100m
    case wind_u_component_100m
    case wind_v_component_120m
    case wind_u_component_120m
    case wind_v_component_140m
    case wind_u_component_140m
    case wind_v_component_160m
    case wind_u_component_160m
    case wind_v_component_180m
    case wind_u_component_180m
    case wind_v_component_200m
    case wind_u_component_200m
    case wind_gusts_10m
    
    case precipitation
    case precipitation_type
    case showers
    case snowfall
    case surface_temperature
    case snow_depth
    case cape
    case convective_inhibition
    case lifted_index
    case visibility
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .snowfall: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_u_component_10m, .wind_v_component_10m: return true
        case .cape: return true
        default: return false
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm: return true
        case .soil_moisture_10_to_40cm: return true
        case .soil_moisture_40_to_100cm: return true
        case .soil_moisture_100_to_200cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature, .soil_temperature_0_to_10cm, .soil_temperature_10_to_40cm, .soil_temperature_40_to_100cm, .soil_temperature_100_to_200cm:
            return (1, -273.15)
        case .snowfall:
            return (100, 0)
        case .shortwave_radiation, .shortwave_radiation_clear_sky:
            return (1/1000, 0)
        case .pressure_msl:
            return (1/100, 0)
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
        case .relative_humidity_2m: return 1
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_30m: return 10
        case .wind_u_component_30m: return 10
        case .wind_v_component_50m: return 10
        case .wind_u_component_50m: return 10
        case .wind_v_component_70m: return 10
        case .wind_u_component_70m: return 10
        case .wind_u_component_100m: return 10
        case .wind_v_component_100m: return 10
        case .wind_v_component_120m: return 10
        case .wind_u_component_120m: return 10
        case .wind_v_component_140m: return 10
        case .wind_u_component_140m: return 10
        case .wind_u_component_160m: return 10
        case .wind_v_component_160m: return 10
        case .wind_u_component_180m: return 10
        case .wind_v_component_180m: return 10
        case .wind_u_component_200m: return 10
        case .wind_v_component_200m: return 10
        case .surface_temperature: return 20
        case .soil_temperature_0_to_10cm: return 20
        case .soil_temperature_10_to_40cm: return 20
        case .soil_temperature_40_to_100cm: return 20
        case .soil_temperature_100_to_200cm: return 20
        case .soil_moisture_0_to_10cm: return 1000
        case .soil_moisture_10_to_40cm: return 1000
        case .soil_moisture_40_to_100cm: return 1000
        case .soil_moisture_100_to_200cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .wind_gusts_10m: return 10
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .cape: return 0.1
        case .lifted_index: return 10
        case .visibility: return 0.05 // 50 meter
        case .convective_inhibition: return 1
        case .shortwave_radiation_clear_sky:
            return 1
        case .precipitation_type:
            return 1
        case .snowfall:
            return 10
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
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .precipitation:
            return .backwards_sum
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .wind_v_component_30m:
            return .hermite(bounds: nil)
        case .wind_u_component_30m:
            return .hermite(bounds: nil)
        case .wind_v_component_50m:
            return .hermite(bounds: nil)
        case .wind_u_component_50m:
            return .hermite(bounds: nil)
        case .wind_v_component_70m:
            return .hermite(bounds: nil)
        case .wind_u_component_70m:
            return .hermite(bounds: nil)
        case .wind_v_component_100m:
            return .hermite(bounds: nil)
        case .wind_u_component_100m:
            return .hermite(bounds: nil)
        case .wind_v_component_120m:
            return .hermite(bounds: nil)
        case .wind_u_component_120m:
            return .hermite(bounds: nil)
        case .wind_v_component_140m:
            return .hermite(bounds: nil)
        case .wind_u_component_140m:
            return .hermite(bounds: nil)
        case .wind_v_component_160m:
            return .hermite(bounds: nil)
        case .wind_u_component_160m:
            return .hermite(bounds: nil)
        case .wind_v_component_180m:
            return .hermite(bounds: nil)
        case .wind_u_component_180m:
            return .hermite(bounds: nil)
        case .wind_v_component_200m:
            return .hermite(bounds: nil)
        case .wind_u_component_200m:
            return .hermite(bounds: nil)
        case .surface_temperature:
            return .hermite(bounds: nil)
        case .soil_temperature_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_temperature_10_to_40cm:
            return .hermite(bounds: nil)
        case .soil_temperature_40_to_100cm:
            return .hermite(bounds: nil)
        case .soil_temperature_100_to_200cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_moisture_10_to_40cm:
            return .hermite(bounds: nil)
        case .soil_moisture_40_to_100cm:
            return .hermite(bounds: nil)
        case .soil_moisture_100_to_200cm:
            return .hermite(bounds: nil)
        case .snow_depth:
            return .linear
        case .showers:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .lifted_index:
            return .hermite(bounds: nil)
        case .visibility:
            return .linear
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .shortwave_radiation_clear_sky:
            return .solar_backwards_averaged
        case .precipitation_type:
            return .backwards
        case .snowfall:
            return .backwards_sum
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloud_cover: return .percentage
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .relative_humidity_2m: return .percentage
        case .precipitation: return .millimetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .wind_v_component_30m: return .metrePerSecond
        case .wind_u_component_30m: return .metrePerSecond
        case .wind_v_component_50m: return .metrePerSecond
        case .wind_u_component_50m: return .metrePerSecond
        case .wind_v_component_70m: return .metrePerSecond
        case .wind_u_component_70m: return .metrePerSecond
        case .wind_v_component_100m: return .metrePerSecond
        case .wind_u_component_100m: return .metrePerSecond
        case .wind_v_component_120m: return .metrePerSecond
        case .wind_u_component_120m: return .metrePerSecond
        case .wind_v_component_140m: return .metrePerSecond
        case .wind_u_component_140m: return .metrePerSecond
        case .wind_v_component_160m: return .metrePerSecond
        case .wind_u_component_160m: return .metrePerSecond
        case .wind_v_component_180m: return .metrePerSecond
        case .wind_u_component_180m: return .metrePerSecond
        case .wind_v_component_200m: return .metrePerSecond
        case .wind_u_component_200m: return .metrePerSecond
        case .surface_temperature: return .celsius
        case .soil_temperature_0_to_10cm: return .celsius
        case .soil_temperature_10_to_40cm: return .celsius
        case .soil_temperature_40_to_100cm: return .celsius
        case .soil_temperature_100_to_200cm: return .celsius
        case .soil_moisture_0_to_10cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_10_to_40cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_40_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_200cm: return .cubicMetrePerCubicMetre
        case .snow_depth: return .metre
        case .showers: return .millimetre
        case .wind_gusts_10m: return .metrePerSecond
        case .pressure_msl: return .hectopascal
        case .shortwave_radiation: return .wattPerSquareMetre
        case .cape: return .joulePerKilogram
        case .lifted_index: return .dimensionless
        case .visibility: return .metre
        case .convective_inhibition: return .joulePerKilogram
        case .shortwave_radiation_clear_sky:
            return .wattPerSquareMetre
        case .precipitation_type:
            return .undefined
        case .snowfall:
            return .centimetre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface_temperature:
            fallthrough
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_10_to_40cm:
            fallthrough
        case .soil_temperature_40_to_100cm:
            fallthrough
        case .soil_temperature_100_to_200cm:
            fallthrough
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
enum CmaPressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case vertical_velocity
    case relative_humidity
    case cloud_cover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct CmaPressureVariable: PressureVariableRespresentable, Hashable, GenericVariableMixable, CmaVariableDownloadable {
    let variable: CmaPressureVariableType
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
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .cloud_cover:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .vertical_velocity:
            return (20..<100).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
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
        case .cloud_cover:
            return .linear
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        case .vertical_velocity:
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
        case .cloud_cover:
            return .percentage
        case .relative_humidity:
            return .percentage
        case .vertical_velocity:
            return .metrePerSecondNotUnitConverted
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias CmaVariable = SurfaceAndPressureVariable<CmaSurfaceVariable, CmaPressureVariable>
