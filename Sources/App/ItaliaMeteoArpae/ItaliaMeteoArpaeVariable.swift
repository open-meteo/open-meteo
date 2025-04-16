import Foundation

enum ItaliaMeteoArpaeVariablesDownload: String, CaseIterable {
    case T_2M
    case TD_2M
    case ASOB_S
    case ASWDIR_S
    case CAPE_ML
    case CIN_ML
    case CLCH
    case CLCL
    case CLCM
    case CLCT
    case HZEROCL
    case H_SNOW
    case LPI
    case PMSL
    case RAIN_CON
    case RAIN_GSP
    case RELHUM
    case SNOWLMT
    case SNOW_CON
    case SNOW_GSP
    case T
    case TQV
    case W_SO
    case T_SO
    case TOT_PREC
    case U
    case V
    case U_10M
    case V_10M
    case VMAX_10M
    case WW
    case FI
    case OMEGA
    
    var levels: [String] {
        switch self {
        case .ASOB_S, .ASWDIR_S, .H_SNOW, .LPI, .WW, .RAIN_CON, .RAIN_GSP, .SNOW_CON, .SNOW_GSP, .TOT_PREC, .TQV:
            return ["surface-0"]
        case .CAPE_ML, .CIN_ML:
            return ["atmML-0"]
        case .CLCH:
            return ["isobaricLayer-0"]
        case .CLCL:
            return ["isobaricLayer-800"]
        case .CLCM:
            return ["isobaricLayer-400"]
        case .CLCT:
            return ["surface-0"]
        case .HZEROCL, .SNOWLMT:
            return ["isothermZero-0"]
        case .PMSL:
            return ["meanSea-0"]
        case .RELHUM, .T, .U, .V, .FI, .OMEGA:
            return ["isobaricInhPa-1000", "isobaricInhPa-250", "isobaricInhPa-500", "isobaricInhPa-700", "isobaricInhPa-850", "isobaricInhPa-925"]
        case .TD_2M, .T_2M:
            return ["heightAboveGround-2"]
        case .T_SO:
            return ["depthBelowLand-0", "depthBelowLand-1", "depthBelowLand-2", "depthBelowLand-5", "depthBelowLand-15"]
        case .W_SO:
            return ["depthBelowLandLayer-0", "depthBelowLandLayer-1", "depthBelowLandLayer-2", "depthBelowLandLayer-7"]
        case .U_10M, .V_10M, .VMAX_10M:
            return ["heightAboveGround-10"]
        }
    }
    
    var keepInMemory: Bool {
        switch self {
        case .RAIN_GSP, .RAIN_CON, .SNOW_CON, .SNOWLMT, .T_2M, .U, .U_10M, .T:
            return true
        default:
            return false
        }
    }
    
    func getGenericVariable(attributes: GribAttributes) -> GenericVariable? {
        switch self {
        case .ASOB_S:
            return ItaliaMeteoArpaeSurfaceVariable.shortwave_radiation
        case .ASWDIR_S:
            return ItaliaMeteoArpaeSurfaceVariable.direct_radiation
        case .CAPE_ML:
            return ItaliaMeteoArpaeSurfaceVariable.cape
        case .CIN_ML:
            return ItaliaMeteoArpaeSurfaceVariable.convective_inhibition
        case .CLCH:
            return ItaliaMeteoArpaeSurfaceVariable.cloud_cover_high
        case .CLCL:
            return ItaliaMeteoArpaeSurfaceVariable.cloud_cover_low
        case .CLCM:
            return ItaliaMeteoArpaeSurfaceVariable.cloud_cover_mid
        case .CLCT:
            return ItaliaMeteoArpaeSurfaceVariable.cloud_cover
        case .HZEROCL:
            return ItaliaMeteoArpaeSurfaceVariable.freezing_level_height
        case .H_SNOW:
            return ItaliaMeteoArpaeSurfaceVariable.snow_depth
        case .LPI:
            return ItaliaMeteoArpaeSurfaceVariable.lightning_potential
        case .PMSL:
            return ItaliaMeteoArpaeSurfaceVariable.pressure_msl
        case .RAIN_CON:
            return nil
        case .RAIN_GSP:
            return nil
        case .RELHUM:
            return ItaliaMeteoArpaePressureVariable(variable: .relative_humidity, level: Int(attributes.levelStr)!)
        case .SNOWLMT:
            return ItaliaMeteoArpaeSurfaceVariable.snowfall_height
        case .SNOW_CON:
            return nil
        case .SNOW_GSP:
            return nil
        case .T:
            return ItaliaMeteoArpaePressureVariable(variable: .temperature, level: Int(attributes.levelStr)!)
        case .TD_2M:
            return nil
        case .T_2M:
            return ItaliaMeteoArpaeSurfaceVariable.temperature_2m
        case .T_SO:
            return nil
        case .W_SO:
            return nil
        case .TOT_PREC:
            return ItaliaMeteoArpaeSurfaceVariable.precipitation
        case .TQV:
            return ItaliaMeteoArpaeSurfaceVariable.total_column_integrated_water_vapour
        case .U:
            return nil
        case .V:
            return nil
        case .U_10M:
            return nil
        case .V_10M:
            return nil
        case .VMAX_10M:
            return ItaliaMeteoArpaeSurfaceVariable.wind_gusts_10m
        case .WW:
            return nil
        case .FI:
            return ItaliaMeteoArpaePressureVariable(variable: .geopotential_height, level: Int(attributes.levelStr)!)
        case .OMEGA:
            return nil
        }
    }
}

