

/// 6-hourly variables in O320 grid
/// 10U/10V/2D/2T/MSL/SF/SSRD/SST/STL1/TCC/TP
enum EcmwfSeasVariableSingleLevel: String, GenericVariable {
    case temperature_2m
    case dew_point_2m
    case pressure_msl
    case sea_surface_temperature
    case wind_u_component_10m
    case wind_v_component_10m
    case snowfall_water_equivalent
    case precipitation
    case shortwave_radiation
    case soil_temperature_0_to_7cm
    case cloud_cover
    
    static func from(shortName: String) -> Self? {
        switch shortName {
        case "10u":
            return .wind_u_component_10m
        case "10v":
            return .wind_v_component_10m
        case "2d":
            return .dew_point_2m
        case "2t":
            return .temperature_2m
        case "msl":
            return .pressure_msl
        case "sf":
            return .snowfall_water_equivalent
        case "ssrd":
            return .shortwave_radiation
        case "stl1":
            return .temperature_2m
        case "tcc":
            return .cloud_cover
        case "tp":
            return .precipitation
        default:
            return nil
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .dew_point_2m:
            return 20
        case .pressure_msl:
            return 10
        case .sea_surface_temperature:
            return 20
        case .wind_u_component_10m, .wind_v_component_10m:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .precipitation:
            return 10
        case .shortwave_radiation:
            return 1
        case .soil_temperature_0_to_7cm:
            return 20
        case .cloud_cover:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .sea_surface_temperature:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .precipitation:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .soil_temperature_0_to_7cm:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .dew_point_2m:
            return .celsius
        case .pressure_msl:
            return .hectopascal
        case .sea_surface_temperature:
            return .celsius
        case .wind_u_component_10m, .wind_v_component_10m:
            return .metrePerSecond
        case .snowfall_water_equivalent:
            return .millimetre
        case .precipitation:
            return .millimetre
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .soil_temperature_0_to_7cm:
            return .celsius
        case .cloud_cover:
            return .percentage
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .dew_point_2m, .soil_temperature_0_to_7cm:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .shortwave_radiation:
            return (1 / 6*3600, 0)
        default:
            return nil
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m, .dew_point_2m, .soil_temperature_0_to_7cm: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/// 24 hourly variables in O320 grid
/// STL1/STL2/STL3/STL4/SUND/SWVL1/SWVL2/SWVL3/SWVL4
/// MEAN2T24/MN2T24/MX2T24
enum EcmwfSeasVariable24HourlySingleLevel: String, GenericVariable {
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    
    case temperature_2m_max24h
    case temperature_2m_min24h
    case temperature_2m_mean24h
    
    case sunshine_duration
    
    static func from(shortName: String) -> Self? {
        switch shortName {
        case "stl1":
            return .soil_temperature_0_to_7cm
        case "stl2":
            return .soil_temperature_7_to_28cm
        case "stl3":
            return .soil_temperature_28_to_100cm
        case "stl4":
            return .soil_temperature_100_to_255cm
        case "sund":
            return .sunshine_duration
        case "swvl1":
            return .soil_moisture_0_to_7cm
        case "swvl2":
            return .soil_moisture_7_to_28cm
        case "swvl3":
            return .soil_moisture_28_to_100cm
        case "swvl4":
            return .soil_moisture_100_to_255cm
        default:
            return nil
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm:
            return (1, -273.15)
        case .temperature_2m_max24h, .temperature_2m_min24h, .temperature_2m_mean24h:
            return (1, -273.15)
        default:
            return nil
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm:
            return 20
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return 1000
        case .temperature_2m_max24h, .temperature_2m_min24h, .temperature_2m_mean24h:
            return 20
        case .sunshine_duration:
            return 1/60
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return .hermite(bounds: nil)
        case .temperature_2m_max24h, .temperature_2m_min24h, .temperature_2m_mean24h:
            return .backwards
        case .sunshine_duration:
            return .backwards
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm:
            return .celsius
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return .cubicMetrePerCubicMetre
        case .temperature_2m_max24h, .temperature_2m_min24h, .temperature_2m_mean24h:
            return .celsius
        case .sunshine_duration:
            return .seconds
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm:
            return true
        case .temperature_2m_max24h, .temperature_2m_min24h, .temperature_2m_mean24h:
            return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return true
        default:
            return false
        }
    }
}

/// Only available as 6-hourly data in N160 grid
/// Model levels 85/87/89 https://confluence.ecmwf.int/display/UDOC/L91+model+level+definitions
/// 85=309.04m, 87=167.39m, 89=67.88m
enum EcmwfSeasVariableUpperLevel: String, GenericVariable {
    case temperature_850hPa
    case temperature_500hPa
    case geopotential_height_500hPa
    case geopotential_height_850hPa
    
    case relative_humidity_70m
    case relative_humidity_170m
    case relative_humidity_310m
    case temperature_70m
    case temperature_170m
    case temperature_310m
    case wind_u_component_70m
    case wind_u_component_170m
    case wind_u_component_310m
    case wind_v_component_70m
    case wind_v_component_170m
    case wind_v_component_310m
    
    static func from(shortName: String, level: String) -> Self? {
        switch (shortName, level) {
        case ("t", "850"):
            return .temperature_850hPa
        case ("t", "500"):
            return .temperature_500hPa
        case ("gh", "850"):
            return .geopotential_height_850hPa
        case ("t", "500"):
            return .geopotential_height_500hPa
        case ("t", "85"):
            return .temperature_310m
        case ("t", "87"):
            return .temperature_170m
        case ("t", "89"):
            return .temperature_70m
        case ("q", "85"):
            return .relative_humidity_310m
        case ("q", "87"):
            return .relative_humidity_170m
        case ("q", "89"):
            return .relative_humidity_70m
        case ("u", "85"):
            return .wind_u_component_310m
        case ("u", "87"):
            return .wind_u_component_170m
        case ("u", "89"):
            return .wind_u_component_70m
        case ("v", "85"):
            return .wind_v_component_310m
        case ("v", "87"):
            return .wind_v_component_170m
        case ("v", "89"):
            return .wind_v_component_70m
        default:
            return nil
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_850hPa, .temperature_500hPa:
            return (1, -273.15)
        case .geopotential_height_500hPa, .geopotential_height_850hPa:
            return (1 / 9.80665, 0)
        default:
            return nil
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_850hPa, .temperature_500hPa:
            return 20
        case .geopotential_height_500hPa, .geopotential_height_850hPa:
            return 1
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return 1
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return 20
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return 10
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return 10
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_850hPa, .temperature_500hPa:
            return .hermite(bounds: nil)
        case .geopotential_height_500hPa, .geopotential_height_850hPa:
            return .hermite(bounds: nil)
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return .hermite(bounds: 0...100)
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return .hermite(bounds: nil)
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return .hermite(bounds: nil)
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_850hPa, .temperature_500hPa:
            return .celsius
        case .geopotential_height_500hPa, .geopotential_height_850hPa:
            return .metre
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return .celsius
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return .celsius
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return .metrePerSecond
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return .metrePerSecond
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

