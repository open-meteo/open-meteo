import Foundation

enum BomVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
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
    case snowfall_water_equivalent
    
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_40m
    case wind_direction_40m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_120m
    case wind_direction_120m
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_35cm
    case soil_temperature_35_to_100cm
    case soil_temperature_100_to_300cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_35cm
    case soil_moisture_35_to_100cm
    case soil_moisture_100_to_300cm
    
    case weather_code
    case visibility
    case wind_gusts_10m
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm: return true
        case .soil_moisture_10_to_35cm: return true
        case .soil_moisture_35_to_100cm: return true
        case .soil_moisture_100_to_300cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .showers, .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation, .direct_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .weather_code: return true
        //case .wind_speed_40m, .wind_direction_40m: return true
        //case .wind_speed_80m, .wind_direction_80m: return true
        //case .wind_speed_120m, .wind_direction_120m: return true
        default: return false
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature, .soil_temperature_0_to_10cm, .soil_temperature_10_to_35cm, .soil_temperature_35_to_100cm, .soil_temperature_100_to_300cm:
            return (1, -273.15)
        case .soil_moisture_0_to_10cm:
            return (0.001 / 0.1, 0) // 10cm depth
        case .soil_moisture_10_to_35cm:
            return (0.001 / 0.25, 0) // 25cm depth
        case .soil_moisture_35_to_100cm:
            return (0.001 / 0.65, 0) // 65cm depth
        case .soil_moisture_100_to_300cm:
            return (0.001 / 2.00, 0) // 200cm depth
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
        case .surface_temperature: return 20
        case .soil_temperature_0_to_10cm: return 20
        case .soil_temperature_10_to_35cm: return 20
        case .soil_temperature_35_to_100cm: return 20
        case .soil_temperature_100_to_300cm: return 20
        case .soil_moisture_0_to_10cm: return 1000
        case .soil_moisture_10_to_35cm: return 1000
        case .soil_moisture_35_to_100cm: return 1000
        case .soil_moisture_100_to_300cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .wind_gusts_10m: return 10
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .direct_radiation: return 1
        case .visibility: return 0.05 // 50 meter
        //case .snowfall: return 10
        case .snowfall_water_equivalent:
            return 10
        case .weather_code:
            return 1
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
        case .surface_temperature:
            return .hermite(bounds: nil)
        case .soil_temperature_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_temperature_10_to_35cm:
            return .hermite(bounds: nil)
        case .soil_temperature_35_to_100cm:
            return .hermite(bounds: nil)
        case .soil_temperature_100_to_300cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_moisture_10_to_35cm:
            return .hermite(bounds: nil)
        case .soil_moisture_35_to_100cm:
            return .hermite(bounds: nil)
        case .soil_moisture_100_to_300cm:
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
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .weather_code:
            return .backwards
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
        case .wind_speed_10m, .wind_speed_40m, .wind_speed_80m, .wind_speed_120m:
            return .metrePerSecond
        case .wind_direction_10m, .wind_direction_40m, .wind_direction_80m, .wind_direction_120m:
            return .degreeDirection
        case .surface_temperature: return .celsius
        case .soil_temperature_0_to_10cm: return .celsius
        case .soil_temperature_10_to_35cm: return .celsius
        case .soil_temperature_35_to_100cm: return .celsius
        case .soil_temperature_100_to_300cm: return .celsius
        case .soil_moisture_0_to_10cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_10_to_35cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_35_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_300cm: return .cubicMetrePerCubicMetre
        case .snow_depth: return .metre
        case .showers: return .millimetre
        case .wind_gusts_10m: return .metrePerSecond
        case .pressure_msl: return .hectopascal
        case .shortwave_radiation, .direct_radiation: return .wattPerSquareMetre
        case .visibility: return .metre
        case .snowfall_water_equivalent:
            return .millimetre
        case .weather_code:
            return .wmoCode
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface_temperature:
            fallthrough
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_10_to_35cm:
            fallthrough
        case .soil_temperature_35_to_100cm:
            fallthrough
        case .soil_temperature_100_to_300cm:
            fallthrough
        case .temperature_2m:
            return true
        default:
            return false
        }
    }
}
