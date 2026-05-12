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

    var suffix: String {
        "\(rawValue)hPa"
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
    case total_precipitation_6hr
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
        case .total_precipitation_6hr:
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
        case .total_precipitation_6hr:
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
             .total_precipitation_6hr,
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
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .relative_humidity:
            return .percentage
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

extension WeatherNextVariable {
    private static let rawPressureVariableTypes: [WeatherNextPressureVariableType] = [
        .geopotential_height,
        .relative_humidity,
        .temperature,
        .wind_u_component,
        .wind_v_component,
        .vertical_velocity
    ]

    static let surfaceVariables: [WeatherNextVariable] =
        WeatherNextSurfaceVariable.allCases.map(Self.surface)

    /**
     Pressure-level variables physically present in the upstream WeatherNext source files.
     */
    static let pressureLevelVariables: [WeatherNextVariable] =
        WeatherNextPressureLevel.allCases.flatMap { level in
            rawPressureVariableTypes.map { type in
                Self.pressure(.init(variable: type, level: level))
            }
        }

    /**
     Variables read directly from the upstream WeatherNext OM files.
     */
    static let rawVariables: [WeatherNextVariable] =
        [
            // .surface(.wind_u_component_100m),
            // .surface(.wind_v_component_100m),
            // .surface(.wind_u_component_10m),
            // .surface(.wind_v_component_10m),
            .surface(.temperature_2m),
            // .surface(.pressure_msl),
            // .surface(.sea_surface_temperature),
            // .surface(.total_precipitation_6hr)
        ] 
        // + pressureLevelVariables

    var isPressureLevelVariable: Bool {
        if case .pressure = self {
            return true
        }
        return false
    }

    var isSurfaceVariable: Bool {
        if case .surface = self {
            return true
        }
        return false
    }

    var isRelativeHumidityPressureLevel: Bool {
        guard case .pressure(let pressure) = self else {
            return false
        }
        return pressure.variable == .relative_humidity
    }

    var pressureLevel: WeatherNextPressureLevel? {
        guard case .pressure(let pressure) = self else {
            return nil
        }
        return pressure.pressureLevel
    }

    static func temperature(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        .pressure(.init(variable: .temperature, level: level))
    }

    static func windU(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        .pressure(.init(variable: .wind_u_component, level: level))
    }

    static func windV(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        .pressure(.init(variable: .wind_v_component, level: level))
    }

    static var cloud_cover: WeatherNextVariable {
        .surface(.cloud_cover)
    }

    static var cloud_cover_low: WeatherNextVariable {
        .surface(.cloud_cover_low)
    }

    static var cloud_cover_mid: WeatherNextVariable {
        .surface(.cloud_cover_mid)
    }

    static var cloud_cover_high: WeatherNextVariable {
        .surface(.cloud_cover_high)
    }

    static var total_precipitation_6hr: WeatherNextVariable {
        .surface(.total_precipitation_6hr)
    }

    /// All variables that appear in the output archive: directly-read raw variables plus
    /// the four cloud-cover variables that are derived from RH pressure levels.
    static let allOutputVariables: [WeatherNextVariable] = rawVariables + [
        // .cloud_cover_low,
        // .cloud_cover_mid,
        // .cloud_cover_high,
        // .cloud_cover
    ]

    /// `true` for the four cloud-cover variables that are derived from RH pressure levels
    /// rather than read directly from the source OM files.
    var isCloudCoverDerived: Bool {
        switch self {
        case .surface(.cloud_cover),
             .surface(.cloud_cover_low),
             .surface(.cloud_cover_mid),
             .surface(.cloud_cover_high):
            return true
        default:
            return false
        }
    }
}
