import Foundation


enum S2SVariable6Hourly: String, GenericVariable {
    case temperature_2m_max
    case temperature_2m_min
    case wind_u_component_10m
    case wind_v_component_10m
    case precipitation
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return 20
        case .wind_u_component_10m, .wind_v_component_10m:
            return 10
        case .precipitation:
            return 10
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return .backwards
        case .wind_u_component_10m, .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return .celsius
        case .wind_u_component_10m, .wind_v_component_10m:
            return .metrePerSecond
        case .precipitation:
            return .millimetre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return true
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
    
    static func fromGrib(attributes: GribAttributes) -> Self? {
        switch attributes.shortName {
        case "10u": return .wind_u_component_10m
        case "10v": return .wind_v_component_10m
        case "mx2t6": return .temperature_2m_max
        case "mn2t6": return .temperature_2m_min
        case "tp": return .precipitation
        default:
            return nil
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return (1, -273.15)
        default:
            return nil
        }
    }
}
