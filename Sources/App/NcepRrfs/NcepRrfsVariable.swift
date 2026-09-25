// See docs/ncep-rrfs/README.md for RRFS products, GRIB inputs and processing details.

import Foundation

enum NcepRrfsSurfaceVariable: String, CaseIterable, GenericVariable {
    case freezing_rain
    case snow_depth_water_equivalent
    /// Lowest detected cloud base, in metres above ground; may include scattered clouds.
    case cloud_base
    /// Ceiling diagnostic: lowest broken/overcast cloud base, in metres above ground.
    case cloud_ceiling
    /// Upper boundary of the cloud layer, in metres above ground; not its ceiling/base.
    case cloud_top
    case temperature_2m
    case relative_humidity_2m
    case pressure_msl
    case precipitation
    case snowfall_water_equivalent
    case snowfall
    case wind_gusts_10m
    /// Instantaneous maximum simulated radar reflectivity over the atmospheric column, in dBZ.
    case radar_reflectivity
    case visibility
    case shortwave_radiation
    case diffuse_radiation
    case categorical_freezing_rain
    case surface_temperature
    case snow_depth
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case cape
    case convective_inhibition
    case boundary_layer_height
    case total_column_integrated_water_vapour
    case freezing_level_height
    case sensible_heat_flux
    case latent_heat_flux
    case lifted_index
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_30m
    case wind_direction_30m
    case wind_speed_50m
    case wind_direction_50m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_100m
    case wind_direction_100m
    case wind_speed_160m
    case wind_direction_160m
    case wind_speed_320m
    case wind_direction_320m
    case temperature_30m
    case temperature_50m
    case temperature_80m
    case temperature_100m
    case temperature_160m
    case temperature_320m
    case soil_temperature_0cm
    case soil_moisture_0cm
    case soil_temperature_1cm
    case soil_moisture_1cm
    case soil_temperature_4cm
    case soil_moisture_4cm
    case soil_temperature_10cm
    case soil_moisture_10cm
    case soil_temperature_30cm
    case soil_moisture_30cm
    case soil_temperature_60cm
    case soil_moisture_60cm
    case soil_temperature_100cm
    case soil_moisture_100cm
    case soil_temperature_160cm
    case soil_moisture_160cm
    case soil_temperature_300cm
    case soil_moisture_300cm

    var omFileName: (file: String, level: Int) { (rawValue, 0) }

    var storePreviousForecast: Bool {
        switch self {
        case .radar_reflectivity: return true
        case .freezing_rain, .snow_depth_water_equivalent, .cloud_base, .cloud_ceiling, .cloud_top: return true
        case .temperature_2m, .relative_humidity_2m, .pressure_msl,
             .precipitation, .snowfall_water_equivalent,
             .snowfall, .wind_gusts_10m, .visibility,
             .shortwave_radiation, .diffuse_radiation, .categorical_freezing_rain,
             .surface_temperature, .snow_depth, .cloud_cover,
             .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high,
             .cape, .convective_inhibition, .boundary_layer_height,
             .total_column_integrated_water_vapour, .freezing_level_height, .sensible_heat_flux,
             .latent_heat_flux, .lifted_index, .wind_speed_10m,
             .wind_direction_10m, .wind_speed_30m, .wind_direction_30m,
             .wind_speed_50m, .wind_direction_50m, .wind_speed_80m,
             .wind_direction_80m, .wind_speed_100m, .wind_direction_100m,
             .wind_speed_160m, .wind_direction_160m, .wind_speed_320m,
             .wind_direction_320m, .temperature_30m, .temperature_50m,
             .temperature_80m, .temperature_100m, .temperature_160m,
             .temperature_320m, .soil_temperature_0cm, .soil_moisture_0cm,
             .soil_temperature_1cm, .soil_moisture_1cm, .soil_temperature_4cm,
             .soil_moisture_4cm, .soil_temperature_10cm, .soil_moisture_10cm,
             .soil_temperature_30cm, .soil_moisture_30cm, .soil_temperature_60cm,
             .soil_moisture_60cm, .soil_temperature_100cm, .soil_moisture_100cm,
             .soil_temperature_160cm, .soil_moisture_160cm, .soil_temperature_300cm,
             .soil_moisture_300cm:
            return true
        default:
            return false
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .radar_reflectivity: return false
        case .freezing_rain, .snow_depth_water_equivalent, .cloud_base, .cloud_ceiling, .cloud_top: return false
        case .temperature_2m, .surface_temperature:
            return true
        default:
            return false
        }
    }

