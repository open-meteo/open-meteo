import Foundation

enum Era5Variable: String, CaseIterable, GenericVariable, GribMessageAssociated {
    case temperature_2m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_gusts_10m
    case dew_point_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case snowfall_water_equivalent
    /// Only ERA5-Land and CERRA have snow depth in ACTUAL height. ERA5 and ECMWF IFS use water equivalent and density
    case snow_depth
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case shortwave_radiation
    case precipitation
    case direct_radiation
    case boundary_layer_height
    case total_column_integrated_water_vapour

    case wave_height
    case wave_direction
    case wave_period
    case wave_peak_period

    case temperature_2m_spread
    case wind_u_component_100m_spread
    case wind_v_component_100m_spread
    case wind_u_component_10m_spread
    case wind_v_component_10m_spread
    case wind_gusts_10m_spread
    case dew_point_2m_spread
    case cloud_cover_spread
    case cloud_cover_low_spread
    case cloud_cover_mid_spread
    case cloud_cover_high_spread
    case pressure_msl_spread
    case snowfall_water_equivalent_spread
    case snow_depth_spread
    case soil_temperature_0_to_7cm_spread
    case soil_temperature_7_to_28cm_spread
    case soil_temperature_28_to_100cm_spread
    case soil_temperature_100_to_255cm_spread
    case soil_moisture_0_to_7cm_spread
    case soil_moisture_7_to_28cm_spread
    case soil_moisture_28_to_100cm_spread
    case soil_moisture_100_to_255cm_spread
    case shortwave_radiation_spread
    case precipitation_spread
    case direct_radiation_spread
    case boundary_layer_height_spread
    case total_column_integrated_water_vapour_spread
    
    case sea_surface_temperature
    case sea_surface_temperature_spread

    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String? {
        switch self {
        case .wind_u_component_100m: return "100m_u_component_of_wind"
        case .wind_v_component_100m: return "100m_v_component_of_wind"
        case .wind_u_component_10m: return "10m_u_component_of_wind"
        case .wind_v_component_10m: return "10m_v_component_of_wind"
        case .wind_gusts_10m: return "instantaneous_10m_wind_gust"
        case .dew_point_2m: return "2m_dewpoint_temperature"
        case .temperature_2m: return "2m_temperature"
        case .cloud_cover: return "total_cloud_cover"
        case .cloud_cover_low: return "low_cloud_cover"
        case .cloud_cover_mid: return "medium_cloud_cover"
        case .cloud_cover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snowfall"
        case .soil_temperature_0_to_7cm: return "soil_temperature_level_1"
        case .soil_temperature_7_to_28cm: return "soil_temperature_level_2"
        case .soil_temperature_28_to_100cm: return "soil_temperature_level_3"
        case .soil_temperature_100_to_255cm: return "soil_temperature_level_4"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "total_sky_direct_solar_radiation_at_surface"
        case .soil_moisture_0_to_7cm: return "volumetric_soil_water_layer_1"
        case .soil_moisture_7_to_28cm: return "volumetric_soil_water_layer_2"
        case .soil_moisture_28_to_100cm: return "volumetric_soil_water_layer_3"
        case .soil_moisture_100_to_255cm: return "volumetric_soil_water_layer_4"
            // NOTE: snow depth uses different definitions in ERA5 and ECMWF IFS. Only ERA5-land returns the actual height directly
        case .snow_depth: return "snow_depth"
        case .wave_height: return "significant_height_of_combined_wind_waves_and_swell"
        case .wave_direction: return "mean_wave_direction"
        case .wave_period: return "mean_wave_period"
        case .wave_peak_period: return "peak_wave_period"
        case .boundary_layer_height: return "boundary_layer_height"
        case .total_column_integrated_water_vapour: return "total_column_water_vapour"
        case .sea_surface_temperature: return "sea_surface_temperature"
        default: return nil
        }
    }

