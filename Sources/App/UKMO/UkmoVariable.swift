import Foundation

/**
 List of all surface Ukmo variables
 */
enum UkmoSurfaceVariable: String, CaseIterable, UkmoVariableDownloadable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case cloud_cover_2m
    case cloud_base
    // case cloud_top

    case pressure_msl
    case relative_humidity_2m

    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m

    case precipitation
    case snowfall_water_equivalent
    case rain
    case hail
    case showers
    case freezing_level_height

    case cape
    case convective_inhibition

    case surface_temperature
    case visibility
    case snow_depth_water_equivalent

    case shortwave_radiation
    case direct_radiation
    case uv_index

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .rain, .snowfall_water_equivalent, .precipitation, .showers: return true
        case .wind_speed_10m, .wind_direction_10m: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .cape: return true
        case .shortwave_radiation, .direct_radiation: return true
        case .wind_gusts_10m: return true
        case .visibility: return true
        default: return false
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
        case .temperature_2m, .surface_temperature:
            return 20
        case .cloud_cover:
            return 1
        case .cloud_cover_low:
            return 1
        case .cloud_cover_mid:
            return 1
        case .cloud_cover_high:
            return 1
        case .relative_humidity_2m:
            return 1
        case .rain:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation, .direct_radiation:
            return 1
        case .snowfall_water_equivalent:
            return 10
        case .wind_speed_10m:
            return 10
        case .snow_depth_water_equivalent:
            return 10
        case .wind_direction_10m:
            return 1
        case .visibility:
            return 0.05 // 50 meter
        case .cloud_cover_2m:
            return 1
        case .cloud_base:// , .cloud_top:
            return 0.05 // 20 metre
        case .precipitation:
            return 10
        case .hail:
            return 10
        case .showers:
            return 10
        case .freezing_level_height:
            return 0.1 // zero height 10 metre resolution
        case .cape:
            return 0.1
        case .convective_inhibition: return 1
        case .uv_index: return 20
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_2m:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            return .hermite(bounds: 0...1000)
        case .rain, .precipitation, .hail, .showers:
            return .backwards_sum
        case .snowfall_water_equivalent, .snow_depth_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        case .wind_direction_10m:
            return .linearDegrees
        case .visibility:
            return .linear
        case .cloud_base:// , .cloud_top:
            return .hermite(bounds: 0...10e9)
        case .freezing_level_height:
            return .linear
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .uv_index:
            return .hermite(bounds: 0...1000)
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .celsius
        case .cloud_cover, .cloud_cover_2m:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .rain, .snow_depth_water_equivalent, .precipitation, .hail, .showers:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_speed_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            return .percentage
        case .visibility:
            return .metre
        case .cloud_base:// , .cloud_top:
            return .metre
        case .freezing_level_height:
            return .metre
        case .uv_index:
            return .dimensionless
        case .convective_inhibition: return .joulePerKilogram
        case .cape:
            return .joulePerKilogram
        }
    }

    func getNcFileName(domain: UkmoDomain, forecastHour: Int, run: Timestamp) -> String? {
        switch domain {
        case .global_deterministic_10km:
            switch self {
            case .showers, .snowfall_water_equivalent, .hail:
                // Global has only instantanous rates for snow and showers
                return nil
            // case .shortwave_radiation:
                // global has only direct radiation, but not diffuse/total
                // return nil
            case .cloud_base:
                return nil
            case .uv_index:
                return nil
            case .freezing_level_height:
                return nil
            default:
                break
            }
        case .global_ensemble_20km:
            switch self {
            case .showers, .hail:
                // Global has only instantanous rates for snow and showers
                return nil
// case .cloud_base:
            //    return "height_ASL_at_cloud_base_where_cloud_cover_2p5_oktas"
            // case .freezing_level_height:
            //    return "height_ASL_at_freezing_level"
            case .shortwave_radiation, .direct_radiation:
                // Radiation is only available until hour 30 for runs 6z and 18z
                if run.hour % 12 == 6 && forecastHour >= 31 {
                    return nil
                }
            case .precipitation:
                // precipitation not available for ensemble
                return nil
            case .rain, .snowfall_water_equivalent:
                if forecastHour >= 57 {
                    /// Only has 1 hourly aggregations, but timeintervals are actually 3 or 6 hourly
                    return nil
                }
            case .cloud_base, .freezing_level_height, .cloud_cover_2m, .convective_inhibition, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .uv_index:
                // Actually available, but not processed for ensembles
                return nil
            default:
                break
            }
        case .uk_deterministic_2km:
            switch self {
            case .convective_inhibition:
                return nil
            default:
                break
            }
        }

        switch self {
        case .cape:
            return "CAPE_surface"
        case .convective_inhibition:
            return "CIN_surface"
        case .cloud_cover_high:
            return "cloud_amount_of_high_cloud"
        case .temperature_2m:
            return "temperature_at_screen_level"
        case .cloud_cover:
            return "cloud_amount_of_total_cloud"
        case .cloud_cover_low:
            return  "cloud_amount_of_low_cloud"
        case .cloud_cover_mid:
            return  "cloud_amount_of_medium_cloud"
        case .cloud_cover_2m:
            return "fog_fraction_at_screen_level"
        case .cloud_base:
            return "height_AGL_at_cloud_base_where_cloud_cover_2p5_oktas"
        case .pressure_msl:
            return "pressure_at_mean_sea_level"
        case .relative_humidity_2m:
            return "relative_humidity_at_screen_level"
        case .wind_speed_10m:
            return "wind_speed_at_10m"
        case .wind_direction_10m:
            return "wind_direction_at_10m"
        case .wind_gusts_10m:
            return "wind_gust_at_10m"
        case .precipitation:
            // return "precipitation_rate"
            // hourly until 49, while rain is hourly until hour 57
            if domain == .global_deterministic_10km {
                if forecastHour >= 150 {
                    return "precipitation_accumulation-PT06H"
                }
                if forecastHour >= 49 {
                    return forecastHour % 3 == 0 ? "precipitation_accumulation-PT03H" : nil
                }
            }
            return "precipitation_accumulation-PT01H" // "precipitation_rate"
        case .snowfall_water_equivalent:
            return "snowfall_accumulation-PT01H"
        case .rain:
            // NOTE "rainfall_rate" is instantanous -> therefore the sum would be wrong
            // hourly until 57
            if forecastHour >= 150 {
                return "rainfall_accumulation-PT06H"
            }
            if forecastHour >= 57 {
                return "rainfall_accumulation-PT03H"
            }
            return "rainfall_accumulation-PT01H" // "rainfall_rate"
        case .hail:
            return "hail_fall_accumulation-PT01H"
        case .showers:
            return nil // "rainfall_rate_from_convection"
        case .freezing_level_height:
            return "height_AGL_at_freezing_level"
        case .surface_temperature:
            return "temperature_at_surface"
        case .visibility:
            return "visibility_at_screen_level"
        case .snow_depth_water_equivalent:
            return "snow_depth_water_equivalent"
        case .shortwave_radiation:
            if forecastHour > 54 {
                return nil
            }
            return "radiation_flux_in_shortwave_total_downward_at_surface"
        case .direct_radiation:
            // Solar radiation is instant. Deaveraging only procudes acceptable results for 1-hourly data.
            // Data after 54 hours is 3 hourly
            if forecastHour > 54 {
                return nil
            }
            return "radiation_flux_in_shortwave_direct_downward_at_surface"
        case .uv_index:
            return "radiation_flux_in_uv_downward_at_surface"
        }
    }

    var skipHour0: Bool {
        switch self {
        case .precipitation, .rain, .hail, .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature:
            return (-273.15, 1) // kelvin to celsius
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .cloud_cover_2m:
            return (0, 100) // fraction to %
        case .relative_humidity_2m:
            return (0, 100) // fraction to %
        case .precipitation, .rain, .snowfall_water_equivalent, .showers, .hail:
            return (0, 1000) // m to mm
        case .uv_index:
            // 0.025 m2/W to get the uv index
            // compared to https://www.aemet.es/es/eltiempo/prediccion/radiacionuv
            return (0, 1 / 0.25)
        case .pressure_msl:
            return (0, 1 / 100)
        default:
            return nil
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m, .surface_temperature:
            return true
        default:
            return false
        }
    }

    func withLevel(level: Float) -> UkmoSurfaceVariable {
        return self
    }
}