    var unit: SiUnit {
        switch self {
        case .radar_reflectivity: return .undefined // TODO: Use dBZ once supported by the SDK.
        case .freezing_rain, .snow_depth_water_equivalent: return .millimetre
        case .cloud_base, .cloud_ceiling, .cloud_top: return .metre
        case .temperature_2m, .surface_temperature, .temperature_30m,
             .temperature_50m, .temperature_80m, .temperature_100m,
             .temperature_160m, .temperature_320m,
             .soil_temperature_0cm, .soil_temperature_1cm, .soil_temperature_4cm,
             .soil_temperature_10cm, .soil_temperature_30cm, .soil_temperature_60cm,
             .soil_temperature_100cm, .soil_temperature_160cm, .soil_temperature_300cm:
            return .celsius
        case .relative_humidity_2m, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high:
            return .percentage
        case .pressure_msl:
            return .hectopascal
        case .precipitation, .snowfall_water_equivalent:
            return .millimetre
        case .snowfall:
            return .centimetre
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_30m,
             .wind_speed_50m, .wind_speed_80m, .wind_speed_100m,
             .wind_speed_160m, .wind_speed_320m:
            return .metrePerSecond
        case .visibility, .snow_depth, .boundary_layer_height,
             .freezing_level_height:
            return .metre
        case .shortwave_radiation, .diffuse_radiation, .sensible_heat_flux,
             .latent_heat_flux:
            return .wattPerSquareMetre
        case .categorical_freezing_rain, .lifted_index:
            return .dimensionless
        case .cape, .convective_inhibition:
            return .joulePerKilogram
        case .total_column_integrated_water_vapour:
            return .kilogramPerSquareMetre
        case .wind_direction_10m, .wind_direction_30m, .wind_direction_50m,
             .wind_direction_80m, .wind_direction_100m, .wind_direction_160m,
             .wind_direction_320m:
            return .degreeDirection
        case .soil_moisture_0cm, .soil_moisture_1cm, .soil_moisture_4cm,
             .soil_moisture_10cm, .soil_moisture_30cm, .soil_moisture_60cm,
             .soil_moisture_100cm, .soil_moisture_160cm, .soil_moisture_300cm:
            return .cubicMetrePerCubicMetre
        }
    }

    var scalefactor: Float {
        switch self {
        case .radar_reflectivity: return 10
        case .freezing_rain, .snow_depth_water_equivalent: return 10
        case .cloud_base, .cloud_ceiling, .cloud_top: return 0.1
        case .temperature_2m, .surface_temperature, .temperature_30m,
             .temperature_50m, .temperature_80m, .temperature_100m,
             .temperature_160m, .temperature_320m,
             .soil_temperature_0cm, .soil_temperature_1cm, .soil_temperature_4cm,
             .soil_temperature_10cm, .soil_temperature_30cm, .soil_temperature_60cm,
             .soil_temperature_100cm, .soil_temperature_160cm, .soil_temperature_300cm:
            return 20
        case .relative_humidity_2m, .shortwave_radiation, .diffuse_radiation,
             .categorical_freezing_rain, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high, .convective_inhibition,
             .wind_direction_10m, .wind_direction_30m, .wind_direction_50m,
             .wind_direction_80m, .wind_direction_100m, .wind_direction_160m,
             .wind_direction_320m:
            return 1
        case .pressure_msl, .precipitation,
             .snowfall_water_equivalent, .wind_gusts_10m, .total_column_integrated_water_vapour,
             .lifted_index, .wind_speed_10m, .wind_speed_30m,
             .wind_speed_50m, .wind_speed_80m, .wind_speed_100m,
             .wind_speed_160m, .wind_speed_320m:
            return 10
        case .snowfall, .snow_depth:
            return 100
        case .visibility:
            return 0.05
        case .cape, .freezing_level_height:
            return 0.1
        case .boundary_layer_height:
            return 0.2
        case .sensible_heat_flux, .latent_heat_flux:
            return 0.144
        case .soil_moisture_0cm, .soil_moisture_1cm, .soil_moisture_4cm,
             .soil_moisture_10cm, .soil_moisture_30cm, .soil_moisture_60cm,
             .soil_moisture_100cm, .soil_moisture_160cm, .soil_moisture_300cm:
            return 1000
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .radar_reflectivity: return .linear
        case .freezing_rain: return .backwards_sum
        case .snow_depth_water_equivalent, .cloud_base, .cloud_ceiling, .cloud_top: return .linear
        case .temperature_2m, .pressure_msl, .surface_temperature,
             .total_column_integrated_water_vapour, .sensible_heat_flux, .latent_heat_flux,
             .lifted_index, .temperature_30m, .temperature_50m,
             .temperature_80m, .temperature_100m, .temperature_160m,
             .temperature_320m,
             .soil_temperature_0cm,
             .soil_moisture_0cm, .soil_temperature_1cm, .soil_moisture_1cm,
             .soil_temperature_4cm, .soil_moisture_4cm, .soil_temperature_10cm,
             .soil_moisture_10cm, .soil_temperature_30cm, .soil_moisture_30cm,
             .soil_temperature_60cm, .soil_moisture_60cm, .soil_temperature_100cm,
             .soil_moisture_100cm, .soil_temperature_160cm, .soil_moisture_160cm,
             .soil_temperature_300cm, .soil_moisture_300cm:
            return .hermite(bounds: nil)
        case .relative_humidity_2m, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .visibility, .snow_depth,
             .freezing_level_height:
            return .linear
        case .precipitation, .snowfall_water_equivalent, .snowfall:
            return .backwards_sum
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_30m,
             .wind_speed_50m, .wind_speed_80m, .wind_speed_100m,
             .wind_speed_160m, .wind_speed_320m:
            return .hermite(bounds: 0...1e9)
        case .shortwave_radiation, .diffuse_radiation:
            return .solar_backwards_averaged
        case .categorical_freezing_rain:
            return .backwards
        case .cape, .convective_inhibition, .boundary_layer_height:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m, .wind_direction_30m, .wind_direction_50m,
             .wind_direction_80m, .wind_direction_100m, .wind_direction_160m,
             .wind_direction_320m:
            return .linearDegrees
        }
    }

}

