import Foundation

/// Native statistics grids. Station heads supply temperature and dew point exclusively.
enum WeatherNext3Domain: String, GenericDomain, CaseIterable {
    case surface, station

    var domainRegistry: DomainRegistry {
        self == .surface ? .google_weathernext3_ensemble_mean : .google_weathernext3_station_ensemble_mean
    }

    var domainRegistryStatic: DomainRegistry? { nil }

    var grid: any Gridable {
        RegularGrid(
            nx: self == .surface ? 3600 : 7200,
            ny: self == .surface ? 1801 : 3601,
            latMin: -90,
            lonMin: -180,
            dx: self == .surface ? 0.1 : 0.05,
            dy: self == .surface ? 0.1 : 0.05
        )
    }

    var dtSeconds: Int { 3600 }

    var updateIntervalSeconds: Int { 3600 }

    var omFileLength: Int { 360 }

    var countEnsembleMember: Int { 1 }

    var masterTimeRange: Range<Timestamp>? { nil }

    var generateFullRun: Bool { false }

    static func hours(run: Timestamp) -> Int { run.hour % 6 == 0 ? 360 : 48 }

    static func path(run: Timestamp) -> String {
        "weathernext_3_0_0_statistics/zarr/2026_to_present/\(run.format_YYYYMMdd)_\(run.hour.zeroPadded(len: 2))hr_01_preds/"
    }
}

struct WeatherNext3Variable: GenericVariable {
    let rawValue: String

    struct Field: Sendable {
        let name: String
        let source: String
        let domain: WeatherNext3Domain
        let unit: SiUnit
        let scale: Float
        let offset: Float
        let spread: Bool
    }

    static let fields: [Field] = [
        .init(
            name: "temperature_2m",
            source: "station_head_temperature_2m",
            domain: .station,
            unit: .celsius,
            scale: 1.0,
            offset: -273.15,
            spread: true
        ),
        .init(
            name: "dew_point_2m",
            source: "station_head_dewpoint_temperature_2m",
            domain: .station,
            unit: .celsius,
            scale: 1.0,
            offset: -273.15,
            spread: true
        ),
        .init(
            name: "pressure_msl",
            source: "mean_sea_level_pressure",
            domain: .surface,
            unit: .hectopascal,
            scale: 0.01,
            offset: 0.0,
            spread: true
        ),
        .init(
            name: "sea_surface_temperature",
            source: "sea_surface_temperature",
            domain: .surface,
            unit: .celsius,
            scale: 1.0,
            offset: -273.15,
            spread: false
        ),
        .init(
            name: "precipitation",
            source: "total_precipitation_1hr",
            domain: .surface,
            unit: .millimetre,
            scale: 1000.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "shortwave_radiation",
            source: "surface_solar_radiation_downwards_1hr",
            domain: .surface,
            unit: .wattPerSquareMetre,
            scale: 0.0002777777777777778,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "direct_radiation",
            source: "total_sky_direct_solar_radiation_at_surface_1hr",
            domain: .surface,
            unit: .wattPerSquareMetre,
            scale: 0.0002777777777777778,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "wind_u_component_10m",
            source: "u_component_of_wind_10m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: true
        ),
        .init(
            name: "wind_v_component_10m",
            source: "v_component_of_wind_10m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: true
        ),
        .init(
            name: "wind_speed_10m",
            source: "wind_speed_10m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "wind_u_component_100m",
            source: "u_component_of_wind_100m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: true
        ),
        .init(
            name: "wind_v_component_100m",
            source: "v_component_of_wind_100m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: true
        ),
        .init(
            name: "wind_speed_100m",
            source: "wind_speed_100m",
            domain: .surface,
            unit: .metrePerSecond,
            scale: 1.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "cloud_cover",
            source: "total_cloud_cover",
            domain: .surface,
            unit: .percentage,
            scale: 100.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "cloud_cover_low",
            source: "low_cloud_cover",
            domain: .surface,
            unit: .percentage,
            scale: 100.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "cloud_cover_mid",
            source: "medium_cloud_cover",
            domain: .surface,
            unit: .percentage,
            scale: 100.0,
            offset: 0.0,
            spread: false
        ),
        .init(
            name: "cloud_cover_high",
            source: "high_cloud_cover",
            domain: .surface,
            unit: .percentage,
            scale: 100.0,
            offset: 0.0,
            spread: false
        ),
    ]

    init?(rawValue: String) {
        let spread = rawValue.hasSuffix("_spread")
        let name = spread ? String(rawValue.dropLast(7)) : rawValue
        guard Self.fields.contains(where: { $0.name == name && (!spread || $0.spread) }) else { return nil }
        self.rawValue = rawValue
    }

    var isSpread: Bool { rawValue.hasSuffix("_spread") }

    var field: Field { Self.fields.first { $0.name == (isSpread ? String(rawValue.dropLast(7)) : rawValue) }! }

    var omFileName: (file: String, level: Int) { (rawValue, 0) }

    var scalefactor: Float {
        if isSpread { return 100 }
        switch field.unit {
        case .celsius: return 20
        case .percentage, .wattPerSquareMetre: return 1
        default: return 10
        }
    }

    var unit: SiUnit { isSpread && field.unit == .celsius ? .kelvin : field.unit }

    var interpolation: ReaderInterpolation {
        if isSpread { return .linear }
        if rawValue == "precipitation" { return .backwards_sum }
        if field.unit == .wattPerSquareMetre { return .solar_backwards_averaged }
        return .linear
    }

    var isElevationCorrectable: Bool { false }

    var storePreviousForecast: Bool { false }

    static func estimatedSpread(low: Float, high: Float, scale: Float) -> Float {
        guard low.isFinite, high.isFinite, high >= low else { return .nan }
        return (high - low) / 2.5631031311 * scale
    }
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

/// Restrict each reader to its actual fields before composing derived quantities.
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
