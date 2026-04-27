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

enum WeatherNextVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
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

    case geopotential_height_50hPa
    case geopotential_height_100hPa
    case geopotential_height_150hPa
    case geopotential_height_200hPa
    case geopotential_height_250hPa
    case geopotential_height_300hPa
    case geopotential_height_400hPa
    case geopotential_height_500hPa
    case geopotential_height_600hPa
    case geopotential_height_700hPa
    case geopotential_height_850hPa
    case geopotential_height_925hPa
    case geopotential_height_1000hPa

    case relative_humidity_50hPa
    case relative_humidity_100hPa
    case relative_humidity_150hPa
    case relative_humidity_200hPa
    case relative_humidity_250hPa
    case relative_humidity_300hPa
    case relative_humidity_400hPa
    case relative_humidity_500hPa
    case relative_humidity_600hPa
    case relative_humidity_700hPa
    case relative_humidity_850hPa
    case relative_humidity_925hPa
    case relative_humidity_1000hPa

    case temperature_50hPa
    case temperature_100hPa
    case temperature_150hPa
    case temperature_200hPa
    case temperature_250hPa
    case temperature_300hPa
    case temperature_400hPa
    case temperature_500hPa
    case temperature_600hPa
    case temperature_700hPa
    case temperature_850hPa
    case temperature_925hPa
    case temperature_1000hPa

    case wind_u_component_50hPa
    case wind_u_component_100hPa
    case wind_u_component_150hPa
    case wind_u_component_200hPa
    case wind_u_component_250hPa
    case wind_u_component_300hPa
    case wind_u_component_400hPa
    case wind_u_component_500hPa
    case wind_u_component_600hPa
    case wind_u_component_700hPa
    case wind_u_component_850hPa
    case wind_u_component_925hPa
    case wind_u_component_1000hPa

    case wind_v_component_50hPa
    case wind_v_component_100hPa
    case wind_v_component_150hPa
    case wind_v_component_200hPa
    case wind_v_component_250hPa
    case wind_v_component_300hPa
    case wind_v_component_400hPa
    case wind_v_component_500hPa
    case wind_v_component_600hPa
    case wind_v_component_700hPa
    case wind_v_component_850hPa
    case wind_v_component_925hPa
    case wind_v_component_1000hPa

    case vertical_velocity_50hPa
    case vertical_velocity_100hPa
    case vertical_velocity_150hPa
    case vertical_velocity_200hPa
    case vertical_velocity_250hPa
    case vertical_velocity_300hPa
    case vertical_velocity_400hPa
    case vertical_velocity_500hPa
    case vertical_velocity_600hPa
    case vertical_velocity_700hPa
    case vertical_velocity_850hPa
    case vertical_velocity_925hPa
    case vertical_velocity_1000hPa

    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_100m
    case wind_direction_100m

    case wind_speed_50hPa
    case wind_speed_100hPa
    case wind_speed_150hPa
    case wind_speed_200hPa
    case wind_speed_250hPa
    case wind_speed_300hPa
    case wind_speed_400hPa
    case wind_speed_500hPa
    case wind_speed_600hPa
    case wind_speed_700hPa
    case wind_speed_850hPa
    case wind_speed_925hPa
    case wind_speed_1000hPa

    case wind_direction_50hPa
    case wind_direction_100hPa
    case wind_direction_150hPa
    case wind_direction_200hPa
    case wind_direction_250hPa
    case wind_direction_300hPa
    case wind_direction_400hPa
    case wind_direction_500hPa
    case wind_direction_600hPa
    case wind_direction_700hPa
    case wind_direction_850hPa
    case wind_direction_925hPa
    case wind_direction_1000hPa

    var omFileName: (file: String, level: Int) {
        (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m,
             .sea_surface_temperature,
             .temperature_50hPa,
             .temperature_100hPa,
             .temperature_150hPa,
             .temperature_200hPa,
             .temperature_250hPa,
             .temperature_300hPa,
             .temperature_400hPa,
             .temperature_500hPa,
             .temperature_600hPa,
             .temperature_700hPa,
             .temperature_850hPa,
             .temperature_925hPa,
             .temperature_1000hPa:
            return 20

        case .relative_humidity_50hPa,
             .relative_humidity_100hPa,
             .relative_humidity_150hPa,
             .relative_humidity_200hPa,
             .relative_humidity_250hPa,
             .relative_humidity_300hPa,
             .relative_humidity_400hPa,
             .relative_humidity_500hPa,
             .relative_humidity_600hPa,
             .relative_humidity_700hPa,
             .relative_humidity_850hPa,
             .relative_humidity_925hPa,
             .relative_humidity_1000hPa:
            return 1

        case .pressure_msl:
            return 10

        case .total_precipitation_6hr:
            return 10

        case .cloud_cover,
             .cloud_cover_low,
             .cloud_cover_mid,
             .cloud_cover_high:
            return 1

        case .wind_speed_10m,
             .wind_speed_100m,
             .wind_speed_50hPa,
             .wind_speed_100hPa,
             .wind_speed_150hPa,
             .wind_speed_200hPa,
             .wind_speed_250hPa,
             .wind_speed_300hPa,
             .wind_speed_400hPa,
             .wind_speed_500hPa,
             .wind_speed_600hPa,
             .wind_speed_700hPa,
             .wind_speed_850hPa,
             .wind_speed_925hPa,
             .wind_speed_1000hPa,
             .wind_u_component_10m,
             .wind_v_component_10m,
             .wind_u_component_100m,
             .wind_v_component_100m,
             .wind_u_component_50hPa,
             .wind_u_component_100hPa,
             .wind_u_component_150hPa,
             .wind_u_component_200hPa,
             .wind_u_component_250hPa,
             .wind_u_component_300hPa,
             .wind_u_component_400hPa,
             .wind_u_component_500hPa,
             .wind_u_component_600hPa,
             .wind_u_component_700hPa,
             .wind_u_component_850hPa,
             .wind_u_component_925hPa,
             .wind_u_component_1000hPa,
             .wind_v_component_50hPa,
             .wind_v_component_100hPa,
             .wind_v_component_150hPa,
             .wind_v_component_200hPa,
             .wind_v_component_250hPa,
             .wind_v_component_300hPa,
             .wind_v_component_400hPa,
             .wind_v_component_500hPa,
             .wind_v_component_600hPa,
             .wind_v_component_700hPa,
             .wind_v_component_850hPa,
             .wind_v_component_925hPa,
             .wind_v_component_1000hPa:
            return 10

        case .wind_direction_10m,
             .wind_direction_100m,
             .wind_direction_50hPa,
             .wind_direction_100hPa,
             .wind_direction_150hPa,
             .wind_direction_200hPa,
             .wind_direction_250hPa,
             .wind_direction_300hPa,
             .wind_direction_400hPa,
             .wind_direction_500hPa,
             .wind_direction_600hPa,
             .wind_direction_700hPa,
             .wind_direction_850hPa,
             .wind_direction_925hPa,
             .wind_direction_1000hPa:
            return 1

        case .geopotential_height_50hPa,
             .geopotential_height_100hPa,
             .geopotential_height_150hPa,
             .geopotential_height_200hPa,
             .geopotential_height_250hPa,
             .geopotential_height_300hPa,
             .geopotential_height_400hPa,
             .geopotential_height_500hPa,
             .geopotential_height_600hPa,
             .geopotential_height_700hPa,
             .geopotential_height_850hPa,
             .geopotential_height_925hPa,
             .geopotential_height_1000hPa:
            return 1

        case .vertical_velocity_50hPa,
             .vertical_velocity_100hPa,
             .vertical_velocity_150hPa,
             .vertical_velocity_200hPa,
             .vertical_velocity_250hPa,
             .vertical_velocity_300hPa,
             .vertical_velocity_400hPa,
             .vertical_velocity_500hPa,
             .vertical_velocity_600hPa,
             .vertical_velocity_700hPa,
             .vertical_velocity_850hPa,
             .vertical_velocity_925hPa,
             .vertical_velocity_1000hPa:
            return 100
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m,
             .sea_surface_temperature,
             .temperature_50hPa,
             .temperature_100hPa,
             .temperature_150hPa,
             .temperature_200hPa,
             .temperature_250hPa,
             .temperature_300hPa,
             .temperature_400hPa,
             .temperature_500hPa,
             .temperature_600hPa,
             .temperature_700hPa,
             .temperature_850hPa,
             .temperature_925hPa,
             .temperature_1000hPa,
             .pressure_msl,
             .geopotential_height_50hPa,
             .geopotential_height_100hPa,
             .geopotential_height_150hPa,
             .geopotential_height_200hPa,
             .geopotential_height_250hPa,
             .geopotential_height_300hPa,
             .geopotential_height_400hPa,
             .geopotential_height_500hPa,
             .geopotential_height_600hPa,
             .geopotential_height_700hPa,
             .geopotential_height_850hPa,
             .geopotential_height_925hPa,
             .geopotential_height_1000hPa,
             .wind_u_component_10m,
             .wind_v_component_10m,
             .wind_u_component_100m,
             .wind_v_component_100m,
             .wind_u_component_50hPa,
             .wind_u_component_100hPa,
             .wind_u_component_150hPa,
             .wind_u_component_200hPa,
             .wind_u_component_250hPa,
             .wind_u_component_300hPa,
             .wind_u_component_400hPa,
             .wind_u_component_500hPa,
             .wind_u_component_600hPa,
             .wind_u_component_700hPa,
             .wind_u_component_850hPa,
             .wind_u_component_925hPa,
             .wind_u_component_1000hPa,
             .wind_v_component_50hPa,
             .wind_v_component_100hPa,
             .wind_v_component_150hPa,
             .wind_v_component_200hPa,
             .wind_v_component_250hPa,
             .wind_v_component_300hPa,
             .wind_v_component_400hPa,
             .wind_v_component_500hPa,
             .wind_v_component_600hPa,
             .wind_v_component_700hPa,
             .wind_v_component_850hPa,
             .wind_v_component_925hPa,
             .wind_v_component_1000hPa,
             .vertical_velocity_50hPa,
             .vertical_velocity_100hPa,
             .vertical_velocity_150hPa,
             .vertical_velocity_200hPa,
             .vertical_velocity_250hPa,
             .vertical_velocity_300hPa,
             .vertical_velocity_400hPa,
             .vertical_velocity_500hPa,
             .vertical_velocity_600hPa,
             .vertical_velocity_700hPa,
             .vertical_velocity_850hPa,
             .vertical_velocity_925hPa,
             .vertical_velocity_1000hPa:
            return .hermite(bounds: nil)

        case .wind_speed_10m,
             .wind_speed_100m,
             .wind_speed_50hPa,
             .wind_speed_100hPa,
             .wind_speed_150hPa,
             .wind_speed_200hPa,
             .wind_speed_250hPa,
             .wind_speed_300hPa,
             .wind_speed_400hPa,
             .wind_speed_500hPa,
             .wind_speed_600hPa,
             .wind_speed_700hPa,
             .wind_speed_850hPa,
             .wind_speed_925hPa,
             .wind_speed_1000hPa:
            return .hermite(bounds: 0...10e9)

        case .wind_direction_10m,
             .wind_direction_100m,
             .wind_direction_50hPa,
             .wind_direction_100hPa,
             .wind_direction_150hPa,
             .wind_direction_200hPa,
             .wind_direction_250hPa,
             .wind_direction_300hPa,
             .wind_direction_400hPa,
             .wind_direction_500hPa,
             .wind_direction_600hPa,
             .wind_direction_700hPa,
             .wind_direction_850hPa,
             .wind_direction_925hPa,
             .wind_direction_1000hPa:
            return .linearDegrees

        case .relative_humidity_50hPa,
             .relative_humidity_100hPa,
             .relative_humidity_150hPa,
             .relative_humidity_200hPa,
             .relative_humidity_250hPa,
             .relative_humidity_300hPa,
             .relative_humidity_400hPa,
             .relative_humidity_500hPa,
             .relative_humidity_600hPa,
             .relative_humidity_700hPa,
             .relative_humidity_850hPa,
             .relative_humidity_925hPa,
             .relative_humidity_1000hPa:
            return .hermite(bounds: 0...100)

        case .total_precipitation_6hr:
            return .backwards_sum

        case .cloud_cover,
             .cloud_cover_low,
             .cloud_cover_mid,
             .cloud_cover_high:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m,
             .sea_surface_temperature,
             .temperature_50hPa,
             .temperature_100hPa,
             .temperature_150hPa,
             .temperature_200hPa,
             .temperature_250hPa,
             .temperature_300hPa,
             .temperature_400hPa,
             .temperature_500hPa,
             .temperature_600hPa,
             .temperature_700hPa,
             .temperature_850hPa,
             .temperature_925hPa,
             .temperature_1000hPa:
            return .celsius

        case .pressure_msl:
            return .hectopascal

        case .total_precipitation_6hr:
            return .millimetre

        case .cloud_cover,
             .cloud_cover_low,
             .cloud_cover_mid,
             .cloud_cover_high:
            return .percentage

        case .relative_humidity_50hPa,
             .relative_humidity_100hPa,
             .relative_humidity_150hPa,
             .relative_humidity_200hPa,
             .relative_humidity_250hPa,
             .relative_humidity_300hPa,
             .relative_humidity_400hPa,
             .relative_humidity_500hPa,
             .relative_humidity_600hPa,
             .relative_humidity_700hPa,
             .relative_humidity_850hPa,
             .relative_humidity_925hPa,
             .relative_humidity_1000hPa:
            return .percentage

        case .wind_speed_10m,
             .wind_speed_100m,
             .wind_speed_50hPa,
             .wind_speed_100hPa,
             .wind_speed_150hPa,
             .wind_speed_200hPa,
             .wind_speed_250hPa,
             .wind_speed_300hPa,
             .wind_speed_400hPa,
             .wind_speed_500hPa,
             .wind_speed_600hPa,
             .wind_speed_700hPa,
             .wind_speed_850hPa,
             .wind_speed_925hPa,
             .wind_speed_1000hPa,
             .wind_u_component_10m,
             .wind_v_component_10m,
             .wind_u_component_100m,
             .wind_v_component_100m,
             .wind_u_component_50hPa,
             .wind_u_component_100hPa,
             .wind_u_component_150hPa,
             .wind_u_component_200hPa,
             .wind_u_component_250hPa,
             .wind_u_component_300hPa,
             .wind_u_component_400hPa,
             .wind_u_component_500hPa,
             .wind_u_component_600hPa,
             .wind_u_component_700hPa,
             .wind_u_component_850hPa,
             .wind_u_component_925hPa,
             .wind_u_component_1000hPa,
             .wind_v_component_50hPa,
             .wind_v_component_100hPa,
             .wind_v_component_150hPa,
             .wind_v_component_200hPa,
             .wind_v_component_250hPa,
             .wind_v_component_300hPa,
             .wind_v_component_400hPa,
             .wind_v_component_500hPa,
             .wind_v_component_600hPa,
             .wind_v_component_700hPa,
             .wind_v_component_850hPa,
             .wind_v_component_925hPa,
             .wind_v_component_1000hPa:
            return .metrePerSecond

        case .wind_direction_10m,
             .wind_direction_100m,
             .wind_direction_50hPa,
             .wind_direction_100hPa,
             .wind_direction_150hPa,
             .wind_direction_200hPa,
             .wind_direction_250hPa,
             .wind_direction_300hPa,
             .wind_direction_400hPa,
             .wind_direction_500hPa,
             .wind_direction_600hPa,
             .wind_direction_700hPa,
             .wind_direction_850hPa,
             .wind_direction_925hPa,
             .wind_direction_1000hPa:
            return .degreeDirection

        case .geopotential_height_50hPa,
             .geopotential_height_100hPa,
             .geopotential_height_150hPa,
             .geopotential_height_200hPa,
             .geopotential_height_250hPa,
             .geopotential_height_300hPa,
             .geopotential_height_400hPa,
             .geopotential_height_500hPa,
             .geopotential_height_600hPa,
             .geopotential_height_700hPa,
             .geopotential_height_850hPa,
             .geopotential_height_925hPa,
             .geopotential_height_1000hPa:
            return .metre

        case .vertical_velocity_50hPa,
             .vertical_velocity_100hPa,
             .vertical_velocity_150hPa,
             .vertical_velocity_200hPa,
             .vertical_velocity_250hPa,
             .vertical_velocity_300hPa,
             .vertical_velocity_400hPa,
             .vertical_velocity_500hPa,
             .vertical_velocity_600hPa,
             .vertical_velocity_700hPa,
             .vertical_velocity_850hPa,
             .vertical_velocity_925hPa,
             .vertical_velocity_1000hPa:
            return .metrePerSecond
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

    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m,
             .sea_surface_temperature,
             .temperature_50hPa,
             .temperature_100hPa,
             .temperature_150hPa,
             .temperature_200hPa,
             .temperature_250hPa,
             .temperature_300hPa,
             .temperature_400hPa,
             .temperature_500hPa,
             .temperature_600hPa,
             .temperature_700hPa,
             .temperature_850hPa,
             .temperature_925hPa,
             .temperature_1000hPa:
            return (1, -273.15)

        case .pressure_msl:
            return (1 / 100, 0)

        default:
            return nil
        }
    }
}

