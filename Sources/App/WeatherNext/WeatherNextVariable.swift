import Foundation

enum WeatherNextPressureLevel: Int, CaseIterable, Sendable {
    case hPa50 = 50
    case hPa100 = 100
    case hPa150 = 150
    case hPa200 = 200
    case hPa250 = 250
    case hPa300 = 300
    case hPa400 = 400
    case hPa500 = 500
    case hPa600 = 600
    case hPa700 = 700
    case hPa850 = 850
    case hPa925 = 925
    case hPa1000 = 1000

    var level: Int {
        rawValue
    }
}

/**
 WeatherNext surface variables.

 Naming notes:
 - `rawValue` is used to address the source OM child in the upstream WeatherNext files.
 - `omFileName.file` is the canonical Open-Meteo output/storage name.
 - Most variables use the same name for both, but `total_precipitation_6hr` is intentionally
   mapped to the canonical output name `precipitation`.
 */
enum WeatherNextSurfaceVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_10m
    case wind_v_component_10m
    case temperature_2m
    case pressure_msl
    case sea_surface_temperature
    case precipitation
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high

    private enum MetadataGroup {
        case temperature
        case pressureMsl
        case precipitation
        case cloudCover
        case windComponent
    }

    private var metadataGroup: MetadataGroup {
        switch self {
        case .temperature_2m, .sea_surface_temperature:
            return .temperature
        case .pressure_msl:
            return .pressureMsl
        case .precipitation:
            return .precipitation
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .cloudCover
        case .wind_u_component_100m,
             .wind_v_component_100m,
             .wind_u_component_10m,
             .wind_v_component_10m:
            return .windComponent
        }
    }

    var omFileName: (file: String, level: Int) {
        switch self {
        case .precipitation:
            return ("precipitation", 0)
        default:
            return (rawValue, 0)
        }
    }

    var scalefactor: Float {
        switch metadataGroup {
        case .temperature:
            return 20
        case .pressureMsl:
            return 10
        case .precipitation:
            return 10
        case .cloudCover:
            return 1
        case .windComponent:
            return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch metadataGroup {
        case .temperature, .pressureMsl, .windComponent:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .cloudCover:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch metadataGroup {
        case .temperature:
            return .celsius
        case .pressureMsl:
            return .hectopascal
        case .precipitation:
            return .millimetre
        case .cloudCover:
            return .percentage
        case .windComponent:
            return .metrePerSecond
        }
    }

    var isElevationCorrectable: Bool {
        self == .temperature_2m
    }

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m,
             .pressure_msl,
             .precipitation,
             .cloud_cover,
             .cloud_cover_low,
             .cloud_cover_mid,
             .cloud_cover_high:
            return true
        default:
            return false
        }
    }
}

enum WeatherNextPressureVariableType: String, CaseIterable, Sendable {
    case geopotential_height
    case relative_humidity
    case specific_humidity
    case temperature
    case wind_u_component
    case wind_v_component
    case vertical_velocity
}

/**
 WeatherNext pressure-level variables.

 `rawValue` and `omFileName.file` are intentionally identical here, so a value like
 `temperature_500hPa` is both:
 - the source OM child name in the upstream WeatherNext file
 - the canonical Open-Meteo storage/API name
 */
struct WeatherNextPressureVariable: PressureVariableRespresentable, Hashable, GenericVariableMixable, GenericVariable {
    let variable: WeatherNextPressureVariableType
    let level: Int

    init(variable: WeatherNextPressureVariableType, level: Int) {
        self.variable = variable
        self.level = level
    }

    init(variable: WeatherNextPressureVariableType, level: WeatherNextPressureLevel) {
        self.init(variable: variable, level: level.level)
    }

    var pressureLevel: WeatherNextPressureLevel? {
        WeatherNextPressureLevel(rawValue: level)
    }

    var omFileName: (file: String, level: Int) {
        (rawValue, 0)
    }

    var scalefactor: Float {
        switch variable {
        case .temperature:
            return 20
        case .relative_humidity:
            return 1
        case .specific_humidity:
            return 1000
        case .geopotential_height:
            return 1
        case .wind_u_component, .wind_v_component:
            return 10
        case .vertical_velocity:
            return 100
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature,
             .geopotential_height,
             .wind_u_component,
             .wind_v_component,
             .vertical_velocity:
            return .hermite(bounds: nil)
        case .relative_humidity, .specific_humidity:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .relative_humidity:
            return .percentage
        case .specific_humidity:
            return .gramPerKilogram
        case .geopotential_height:
            return .metre
        case .wind_u_component, .wind_v_component, .vertical_velocity:
            return .metrePerSecond
        }
    }

    var isElevationCorrectable: Bool {
        false
    }

    var storePreviousForecast: Bool {
        false
    }
}

typealias WeatherNextVariable = SurfaceAndPressureVariable<WeatherNextSurfaceVariable, WeatherNextPressureVariable>
