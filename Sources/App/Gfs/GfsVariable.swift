import Foundation


/**
 List of all surface GFS variables to download
 */
enum GfsSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case temperature_80m
    case temperature_100m
    
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case surface_pressure
    
    case relativehumidity_2m
    
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
    case sensible_heatflux
    case latent_heatflux
    
    case showers
    
    /// CPOFP Percent frozen precipitation [%]
    case frozen_precipitation_percent
    
    /// CFRZR Categorical Freezing Rain (0 or 1)
    case categorical_freezing_rain
    
    //case rain
    //case snowfall_convective_water_equivalent
    //case snowfall_water_equivalent
    
    case windgusts_10m
    case freezinglevel_height
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
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .temperature_80m: return 20
        case .temperature_100m: return 20
        case .cloudcover: return 1
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .relativehumidity_2m: return 1
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
        case .sensible_heatflux: return 0.144
        case .latent_heatflux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .windgusts_10m: return 10
        case .freezinglevel_height:  return 0.1 // zero height 10 meter resolution
        case .showers: return 10
        case .surface_pressure: return 10
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
        case .cloudcover:
            return .linear
        case .cloudcover_low:
            return .linear
        case .cloudcover_mid:
            return .linear
        case .cloudcover_high:
            return .linear
        case .surface_pressure:
            return .hermite(bounds: nil)
        case .relativehumidity_2m:
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
        case .sensible_heatflux:
            return .hermite(bounds: nil)
        case .latent_heatflux:
            return .hermite(bounds: nil)
        case .showers:
            return .backwards_sum
        case .frozen_precipitation_percent:
            return .nearest
        case .categorical_freezing_rain:
            return .nearest
        case .windgusts_10m:
            return .hermite(bounds: nil)
        case .freezinglevel_height:
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
            return .hermite(bounds: nil)
        case .lifted_index:
            return .hermite(bounds: nil)
        case .visibility:
            return .linear
        case .precipitation_probability:
            return .linear
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .temperature_80m: return .celsius
        case .temperature_100m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .relativehumidity_2m: return .percent
        case .precipitation: return .millimeter
        case .wind_v_component_10m: return .ms
        case .wind_u_component_10m: return .ms
        case .wind_v_component_80m: return .ms
        case .wind_u_component_80m: return .ms
        case .wind_v_component_100m: return .ms
        case .wind_u_component_100m: return .ms
        case .surface_temperature: return .celsius
        case .soil_temperature_0_to_10cm: return .celsius
        case .soil_temperature_10_to_40cm: return .celsius
        case .soil_temperature_40_to_100cm: return .celsius
        case .soil_temperature_100_to_200cm: return .celsius
        case .soil_moisture_0_to_10cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_10_to_40cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_40_to_100cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_200cm: return .qubicMeterPerQubicMeter
        case .snow_depth: return .meter
        case .sensible_heatflux: return .wattPerSquareMeter
        case .latent_heatflux: return .wattPerSquareMeter
        case .showers: return .millimeter
        case .windgusts_10m: return .ms
        case .freezinglevel_height: return .meter
        case .surface_pressure: return .hectoPascal
        case .shortwave_radiation: return .wattPerSquareMeter
        case .frozen_precipitation_percent: return .percent
        case .cape: return .joulesPerKilogram
        case .lifted_index: return .dimensionless
        case .visibility: return .meter
        case .diffuse_radiation: return .wattPerSquareMeter
        case .uv_index: return .dimensionless
        case .uv_index_clear_sky: return .dimensionless
        case .precipitation_probability: return .percent
        case .categorical_freezing_rain: return .dimensionless
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
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
    case cloudcover
    case relativehumidity
    case vertical_velocity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: GfsPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
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
        case .cloudcover:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .relativehumidity:
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
        case .cloudcover:
            return .linear
        case .relativehumidity:
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
            return .ms
        case .wind_v_component:
            return .ms
        case .geopotential_height:
            return .meter
        case .cloudcover:
            return .percent
        case .relativehumidity:
            return .percent
        case .vertical_velocity:
            return .ms_not_unit_converted
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