extension WeatherNextVariable {
    static let rawVariables: [WeatherNextVariable] = [
        .wind_u_component_100m,
        .wind_v_component_100m,
        .wind_u_component_10m,
        .wind_v_component_10m,
        .temperature_2m,
        .pressure_msl,
        .sea_surface_temperature,
        .total_precipitation_6hr,
        .geopotential_height_50hPa,
        .geopotential_height_100hPa,
        .geopotential_height_150hPa,
        .geopotential_height_200hPa,
        .geopotential_height_250hPa,
        .geopotential_height_300hPa,
        .geopotential_height_400hPa,
        .geopotential_height_500hPa,
        .geopotential_height_600hPa,
        .geopotential_height_700hPa,
        .geopotential_height_850hPa,
        .geopotential_height_925hPa,
        .geopotential_height_1000hPa,
        .relative_humidity_50hPa,
        .relative_humidity_100hPa,
        .relative_humidity_150hPa,
        .relative_humidity_200hPa,
        .relative_humidity_250hPa,
        .relative_humidity_300hPa,
        .relative_humidity_400hPa,
        .relative_humidity_500hPa,
        .relative_humidity_600hPa,
        .relative_humidity_700hPa,
        .relative_humidity_850hPa,
        .relative_humidity_925hPa,
        .relative_humidity_1000hPa,
        .temperature_50hPa,
        .temperature_100hPa,
        .temperature_150hPa,
        .temperature_200hPa,
        .temperature_250hPa,
        .temperature_300hPa,
        .temperature_400hPa,
        .temperature_500hPa,
        .temperature_600hPa,
        .temperature_700hPa,
        .temperature_850hPa,
        .temperature_925hPa,
        .temperature_1000hPa,
        .wind_u_component_50hPa,
        .wind_u_component_100hPa,
        .wind_u_component_150hPa,
        .wind_u_component_200hPa,
        .wind_u_component_250hPa,
        .wind_u_component_300hPa,
        .wind_u_component_400hPa,
        .wind_u_component_500hPa,
        .wind_u_component_600hPa,
        .wind_u_component_700hPa,
        .wind_u_component_850hPa,
        .wind_u_component_925hPa,
        .wind_u_component_1000hPa,
        .wind_v_component_50hPa,
        .wind_v_component_100hPa,
        .wind_v_component_150hPa,
        .wind_v_component_200hPa,
        .wind_v_component_250hPa,
        .wind_v_component_300hPa,
        .wind_v_component_400hPa,
        .wind_v_component_500hPa,
        .wind_v_component_600hPa,
        .wind_v_component_700hPa,
        .wind_v_component_850hPa,
        .wind_v_component_925hPa,
        .wind_v_component_1000hPa,
        .vertical_velocity_50hPa,
        .vertical_velocity_100hPa,
        .vertical_velocity_150hPa,
        .vertical_velocity_200hPa,
        .vertical_velocity_250hPa,
        .vertical_velocity_300hPa,
        .vertical_velocity_400hPa,
        .vertical_velocity_500hPa,
        .vertical_velocity_600hPa,
        .vertical_velocity_700hPa,
        .vertical_velocity_850hPa,
        .vertical_velocity_925hPa,
        .vertical_velocity_1000hPa
    ]

