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

enum GfsSurfaceVariableCatalog {
    static let temperature2m = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 20, interpolation: .hermite(bounds: nil), unit: .celsius, isElevationCorrectable: true)
    static let temperature80m = GfsVariableMetadata(scalefactor: 20, interpolation: .hermite(bounds: nil), unit: .celsius, isElevationCorrectable: true)
    static let temperature100m = temperature80m
    static let cloudCover = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
    static let cloudCoverLow = GfsVariableMetadata(scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
    static let cloudCoverMid = cloudCoverLow
    static let cloudCoverHigh = cloudCoverLow
    static let pressureMsl = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .hectopascal)
    static let relativeHumidity2m = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 1, interpolation: .hermite(bounds: 0...100), unit: .percentage)
    static let precipitation = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 10, interpolation: .backwards_sum, unit: .millimetre)
    static let windComponent = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .metrePerSecond)
    static let surfaceTemperature = GfsVariableMetadata(scalefactor: 20, interpolation: .hermite(bounds: nil), unit: .celsius, isElevationCorrectable: true)
    static let soilTemperature = surfaceTemperature
    static let soilMoisture = GfsVariableMetadata(scalefactor: 1000, interpolation: .hermite(bounds: nil), unit: .cubicMetrePerCubicMetre)
    static let snowDepth = GfsVariableMetadata(scalefactor: 100, interpolation: .linear, unit: .metre)
    static let sensibleHeatFlux = GfsVariableMetadata(scalefactor: 0.144, interpolation: .hermite(bounds: nil), unit: .wattPerSquareMetre)
    static let latentHeatFlux = sensibleHeatFlux
    static let showers = precipitation
    static let frozenPrecipitationPercent = GfsVariableMetadata(scalefactor: 1, interpolation: .backwards, unit: .percentage)
    static let categoricalFreezingRain = GfsVariableMetadata(scalefactor: 1, interpolation: .backwards, unit: .dimensionless)
    static let snowfallWaterEquivalent = precipitation
    static let convectiveInhibition = GfsVariableMetadata(scalefactor: 1, interpolation: .hermite(bounds: 0...10e9), unit: .joulePerKilogram)
    static let windGusts10m = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: 0...10e9), unit: .metrePerSecond)
    static let freezingLevelHeight = GfsVariableMetadata(scalefactor: 0.1, interpolation: .linear, unit: .metre)
    static let shortwaveRadiation = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 1, interpolation: .solar_backwards_averaged, unit: .wattPerSquareMetre)
    static let diffuseRadiation = shortwaveRadiation
    static let uvIndex = GfsVariableMetadata(scalefactor: 20, interpolation: .solar_backwards_averaged, unit: .dimensionless)
    static let uvIndexClearSky = uvIndex
    static let cape = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 0.1, interpolation: .hermite(bounds: 0...10e9), unit: .joulePerKilogram)
    static let liftedIndex = GfsVariableMetadata(storePreviousForecast: true, scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .dimensionless)
    static let visibility = GfsVariableMetadata(scalefactor: 0.05, interpolation: .linear, unit: .metre)
    static let boundaryLayerHeight = GfsVariableMetadata(scalefactor: 0.2, interpolation: .hermite(bounds: 0...10e9), unit: .metre)
    static let totalColumnIntegratedWaterVapour = GfsVariableMetadata(scalefactor: 10, interpolation: .hermite(bounds: nil), unit: .kilogramPerSquareMetre)
    static let massDensity8m = GfsVariableMetadata(scalefactor: 0.1, interpolation: .linear, unit: .microgramsPerCubicMetre)
}

protocol GfsSurfaceVariableMetadataBacked: GenericVariable {
    var field: GfsSurfaceField { get }
}

