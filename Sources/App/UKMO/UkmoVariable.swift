import Foundation

/**
 List of all surface Ukmo variables
 */
enum UkmoSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case cloud_cover_2m
    case cloud_base
    case cloud_top
    
    case pressure_msl
    case relative_humidity_2m
    
    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m
    
    case precipitation
    case snowfall_water_equivalent
    case rain
    case hail
    case showers
    case freezing_level_height
    
    case cape
    case convective_inhibition
    
    case surface_temperature
    case visibility
    case snow_depth_water_equivalent

    case shortwave_radiation
    case direct_radiation
    case uv_index
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .rain, .snowfall_water_equivalent, .precipitation: return true
        case .wind_speed_10m, .wind_direction_10m: return true
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
        case .rain:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation, .direct_radiation:
            return 1
        case .snowfall_water_equivalent:
            return 10
        case .wind_speed_10m:
            return 10
        case .snow_depth_water_equivalent:
            return 10
        case .wind_direction_10m:
            return 1
        case .visibility:
            return 0.05 // 50 meter
        case .cloud_cover_2m:
            return 1
        case .cloud_base, .cloud_top:
            return 0.05 // 20 metre
        case .precipitation:
            return 10
        case .hail:
            return 10
        case .showers:
            return 10
        case .freezing_level_height:
            return 0.1 // zero height 10 metre resolution
        case .cape:
            return 0.1
        case .convective_inhibition: return 1
        case .uv_index: return 20
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_2m:
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
        case .wind_speed_10m:
            return .hermite(bounds: 0...1000)
        case .rain, .precipitation, .hail, .showers:
            return .backwards_sum
        case .snowfall_water_equivalent, .snow_depth_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .wind_direction_10m:
            return .linearDegrees
        case .visibility:
            return .linear
        case .cloud_top, .cloud_base:
            return .hermite(bounds: 0...10e9)
        case .freezing_level_height:
            return .linear
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .uv_index:
            return .hermite(bounds: 0...1000)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m,.surface_temperature:
            return .celsius
        case .cloud_cover, .cloud_cover_2m:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .rain, .snow_depth_water_equivalent, .precipitation, .hail, .showers:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_speed_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            return .percentage
        case .visibility:
            return .metre
        case .cloud_top, .cloud_base:
            return .metre
        case .freezing_level_height:
            return .metre
        case .uv_index:
            return .dimensionless
        case .convective_inhibition: return .joulePerKilogram
        case .cape:
            return .joulePerKilogram
        }
    }
    
    func getNcFileName(domain: UkmoDomain) -> String? {
        switch self {
        case .cape:
            return "CAPE_surface"
        case .convective_inhibition:
            return "CIN_surface"
        case .cloud_cover_high:
            return "cloud_amount_of_high_cloud"
        case .temperature_2m:
            return "temperature_at_screen_level"
        case .cloud_cover:
            return "cloud_amount_of_total_cloud"
        case .cloud_cover_low:
            return  "cloud_amount_of_low_cloud"
        case .cloud_cover_mid:
            return  "cloud_amount_of_medium_cloud"
        case .cloud_cover_2m:
            return "fog_fraction_at_screen_level"
        case .cloud_base:
            return nil
        case .cloud_top:
            return nil
        case .pressure_msl:
            return "pressure_at_mean_sea_level"
        case .relative_humidity_2m:
            return "relative_humidity_at_screen_level"
        case .wind_speed_10m:
            return "wind_speed_at_10m"
        case .wind_direction_10m:
            return "wind_direction_at_10m"
        case .wind_gusts_10m:
            return "wind_direction_at_10m"
        case .precipitation:
            return "precipitation_rate" //"precipitation_accumulation-PT01H"
        case .snowfall_water_equivalent:
            return "snowfall_rate"
        case .rain:
            return "rainfall_rate" // "rainfall_accumulation-PT01H"
        case .hail:
            return nil
        case .showers:
            return "rainfall_rate_from_convection"
        case .freezing_level_height:
            return nil
        case .surface_temperature:
            return "temperature_at_surface"
        case .visibility:
            return "visibility_at_screen_level"
        case .snow_depth_water_equivalent:
            return "snow_depth_water_equivalent"
        case .shortwave_radiation:
            return "radiation_flux_in_shortwave_direct_downward_at_surface"
        case .direct_radiation:
            return nil
        case .uv_index:
            return nil
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation, .rain:
            return false
        default:
            return false
        }
    }
    
    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature:
            return (-273.15, 1) // kelvin to celsius
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .cloud_cover_2m:
            return (0, 100) // fraction to %
        case .relative_humidity_2m:
            return (0, 100) // fraction to %
        case .precipitation, .rain, .snowfall_water_equivalent, .showers, .hail:
            return (0, 100 * 3600) // ms-1 to mm/h
        case .uv_index:
            // UVB to etyhemally UV factor 18.9 https://link.springer.com/article/10.1039/b312985c
            // 0.025 m2/W to get the uv index
            // compared to https://www.aemet.es/es/eltiempo/prediccion/radiacionuv
            return (18.9 * 0.025, 0)
        case .pressure_msl:
            return (1/100, 0)
        default:
            return nil
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m:
            fallthrough
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum UkmoPressureVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case geopotential_height
    case relative_humidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct UkmoPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: UkmoPressureVariableType
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
            return .percentage
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
typealias UkmoVariable = SurfaceAndPressureVariable<UkmoSurfaceVariable, UkmoPressureVariable>
