

enum ArpaeSurfaceVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
    case temperature_2m
    case cloud_cover
    case pressure_msl
    case dew_point_2m
    case wind_v_component_10m
    case wind_u_component_10m
    case precipitation
    case snowfall_water_equivalent
    case surface_temperature
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .dew_point_2m: return true
        case .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .wind_u_component_10m, .wind_v_component_10m: return true
        default: return false
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature, .dew_point_2m:
            return (1, -273.15)
        case .snowfall_water_equivalent:
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
        case .dew_point_2m: return 20
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .surface_temperature: return 20
        case .pressure_msl: return 10
        case .snowfall_water_equivalent: return 10
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .linear
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .surface_temperature:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloud_cover: return .percentage
        case .dew_point_2m: return .celsius
        case .precipitation: return .millimetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .surface_temperature: return .celsius
        case .pressure_msl: return .hectopascal
        case .snowfall_water_equivalent: return .millimetre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface_temperature:
            fallthrough
        case .temperature_2m:
            return true
        default:
            return false
        }
    }
}