    func netCdfScaling(domain: CdsDomain) -> (offset: Float, scalefactor: Float)? {
        switch self {
        case .temperature_2m, .sea_surface_temperature: return (-273.15, 1) // kelvin to celsius
        case .dew_point_2m: return (-273.15, 1)
        case .cloud_cover, .cloud_cover_spread: return (0, 100) // fraction to percent
        case .cloud_cover_low, .cloud_cover_low_spread: return (0, 100) // fraction to percent
        case .cloud_cover_mid, .cloud_cover_mid_spread: return (0, 100)
        case .cloud_cover_high, .cloud_cover_high_spread: return (0, 100)
        case .pressure_msl: return (0, 1) // keep in Pa (not hPa)
        case .snowfall_water_equivalent, .snowfall_water_equivalent_spread: return (0, 1000) // meter to millimeter
        case .soil_temperature_0_to_7cm: return (-273.15, 1) // kelvin to celsius
        case .soil_temperature_7_to_28cm: return (-273.15, 1)
        case .soil_temperature_28_to_100cm: return (-273.15, 1)
        case .soil_temperature_100_to_255cm: return (-273.15, 1)
        case .shortwave_radiation, .shortwave_radiation_spread: return (0, 1 / Float(domain.dtSeconds)) // joules to watt
        case .precipitation, .precipitation_spread: return (0, 1000) // meter to millimeter
        case .direct_radiation, .direct_radiation_spread: return (0, 1 / Float(domain.dtSeconds))
        default:
            return nil
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wind_u_component_100m, .wind_v_component_100m,
                .wind_u_component_10m, .wind_v_component_10m: return 20 // 0.05 m/s resolution. Typically 10, but want to have sligthly higher resolution
        case .wind_u_component_100m_spread, .wind_v_component_100m_spread,
                .wind_u_component_10m_spread, .wind_v_component_10m_spread: return 50 // 0.02 m/s resolution
        case .cloud_cover, .cloud_cover_spread: return 1
        case .cloud_cover_low, .cloud_cover_low_spread: return 1
        case .cloud_cover_mid, .cloud_cover_mid_spread: return 1
        case .cloud_cover_high, .cloud_cover_high_spread: return 1
        case .wind_gusts_10m, .wind_gusts_10m_spread: return 10
        case .dew_point_2m, .dew_point_2m_spread: return 20
        case .temperature_2m, .temperature_2m_spread: return 20
        case .pressure_msl, .pressure_msl_spread: return 0.1
        case .snowfall_water_equivalent, .snowfall_water_equivalent_spread: return 10
        case .soil_temperature_0_to_7cm, .soil_temperature_0_to_7cm_spread: return 20
        case .soil_temperature_7_to_28cm, .soil_temperature_7_to_28cm_spread: return 20
        case .soil_temperature_28_to_100cm, .soil_temperature_28_to_100cm_spread: return 20
        case .soil_temperature_100_to_255cm, .soil_temperature_100_to_255cm_spread: return 20
        case .shortwave_radiation, .shortwave_radiation_spread: return 1
        case .precipitation, .precipitation_spread: return 10
        case .direct_radiation, .direct_radiation_spread: return 1
        case .soil_moisture_0_to_7cm, .soil_moisture_0_to_7cm_spread: return 1000
        case .soil_moisture_7_to_28cm, .soil_moisture_7_to_28cm_spread: return 1000
        case .soil_moisture_28_to_100cm, .soil_moisture_28_to_100cm_spread: return 1000
        case .soil_moisture_100_to_255cm, .soil_moisture_100_to_255cm_spread: return 1000
        case .snow_depth, .snow_depth_spread: return 100 // 1 cm resolution
        case .boundary_layer_height, .boundary_layer_height_spread:
            return 0.2 // 5m resolution
        case .wave_height:
            return 50 // 0.02m resolution
        case .wave_direction:
            return 1
        case .wave_period, .wave_peak_period:
            return 20 // 0.05s resolution
        case .total_column_integrated_water_vapour, .total_column_integrated_water_vapour_spread:
            return 10
        case .sea_surface_temperature, .sea_surface_temperature_spread:
            return 20
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .temperature_2m_spread:
            return .hermite(bounds: nil)
        case .wind_u_component_100m, .wind_u_component_100m_spread:
            return .hermite(bounds: nil)
        case .wind_v_component_100m, .wind_v_component_100m_spread:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_u_component_10m_spread:
            return .hermite(bounds: nil)
        case .wind_v_component_10m, .wind_v_component_10m_spread:
            return .hermite(bounds: nil)
        case .wind_gusts_10m, .wind_gusts_10m_spread:
            return .hermite(bounds: nil)
        case .dew_point_2m, .dew_point_2m_spread:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_spread:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low, .cloud_cover_low_spread:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid, .cloud_cover_mid_spread:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high, .cloud_cover_high_spread:
            return .hermite(bounds: 0...100)
        case .pressure_msl, .pressure_msl_spread:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent, .snowfall_water_equivalent_spread:
            return .backwards_sum
        case .snow_depth, .snow_depth_spread:
            return .linear
        case .soil_temperature_0_to_7cm, .soil_temperature_0_to_7cm_spread:
            return .hermite(bounds: nil)
        case .soil_temperature_7_to_28cm, .soil_temperature_7_to_28cm_spread:
            return .hermite(bounds: nil)
        case .soil_temperature_28_to_100cm, .soil_temperature_28_to_100cm_spread:
            return .hermite(bounds: nil)
        case .soil_temperature_100_to_255cm, .soil_temperature_100_to_255cm_spread:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_7cm, .soil_moisture_0_to_7cm_spread:
            return .hermite(bounds: nil)
        case .soil_moisture_7_to_28cm, .soil_moisture_7_to_28cm_spread:
            return .hermite(bounds: nil)
        case .soil_moisture_28_to_100cm, .soil_moisture_28_to_100cm_spread:
            return .hermite(bounds: nil)
        case .soil_moisture_100_to_255cm, .soil_moisture_100_to_255cm_spread:
            return .hermite(bounds: nil)
        case .shortwave_radiation, .shortwave_radiation_spread:
            return .solar_backwards_averaged
        case .precipitation, .precipitation_spread:
            return .backwards_sum
        case .direct_radiation, .direct_radiation_spread:
            return .solar_backwards_averaged
        case .wave_height:
            return .hermite(bounds: nil)
        case .wave_direction:
            return .linearDegrees
        case .wave_period, .wave_peak_period:
            return .hermite(bounds: nil)
        case .boundary_layer_height, .boundary_layer_height_spread:
            return .hermite(bounds: 0...10e9)
        case .total_column_integrated_water_vapour, .total_column_integrated_water_vapour_spread:
            return .hermite(bounds: nil)
        case .sea_surface_temperature, .sea_surface_temperature_spread:
            return .hermite(bounds: nil)
        }
    }