extension GfsSurfaceVariableMetadataBacked {
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
        case .temperature_2m: return GfsSurfaceVariableCatalog.temperature2m
        case .temperature_80m: return GfsSurfaceVariableCatalog.temperature80m
        case .temperature_100m: return GfsSurfaceVariableCatalog.temperature100m
        case .cloud_cover: return GfsSurfaceVariableCatalog.cloudCover
        case .cloud_cover_low: return GfsSurfaceVariableCatalog.cloudCoverLow
        case .cloud_cover_mid: return GfsSurfaceVariableCatalog.cloudCoverMid
        case .cloud_cover_high: return GfsSurfaceVariableCatalog.cloudCoverHigh
        case .pressure_msl: return GfsSurfaceVariableCatalog.pressureMsl
        case .relative_humidity_2m: return GfsSurfaceVariableCatalog.relativeHumidity2m
        case .precipitation: return GfsSurfaceVariableCatalog.precipitation
        case .wind_v_component_10m, .wind_u_component_10m,
             .wind_v_component_80m, .wind_u_component_80m,
             .wind_v_component_100m, .wind_u_component_100m:
            return GfsSurfaceVariableCatalog.windComponent
        case .surface_temperature: return GfsSurfaceVariableCatalog.surfaceTemperature
        case .soil_temperature_0_to_10cm, .soil_temperature_10_to_40cm,
             .soil_temperature_40_to_100cm, .soil_temperature_100_to_200cm:
            return GfsSurfaceVariableCatalog.soilTemperature
        case .soil_moisture_0_to_10cm, .soil_moisture_10_to_40cm,
             .soil_moisture_40_to_100cm, .soil_moisture_100_to_200cm:
            return GfsSurfaceVariableCatalog.soilMoisture
        case .snow_depth: return GfsSurfaceVariableCatalog.snowDepth
        case .sensible_heat_flux: return GfsSurfaceVariableCatalog.sensibleHeatFlux
        case .latent_heat_flux: return GfsSurfaceVariableCatalog.latentHeatFlux
        case .showers: return GfsSurfaceVariableCatalog.showers
        case .frozen_precipitation_percent: return GfsSurfaceVariableCatalog.frozenPrecipitationPercent
        case .categorical_freezing_rain: return GfsSurfaceVariableCatalog.categoricalFreezingRain
        case .snowfall_water_equivalent: return GfsSurfaceVariableCatalog.snowfallWaterEquivalent
        case .convective_inhibition: return GfsSurfaceVariableCatalog.convectiveInhibition
        case .wind_gusts_10m: return GfsSurfaceVariableCatalog.windGusts10m
        case .freezing_level_height: return GfsSurfaceVariableCatalog.freezingLevelHeight
        case .shortwave_radiation: return GfsSurfaceVariableCatalog.shortwaveRadiation
        case .diffuse_radiation: return GfsSurfaceVariableCatalog.diffuseRadiation
        case .uv_index: return GfsSurfaceVariableCatalog.uvIndex
        case .uv_index_clear_sky: return GfsSurfaceVariableCatalog.uvIndexClearSky
        case .cape: return GfsSurfaceVariableCatalog.cape
        case .lifted_index: return GfsSurfaceVariableCatalog.liftedIndex
        case .visibility: return GfsSurfaceVariableCatalog.visibility
        case .boundary_layer_height: return GfsSurfaceVariableCatalog.boundaryLayerHeight
        case .total_column_integrated_water_vapour: return GfsSurfaceVariableCatalog.totalColumnIntegratedWaterVapour
        case .mass_density_8m: return GfsSurfaceVariableCatalog.massDensity8m
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

    var field: GfsSurfaceField {
        switch self {
        case .temperature_2m: return .temperature_2m
        case .cloud_cover: return .cloud_cover
        case .cloud_cover_low: return .cloud_cover_low
        case .cloud_cover_mid: return .cloud_cover_mid
        case .cloud_cover_high: return .cloud_cover_high
        case .relative_humidity_2m: return .relative_humidity_2m
        case .precipitation: return .precipitation
        case .wind_v_component_10m: return .wind_v_component_10m
        case .wind_u_component_10m: return .wind_u_component_10m
        case .surface_temperature: return .surface_temperature
        case .soil_temperature_0_to_10cm: return .soil_temperature_0_to_10cm
        case .soil_temperature_10_to_40cm: return .soil_temperature_10_to_40cm
        case .soil_temperature_40_to_100cm: return .soil_temperature_40_to_100cm
        case .soil_temperature_100_to_200cm: return .soil_temperature_100_to_200cm
        case .soil_moisture_0_to_10cm: return .soil_moisture_0_to_10cm
        case .soil_moisture_10_to_40cm: return .soil_moisture_10_to_40cm
        case .soil_moisture_40_to_100cm: return .soil_moisture_40_to_100cm
        case .soil_moisture_100_to_200cm: return .soil_moisture_100_to_200cm
        case .snow_depth: return .snow_depth
        case .sensible_heat_flux: return .sensible_heat_flux
        case .latent_heat_flux: return .latent_heat_flux
        case .showers: return .showers
        case .snowfall_water_equivalent: return .snowfall_water_equivalent
        case .shortwave_radiation: return .shortwave_radiation
        case .diffuse_radiation: return .diffuse_radiation
        case .uv_index: return .uv_index
        case .uv_index_clear_sky: return .uv_index_clear_sky
        case .boundary_layer_height: return .boundary_layer_height
        case .total_column_integrated_water_vapour: return .total_column_integrated_water_vapour
        }
    }
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

    var field: GfsSurfaceField {
        switch self {
        case .temperature_80m: return .temperature_80m
        case .temperature_100m: return .temperature_100m
        case .pressure_msl: return .pressure_msl
        case .wind_v_component_80m: return .wind_v_component_80m
        case .wind_u_component_80m: return .wind_u_component_80m
        case .wind_v_component_100m: return .wind_v_component_100m
        case .wind_u_component_100m: return .wind_u_component_100m
        case .categorical_freezing_rain: return .categorical_freezing_rain
        case .convective_inhibition: return .convective_inhibition
        case .wind_gusts_10m: return .wind_gusts_10m
        case .freezing_level_height: return .freezing_level_height
        case .cape: return .cape
        case .lifted_index: return .lifted_index
        case .visibility: return .visibility
        }
    }
}

typealias Gfs013Variable = Gfs013SurfaceVariable
typealias Gfs025Variable = SurfaceAndPressureVariable<Gfs025SurfaceVariable, Gfs025PressureVariable>
