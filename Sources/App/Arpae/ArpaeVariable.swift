

enum ArpaeSurfaceVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case relative_humidity_2m
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    case wind_gusts_10m
    
    case precipitation
    case showers
    case snowfall_water_equivalent
    case surface_temperature
    case freezing_level_height
    
    case cape
    case convective_inhibition
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .wind_gusts_10m, .wind_u_component_10m, .wind_v_component_10m: return true
        case .cape: return true
        default: return false
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature:
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
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .relative_humidity_2m: return 1
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .surface_temperature: return 20
        case .wind_gusts_10m: return 10
        case .showers: return 10
        case .pressure_msl: return 10
        case .cape: return 0.1
        case .convective_inhibition: return 1
        case .snowfall_water_equivalent: return 10
        case .freezing_level_height:  return 0.1 // zero height 10 meter resolution
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
        case .showers:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .freezing_level_height:
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
        case .relative_humidity_2m: return .percentage
        case .precipitation: return .millimetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .surface_temperature: return .celsius
        case .showers: return .millimetre
        case .wind_gusts_10m: return .metrePerSecond
        case .pressure_msl: return .hectopascal
        case .cape: return .joulePerKilogram
        case .convective_inhibition: return .joulePerKilogram
        case .snowfall_water_equivalent: return .centimetre
        case .freezing_level_height: return .metre
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