    func availableForDomain(domain: CdsDomain) -> Bool {
        if self.rawValue.contains("_spread") {
            return false
        }

        /// Snow depth is only directly available in era5-land
        /// Others have to download snow depth water equivalent and density separately (not implemented)
        if self == .snow_depth {
            return domain == .era5_land
        }

        // Waves are only available for ERA5 ocean at 0.5° resolution
        switch self {
        case .wave_height, .wave_period, .wave_direction, .wave_peak_period:
            return domain == .era5_ocean
        default:
            if domain == .era5_ocean {
                return false
            }
        }

        if domain == .ecmwf_ifs_analysis_long_window || domain == .ecmwf_ifs_analysis {
            switch self {
            case .wind_gusts_10m, .snowfall_water_equivalent, .snow_depth, .shortwave_radiation, .direct_radiation, .boundary_layer_height, .precipitation, .sea_surface_temperature:
                // PZ 2025-01-27: ECMWF removed precipitation from assimilation
                return false
            default:
                return true
            }
        }

        // Note: ERA5-Land wind, pressure, snowfall, radiation and precipitation are only linearly interpolated from ERA5
        if domain == .era5_land {
            switch self {
            case .temperature_2m, .dew_point_2m, .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
                return true
            default: return false
            }
        }
        return true
    }

