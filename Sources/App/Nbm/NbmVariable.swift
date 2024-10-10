import Foundation


/**
 List of all surface NBM variables to download
 */
enum NbmSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case relative_humidity_2m
    case precipitation
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m
    case snowfall_water_equivalent
    case wind_gusts_10m
    case shortwave_radiation
    case cape
    case visibility
    case thunderstorm_probability
    case precipitation_probability
    case rain_probability
    case freezing_rain_probability
    case ice_pellets_probability
    case snowfall_probability
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .snowfall_water_equivalent: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .cape: return true
        case .precipitation_probability, .thunderstorm_probability, .rain_probability, .freezing_rain_probability, .ice_pellets_probability, .snowfall_probability: return true
        case .wind_speed_80m, .wind_direction_80m: return true
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
        case .temperature_2m: return 20
        case .cloud_cover: return 1
        case .relative_humidity_2m: return 1
        case .precipitation: return 10
        case .wind_speed_10m, .wind_speed_80m: return 10
        case .wind_direction_10m, .wind_direction_80m: return 1
        //case .surface_temperature: return 20
        case .snowfall_water_equivalent: return 10
        case .wind_gusts_10m: return 10
        //case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .cape: return 0.1
        case .visibility: return 0.05 // 50 meter
        case .precipitation_probability, .thunderstorm_probability, .rain_probability, .freezing_rain_probability, .ice_pellets_probability, .snowfall_probability:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .wind_speed_10m, .wind_speed_80m:
            return .hermite(bounds: 0...1e9)
        case .wind_direction_10m, .wind_direction_80m:
            return .linearDegrees
        case .cloud_cover:
            return .linear
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .precipitation:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: 0...1e9)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .visibility:
            return .linear
        case .precipitation_probability, .thunderstorm_probability:
            return .backwards
        case .rain_probability, .freezing_rain_probability, .ice_pellets_probability, .snowfall_probability:
            return .linear
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloud_cover: return .percentage
        case .relative_humidity_2m: return .percentage
        case .precipitation, .snowfall_water_equivalent: return .millimetre
        case .wind_speed_10m, .wind_speed_80m: return .metrePerSecond
        case .wind_direction_10m, .wind_direction_80m: return .degreeDirection
        case .wind_gusts_10m: return .metrePerSecond
        case .shortwave_radiation: return .wattPerSquareMetre
        case .cape: return .joulePerKilogram
        case .visibility: return .metre
        case .precipitation_probability, .thunderstorm_probability, .rain_probability, .freezing_rain_probability, .ice_pellets_probability, .snowfall_probability:
            return .percentage
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
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
enum NbmPressureVariableType: String, CaseIterable, RawRepresentableString {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case cloud_cover
    case relative_humidity
    case vertical_velocity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct NbmPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: NbmPressureVariableType
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
typealias NbmVariable = SurfaceAndPressureVariable<NbmSurfaceVariable, NbmPressureVariable>
