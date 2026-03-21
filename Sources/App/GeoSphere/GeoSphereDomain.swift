import Foundation
import OmFileFormat
import Vapor

/// GeoSphere Austria AROME 2.5km regional model
/// Data: https://data.hub.geosphere.at/dataset/nwp-v1-1h-2500m
enum GeoSphereDomain: String, GenericDomain, CaseIterable {
    case arome_austria

    var domainRegistry: DomainRegistry {
        switch self {
        case .arome_austria:
            return .geosphere_arome_austria
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var countEnsembleMember: Int {
        return 1
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        return 3600
    }

    var isGlobal: Bool {
        return false
    }

    /// Runs every 3 hours (00, 03, 06, 09, 12, 15, 18, 21) with ~4h delay
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // Subtract 4 hours for delay, then floor to nearest 3h
        let adjustedHour = (t.hour - 4 + 24) % 24
        let runHour = adjustedHour - (adjustedHour % 3)
        return t.with(hour: runHour)
    }

    /// 60h forecast + 2 days buffer
    var omFileLength: Int {
        return 108
    }

    var grid: any Gridable {
        switch self {
        case .arome_austria:
            // lon=594, lat=492, south-to-north
            return RegularGrid(nx: 594, ny: 492, latMin: 42.981, lonMin: 5.498, dx: 0.028, dy: 0.018)
        }
    }

    var updateIntervalSeconds: Int {
        return 10800 // 3 hours
    }
}

/// SYMBOL (weather symbol) uses GeoSphere-specific codes 1-31 (not WMO), so weather_code
/// is derived from raw fields via WeatherCode.calculate().
enum GeoSphereVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case relative_humidity_2m
    case temperature_2m_min
    case temperature_2m_max
    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m
    case precipitation
    case rain
    case snowfall_water_equivalent
    case pressure_msl
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case surface_temperature
    case snow_depth_water_equivalent
    
    case shortwave_radiation
    case cape
    case convective_inhibition
    case snowfall_height
    case sunshine_duration
    case weather_code

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .rain, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .cape, .snowfall_height, .sunshine_duration, .weather_code: return false
        default:
            return false
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return 20
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return 1
        case .convective_inhibition:
            return 1
        case .relative_humidity_2m:
            return 1
        case .precipitation:
            return 10
        case .rain:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .wind_speed_10m:
            return 10
        case .wind_direction_10m:
            return 1
        case .cape:
            return 0.1
        case .snowfall_height:
            return 0.1
        case .sunshine_duration:
            return 1
        case .weather_code:
            return 1
        case .snow_depth_water_equivalent:
            return 1 // 1mm res
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m:
            return .linearDegrees
        case .precipitation:
            return .backwards_sum
        case .rain:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: 0...10e9)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .snowfall_height:
            return .hermite(bounds: nil)
        case .sunshine_duration:
            return .backwards_sum
        case .weather_code:
            return .backwards
        case .snow_depth_water_equivalent:
            return .linear
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return .celsius
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation:
            return .millimetre
        case .rain:
            return .millimetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .wind_speed_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            return .degreeDirection
        case .cape:
            return .joulePerKilogram
        case .convective_inhibition:
            return .joulePerKilogram
        case .snowfall_height:
            return .metre
        case .sunshine_duration:
            return .seconds
        case .weather_code:
            return .wmoCode
        case .snow_depth_water_equivalent:
            return .millimetre
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .temperature_2m_max || self == .temperature_2m_min || self == .surface_temperature
    }
}