/**
 Types of pressure level variables
 */
enum UkmoPressureVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case geopotential_height
    case relative_humidity
    case vertical_velocity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct UkmoPressureVariable: PressureVariableRespresentable, UkmoVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: UkmoPressureVariableType
    let level: Int

    var storePreviousForecast: Bool {
        return false
    }

    var requiresOffsetCorrectionForMixing: Bool {
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
        case .wind_speed:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .wind_direction:
            return (0.2..<0.5).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
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
        case .wind_speed:
            return .hermite(bounds: 0...1000)
        case .wind_direction:
            return .linearDegrees
        case .geopotential_height:
            return .hermite(bounds: nil)
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
        case .wind_speed:
            return .metrePerSecond
        case .wind_direction:
            return .degreeDirection
        case .geopotential_height:
            return .metre
        case .relative_humidity:
            return .percentage
        case .vertical_velocity:
            return .metrePerSecondNotUnitConverted
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var skipHour0: Bool {
        return false
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch variable {
        case .temperature:
            return (-273.15, 1) // kelvin to celsius
        case .relative_humidity:
            return (0, 100) // fraction to %
        default:
            return nil
        }
    }

    func getNcFileName(domain: UkmoDomain, forecastHour: Int, run: Timestamp) -> String? {
        switch domain {
        case .global_deterministic_10km, .global_ensemble_20km:
            break
        case .uk_deterministic_2km:
            if variable == .vertical_velocity {
                return nil
            }
        }

        switch variable {
        case .temperature:
            return "temperature_on_pressure_levels"
        case .wind_speed:
            return "wind_speed_on_pressure_levels"
        case .wind_direction:
            return "wind_direction_on_pressure_levels"
        case .geopotential_height:
            return "height_ASL_on_pressure_levels"
        case .relative_humidity:
            return "relative_humidity_on_pressure_levels"
        case .vertical_velocity:
            return "wind_vertical_velocity_on_pressure_levels"
        }
    }

    func withLevel(level: Float) -> UkmoPressureVariable {
        return UkmoPressureVariable(variable: variable, level: Int(level))
    }
}

