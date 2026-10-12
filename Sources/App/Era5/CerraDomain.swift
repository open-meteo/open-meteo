import Foundation
import Vapor
@preconcurrency import SwiftEccodes
import OmFileFormat

/**
Sources:
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-land?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-single-levels?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-height-levels?tab=overview
 */
enum CerraVariable: String, CaseIterable, GenericVariable {
    case temperature_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_100m
    case wind_direction_100m
    case wind_gusts_10m
    case relative_humidity_2m
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case snowfall_water_equivalent
    /*case soil_temperature_0_to_7cm  // special dataset now, with very fine grained spacing ~1-4cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm*/
    case shortwave_radiation
    case precipitation
    case direct_radiation
    case albedo
    case snow_depth
    case snow_depth_water_equivalent

    var storePreviousForecast: Bool {
        return false
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .wind_speed_10m:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m:
            return .linearDegrees
        case .wind_speed_100m:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_100m:
            return .linearDegrees
        case .wind_gusts_10m:
            return .hermite(bounds: 0...10e9)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .precipitation:
            return .backwards_sum
        case .direct_radiation:
            return .solar_backwards_averaged
        case .albedo:
            return .linear
        case .snow_depth, .snow_depth_water_equivalent:
            return .linear
        }
    }

    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .wind_gusts_10m: return "10m_wind_gust_since_previous_post_processing"
        case .relative_humidity_2m: return "2m_relative_humidity"
        case .temperature_2m: return "2m_temperature"
        case .cloud_cover_low: return "low_cloud_cover"
        case .cloud_cover_mid: return "medium_cloud_cover"
        case .cloud_cover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snow_fall_water_equivalent"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "time_integrated_surface_direct_short_wave_radiation_flux"
        case .wind_speed_10m: return "10m_wind_speed"
        case .wind_direction_10m: return "10m_wind_direction"
        case .wind_speed_100m: return "wind_speed"
        case .wind_direction_100m: return "wind_direction"
        case .albedo: return "albedo"
        case .snow_depth: return "snow_depth"
        case .snow_depth_water_equivalent: return "snow_depth_water_equivalent"
        }
    }

    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation, .direct_radiation, .precipitation, .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }

    var isHeightLevel: Bool {
        switch self {
        case .wind_speed_100m, .wind_direction_100m: return true
        default: return false
        }
    }

    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .shortwave_radiation, .direct_radiation: return (0, 1 / 3600) // joules to watt
        case .albedo: return (0, 100)
        case .snow_depth: return (0, 1 / 100) // cm to metre. GRIB files show metre, but it is cm
        default: return nil
        }
    }

    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .wind_speed_10m: return ["10si"]
        case .wind_direction_10m: return ["10wdir"]
        case .wind_speed_100m: return ["ws"]
        case .wind_direction_100m: return ["wdir"]
        case .wind_gusts_10m: return ["10fg", "gust"] // or "gust" on ubuntu 22.04
        case .relative_humidity_2m: return ["2r"]
        case .temperature_2m: return ["2t"]
        case .cloud_cover_low: return ["lcc"]
        case .cloud_cover_mid: return ["mcc"]
        case .cloud_cover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf"]
        case .albedo: return ["al"]
        case .snow_depth: return ["sd"]
        case .snow_depth_water_equivalent: return ["sde"]
        }
    }

    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .wind_gusts_10m: return 10
        case .relative_humidity_2m: return 1
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .wind_speed_10m: return 10
        case .wind_direction_10m: return 0.5
        case .wind_speed_100m: return 10
        case .wind_direction_100m: return 0.5
        case .albedo: return 1
        case .snow_depth: return 100 // 1cm res
        case .snow_depth_water_equivalent: return 1 // 1mm res
        }
    }

    var unit: SiUnit {
        switch self {
        case .wind_speed_10m, .wind_speed_100m, .wind_gusts_10m: return .metrePerSecond
        case .wind_direction_10m: return .degreeDirection
        case .wind_direction_100m: return .degreeDirection
        case .relative_humidity_2m: return .percentage
        case .temperature_2m: return .celsius
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimetre
        case .shortwave_radiation: return .wattPerSquareMetre
        case .precipitation: return .millimetre
        case .direct_radiation: return .wattPerSquareMetre
        case .albedo: return .percentage
        case .snow_depth: return .metre
        case .snow_depth_water_equivalent: return .millimetre
        }
    }
}