/**
 List of all surface ItaliaMeteoArpae variables
 */
enum ItaliaMeteoArpaeSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    
    case convective_inhibition
    
    case pressure_msl
    case relative_humidity_2m
    
    case wind_speed_10m
    case wind_direction_10m
    
    case snowfall_water_equivalent
    case showers
    case precipitation
    case rain
    
    case snow_depth
    
    case weather_code
        
    case wind_gusts_10m

    case shortwave_radiation
    case direct_radiation
    
    //case surface_temperature
    case cape
    
    /// Soil temperature
    case soil_temperature_0cm
    case soil_temperature_6cm
    case soil_temperature_18cm
    case soil_temperature_54cm
    case soil_temperature_162cm
    case soil_temperature_486cm
    case soil_temperature_1458cm
    
    /// Soil moisture
    /// The model soil moisture data was converted from kg/m2 to m3/m3 by using the formula SM[m3/m3] = SM[kg/m2] * 0.001 * 1/d, where d is the thickness of the soil layer in meters. The factor 0.001 is due to the assumption that 1kg of water represents 1000cm3, which is 0.001m3.
    case soil_moisture_0_to_1cm
    case soil_moisture_1_to_3cm
    case soil_moisture_3_to_9cm
    case soil_moisture_9_to_27cm
    case soil_moisture_27_to_81cm
    case soil_moisture_81_to_243cm
    case soil_moisture_243_to_729cm
    case soil_moisture_729_to_2187cm
    
    /// LPI Lightning Potential Index . Scales form 0 to ~120
    case lightning_potential
    
    /// Height of the 0◦ C isotherm above MSL. In case of multiple 0◦ C isotherms, HZEROCL contains the uppermost one.
    /// If the temperature is below 0◦ C throughout the entire atmospheric column, HZEROCL is set equal to the topography height (fill value).
    case freezing_level_height
    case snowfall_height
    case total_column_integrated_water_vapour
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation, .direct_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .weather_code: return true
        default: return false
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offsets if multiple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_1cm: return true
        case .soil_moisture_1_to_3cm: return true
        case .soil_moisture_3_to_9cm: return true
        case .soil_moisture_9_to_27cm: return true
        case .soil_moisture_27_to_81cm: return true
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
        case .cloud_cover: return 1
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .precipitation: return 10
        case .weather_code: return 1
        case .wind_speed_10m: return 10
        case .wind_direction_10m: return 1
        case .soil_temperature_0cm: return 20
        case .soil_temperature_6cm: return 20
        case .soil_temperature_18cm: return 20
        case .soil_temperature_54cm, .soil_temperature_162cm, .soil_temperature_486cm, .soil_temperature_1458cm: return 20
        case .soil_moisture_0_to_1cm: return 1000
        case .soil_moisture_1_to_3cm: return 1000
        case .soil_moisture_3_to_9cm: return 1000
        case .soil_moisture_9_to_27cm: return 1000
        case .soil_moisture_27_to_81cm, .soil_moisture_81_to_243cm, .soil_moisture_243_to_729cm, .soil_moisture_729_to_2187cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .wind_gusts_10m: return 10
        case .freezing_level_height:  return 0.1 // zero height 10 meter resolution
        case .relative_humidity_2m: return 1
        case .shortwave_radiation: return 1
        case .direct_radiation: return 1
        case .showers: return 10
        case .rain: return 10
        case .pressure_msl: return 10
        case .snowfall_water_equivalent: return 10
        case .cape:
            return 0.1
        case .lightning_potential:
            return 10
        case .snowfall_height:
            return 0.1
        case .convective_inhibition:
            return 1
        case .total_column_integrated_water_vapour:
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
        case .precipitation:
            return .backwards_sum
        case .weather_code:
            return .backwards
        case .wind_speed_10m:
            return .hermite(bounds: 0...10e6)
        case .wind_direction_10m:
            return .linearDegrees
        case .soil_temperature_0cm:
            return .hermite(bounds: nil)
        case .soil_temperature_6cm:
            return .hermite(bounds: nil)
        case .soil_temperature_18cm:
            return .hermite(bounds: nil)
        case .soil_temperature_54cm, .soil_temperature_162cm, .soil_temperature_486cm, .soil_temperature_1458cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_1cm:
            return .hermite(bounds: nil)
        case .soil_moisture_1_to_3cm:
            return .hermite(bounds: nil)
        case .soil_moisture_3_to_9cm:
            return .hermite(bounds: nil)
        case .soil_moisture_9_to_27cm:
            return .hermite(bounds: nil)
        case .soil_moisture_27_to_81cm, .soil_moisture_81_to_243cm, .soil_moisture_243_to_729cm, .soil_moisture_729_to_2187cm:
            return .hermite(bounds: nil)
        case .snow_depth:
            return .linear
        case .showers:
            return .backwards_sum
        case .rain:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .lightning_potential:
            return .linear
        case .wind_gusts_10m:
            return .linear
        case .snowfall_height:
            return .linear
        case .freezing_level_height:
            return .linear
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .direct_radiation:
            return .solar_backwards_averaged
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .total_column_integrated_water_vapour:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
            case .temperature_2m: return .celsius
            case .cloud_cover: return .percentage
            case .cloud_cover_low: return .percentage
            case .cloud_cover_mid: return .percentage
            case .cloud_cover_high: return .percentage
            case .precipitation: return .millimetre
            case .weather_code: return .wmoCode
            case .wind_speed_10m: return .metrePerSecond
            case .wind_direction_10m: return .degreeDirection
            case .soil_temperature_0cm: return .celsius
            case .soil_temperature_6cm: return .celsius
            case .soil_temperature_18cm: return .celsius
            case .soil_temperature_54cm, .soil_temperature_162cm, .soil_temperature_486cm, .soil_temperature_1458cm: return .celsius
            case .soil_moisture_0_to_1cm: return .cubicMetrePerCubicMetre
            case .soil_moisture_1_to_3cm: return .cubicMetrePerCubicMetre
            case .soil_moisture_3_to_9cm: return .cubicMetrePerCubicMetre
            case .soil_moisture_9_to_27cm: return .cubicMetrePerCubicMetre
            case .soil_moisture_27_to_81cm, .soil_moisture_81_to_243cm, .soil_moisture_243_to_729cm, .soil_moisture_729_to_2187cm: return .cubicMetrePerCubicMetre
            case .snow_depth: return .metre
            case .showers: return .millimetre
            case .rain: return .millimetre
            case .wind_gusts_10m: return .metrePerSecond
            case .freezing_level_height: return .metre
            case .relative_humidity_2m: return .percentage
            case .shortwave_radiation: return .wattPerSquareMetre
            case .snowfall_water_equivalent: return .millimetre
            case .direct_radiation: return .wattPerSquareMetre
            case .pressure_msl: return .hectopascal
            case .cape:
                return .joulePerKilogram
            case .lightning_potential:
                return .joulePerKilogram
            case .snowfall_height:
                return .metre
            case .convective_inhibition:
                return .joulePerKilogram
            case .total_column_integrated_water_vapour:
                return .kilogramPerSquareMetre
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .soil_temperature_0cm || self == .soil_temperature_6cm ||
            self == .soil_temperature_18cm || self == .soil_temperature_54cm
    }
}

/**
 Types of pressure level variables
 */
enum ItaliaMeteoArpaePressureVariableType: String, CaseIterable {
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
struct ItaliaMeteoArpaePressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: ItaliaMeteoArpaePressureVariableType
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
            return .hermite(bounds: 0...10e6)
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
}
/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias ItaliaMeteoArpaeVariable = SurfaceAndPressureVariable<ItaliaMeteoArpaeSurfaceVariable, ItaliaMeteoArpaePressureVariable>
