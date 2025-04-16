import Foundation
import OmFileFormat

enum MetNoDomain: String, GenericDomain, CaseIterable {
    case nordic_pp

    var domainRegistry: DomainRegistry {
        switch self {
        case .nordic_pp:
            return .metno_nordic_pp
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
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

    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // 30 min delay
        return t.with(hour: t.hour)
    }

    var omFileLength: Int {
        return 64 + 2 * 24
    }

    var grid: Gridable {
        switch self {
        case .nordic_pp:
            return ProjectionGrid(nx: 1796, ny: 2321, latitude: 52.30272...72.18527, longitude: 1.9184653...41.764282, projection: LambertConformalConicProjection(λ0: 15, ϕ0: 63, ϕ1: 63, ϕ2: 63))
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .nordic_pp:
            return 3600
        }
    }
}

enum MetNoVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case pressure_msl
    case relative_humidity_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m
    case shortwave_radiation
    case precipitation

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        // default: return false
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
        case .temperature_2m:
            return 20
        case .cloud_cover:
            return 1
        case .relative_humidity_2m:
            return 1
        case .precipitation:
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
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            return .hermite(bounds: nil)
        case .wind_direction_10m:
            return .linearDegrees
        case .precipitation:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloud_cover:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation:
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
        }
    }

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .cloud_cover:
            return (100, 0)
        case .relative_humidity_2m:
            return (100, 0)
        case .pressure_msl:
            return (1 / 100, 0)
        case .shortwave_radiation:
            return (1 / 3600, 0)
        default:
            return nil
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }

    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation: return true
        default: return false
        }
    }

    var netCdfName: String {
        switch self {
        case .temperature_2m:
            return "air_temperature_2m"
        case .cloud_cover:
            return "cloud_area_fraction"
        case .pressure_msl:
            return "air_pressure_at_sea_level"
        case .relative_humidity_2m:
            return "relative_humidity_2m"
        case .wind_speed_10m:
            return "wind_speed_10m"
        case .wind_direction_10m:
            return "wind_direction_10m"
        case .wind_gusts_10m:
            return "wind_speed_of_gust"
        case .shortwave_radiation:
            return "integral_of_surface_downwelling_shortwave_flux_in_air_wrt_time"
        case .precipitation:
            return "precipitation_amount"
        }
    }
}
