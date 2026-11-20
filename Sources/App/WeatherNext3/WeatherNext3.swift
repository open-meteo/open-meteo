import Foundation

enum WeatherNext3Domain: String, GenericDomain, CaseIterable {
    case surface, station

    var domainRegistry: DomainRegistry {
        switch self {
        case .surface:
            .google_weathernext3_ensemble_mean
        case .station:
            .google_weathernext3_station_ensemble_mean
        }
    }

    // Surface (0.1°): ECMWF surface geopotential and land/sea mask provide static forcings; these grids are not included in the forecast buckets.
    // Station (0.05°): GMTED2010 elevation and ESA WorldCover 10m v200 land/sea data are averaged onto the grid for the station decoder; these grids are not included in the forecast buckets.
    var domainRegistryStatic: DomainRegistry? { nil }

    var grid: any Gridable {
        switch self {
        case .surface:
            RegularGrid(
                nx: 3600,
                ny: 1801,
                latMin: -90,
                lonMin: -180,
                dx: 0.1,
                dy: 0.1
            )
        case .station:
            RegularGrid(
                nx: 7200,
                ny: 3601,
                latMin: -90,
                lonMin: -180,
                dx: 0.05,
                dy: 0.05
            )
        }
    }

    var dtSeconds: Int { 3600 }

    var coordinateSuffix: String {
        switch self {
        case .surface: "0p1"
        case .station: "0p05"
        }
    }

    var updateIntervalSeconds: Int { 6 * 3600 }

    var omFileLength: Int { 360 + 24 }

    var countEnsembleMember: Int { 1 }

    var masterTimeRange: Range<Timestamp>? { nil }

    var generateFullRun: Bool { false }

    static func latestRun(now: Timestamp = .now()) -> Timestamp {
        // GCS targets publication of the six-hourly main runs at init + 7h45.
        now.add(-(7 * 3600 + 45 * 60)).floor(toNearest: 6 * 3600)
    }

    static let hours = 360

    static func path(run: Timestamp) -> String {
        "weathernext_3_0_0_statistics/zarr/2026_to_present/\(run.format_YYYYMMdd)_\(run.hour.zeroPadded(len: 2))hr_01_preds/"
    }
}

enum WeatherNext3Field: String, CaseIterable, Sendable {
    case temperature_2m
    case dew_point_2m
    case pressure_msl
    case sea_surface_temperature
    case precipitation
    case shortwave_radiation
    case direct_radiation
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_speed_10m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_speed_100m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high

    var source: String {
        switch self {
        case .temperature_2m: "station_head_temperature_2m"
        case .dew_point_2m: "station_head_dewpoint_temperature_2m"
        case .pressure_msl: "mean_sea_level_pressure"
        case .sea_surface_temperature, .wind_speed_10m, .wind_speed_100m: rawValue
        case .precipitation: "total_precipitation_1hr"
        case .shortwave_radiation: "surface_solar_radiation_downwards_1hr"
        case .direct_radiation: "total_sky_direct_solar_radiation_at_surface_1hr"
        case .wind_u_component_10m: "u_component_of_wind_10m"
        case .wind_v_component_10m: "v_component_of_wind_10m"
        case .wind_u_component_100m: "u_component_of_wind_100m"
        case .wind_v_component_100m: "v_component_of_wind_100m"
        case .cloud_cover: "total_cloud_cover"
        case .cloud_cover_low: "low_cloud_cover"
        case .cloud_cover_mid: "medium_cloud_cover"
        case .cloud_cover_high: "high_cloud_cover"
        }
    }

    var domain: WeatherNext3Domain {
        switch self {
        case .temperature_2m, .dew_point_2m:
            .station
        case .pressure_msl, .sea_surface_temperature, .precipitation, .shortwave_radiation, .direct_radiation,
            .wind_u_component_10m, .wind_v_component_10m, .wind_speed_10m,
            .wind_u_component_100m, .wind_v_component_100m, .wind_speed_100m,
            .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            .surface
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .dew_point_2m, .sea_surface_temperature:
            .celsius
        case .pressure_msl:
            .hectopascal
        case .precipitation:
            .millimetre
        case .shortwave_radiation, .direct_radiation:
            .wattPerSquareMetre
        case .wind_u_component_10m, .wind_v_component_10m, .wind_speed_10m,
            .wind_u_component_100m, .wind_v_component_100m, .wind_speed_100m:
            .metrePerSecond
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            .percentage
        }
    }