enum NcepRrfs15MinVariable: String, CaseIterable, GenericVariable {
    case freezing_rain
    /// Lowest detected cloud base, in metres above ground; may include scattered clouds.
    case cloud_base
    /// Ceiling diagnostic: lowest broken/overcast cloud base, in metres above ground.
    case cloud_ceiling
    /// Upper boundary of the cloud layer, in metres above ground; not its ceiling/base.
    case cloud_top
    case temperature_2m
    case relative_humidity_2m
    case pressure_msl
    case precipitation
    case snowfall_water_equivalent
    case snowfall
    case wind_gusts_10m
    /// Instantaneous maximum simulated radar reflectivity over the atmospheric column, in dBZ.
    case radar_reflectivity
    case visibility
    case shortwave_radiation
    case diffuse_radiation
    case categorical_freezing_rain
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m

    var omFileName: (file: String, level: Int) { (rawValue, 0) }

    var storePreviousForecast: Bool {
        switch self {
        case .radar_reflectivity: return true
        case .freezing_rain, .cloud_base, .cloud_ceiling, .cloud_top: return true
        case .temperature_2m, .relative_humidity_2m, .pressure_msl,
             .precipitation, .snowfall_water_equivalent,
             .snowfall, .wind_gusts_10m, .visibility,
             .shortwave_radiation, .diffuse_radiation, .categorical_freezing_rain,
             .wind_speed_10m, .wind_direction_10m, .wind_speed_80m,
             .wind_direction_80m:
            return true
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .radar_reflectivity: return false
        case .freezing_rain, .cloud_base, .cloud_ceiling, .cloud_top: return false
        case .temperature_2m:
            return true
        case .relative_humidity_2m, .pressure_msl,
             .precipitation, .snowfall_water_equivalent, .snowfall,
             .wind_gusts_10m, .visibility, .shortwave_radiation,
             .diffuse_radiation, .categorical_freezing_rain, .wind_speed_10m,
             .wind_direction_10m, .wind_speed_80m, .wind_direction_80m:
            return false
        }
    }

    var unit: SiUnit {
        switch self {
        case .radar_reflectivity: return .undefined // TODO: Use dBZ once supported by the SDK.
        case .freezing_rain: return .millimetre
        case .cloud_base, .cloud_ceiling, .cloud_top: return .metre
        case .temperature_2m:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .pressure_msl:
            return .hectopascal
        case .precipitation, .snowfall_water_equivalent:
            return .millimetre
        case .snowfall:
            return .centimetre
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_80m:
            return .metrePerSecond
        case .visibility:
            return .metre
        case .shortwave_radiation, .diffuse_radiation:
            return .wattPerSquareMetre
        case .categorical_freezing_rain:
            return .dimensionless
        case .wind_direction_10m, .wind_direction_80m:
            return .degreeDirection
        }
    }

