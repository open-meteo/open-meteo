import Foundation

/// Required additions to a GFS variable to make it downloadable
protocol BomVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
}

enum BomSurfaceVariable: String, CaseIterable, GenericVariableMixable, BomVariableDownloadable {
    // ml has 1h delay! ml analysis has a lot of levels!
    // ml temp: 20 53.3 100 160
    // ml wind: 10 36.6 76.6 130
    
    case showers
    case precipitation
    case pressure_msl
    case direct_radiation
    case shortwave_radiation
    case temperature_2m
    case relative_humidity_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case surface_temperature
    case snow_depth
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    case soil_temperature_10cm
    case soil_temperature_35cm
    case soil_temperature_100cm
    case soil_temperature_300cm
    
    case soil_moisture_10cm
    case soil_moisture_35cm
    case soil_moisture_100cm
    case soil_moisture_300cm
    
    case visibility
    //case thunderstorm_probability // bright et all 0-1000K
    
    case wind_gusts_10m
    
    //case snow_large_scale
    //case snow_showers
    
    var bomName: String {
        switch self {
        case .temperature_2m: "temp_scrn"
        case .showers: "accum_conv_rain"
        case .precipitation: "accum_prcp"
        case .pressure_msl: "mslp" //Pa
        case .direct_radiation: "av_sfc_sw_dir"
        case .shortwave_radiation: "av_swsfcdown"
        case .relative_humidity_2m: "rh_scrn" // %, BUT >117%
        case .cloud_cover: "ttl_cld"
        case .cloud_cover_high: "hi_cld" //0-1
        case .cloud_cover_mid: "mid_cld"
        case .cloud_cover_low: "low_cld"
        case .surface_temperature: "sfc_temp"
        case .snow_depth: "snow_amt_lnd" // kg/m2
        case .soil_temperature_10cm: "soil_temp"
        case .soil_temperature_35cm: "soil_temp2"
        case .soil_temperature_100cm: "soil_temp3"
        case .soil_temperature_300cm: "soil_temp4"
        case .soil_moisture_10cm: "soil_mois"
        case .soil_moisture_35cm: "soil_mois2"
        case .soil_moisture_100cm: "soil_mois3"
        case .soil_moisture_300cm: "soil_mois4"
        case .wind_v_component_10m: "uwnd10m"
        case .wind_u_component_10m: "vwnd10m"
        case .visibility: "visibility"
        case .wind_gusts_10m: "wndgust10m"
        //case .thunderstorm_probability: "cld_phys_thunder_p"
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_10cm: return true
        case .soil_moisture_35cm: return true
        case .soil_moisture_100cm: return true
        case .soil_moisture_300cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature, .soil_temperature_10cm, .soil_temperature_35cm, .soil_temperature_100cm, .soil_temperature_300cm:
            return (1, -273.15)
        case .snow_depth:
            return (0.7/100, 0)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return (100, 0)
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
        case .surface_temperature: return 20
        case .soil_temperature_10cm: return 20
        case .soil_temperature_35cm: return 20
        case .soil_temperature_100cm: return 20
        case .soil_temperature_300cm: return 20
        case .soil_moisture_10cm: return 1000
        case .soil_moisture_35cm: return 1000
        case .soil_moisture_100cm: return 1000
        case .soil_moisture_300cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .wind_gusts_10m: return 10
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .direct_radiation: return 1
        case .visibility: return 0.05 // 50 meter
        //case .snowfall: return 10
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
        case .surface_temperature:
            return .hermite(bounds: nil)
        case .soil_temperature_10cm:
            return .hermite(bounds: nil)
        case .soil_temperature_35cm:
            return .hermite(bounds: nil)
        case .soil_temperature_100cm:
            return .hermite(bounds: nil)
        case .soil_temperature_300cm:
            return .hermite(bounds: nil)
        case .soil_moisture_10cm:
            return .hermite(bounds: nil)
        case .soil_moisture_35cm:
            return .hermite(bounds: nil)
        case .soil_moisture_100cm:
            return .hermite(bounds: nil)
        case .soil_moisture_300cm:
            return .hermite(bounds: nil)
        case .snow_depth:
            return .linear
        case .showers:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .visibility:
            return .linear
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
        case .surface_temperature: return .celsius
        case .soil_temperature_10cm: return .celsius
        case .soil_temperature_35cm: return .celsius
        case .soil_temperature_100cm: return .celsius
        case .soil_temperature_300cm: return .celsius
        case .soil_moisture_10cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_35cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_300cm: return .cubicMetrePerCubicMetre
        case .snow_depth: return .metre
        case .showers: return .millimetre
        case .wind_gusts_10m: return .metrePerSecond
        case .pressure_msl: return .hectopascal
        case .shortwave_radiation, .direct_radiation: return .wattPerSquareMetre
        case .visibility: return .metre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface_temperature:
            fallthrough
        case .soil_temperature_10cm:
            fallthrough
        case .soil_temperature_35cm:
            fallthrough
        case .soil_temperature_100cm:
            fallthrough
        case .soil_temperature_300cm:
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
enum BomPressureVariableType: String, CaseIterable {
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
struct BomPressureVariable: PressureVariableRespresentable, Hashable, GenericVariableMixable, BomVariableDownloadable {
    let variable: BomPressureVariableType
    let level: Int
    
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
typealias BomVariable = SurfaceAndPressureVariable<BomSurfaceVariable, BomPressureVariable>
