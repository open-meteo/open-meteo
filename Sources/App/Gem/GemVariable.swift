import Foundation

/**
 Protocol to define meta information to download
 */
protocol GemVariableDownloadable: GenericVariable {
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)?
    var skipHour0: Bool { get }
    func includedFor(hour: Int, domain: GemDomain) -> Bool
    func gribName(domain: GemDomain) -> String?
}

/**
 List of available GEM variables to download
 */
enum GemSurfaceVariable: String, CaseIterable, GemVariableDownloadable, GenericVariableMixable {
    case temperature_2m
    case temperature_40m
    case temperature_80m
    case temperature_120m
    case relative_humidity_2m
    case cloud_cover
    case pressure_msl
    
    case shortwave_radiation
    
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_40m
    case wind_direction_40m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_120m
    case wind_direction_120m
    
    /// there is also min/max
    case wind_gusts_10m
    
    case showers
    
    case snowfall_water_equivalent
    
    case snow_depth
    
    case soil_temperature_0_to_10cm
    case soil_moisture_0_to_10cm
    
    
    /// accumulated since forecast start `kg m-2 sec-1`
    case precipitation
    
    case cape
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .wind_speed_80m, .wind_direction_80m: return true
        case .wind_speed_120m, .wind_direction_120m: return true
        case .cape: return true
        default: return false
        }
    }
    
    //case cin
    
    //case lifted_index
    
    func gribName(domain: GemDomain) -> String? {
        switch domain {
        case .gem_global:
            fallthrough
        case .gem_regional:
            switch self {
            case .temperature_2m:
                return "TMP_TGL_2"
            case .temperature_40m:
                return "TMP_TGL_40"
            case .temperature_80m:
                return "TMP_TGL_80"
            case .temperature_120m:
                return "TMP_TGL_120"
            case .wind_speed_10m:
                return "WIND_TGL_10"
            case .wind_direction_10m:
                return "WDIR_TGL_10"
            case .wind_speed_40m:
                return "WIND_TGL_40"
            case .wind_direction_40m:
                return "WDIR_TGL_40"
            case .wind_speed_80m:
                return "WIND_TGL_80"
            case .wind_direction_80m:
                return "WDIR_TGL_80"
            case .wind_speed_120m:
                return "WIND_TGL_120"
            case .wind_direction_120m:
                return "WDIR_TGL_120"
            case .relative_humidity_2m:
                return "RH_TGL_2"
            case .showers:
                return "ACPCP_SFC_0"
            case .cloud_cover:
                return "TCDC_SFC_0"
            case .pressure_msl:
                return "PRMSL_MSL_0"
            case .shortwave_radiation:
                return "DSWRF_SFC_0"
            case .wind_gusts_10m:
                return "GUST_TGL_10"
            case .precipitation:
                return "APCP_SFC_0"
            case .snowfall_water_equivalent:
                return "WEASN_SFC_0"
            case .cape:
                return "CAPE_SFC_0"
            //case .cin:
            //    return "CIN_SFC_0"
            //case .lifted_index:
            //    return "4LFTX_SFC_0"
            case .soil_temperature_0_to_10cm:
                return "TSOIL_SFC_0"
            case .soil_moisture_0_to_10cm:
                return "SOILW_DBLY_10"
            case .snow_depth:
                return "SNOD_SFC_0"
            }
        case .gem_hrdps_continental:
            switch self {
            case .temperature_2m:
                return "TMP_AGL-2m"
            case .temperature_40m:
                return "TMP_AGL-40m"
            case .temperature_80m:
                return "TMP_AGL-80m"
            case .temperature_120m:
                return "TMP_AGL-120m"
            case .relative_humidity_2m:
                return "RH_AGL-2m"
            case .cloud_cover:
                return "TCDC_Sfc"
            case .pressure_msl:
                return "PRMSL_MSL"
            case .shortwave_radiation:
                return "DSWRF_Sfc"
            case .wind_speed_10m:
                return "WIND_AGL-10m"
            case .wind_direction_10m:
                return "WDIR_AGL-10m"
            case .wind_speed_40m:
                return "WIND_AGL-40m"
            case .wind_direction_40m:
                return "WDIR_AGL-40m"
            case .wind_speed_80m:
                return "WIND_AGL-80m"
            case .wind_direction_80m:
                return "WDIR_AGL-80m"
            case .wind_speed_120m:
                return "WIND_AGL-120m"
            case .wind_direction_120m:
                return "WDIR_AGL-120m"
            case .wind_gusts_10m:
                return "GUST_AGL-10m"
            case .showers:
                return "ACPCP_Sfc"
            case .snowfall_water_equivalent:
                return "WEASN_Sfc"
            case .soil_temperature_0_to_10cm:
                return "TSOIL_DBS-0-10cm"
            case .soil_moisture_0_to_10cm:
                return "SOILW_DBS-0-10cm"
            case .precipitation:
                return "APCP_Sfc"
            case .cape:
                return "CAPE_Sfc"
            case .snow_depth:
                return "SNOD_Sfc"
            }
        case .gem_global_ensemble:
            switch self {
            case .relative_humidity_2m:
                return "RH_TGL_2m"
            case .showers:
                return nil
            case .wind_speed_10m:
                return "UGRD_TGL_10m"
            case .wind_direction_10m:
                return "VGRD_TGL_10m"
            case .wind_speed_40m:
                return nil
            case .wind_direction_40m:
                return nil
            case .wind_speed_80m:
                return nil
            case .wind_direction_80m:
                return nil
            case .wind_speed_120m:
                return nil
            case .wind_direction_120m:
                return nil
            case .temperature_2m:
                return "TMP_TGL_2m"
            case .temperature_40m:
                return nil
            case .temperature_80m:
                return nil
            case .temperature_120m:
                return nil
            case .snowfall_water_equivalent:
                return "ASNOW_SFC_0"
            case .soil_temperature_0_to_10cm:
                return nil
            case .soil_moisture_0_to_10cm:
                return nil
            case .cloud_cover:
                return "TCDC_SFC_0"
            case .pressure_msl:
                return "PRMSL_MSL_0"
            case .shortwave_radiation:
                return "DSWRF_SFC_0"
            case .precipitation:
                return "APCP_SFC_0"
            case .cape:
                return "CAPE_SFC_0"
            case .wind_gusts_10m:
                return nil
            case .snow_depth:
                return "SNOD_SFC_0"
            }
        }
    }
    
    func includedFor(hour: Int, domain: GemDomain) -> Bool {
        if self == .cape && hour >= 171 {
            return false
        }
        return true
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    /// If this variable is winddirection, return the counterpater windspeed variable. Used to calculate data while downloading
    var winddirectionCounterPartVariable: Self? {
        switch self {
        case .wind_direction_10m:
            return .wind_speed_10m
        case .wind_direction_40m:
            return .wind_speed_40m
        case .wind_direction_80m:
            return .wind_speed_80m
        case .wind_direction_120m:
            return .wind_speed_120m
        default:
            return nil
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloud_cover:
            return 1
        case .precipitation:
            return 10
        case .pressure_msl:
            return 10
        case .wind_speed_10m:
            fallthrough
        case .wind_speed_40m:
            fallthrough
        case .wind_speed_80m:
            fallthrough
        case .wind_speed_120m:
            return 10
        case .wind_direction_10m:
            fallthrough
        case .wind_direction_40m:
            fallthrough
        case .wind_direction_80m:
            fallthrough
        case .wind_direction_120m:
            return 1
        case .soil_temperature_0_to_10cm:
            return 20
        case .soil_moisture_0_to_10cm:
            return 1000
        case .shortwave_radiation:
            return 1
        case .temperature_40m:
            return 20
        case .temperature_80m:
            return 20
        case .temperature_120m:
            return 20
        case .relative_humidity_2m:
            return 1
        case .wind_gusts_10m:
            return 10
        case .showers:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .cape:
            return 0.1
        case .snow_depth:
            return 100 // 1cm res
        }
    }
    
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_40m:
            fallthrough
        case .temperature_80m:
            fallthrough
        case .temperature_120m:
            fallthrough
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .shortwave_radiation:
            return (1/Float(dtSeconds), 0) // joules to watt
        default:
            return nil
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .temperature_40m:
            return .hermite(bounds: nil)
        case .temperature_80m:
            return .hermite(bounds: nil)
        case .temperature_120m:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            fallthrough
        case .wind_speed_40m:
            fallthrough
        case .wind_speed_80m:
            fallthrough
        case .wind_speed_120m:
            return .hermite(bounds: nil)
        case .wind_direction_10m:
            fallthrough
        case .wind_direction_40m:
            fallthrough
        case .wind_direction_80m:
            fallthrough
        case .wind_direction_120m:
            // TODO need a better interpolation for wind direction
            return .backwards
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .showers:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .soil_temperature_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm:
            return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .snow_depth:
            return .linear
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloud_cover:
            return .percentage
        case .precipitation:
            return .millimetre
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .temperature_40m:
            return .celsius
        case .temperature_80m:
            return .celsius
        case .temperature_120m:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .wind_speed_10m:
            fallthrough
        case .wind_speed_40m:
            fallthrough
        case .wind_speed_80m:
            fallthrough
        case .wind_speed_120m:
            fallthrough
        case .wind_gusts_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            fallthrough
        case .wind_direction_40m:
            fallthrough
        case .wind_direction_80m:
            fallthrough
        case .wind_direction_120m:
            return .degreeDirection
        case .showers:
            return .millimetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .soil_temperature_0_to_10cm:
            return .celsius
        case .soil_moisture_0_to_10cm:
            return .cubicMetrePerCubicMetre
        case .cape:
            return .joulePerKilogram
        case .snow_depth:
            return .metre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .temperature_2m:
            fallthrough
        case .temperature_40m:
            fallthrough
        case .temperature_80m:
            fallthrough
        case .temperature_120m:
            return true
        default:
            return false
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return self == .soil_moisture_0_to_10cm || self == .snow_depth
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .showers: return true
        case .snowfall_water_equivalent: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum GemPressureVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case geopotential_height
    case relative_humidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct GemPressureVariable: PressureVariableRespresentable, GemVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: GemPressureVariableType
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
    func gribName(domain: GemDomain) -> String? {
        let isbl = (domain == .gem_hrdps_continental || domain == .gem_global_ensemble) ? "ISBL_\(level.zeroPadded(len: 4))" : "ISBL_\(level)"
        switch variable {
        case .temperature:
            return "TMP_\(isbl)"
        case .wind_speed:
            return "WIND_\(isbl)"
        case .wind_direction:
            return "WDIR_\(isbl)"
        case .geopotential_height:
            return "HGT_\(isbl)"
        case .relative_humidity:
            return "RH_\(isbl)"
        }
    }
    
    func includedFor(hour: Int, domain: GemDomain) -> Bool {
        if domain == .gem_global_ensemble {
            // temperature and RH is missing for level 300 hpa
            if (variable == .temperature || variable == .relative_humidity) && level == 300 {
                return false
            }
            return true
        }
        // Since 2003-05-16, upper level geopotenial is missing for hour 46...
        if domain == .gem_hrdps_continental && hour == 46 && variable == .geopotential_height && [175, 200].contains(level) {
            return false
        }
        if hour >= 171 && hour % 6 != 0 && variable == .relative_humidity {
            return false
        }
        if hour >= 171 && hour % 6 != 0 && ![1000, 925, 850, 700, 500, 5, 1].contains(level) {
            return false
        }
        return true
    }
    
    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .wind_speed:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .wind_direction:
            return (0.2..<0.5).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        case .wind_speed:
            return .hermite(bounds: nil)
        case .wind_direction:
            // TODO better interpolation for wind direction
            return .backwards
        case .geopotential_height:
            return .hermite(bounds: nil)
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        default:
            return nil
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
    
    var skipHour0: Bool {
        return false
    }
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias GemVariable = SurfaceAndPressureVariable<GemSurfaceVariable, GemPressureVariable>