    var marsGribCode: String {
        switch self {
        case .temperature_2m:
            return "167.128"
        case .wind_u_component_100m:
            return "246.228"
        case .wind_v_component_100m:
            return "247.228"
        case .wind_u_component_10m:
            return "165.128"
        case .wind_v_component_10m:
            return "166.128"
        case .wind_gusts_10m:
            return "49.128"
        case .dew_point_2m:
            return "168.128"
        case .cloud_cover:
            return "164.128"
        case .cloud_cover_low:
            return "186.128"
        case .cloud_cover_mid:
            return "187.128"
        case .cloud_cover_high:
            return "188.128"
        case .pressure_msl:
            return "151.128"
        case .snowfall_water_equivalent:
            return "144.128"
        case .snow_depth:
            fatalError("Not supported")
        case .soil_temperature_0_to_7cm:
            return "139.128"
        case .soil_temperature_7_to_28cm:
            return "170.128"
        case .soil_temperature_28_to_100cm:
            return "183.128"
        case .soil_temperature_100_to_255cm:
            return "236.128"
        case .soil_moisture_0_to_7cm:
            return "39.128"
        case .soil_moisture_7_to_28cm:
            return "40.128"
        case .soil_moisture_28_to_100cm:
            return "41.128"
        case .soil_moisture_100_to_255cm:
            return "42.128"
        case .shortwave_radiation:
            return "169.128"
        case .precipitation:
            return "228.128"
        case .direct_radiation:
            return "21.228"
        case .wave_height:
            fatalError("Not supported")
        case .wave_direction:
            fatalError("Not supported")
        case .wave_period, .wave_peak_period:
            fatalError("Not supported")
        case .boundary_layer_height:
            return "159.128"
        case .total_column_integrated_water_vapour:
            return "137.128"
        case .sea_surface_temperature:
            return "34.128"
        default:
            fatalError("Not supported")
        }
    }