    static let surfaceVariables: [WeatherNextVariable] = [
        .wind_u_component_100m,
        .wind_v_component_100m,
        .wind_u_component_10m,
        .wind_v_component_10m,
        .temperature_2m,
        .pressure_msl,
        .sea_surface_temperature,
        .total_precipitation_6hr,
        .cloud_cover,
        .cloud_cover_low,
        .cloud_cover_mid,
        .cloud_cover_high,
        .wind_speed_10m,
        .wind_direction_10m,
        .wind_speed_100m,
        .wind_direction_100m
    ]

    static let pressureLevelVariables: [WeatherNextVariable] = [
        .geopotential_height_50hPa,
        .geopotential_height_100hPa,
        .geopotential_height_150hPa,
        .geopotential_height_200hPa,
        .geopotential_height_250hPa,
        .geopotential_height_300hPa,
        .geopotential_height_400hPa,
        .geopotential_height_500hPa,
        .geopotential_height_600hPa,
        .geopotential_height_700hPa,
        .geopotential_height_850hPa,
        .geopotential_height_925hPa,
        .geopotential_height_1000hPa,

        .relative_humidity_50hPa,
        .relative_humidity_100hPa,
        .relative_humidity_150hPa,
        .relative_humidity_200hPa,
        .relative_humidity_250hPa,
        .relative_humidity_300hPa,
        .relative_humidity_400hPa,
        .relative_humidity_500hPa,
        .relative_humidity_600hPa,
        .relative_humidity_700hPa,
        .relative_humidity_850hPa,
        .relative_humidity_925hPa,
        .relative_humidity_1000hPa,

        .temperature_50hPa,
        .temperature_100hPa,
        .temperature_150hPa,
        .temperature_200hPa,
        .temperature_250hPa,
        .temperature_300hPa,
        .temperature_400hPa,
        .temperature_500hPa,
        .temperature_600hPa,
        .temperature_700hPa,
        .temperature_850hPa,
        .temperature_925hPa,
        .temperature_1000hPa,

        .wind_u_component_50hPa,
        .wind_u_component_100hPa,
        .wind_u_component_150hPa,
        .wind_u_component_200hPa,
        .wind_u_component_250hPa,
        .wind_u_component_300hPa,
        .wind_u_component_400hPa,
        .wind_u_component_500hPa,
        .wind_u_component_600hPa,
        .wind_u_component_700hPa,
        .wind_u_component_850hPa,
        .wind_u_component_925hPa,
        .wind_u_component_1000hPa,

        .wind_v_component_50hPa,
        .wind_v_component_100hPa,
        .wind_v_component_150hPa,
        .wind_v_component_200hPa,
        .wind_v_component_250hPa,
        .wind_v_component_300hPa,
        .wind_v_component_400hPa,
        .wind_v_component_500hPa,
        .wind_v_component_600hPa,
        .wind_v_component_700hPa,
        .wind_v_component_850hPa,
        .wind_v_component_925hPa,
        .wind_v_component_1000hPa,

        .vertical_velocity_50hPa,
        .vertical_velocity_100hPa,
        .vertical_velocity_150hPa,
        .vertical_velocity_200hPa,
        .vertical_velocity_250hPa,
        .vertical_velocity_300hPa,
        .vertical_velocity_400hPa,
        .vertical_velocity_500hPa,
        .vertical_velocity_600hPa,
        .vertical_velocity_700hPa,
        .vertical_velocity_850hPa,
        .vertical_velocity_925hPa,
        .vertical_velocity_1000hPa
    ]

