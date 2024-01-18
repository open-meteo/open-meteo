import Foundation


/**
 List of all surface GFS variables to download
 */
enum GfsSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case temperature_80m
    case temperature_100m
    
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    
    case relative_humidity_2m
    
    /// accumulated since forecast start
    case precipitation
    
    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_80m
    case wind_u_component_80m
    case wind_v_component_100m
    case wind_u_component_100m
    
    case surface_temperature
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    case snow_depth
    
    /// averaged since model start
    case sensible_heat_flux
    case latent_heat_flux
    
    case showers
    
    /// CPOFP Percent frozen precipitation [%]
    case frozen_precipitation_percent
    
    /// CFRZR Categorical Freezing Rain (0 or 1)
    case categorical_freezing_rain
    
    /// :CIN:surface: convective inhibition
    case convective_inhibition
    
    //case rain
    //case snowfall_convective_water_equivalent
    //case snowfall_water_equivalent
    
    case wind_gusts_10m
    case freezing_level_height
    case shortwave_radiation
    /// Only for HRRR domain. Otherwise diff could be estimated with https://arxiv.org/pdf/2007.01639.pdf 3) method
    case diffuse_radiation
    //case direct_radiation
    
    /// only GFS
    case uv_index
    case uv_index_clear_sky
    
    case cape
    case lifted_index
    
    case visibility
    
    case precipitation_probability
    
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .frozen_precipitation_percent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation, .diffuse_radiation: return true
        case .wind_gusts_10m, .wind_u_component_10m, .wind_v_component_10m: return true
        case .cape, .lifted_index: return true
        //case .wind_speed_40m, .wind_direction_40m: return true
        //case .wind_speed_80m, .wind_direction_80m: return true
        //case .wind_speed_120m, .wind_direction_120m: return true
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
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .temperature_80m: return 20
        case .temperature_100m: return 20
        case .cloud_cover: return 1
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .relative_humidity_2m: return 1
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_80m: return 10
        case .wind_u_component_80m: return 10
        case .wind_u_component_100m: return 10
        case .wind_v_component_100m: return 10
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
        case .sensible_heat_flux: return 0.144
        case .latent_heat_flux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .wind_gusts_10m: return 10
        case .freezing_level_height:  return 0.1 // zero height 10 meter resolution
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .frozen_precipitation_percent: return 1
        case .cape: return 0.1
        case .lifted_index: return 10
        case .visibility: return 0.05 // 50 meter
        case .diffuse_radiation: return 1
        case .uv_index: return 20
        case .uv_index_clear_sky: return 20
        case .precipitation_probability: return 1
        case .categorical_freezing_rain: return 1
        case .convective_inhibition: return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .temperature_80m:
            return .hermite(bounds: nil)
        case .temperature_100m:
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
        case .wind_v_component_80m:
            return .hermite(bounds: nil)
        case .wind_u_component_80m:
            return .hermite(bounds: nil)
        case .wind_v_component_100m:
            return .hermite(bounds: nil)
        case .wind_u_component_100m:
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
        case .sensible_heat_flux:
            return .hermite(bounds: nil)
        case .latent_heat_flux:
            return .hermite(bounds: nil)
        case .showers:
            return .backwards_sum
        case .frozen_precipitation_percent:
            return .backwards
        case .categorical_freezing_rain:
            return .backwards
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .freezing_level_height:
            return .linear
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .diffuse_radiation:
            return .solar_backwards_averaged
        case .uv_index:
            return .hermite(bounds: 0...1000)
        case .uv_index_clear_sky:
            return .hermite(bounds: 0...1000)
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .lifted_index:
            return .hermite(bounds: nil)
        case .visibility:
            return .linear
        case .precipitation_probability:
            return .linear
        case .convective_inhibition:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .temperature_80m: return .celsius
        case .temperature_100m: return .celsius
        case .cloud_cover: return .percentage
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .relative_humidity_2m: return .percentage
        case .precipitation: return .millimetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .wind_v_component_80m: return .metrePerSecond
        case .wind_u_component_80m: return .metrePerSecond
        case .wind_v_component_100m: return .metrePerSecond
        case .wind_u_component_100m: return .metrePerSecond
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
        case .sensible_heat_flux: return .wattPerSquareMetre
        case .latent_heat_flux: return .wattPerSquareMetre
        case .showers: return .millimetre
        case .wind_gusts_10m: return .metrePerSecond
        case .freezing_level_height: return .metre
        case .pressure_msl: return .hectopascal
        case .shortwave_radiation: return .wattPerSquareMetre
        case .frozen_precipitation_percent: return .percentage
        case .cape: return .joulePerKilogram
        case .lifted_index: return .dimensionless
        case .visibility: return .metre
        case .diffuse_radiation: return .wattPerSquareMetre
        case .uv_index: return .dimensionless
        case .uv_index_clear_sky: return .dimensionless
        case .precipitation_probability: return .percentage
        case .categorical_freezing_rain: return .dimensionless
        case .convective_inhibition: return .joulePerKilogram
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
            fallthrough
        case .temperature_80m:
            fallthrough
        case .temperature_100m:
            return true
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableType: String, CaseIterable, RawRepresentableString {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case cloud_cover
    case relative_humidity
    case vertical_velocity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: GfsPressureVariableType
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
typealias GfsVariable = SurfaceAndPressureVariable<GfsSurfaceVariable, GfsPressureVariable>
