import Foundation

/// Surface variables provided by the ČHMÚ ALADIN CZ 1km model.
/// ALADIN does not publish a usable WMO weather symbol, so weather_code is omitted
/// from this first ingestion and can be derived later via WeatherCode.calculate().
enum ChmiVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case surface_temperature
    case dew_point_2m
    case relative_humidity_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m
    case pressure_msl
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case precipitation
    case rain
    case snowfall_water_equivalent
    case snow_depth_water_equivalent
    case shortwave_radiation
    case direct_radiation
    case cape
    case visibility
    case sunshine_duration

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .rain, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        default:
            return false
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m, .surface_temperature, .dew_point_2m:
            return 20
        case .relative_humidity_2m:
            return 1
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return 1
        case .wind_speed_10m:
            return 10
        case .wind_direction_10m:
            return 1
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .precipitation, .rain, .snowfall_water_equivalent:
            return 10
        case .snow_depth_water_equivalent:
            return 1 // 1mm res
        case .shortwave_radiation, .direct_radiation:
            return 1
        case .cape:
            return 0.1
        case .visibility:
            return 0.05 // 20 metre
        case .sunshine_duration:
            return 1
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature, .dew_point_2m:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m:
            return .linearDegrees
        case .wind_gusts_10m:
            return .hermite(bounds: 0...10e9)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .precipitation, .rain, .snowfall_water_equivalent:
            return .backwards_sum
        case .snow_depth_water_equivalent:
            return .linear
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .visibility:
            return .linear
        case .sunshine_duration:
            return .backwards_sum
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature, .dew_point_2m:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .percentage
        case .wind_speed_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            return .degreeDirection
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .precipitation, .rain, .snowfall_water_equivalent:
            return .millimetre
        case .snow_depth_water_equivalent:
            return .millimetre
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .cape:
            return .joulePerKilogram
        case .visibility:
            return .metre
        case .sunshine_duration:
            return .seconds
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .surface_temperature || self == .dew_point_2m
    }
}