    var isPressureLevelVariable: Bool {
        Self.pressureLevelVariables.contains(self)
    }

    var isSurfaceVariable: Bool {
        Self.surfaceVariables.contains(self)
    }

    var isRelativeHumidityPressureLevel: Bool {
        switch self {
        case .relative_humidity_50hPa,
             .relative_humidity_100hPa,
             .relative_humidity_150hPa,
             .relative_humidity_200hPa,
             .relative_humidity_250hPa,
             .relative_humidity_300hPa,
             .relative_humidity_400hPa,
             .relative_humidity_500hPa,
             .relative_humidity_600hPa,
             .relative_humidity_700hPa,
             .relative_humidity_850hPa,
             .relative_humidity_925hPa,
             .relative_humidity_1000hPa:
            return true
        default:
            return false
        }
    }

    static func temperature(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        switch level {
        case .hPa50: return .temperature_50hPa
        case .hPa100: return .temperature_100hPa
        case .hPa150: return .temperature_150hPa
        case .hPa200: return .temperature_200hPa
        case .hPa250: return .temperature_250hPa
        case .hPa300: return .temperature_300hPa
        case .hPa400: return .temperature_400hPa
        case .hPa500: return .temperature_500hPa
        case .hPa600: return .temperature_600hPa
        case .hPa700: return .temperature_700hPa
        case .hPa850: return .temperature_850hPa
        case .hPa925: return .temperature_925hPa
        case .hPa1000: return .temperature_1000hPa
        }
    }