/**
 Types of height level variables
 */
enum UkmoHeightVariableType: String, CaseIterable {
    case temperature
    case wind_speed
    case wind_direction
    case cloud_cover
}

/**
 A height level variable on a given level in hPa / mb
 */
struct UkmoHeightVariable: HeightVariableRespresentable, UkmoVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: UkmoHeightVariableType
    let level: Int

    var storePreviousForecast: Bool {
        switch variable {
        case .wind_speed, .wind_direction:
            return level <= 300
        default:
            return false
        }
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            return 10
        case .wind_speed:
            return 10
        case .wind_direction:
            return 0.5
        case .cloud_cover:
            return 1
        }
    }

    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_speed:
            return .hermite(bounds: 0...1000)
        case .wind_direction:
            return .linearDegrees
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        }
    }

    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_speed:
            return .metrePerSecond
        case .wind_direction:
            return .degreeDirection
        case .cloud_cover:
            return .percentage
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var skipHour0: Bool {
        return false
    }

    var multiplyAdd: (offset: Float, scalefactor: Float)? {
        switch variable {
        case .temperature:
            return (-273.15, 1) // kelvin to celsius
        case .cloud_cover:
            return (0, 100) // fraction to %
        default:
            return nil
        }
    }

    func getNcFileName(domain: UkmoDomain, forecastHour: Int, run: Timestamp) -> String? {
        switch domain {
        case .global_deterministic_10km, .global_ensemble_20km:
            return nil
        case .uk_deterministic_2km:
            break
        }
        switch variable {
        case .temperature:
            return "temperature_on_height_levels"
        case .wind_speed:
            return "wind_speed_on_height_levels"
        case .wind_direction:
            return "wind_direction_on_height_levels"
        case .cloud_cover:
            return "cloud_amount_on_height_levels"
        }
    }

    func withLevel(level: Float) -> UkmoHeightVariable {
        return UkmoHeightVariable(variable: variable, level: Int(level))
    }
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias UkmoVariable = SurfacePressureAndHeightVariable<UkmoSurfaceVariable, UkmoPressureVariable, UkmoHeightVariable>

protocol UkmoVariableDownloadable: GenericVariable {
    var skipHour0: Bool { get }
    var multiplyAdd: (offset: Float, scalefactor: Float)? { get }
    func getNcFileName(domain: UkmoDomain, forecastHour: Int, run: Timestamp) -> String?
    func withLevel(level: Float) -> Self
}
