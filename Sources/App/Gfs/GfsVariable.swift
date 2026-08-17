import Foundation

enum GfsUvIndexVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    /// only GFS013
    case uv_index
    case uv_index_clear_sky
    
    var storePreviousForecast: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        return 20
    }

    var interpolation: ReaderInterpolation {
        return .solar_backwards_averaged
    }

    var unit: SiUnit {
        return .dimensionless
    }

    var isElevationCorrectable: Bool {
        return false
    }
}


/// Metadata shared by downloader and product-specific API variable enums.
struct GfsVariableMetadata {
    let storePreviousForecast: Bool
    let scalefactor: Float
    let interpolation: ReaderInterpolation
    let unit: SiUnit
    let isElevationCorrectable: Bool

    init(
        storePreviousForecast: Bool = false,
        scalefactor: Float,
        interpolation: ReaderInterpolation,
        unit: SiUnit,
        isElevationCorrectable: Bool = false
    ) {
        self.storePreviousForecast = storePreviousForecast
        self.scalefactor = scalefactor
        self.interpolation = interpolation
        self.unit = unit
        self.isElevationCorrectable = isElevationCorrectable
    }
}

protocol GfsSurfaceVariableMetadataBacked: GenericVariable {
    var field: GfsSurfaceField { get }
}

extension GfsSurfaceVariableMetadataBacked {
    var field: GfsSurfaceField {
        guard let field = GfsSurfaceField(rawValue: rawValue) else {
            preconditionFailure("\(Self.self).\(rawValue) has no matching GFS surface field")
        }
        return field
    }

    var metadata: GfsVariableMetadata { field.metadata }
    var storePreviousForecast: Bool { metadata.storePreviousForecast }
    var omFileName: (file: String, level: Int) { (rawValue, 0) }
    var scalefactor: Float { metadata.scalefactor }
    var interpolation: ReaderInterpolation { metadata.interpolation }
    var unit: SiUnit { metadata.unit }
    var isElevationCorrectable: Bool { metadata.isElevationCorrectable }
}

/// Semantic identity shared by domain-specific GFS-family variables.
/// This type does not parse API or downloader variables and therefore does not define availability.
enum GfsSurfaceField: String, Sendable, Hashable {
    case temperature_2m
    case temperature_80m
    case temperature_100m

    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl

    case relative_humidity_2m

    /// accumulated since forecast start
    case precipitation

    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_80m
    case wind_u_component_80m
    case wind_v_component_100m
    case wind_u_component_100m

    case surface_temperature
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm

    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm

    case snow_depth

    /// averaged since model start
    case sensible_heat_flux
    case latent_heat_flux

    case showers

    /// CPOFP Percent frozen precipitation [%]
    /// Download only to calculate `snowfall_water_equivalent` on the fly
    case frozen_precipitation_percent

    /// CFRZR Categorical Freezing Rain (0 or 1)
    case categorical_freezing_rain

    case snowfall_water_equivalent

    /// :CIN:surface: convective inhibition
    case convective_inhibition

    // case rain
    // case snowfall_convective_water_equivalent
    // case snowfall_water_equivalent

    case wind_gusts_10m
    case freezing_level_height
    case shortwave_radiation
    /// Only for HRRR domain. Otherwise diff could be estimated with https://arxiv.org/pdf/2007.01639.pdf 3) method
    case diffuse_radiation
    // case direct_radiation

    /// only GFS
    case uv_index
    case uv_index_clear_sky

    case cape
    case lifted_index

    case visibility

    case boundary_layer_height

    case total_column_integrated_water_vapour

    case mass_density_8m