    var scalefactor: Float {
        switch self {
        case .radar_reflectivity: return 10
        case .freezing_rain: return 10
        case .cloud_base, .cloud_ceiling, .cloud_top: return 0.1
        case .temperature_2m:
            return 20
        case .relative_humidity_2m, .shortwave_radiation, .diffuse_radiation,
             .categorical_freezing_rain, .wind_direction_10m, .wind_direction_80m:
            return 1
        case .pressure_msl, .precipitation,
             .snowfall_water_equivalent, .wind_gusts_10m, .wind_speed_10m,
             .wind_speed_80m:
            return 10
        case .snowfall:
            return 100
        case .visibility:
            return 0.05
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .radar_reflectivity: return .linear
        case .freezing_rain: return .backwards_sum
        case .cloud_base, .cloud_ceiling, .cloud_top: return .linear
        case .temperature_2m, .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .visibility:
            return .linear
        case .precipitation, .snowfall_water_equivalent, .snowfall:
            return .backwards_sum
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_80m:
            return .hermite(bounds: 0...1e9)
        case .shortwave_radiation, .diffuse_radiation:
            return .solar_backwards_averaged
        case .categorical_freezing_rain:
            return .backwards
        case .wind_direction_10m, .wind_direction_80m:
            return .linearDegrees
        }
    }

}

enum NcepRrfsEnsembleSurfaceVariable: String, CaseIterable, GenericVariable {
    case freezing_rain
    case temperature_2m
    case relative_humidity_2m
    case pressure_msl
    case precipitation
    case snowfall_water_equivalent
    case snowfall
    case wind_gusts_10m
    /// Instantaneous maximum simulated radar reflectivity over the atmospheric column, in dBZ.
    case radar_reflectivity
    case visibility
    case shortwave_radiation
    case categorical_freezing_rain
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case cape
    case convective_inhibition
    case total_column_integrated_water_vapour
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_160m
    case wind_direction_160m
    case wind_speed_320m
    case wind_direction_320m

    var omFileName: (file: String, level: Int) { (rawValue, 0) }

    var storePreviousForecast: Bool {
        switch self {
        case .radar_reflectivity: return true
        case .freezing_rain: return true
        case .temperature_2m, .relative_humidity_2m, .pressure_msl,
             .precipitation, .snowfall_water_equivalent,
             .snowfall, .wind_gusts_10m, .visibility,
             .shortwave_radiation, .categorical_freezing_rain, .cloud_cover,
             .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high,
             .cape, .convective_inhibition, .total_column_integrated_water_vapour,
             .wind_speed_10m, .wind_direction_10m, .wind_speed_80m,
             .wind_direction_80m, .wind_speed_160m, .wind_direction_160m,
             .wind_speed_320m, .wind_direction_320m:
            return true
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .radar_reflectivity: return false
        case .freezing_rain: return false
        case .temperature_2m:
            return true
        case .relative_humidity_2m, .pressure_msl,
             .precipitation, .snowfall_water_equivalent, .snowfall,
             .wind_gusts_10m, .visibility, .shortwave_radiation,
             .categorical_freezing_rain, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high, .cape,
             .convective_inhibition, .total_column_integrated_water_vapour, .wind_speed_10m,
             .wind_direction_10m, .wind_speed_80m, .wind_direction_80m,
             .wind_speed_160m, .wind_direction_160m, .wind_speed_320m,
             .wind_direction_320m:
            return false
        }
    }

    var unit: SiUnit {
        switch self {
        case .radar_reflectivity: return .undefined // TODO: Use dBZ once supported by the SDK.
        case .freezing_rain: return .millimetre
        case .temperature_2m:
            return .celsius
        case .relative_humidity_2m, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high:
            return .percentage
        case .pressure_msl:
            return .hectopascal
        case .precipitation, .snowfall_water_equivalent:
            return .millimetre
        case .snowfall:
            return .centimetre
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_80m,
             .wind_speed_160m, .wind_speed_320m:
            return .metrePerSecond
        case .visibility:
            return .metre
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .categorical_freezing_rain:
            return .dimensionless
        case .cape, .convective_inhibition:
            return .joulePerKilogram
        case .total_column_integrated_water_vapour:
            return .kilogramPerSquareMetre
        case .wind_direction_10m, .wind_direction_80m, .wind_direction_160m,
             .wind_direction_320m:
            return .degreeDirection
        }
    }