    static func windU(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        switch level {
        case .hPa50: return .wind_u_component_50hPa
        case .hPa100: return .wind_u_component_100hPa
        case .hPa150: return .wind_u_component_150hPa
        case .hPa200: return .wind_u_component_200hPa
        case .hPa250: return .wind_u_component_250hPa
        case .hPa300: return .wind_u_component_300hPa
        case .hPa400: return .wind_u_component_400hPa
        case .hPa500: return .wind_u_component_500hPa
        case .hPa600: return .wind_u_component_600hPa
        case .hPa700: return .wind_u_component_700hPa
        case .hPa850: return .wind_u_component_850hPa
        case .hPa925: return .wind_u_component_925hPa
        case .hPa1000: return .wind_u_component_1000hPa
        }
    }

    static func windV(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        switch level {
        case .hPa50: return .wind_v_component_50hPa
        case .hPa100: return .wind_v_component_100hPa
        case .hPa150: return .wind_v_component_150hPa
        case .hPa200: return .wind_v_component_200hPa
        case .hPa250: return .wind_v_component_250hPa
        case .hPa300: return .wind_v_component_300hPa
        case .hPa400: return .wind_v_component_400hPa
        case .hPa500: return .wind_v_component_500hPa
        case .hPa600: return .wind_v_component_600hPa
        case .hPa700: return .wind_v_component_700hPa
        case .hPa850: return .wind_v_component_850hPa
        case .hPa925: return .wind_v_component_925hPa
        case .hPa1000: return .wind_v_component_1000hPa
        }
    }

