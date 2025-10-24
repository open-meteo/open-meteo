/// 6-hourly variables in O320 grid
/// 10u/10v/100u/100v/2d/2t/msl/200u/200v/cp/sst/sf/stl1/stl2/stl3/stl4/fdir/ssrd/tcc/tp/10fg/sund/mx2t6/mn2t6/swvl1/swvl2/swvl3/swvl4
/// 0/to/1104/by/6
enum EcmwfEC46Variable6Hourly: String, EcmwfSeasVariable, CaseIterable {
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
    
    // Variables above are also in SEAS5
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_200m
    case wind_v_component_200m
    case direct_radiation
    case temperature_2m_max
    case temperature_2m_min
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case showers
    case wind_gusts_10m
    case sunshine_duration
    
    var gribCode: String {
        switch self {
        case .wind_u_component_10m:
            return "10u"
        case .wind_v_component_10m:
            return "10v"
        case .wind_u_component_100m:
            return "100u"
        case .wind_v_component_100m:
            return "100v"
        case .wind_u_component_200m:
            return "200u"
        case .wind_v_component_200m:
            return "200v"
        case .soil_temperature_0_to_7cm:
            return "stl1"
        case .soil_temperature_7_to_28cm:
            return "stl2"
        case .soil_temperature_28_to_100cm:
            return "stl3"
        case .soil_temperature_100_to_255cm:
            return "stl4"
        case .soil_moisture_0_to_7cm:
            return "swvl1"
        case .soil_moisture_7_to_28cm:
            return "swvl2"
        case .soil_moisture_28_to_100cm:
            return "swvl3"
        case .soil_moisture_100_to_255cm:
            return "swvl4"
        case .cloud_cover:
            return "tcc"
        case .showers:
            return "cp"
        case .direct_radiation:
            return "fdir"
        case .temperature_2m:
            return "2t"
        case .wind_gusts_10m:
            return "10fg"
        case .dew_point_2m:
            return "2d"
        case .pressure_msl:
            return "msl"
        case .temperature_2m_min:
            return "mn2t6"
        case .temperature_2m_max:
            return "mx2t6"
        case .snowfall_water_equivalent:
            return "sf"
        case .shortwave_radiation:
            return "ssrd"
        case .precipitation:
            return "tp"
        case .sea_surface_temperature:
            return "sst"
        case .sunshine_duration:
            return "sund"
        }
    }
    
    static func from(shortName: String) -> Self? {
        return Self.allCases.first(where: { $0.gribCode == shortName })
    }
    
    var shift24h: Bool {
        return false
    }
    
    var skipHour0: Bool {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return true
        default:
            return isAccumulated
        }
    }
    
    var isAccumulated: Bool {
        switch self {
        case .precipitation, .snowfall_water_equivalent ,.showers:
            return true
        case .shortwave_radiation, .direct_radiation, .sunshine_duration:
            return true
        default:
            return false
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min:
            return 20
        case .dew_point_2m:
            return 20
        case .pressure_msl:
            return 10
        case .sea_surface_temperature:
            return 20
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m:
            return 10
        case .wind_gusts_10m: return 10
        case .snowfall_water_equivalent:
            return 10
        case .precipitation, .showers:
            return 10
        case .shortwave_radiation:
            return 1
        case .soil_temperature_0_to_7cm: return 20
        case .soil_temperature_7_to_28cm: return 20
        case .soil_temperature_28_to_100cm: return 20
        case .soil_temperature_100_to_255cm: return 20
        case .direct_radiation: return 1
        case .soil_moisture_0_to_7cm: return 1000
        case .soil_moisture_7_to_28cm: return 1000
        case .soil_moisture_28_to_100cm: return 1000
        case .soil_moisture_100_to_255cm: return 1000
        case .cloud_cover:
            return 1
        case .sunshine_duration:
            return 1/60
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return .backwards
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .sea_surface_temperature:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_200m, .wind_v_component_200m, .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .precipitation, .showers:
            return .backwards_sum
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .soil_temperature_0_to_7cm:
            return .hermite(bounds: nil)
        case .soil_temperature_7_to_28cm:
            return .hermite(bounds: nil)
        case .soil_temperature_28_to_100cm:
            return .hermite(bounds: nil)
        case .soil_temperature_100_to_255cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_7cm:
            return .hermite(bounds: nil)
        case .soil_moisture_7_to_28cm:
            return .hermite(bounds: nil)
        case .soil_moisture_28_to_100cm:
            return .hermite(bounds: nil)
        case .soil_moisture_100_to_255cm:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .sunshine_duration:
            return .backwards
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min:
            return .celsius
        case .dew_point_2m:
            return .celsius
        case .pressure_msl:
            return .hectopascal
        case .sea_surface_temperature:
            return .celsius
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m, .wind_gusts_10m:
            return .metrePerSecond
        case .snowfall_water_equivalent:
            return .millimetre
        case .precipitation, .showers:
            return .millimetre
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .soil_moisture_0_to_7cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_7_to_28cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_28_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_255cm: return .cubicMetrePerCubicMetre
        case .cloud_cover:
            return .percentage
        case .sunshine_duration:
            return .seconds
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .sea_surface_temperature, .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .cloud_cover:
            return (100, 0)
        case .shortwave_radiation, .direct_radiation:
            return (1 / (6*3600), 0)
        case .precipitation, .snowfall_water_equivalent, .showers:
            return (1000, 0) // meters to millimeter
        default:
            return nil
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
}
