import Foundation

/**
 List of all surface MeteoSwiss variables
 */
enum MeteoSwissSurfaceVariable: String, CaseIterable, MeteoSwissVariableDownloadable, GenericVariableMixable {
    
    
    //case albedo
    //case latent_heat_flux
    //case sensible_heat_flux
    ///
    case shortwave_radiation
    case direct_radiation
    //case longwave_radiation
    /// using most unstable
    case cape
    /// ceiling
    case cloud_base
    /// using most unstable
    case convective_inhibition
    case cloud_cover
    /// 800 hPa to ground
    case cloud_cover_low
    /// 400 - 800 hpa
    case cloud_cover_mid
    /// 0-400 hpa
    case cloud_cover_high
    
    case sunshine_duration
    case freezing_level_height
    case snow_depth
    case pressure_msl
    case snowfall_height
    case relative_humidity_2m
    
    case temperature_2m
    //case temperature_2m_max
    //case temperature_2m_min
    case precipitation
    //case snow_temperature
    case surface_temperature
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_gusts_10m
    
    /// z0 surface
    //case roughness_length

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .snowfall_height, .precipitation: return true
        case .wind_u_component_10m, .wind_v_component_10m: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .cape, .convective_inhibition: return true
        case .shortwave_radiation, .direct_radiation: return true
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
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation, .direct_radiation:
            return 1
        case .wind_u_component_10m, .wind_v_component_10m:
            return 10
        case .cloud_base:// , .cloud_top:
            return 0.05 // 20 metre
        case .precipitation:
            return 10
        case .freezing_level_height:
            return 0.1 // zero height 10 metre resolution
        case .cape:
            return 0.1
        case .convective_inhibition: return 1
        case .sunshine_duration:
            return 1/60
        case .snow_depth:
            return 100 // 1cm res
        case .snowfall_height:
            return 0.1
        case .relative_humidity_2m:
            return 20
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature, .relative_humidity_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_v_component_10m:
            return .hermite(bounds: 0...1000)
        case .precipitation:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .direct_radiation:
            return .hermite(bounds: 0...10e9)
        case .freezing_level_height:
            return .linear
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .cloud_base:
            return .hermite(bounds: 0...10e9)
        case .sunshine_duration:
            return .linear
        case .snow_depth:
            return .backwards
        case .snowfall_height:
            return .backwards
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .cloud_cover:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .precipitation:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .wind_u_component_10m, .wind_v_component_10m:
            return .metrePerSecond
        case .cloud_base:// , .cloud_top:
            return .metre
        case .freezing_level_height:
            return .metre
        case .convective_inhibition: return .joulePerKilogram
        case .cape:
            return .joulePerKilogram
        case .sunshine_duration:
            return .seconds
        case .snow_depth:
            return .metre
        case .snowfall_height:
            return .metre
        }
    }

    

    var skipHour0: Bool {
        switch self {
        case .precipitation:
            return true
        default:
            return false
        }
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature, .relative_humidity_2m:
            // RH is dewpoint initially
            return (-273.15, 1) // kelvin to celsius
        case .pressure_msl:
            return (0, 1 / 100)
        default:
            return nil
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m, .surface_temperature:
            return true
        default:
            return false
        }
    }
    
    var gribName: String {
        switch self {
        case .shortwave_radiation:
            // Diffuse radiation is selected here. Direct radiation is added in the downloader
            return "ASWDIFD_S"
        case .direct_radiation:
            return "ASWDIR_S"
        case .cape:
            return "CAPE_MU"
        case .cloud_base:
            return "CEILING"
        case .convective_inhibition:
            return "CIN_MU"
        case .cloud_cover:
            return "CLCT"
        case .cloud_cover_low:
            return "CLCL"
        case .cloud_cover_mid:
            return "CLCM"
        case .cloud_cover_high:
            return "CLCH"
        case .sunshine_duration:
            return "DURSUN"
        case .freezing_level_height:
            return "HZEROCL"
        case .snow_depth:
            return "H_SNOW"
        case .pressure_msl:
            return "PMSL"
        case .snowfall_height:
            return "SNOWLMT"
        case .relative_humidity_2m:
            // dewpoint selected, converted to RH later
            return "TD_2M"
        case .temperature_2m:
            return "T_2M"
        case .precipitation:
            return "TOT_PREC"
        case .surface_temperature:
            return "T_G"
        case .wind_u_component_10m:
            return "U_10M"
        case .wind_v_component_10m:
            return "V_10M"
        case .wind_gusts_10m:
            return "VMAX_10M"
        }
    }
}

/**
 Types of pressure level variables
 */
enum MeteoSwissPressureVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case geopotential_height
    case relative_humidity
    case vertical_velocity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct MeteoSwissPressureVariable: PressureVariableRespresentable, MeteoSwissVariableDownloadable, Hashable, GenericVariableMixable {
    var gribName: String {
        fatalError()
    }
    
    
    
    let variable: MeteoSwissPressureVariableType
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
        case .vertical_velocity:
            return (20..<100).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
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
        case .vertical_velocity:
            return .hermite(bounds: nil)
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
        case .vertical_velocity:
            return .metrePerSecondNotUnitConverted
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var skipHour0: Bool {
        return false
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch variable {
        case .temperature:
            return (-273.15, 1) // kelvin to celsius
        case .relative_humidity:
            return (0, 100) // fraction to %
        default:
            return nil
        }
    }

    func withLevel(level: Float) -> MeteoSwissPressureVariable {
        return MeteoSwissPressureVariable(variable: variable, level: Int(level))
    }
}

/**
 Types of height level variables
 */
enum MeteoSwissHeightVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case pressure
}

/**
 A height level variable on a given metre above ground
 */
struct MeteoSwissHeightVariable: HeightVariableRespresentable, MeteoSwissVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: MeteoSwissHeightVariableType
    let level: Int

    var storePreviousForecast: Bool {
        /*switch variable {
        case .wind_speed, .wind_direction:
            return level <= 300
        default:
            return false
        }*/
        return false
    }
    
    var gribName: String {
        fatalError()
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
            return 10
        case .wind_u_component, .wind_v_component:
            return 10
        case .pressure:
            return 1
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component, .wind_v_component:
            return .hermite(bounds: 0...1000)
        case .pressure:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component, .wind_v_component:
            return .metrePerSecond
        case .pressure:
            return .hectopascal
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var skipHour0: Bool {
        return false
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch variable {
        case .temperature:
            return (-273.15, 1) // kelvin to celsius
        default:
            return nil
        }
    }
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias MeteoSwissVariable = SurfacePressureAndHeightVariable<MeteoSwissSurfaceVariable, MeteoSwissPressureVariable, MeteoSwissHeightVariable>

protocol MeteoSwissVariableDownloadable: GenericVariable {
    var skipHour0: Bool { get }
    var multiplyAdd: (offset: Float, scalefactor: Float)? { get }
    var gribName: String { get }
}