    static func windSpeed(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        switch level {
        case .hPa50: return .wind_speed_50hPa
        case .hPa100: return .wind_speed_100hPa
        case .hPa150: return .wind_speed_150hPa
        case .hPa200: return .wind_speed_200hPa
        case .hPa250: return .wind_speed_250hPa
        case .hPa300: return .wind_speed_300hPa
        case .hPa400: return .wind_speed_400hPa
        case .hPa500: return .wind_speed_500hPa
        case .hPa600: return .wind_speed_600hPa
        case .hPa700: return .wind_speed_700hPa
        case .hPa850: return .wind_speed_850hPa
        case .hPa925: return .wind_speed_925hPa
        case .hPa1000: return .wind_speed_1000hPa
        }
    }

    static func windDirection(level: WeatherNextPressureLevel) -> WeatherNextVariable {
        switch level {
        case .hPa50: return .wind_direction_50hPa
        case .hPa100: return .wind_direction_100hPa
        case .hPa150: return .wind_direction_150hPa
        case .hPa200: return .wind_direction_200hPa
        case .hPa250: return .wind_direction_250hPa
        case .hPa300: return .wind_direction_300hPa
        case .hPa400: return .wind_direction_400hPa
        case .hPa500: return .wind_direction_500hPa
        case .hPa600: return .wind_direction_600hPa
        case .hPa700: return .wind_direction_700hPa
        case .hPa850: return .wind_direction_850hPa
        case .hPa925: return .wind_direction_925hPa
        case .hPa1000: return .wind_direction_1000hPa
        }
    }