    var metadata: GfsVariableMetadata {
        switch self {
        case .temperature_2m:
            return .init(storePreviousForecast: true, scalefactor: 20, interpolation: .hermite(bounds: nil), unit: .celsius, isElevationCorrectable: true)
        case .temperature_80m, .temperature_100m, .surface_temperature,
             .soil_temperature_0_to_10cm, .soil_temperature_10_to_40cm,
             .soil_temperature_40_to_100cm, .soil_temperature_100_to_200cm:
            return .init(scalefactor: 20, interpolation: .hermite(bounds: nil), unit: .celsius, isElevationCorrectable: true)
        case .cloud_cover:
            return .init(storePreviousForecast: true, scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
        case .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .init(scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
        case .pressure_msl:
            return .init(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .hectopascal)
        case .relative_humidity_2m:
            return .init(storePreviousForecast: true, scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
        case .precipitation, .showers, .snowfall_water_equivalent:
            return .init(storePreviousForecast: true, scalefactor: 10, interpolation: .backwards_sum, unit: .millimetre)
        case .wind_v_component_10m, .wind_u_component_10m,
             .wind_v_component_80m, .wind_u_component_80m,
             .wind_v_component_100m, .wind_u_component_100m:
            return .init(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .metrePerSecond)
        case .soil_moisture_0_to_10cm, .soil_moisture_10_to_40cm,
             .soil_moisture_40_to_100cm, .soil_moisture_100_to_200cm:
            return .init(scalefactor: 1000, interpolation: .hermite(bounds: nil), unit: .cubicMetrePerCubicMetre)
        case .snow_depth:
            return .init(scalefactor: 100, interpolation: .linear, unit: .metre)
        case .sensible_heat_flux, .latent_heat_flux:
            return .init(scalefactor: 0.144, interpolation: .hermite(bounds: nil), unit: .wattPerSquareMetre)
        case .frozen_precipitation_percent:
            return .init(scalefactor: 1, interpolation: .backwards, unit: .percentage)
        case .categorical_freezing_rain:
            return .init(scalefactor: 1, interpolation: .backwards, unit: .dimensionless)
        case .convective_inhibition:
            return .init(scalefactor: 1, interpolation: .hermite(bounds: 0...10e9), unit: .joulePerKilogram)
        case .wind_gusts_10m:
            return .init(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: 0...10e9), unit: .metrePerSecond)
        case .freezing_level_height:
            return .init(scalefactor: 0.1, interpolation: .linear, unit: .metre)
        case .shortwave_radiation, .diffuse_radiation:
            return .init(storePreviousForecast: true, scalefactor: 1, interpolation: .solar_backwards_averaged, unit: .wattPerSquareMetre)
        case .uv_index, .uv_index_clear_sky:
            return .init(scalefactor: 20, interpolation: .solar_backwards_averaged, unit: .dimensionless)
        case .cape:
            return .init(storePreviousForecast: true, scalefactor: 0.1, interpolation: .hermite(bounds: 0...10e9), unit: .joulePerKilogram)
        case .lifted_index:
            return .init(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .dimensionless)
        case .visibility:
            return .init(scalefactor: 0.05, interpolation: .linear, unit: .metre)
        case .boundary_layer_height:
            return .init(scalefactor: 0.2, interpolation: .hermite(bounds: 0...10e9), unit: .metre)
        case .total_column_integrated_water_vapour:
            return .init(scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .kilogramPerSquareMetre)
        case .mass_density_8m:
            return .init(scalefactor: 0.1, interpolation: .linear, unit: .microgramsPerCubicMetre)
        }
    }
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableType: String, CaseIterable, RawRepresentableString {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case cloud_cover
    case relative_humidity
    case vertical_velocity
}

/// Semantic identity of a pressure-level field, independent of domain availability.
struct GfsPressureField: PressureVariableRespresentable, Hashable, Sendable {
    let variable: GfsPressureVariableType
    let level: Int
}

protocol GfsPressureVariableSchema {
    static var levels: [Int] { get }
    static var variableTypes: [GfsPressureVariableType] { get }
    static func supports(variable: GfsPressureVariableType, level: Int) -> Bool
}

extension GfsPressureVariableSchema {
    static func supports(variable: GfsPressureVariableType, level: Int) -> Bool {
        levels.contains(level) && variableTypes.contains(variable)
    }
}

struct GfsPressureVariable<Schema: GfsPressureVariableSchema>: GenericVariable {
    let variable: GfsPressureVariableType
    let level: Int

    init(variable: GfsPressureVariableType, level: Int) {
        self.variable = variable
        self.level = level
    }

    static var allVariables: [Self] {
        Schema.levels.reversed().flatMap { level in
            Schema.variableTypes.compactMap { variable in
                Schema.supports(variable: variable, level: level) ? Self(variable: variable, level: level) : nil
            }
        }
    }

    init?(rawValue: String) {
        guard
            let field = GfsPressureField(rawValue: rawValue),
            Schema.supports(variable: field.variable, level: field.level)
        else {
            return nil
        }
        self.init(variable: field.variable, level: field.level)
    }

    var rawValue: String { GfsPressureField(variable: variable, level: level).rawValue }

    var storePreviousForecast: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .wind_u_component, .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .cloud_cover:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .vertical_velocity:
            return (20..<100).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
        case .geopotential_height:
            return .linear
        case .cloud_cover:
            return .linear
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        case .vertical_velocity:
            return .hermite(bounds: nil)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .metrePerSecond
        case .wind_v_component:
            return .metrePerSecond
        case .geopotential_height:
            return .metre
        case .cloud_cover:
            return .percentage
        case .relative_humidity:
            return .percentage
        case .vertical_velocity:
            return .metrePerSecondNotUnitConverted
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }
}

enum Gfs025PressureVariableSchema: GfsPressureVariableSchema {
    static let levels = [10, 15, 20, 30, 40, 50, 70, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
    static let variableTypes = GfsPressureVariableType.allCases

    static func supports(variable: GfsPressureVariableType, level: Int) -> Bool {
        guard levels.contains(level), variableTypes.contains(variable) else {
            return false
        }
        return variable != .cloud_cover || (level >= 50 && level != 70)
    }
}

enum HrrrPressureVariableSchema: GfsPressureVariableSchema {
    static let levels = [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
    static let variableTypes: [GfsPressureVariableType] = [.temperature, .wind_u_component, .wind_v_component, .geopotential_height, .relative_humidity, .vertical_velocity]
}

enum Gefs05PressureVariableSchema: GfsPressureVariableSchema {
    static let levels = [50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000]
    static let variableTypes: [GfsPressureVariableType] = [.temperature, .wind_u_component, .wind_v_component, .geopotential_height, .relative_humidity, .vertical_velocity]
}

typealias Gfs025PressureVariable = GfsPressureVariable<Gfs025PressureVariableSchema>
typealias HrrrPressureVariable = GfsPressureVariable<HrrrPressureVariableSchema>
typealias Gefs05PressureVariable = GfsPressureVariable<Gefs05PressureVariableSchema>

/// Product-specific enums explicitly define availability while sharing GFS metadata.
enum Gfs013SurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case relative_humidity_2m
    case precipitation
    case wind_v_component_10m
    case wind_u_component_10m
    case surface_temperature
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    case snow_depth
    case sensible_heat_flux
    case latent_heat_flux
    case showers
    case snowfall_water_equivalent
    case shortwave_radiation
    case diffuse_radiation
    case uv_index
    case uv_index_clear_sky
    case boundary_layer_height
    case total_column_integrated_water_vapour

}

enum Gfs025SurfaceVariable: String, CaseIterable, GfsSurfaceVariableMetadataBacked {
    case temperature_80m
    case temperature_100m
    case pressure_msl
    case wind_v_component_80m
    case wind_u_component_80m
    case wind_v_component_100m
    case wind_u_component_100m
    case categorical_freezing_rain
    case convective_inhibition
    case wind_gusts_10m
    case freezing_level_height
    case cape
    case lifted_index
    case visibility

}

typealias Gfs013Variable = Gfs013SurfaceVariable
typealias Gfs025Variable = SurfaceAndPressureVariable<Gfs025SurfaceVariable, Gfs025PressureVariable>