    var scalefactor: Float {
        switch self {
        case .radar_reflectivity: return 10
        case .freezing_rain: return 10
        case .temperature_2m:
            return 20
        case .relative_humidity_2m, .shortwave_radiation, .categorical_freezing_rain,
             .cloud_cover, .cloud_cover_low, .cloud_cover_mid,
             .cloud_cover_high, .convective_inhibition, .wind_direction_10m,
             .wind_direction_80m, .wind_direction_160m, .wind_direction_320m:
            return 1
        case .pressure_msl, .precipitation,
             .snowfall_water_equivalent, .wind_gusts_10m, .total_column_integrated_water_vapour,
             .wind_speed_10m, .wind_speed_80m, .wind_speed_160m,
             .wind_speed_320m:
            return 10
        case .snowfall:
            return 100
        case .visibility:
            return 0.05
        case .cape:
            return 0.1
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .radar_reflectivity: return .linear
        case .freezing_rain: return .backwards_sum
        case .temperature_2m, .pressure_msl, .total_column_integrated_water_vapour:
            return .hermite(bounds: nil)
        case .relative_humidity_2m, .cloud_cover, .cloud_cover_low,
             .cloud_cover_mid, .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .visibility:
            return .linear
        case .precipitation, .snowfall_water_equivalent, .snowfall:
            return .backwards_sum
        case .wind_gusts_10m, .wind_speed_10m, .wind_speed_80m,
             .wind_speed_160m, .wind_speed_320m:
            return .hermite(bounds: 0...1e9)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .categorical_freezing_rain:
            return .backwards
        case .cape, .convective_inhibition:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m, .wind_direction_80m, .wind_direction_160m,
             .wind_direction_320m:
            return .linearDegrees
        }
    }

}

enum NcepRrfsPressureVariableType: String, CaseIterable, RawRepresentableString {
    case temperature, relative_humidity, geopotential_height, wind_speed, wind_direction, vertical_velocity
}

protocol NcepRrfsPressureSchema {
    static var levels: [Int] { get }
    static var types: [NcepRrfsPressureVariableType] { get }
}

enum NcepRrfsDeterministicPressureSchema: NcepRrfsPressureSchema {
    static let levels = [50, 70, 100] + Array(stride(from: 125, through: 1000, by: 25))
    static let types = NcepRrfsPressureVariableType.allCases
}

enum NcepRrfsEnsemblePressureSchema: NcepRrfsPressureSchema {
    static let levels = [250, 300, 400, 500, 600, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
    static let types: [NcepRrfsPressureVariableType] = [.temperature, .relative_humidity, .geopotential_height, .wind_speed, .wind_direction]
}

struct NcepRrfsPressureField: PressureVariableRespresentable {
    let variable: NcepRrfsPressureVariableType
    let level: Int
}

struct NcepRrfsPressureVariable<Schema: NcepRrfsPressureSchema>: GenericVariable {
    let variable: NcepRrfsPressureVariableType
    let level: Int
    var rawValue: String { "\(variable.rawValue)_\(level)hPa" }
    init(variable: NcepRrfsPressureVariableType, level: Int) {
        self.variable = variable
        self.level = level
    }
    init?(rawValue: String) {
        guard let field = NcepRrfsPressureField(rawValue: rawValue), field.rawValue == rawValue,
              Schema.levels.contains(field.level), Schema.types.contains(field.variable) else { return nil }
        self.init(variable: field.variable, level: field.level)
    }
    var omFileName: (file: String, level: Int) { (rawValue, 0) }
    var storePreviousForecast: Bool { false }
    var isElevationCorrectable: Bool { false }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .relative_humidity:
            return .percentage
        case .geopotential_height:
            return .metre
        case .wind_speed:
            return .metrePerSecond
        case .vertical_velocity:
            // DZDT is already geometric velocity in m/s; do not apply wind-speed units.
            return .metrePerSecondNotUnitConverted
        case .wind_direction:
            return .degreeDirection
        }
    }

    var scalefactor: Float {
        switch variable {
        case .temperature:
            return 20
        case .relative_humidity, .geopotential_height, .wind_direction:
            return 1
        case .wind_speed:
            return 10
        case .vertical_velocity:
            return 100
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature, .vertical_velocity:
            return .hermite(bounds: nil)
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        case .geopotential_height:
            return .linear
        case .wind_speed:
            return .hermite(bounds: 0...1e9)
        case .wind_direction:
            return .linearDegrees
        }
    }

    static var allVariables: [Self] {
        Schema.levels.flatMap { level in Schema.types.map { Self(variable: $0, level: level) } }
    }
}

typealias NcepRrfsConusPressureVariable = NcepRrfsPressureVariable<NcepRrfsDeterministicPressureSchema>
typealias NcepRrfsEnsemblePressureVariable = NcepRrfsPressureVariable<NcepRrfsEnsemblePressureSchema>
typealias NcepRrfsVariable = SurfaceAndPressureVariable<NcepRrfsSurfaceVariable, NcepRrfsConusPressureVariable>
typealias NcepRrfsEnsembleVariable = SurfaceAndPressureVariable<NcepRrfsEnsembleSurfaceVariable, NcepRrfsEnsemblePressureVariable>