    var sourceUnit: String {
        switch self {
        case .temperature_2m, .dew_point_2m, .sea_surface_temperature:
            "K"
        case .pressure_msl:
            "Pa"
        case .precipitation:
            "m"
        case .shortwave_radiation, .direct_radiation:
            "J m**-2"
        case .wind_u_component_10m, .wind_v_component_10m, .wind_speed_10m,
            .wind_u_component_100m, .wind_v_component_100m, .wind_speed_100m:
            "m s**-1"
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            "(0 - 1)"
        }
    }

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .dew_point_2m, .sea_surface_temperature:
            (1, -273.15)
        case .pressure_msl:
            (0.01, 0)
        case .precipitation:
            (1000, 0)
        case .shortwave_radiation, .direct_radiation:
            (1 / 3600, 0)
        case .wind_u_component_10m, .wind_v_component_10m, .wind_speed_10m,
            .wind_u_component_100m, .wind_v_component_100m, .wind_speed_100m:
            nil
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            (100, 0)
        }
    }

    var spread: Bool {
        switch self {
        case .temperature_2m, .dew_point_2m, .pressure_msl,
            .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m:
            true
        case .sea_surface_temperature, .precipitation, .shortwave_radiation, .direct_radiation,
            .wind_speed_10m, .wind_speed_100m, .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            false
        }
    }
}

struct WeatherNext3Variable: GenericVariable {

    enum Statistic: String, CaseIterable {
        case mean
        case p10
        case p25
        case p50
        case p75
        case p90
    }

    let statistic: Statistic
    let field: WeatherNext3Field

    var rawValue: String {
        statistic == .mean ? field.rawValue : field.rawValue + "_" + statistic.rawValue
    }

    init(field: WeatherNext3Field, statistic: Statistic) {
        self.field = field
        self.statistic = statistic
    }

    init?(rawValue: String) {
        let statistic = Statistic.allCases.first { $0 != .mean && rawValue.hasSuffix("_" + $0.rawValue) } ?? .mean
        let name = statistic == .mean ? rawValue : String(rawValue.dropLast(statistic.rawValue.count + 1))
        guard let field = WeatherNext3Field(rawValue: name) else { return nil }
        self.init(field: field, statistic: statistic)
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }

    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    var omFileName: (file: String, level: Int) { (rawValue, 0) }

    var scalefactor: Float {
        if statistic != .mean {
            switch field.unit {
            case .hectopascal, .wattPerSquareMetre, .millimetre: return 10
            default: return 100
            }
        }
        switch field.unit {
        case .celsius: return 20
        case .percentage, .wattPerSquareMetre: return 1
        default: return 10
        }
    }

    var unit: SiUnit { field.unit }

    var interpolation: ReaderInterpolation {
        if statistic != .mean { return .linear }
        if field == .precipitation { return .backwards_sum }
        if field.unit == .wattPerSquareMetre { return .solar_backwards_averaged }
        return .linear
    }

    var isElevationCorrectable: Bool { false }

    var storePreviousForecast: Bool { false }
}

protocol WeatherNext3Grid: Sendable, Hashable {
    static var domain: WeatherNext3Domain { get }
}

enum WeatherNext3SurfaceGrid: WeatherNext3Grid {
    static var domain: WeatherNext3Domain { .surface }
}

enum WeatherNext3StationGrid: WeatherNext3Grid {
    static var domain: WeatherNext3Domain { .station }
}

struct WeatherNext3GridVariable<Grid: WeatherNext3Grid>: GenericVariable {
    let variable: WeatherNext3Variable

    init?(rawValue: String) {
        guard let variable = WeatherNext3Variable(rawValue: rawValue), variable.field.domain == Grid.domain else {
            return nil
        }
        self.variable = variable
    }

    var rawValue: String { variable.rawValue }

    var omFileName: (file: String, level: Int) { variable.omFileName }

    var scalefactor: Float { variable.scalefactor }

    var unit: SiUnit { variable.unit }

    var interpolation: ReaderInterpolation { variable.interpolation }

    var isElevationCorrectable: Bool { false }

    var storePreviousForecast: Bool { false }
}