    var pressureLevel: WeatherNextPressureLevel? {
        switch self {
        case .geopotential_height_50hPa,
             .relative_humidity_50hPa,
             .temperature_50hPa,
             .wind_u_component_50hPa,
             .wind_v_component_50hPa,
             .vertical_velocity_50hPa:
            return .hPa50
        case .geopotential_height_100hPa,
             .relative_humidity_100hPa,
             .temperature_100hPa,
             .wind_u_component_100hPa,
             .wind_v_component_100hPa,
             .vertical_velocity_100hPa:
            return .hPa100
        case .geopotential_height_150hPa,
             .relative_humidity_150hPa,
             .temperature_150hPa,
             .wind_u_component_150hPa,
             .wind_v_component_150hPa,
             .vertical_velocity_150hPa:
            return .hPa150
        case .geopotential_height_200hPa,
             .relative_humidity_200hPa,
             .temperature_200hPa,
             .wind_u_component_200hPa,
             .wind_v_component_200hPa,
             .vertical_velocity_200hPa:
            return .hPa200
        case .geopotential_height_250hPa,
             .relative_humidity_250hPa,
             .temperature_250hPa,
             .wind_u_component_250hPa,
             .wind_v_component_250hPa,
             .vertical_velocity_250hPa:
            return .hPa250
        case .geopotential_height_300hPa,
             .relative_humidity_300hPa,
             .temperature_300hPa,
             .wind_u_component_300hPa,
             .wind_v_component_300hPa,
             .vertical_velocity_300hPa:
            return .hPa300
        case .geopotential_height_400hPa,
             .relative_humidity_400hPa,
             .temperature_400hPa,
             .wind_u_component_400hPa,
             .wind_v_component_400hPa,
             .vertical_velocity_400hPa:
            return .hPa400
        case .geopotential_height_500hPa,
             .relative_humidity_500hPa,
             .temperature_500hPa,
             .wind_u_component_500hPa,
             .wind_v_component_500hPa,
             .vertical_velocity_500hPa:
            return .hPa500
        case .geopotential_height_600hPa,
             .relative_humidity_600hPa,
             .temperature_600hPa,
             .wind_u_component_600hPa,
             .wind_v_component_600hPa,
             .vertical_velocity_600hPa:
            return .hPa600
        case .geopotential_height_700hPa,
             .relative_humidity_700hPa,
             .temperature_700hPa,
             .wind_u_component_700hPa,
             .wind_v_component_700hPa,
             .vertical_velocity_700hPa:
            return .hPa700
        case .geopotential_height_850hPa,
             .relative_humidity_850hPa,
             .temperature_850hPa,
             .wind_u_component_850hPa,
             .wind_v_component_850hPa,
             .vertical_velocity_850hPa:
            return .hPa850
        case .geopotential_height_925hPa,
             .relative_humidity_925hPa,
             .temperature_925hPa,
             .wind_u_component_925hPa,
             .wind_v_component_925hPa,
             .vertical_velocity_925hPa:
            return .hPa925
        case .geopotential_height_1000hPa,
             .relative_humidity_1000hPa,
             .temperature_1000hPa,
             .wind_u_component_1000hPa,
             .wind_v_component_1000hPa,
             .vertical_velocity_1000hPa:
            return .hPa1000
        default:
            return nil
        }
    }
}