    var unit: SiUnit {
        switch self {
        case .wind_u_component_100m, .wind_u_component_100m_spread, .wind_v_component_100m, .wind_v_component_100m_spread, .wind_u_component_10m, .wind_u_component_10m_spread, .wind_v_component_10m, .wind_v_component_10m_spread, .wind_gusts_10m, .wind_gusts_10m_spread: return .metrePerSecond
        case .dew_point_2m: return .celsius
        case .temperature_2m: return .celsius
        case .cloud_cover, .cloud_cover_spread: return .percentage
        case .cloud_cover_low, .cloud_cover_low_spread: return .percentage
        case .cloud_cover_mid, .cloud_cover_mid_spread: return .percentage
        case .cloud_cover_high, .cloud_cover_high_spread: return .percentage
        case .pressure_msl, .pressure_msl_spread: return .pascal
        case .snowfall_water_equivalent, .snowfall_water_equivalent_spread: return .millimetre
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .shortwave_radiation, .shortwave_radiation_spread: return .wattPerSquareMetre
        case .precipitation, .precipitation_spread: return .millimetre
        case .direct_radiation, .direct_radiation_spread: return .wattPerSquareMetre
        case .soil_moisture_0_to_7cm, .soil_moisture_0_to_7cm_spread: return .cubicMetrePerCubicMetre
        case .soil_moisture_7_to_28cm, .soil_moisture_7_to_28cm_spread: return .cubicMetrePerCubicMetre
        case .soil_moisture_28_to_100cm, .soil_moisture_28_to_100cm_spread: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_255cm, .soil_moisture_100_to_255cm_spread: return .cubicMetrePerCubicMetre
        case .snow_depth, .snow_depth_spread: return .metre
        case .wave_height:
            return .metre
        case .wave_direction:
            return .degreeDirection
        case .wave_period, .wave_peak_period:
            return .seconds
        case .dew_point_2m_spread, .temperature_2m_spread, .soil_temperature_0_to_7cm_spread, .soil_temperature_7_to_28cm_spread, .soil_temperature_28_to_100cm_spread, .soil_temperature_100_to_255cm_spread: return .kelvin
        case .boundary_layer_height, .boundary_layer_height_spread:
            return .metre
        case .total_column_integrated_water_vapour, .total_column_integrated_water_vapour_spread:
            return .kilogramPerSquareMetre
        case .sea_surface_temperature:
            return .celsius
        case .sea_surface_temperature_spread:
            return .kelvin
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dew_point_2m ||
            self == .soil_temperature_0_to_7cm || self == .soil_temperature_7_to_28cm ||
            self == .soil_temperature_28_to_100cm || self == .soil_temperature_100_to_255cm
    }

    var storePreviousForecast: Bool {
        return false
    }

    static func fromGrib(attributes: GribAttributes) -> Self? {
        if attributes.dataType == "es" {
            switch attributes.shortName {
            case "2t": return .temperature_2m_spread
            case "tcc": return .cloud_cover_spread
            case "lcc": return .cloud_cover_low_spread
            case "mcc": return .cloud_cover_mid_spread
            case "hcc": return .cloud_cover_high_spread
            case "msl": return .pressure_msl_spread
            case "sf": return .snowfall_water_equivalent_spread
            case "ssrd": return .shortwave_radiation_spread
            case "tp": return .precipitation_spread
            case "tidirswrf", "fdir": return .direct_radiation_spread
            case "100u": return .wind_u_component_100m_spread
            case "100v": return .wind_v_component_100m_spread
            case "10u": return .wind_u_component_10m_spread
            case "10v": return .wind_v_component_10m_spread
            case "10fg", "gust", "i10fg": return .wind_gusts_10m_spread
            case "2d": return .dew_point_2m_spread
            case "stl1": return .soil_temperature_0_to_7cm_spread
            case "stl2": return .soil_temperature_7_to_28cm_spread
            case "stl3": return .soil_temperature_28_to_100cm_spread
            case "stl4": return .soil_temperature_100_to_255cm_spread
            case "swvl1": return .soil_moisture_0_to_7cm_spread
            case "swvl2": return .soil_moisture_7_to_28cm_spread
            case "swvl3": return .soil_moisture_28_to_100cm_spread
            case "swvl4": return .soil_moisture_100_to_255cm_spread
            case "sde": return .snow_depth_spread
            case "blh": return .boundary_layer_height_spread
            case "tcwv": return .total_column_integrated_water_vapour_spread
            case "sst": return .sea_surface_temperature_spread
            default:
                return nil
            }
        }

        switch attributes.shortName {
        case "2t": return .temperature_2m
        case "tcc": return .cloud_cover
        case "lcc": return .cloud_cover_low
        case "mcc": return .cloud_cover_mid
        case "hcc": return .cloud_cover_high
        case "msl": return .pressure_msl
        case "sf": return .snowfall_water_equivalent
        case "ssrd": return .shortwave_radiation
        case "tp": return .precipitation
        case "tidirswrf", "fdir": return .direct_radiation
        case "100u": return .wind_u_component_100m
        case "100v": return .wind_v_component_100m
        case "10u": return .wind_u_component_10m
        case "10v": return .wind_v_component_10m
        case "10fg", "gust", "i10fg": return .wind_gusts_10m
        case "2d": return .dew_point_2m
        case "stl1": return .soil_temperature_0_to_7cm
        case "stl2": return .soil_temperature_7_to_28cm
        case "stl3": return .soil_temperature_28_to_100cm
        case "stl4": return .soil_temperature_100_to_255cm
        case "swvl1": return .soil_moisture_0_to_7cm
        case "swvl2": return .soil_moisture_7_to_28cm
        case "swvl3": return .soil_moisture_28_to_100cm
        case "swvl4": return .soil_moisture_100_to_255cm
        case "blh": return .boundary_layer_height
        case "tcwv": return .total_column_integrated_water_vapour
        case "sde": return .snow_depth
        case "swh": return .wave_height
        case "mwd": return .wave_direction
        case "mwp": return .wave_period
        case "pp1d": return .wave_peak_period
        case "sst": return .sea_surface_temperature
        default:
            return nil
        }
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
