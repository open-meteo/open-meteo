import Foundation

protocol EcmwfVariableDownloadable: GenericVariable {
}

enum EcmwfWaveVariable: String, CaseIterable, EcmwfVariableDownloadable, GenericVariableMixable {
    case wave_direction
    case wave_height
    case wave_period
    case wave_period_peak

    var interpolation: ReaderInterpolation {
        switch self {
        case .wave_height:
            return .linear
        case .wave_period, .wave_period_peak:
            return .hermite(bounds: 0...Float.infinity)
        case .wave_direction:
            return .linearDegrees
        }
    }

    var unit: SiUnit {
        switch self {
        case .wave_height:
            return .metre
        case .wave_period, .wave_period_peak:
            return .seconds
        case .wave_direction:
            return .degreeDirection
        }
    }
    var scalefactor: Float {
        let period: Float = 20 // 0.05s resolution
        let height: Float = 50 // 0.02m resolution
        let direction: Float = 1
        switch self {
        case .wave_height:
            return height
        case .wave_period, .wave_period_peak:
            return period
        case .wave_direction:
            return direction
        }
    }

    var storePreviousForecast: Bool {
        return false
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (nameInFiles, 0)
    }

    var nameInFiles: String {
        return rawValue
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var gribName: String? {
        // mp2    Mean zero-crossing wave period
        switch self {
        case .wave_direction:
            return "mwd"
        case .wave_height:
            return "swh" // Significant height of combined wind waves and swell
        case .wave_period:
            return "mwp"
        case .wave_period_peak:
            return "pp1d"
        }
    }
}

/// Represent a ECMWF variable as available in the grib2 files
/// Only AIFS has additional levels 100, 400 and 600
enum EcmwfVariable: String, CaseIterable, Hashable, EcmwfVariableDownloadable, GenericVariableMixable {
    case precipitation
    /**
     0 = No precipitation
     1 = Rain
     3 = Freezing rain (i.e. supercooled raindrops which freeze on contact with the ground and other surfaces)
     5 = Snow
     6 = Wet snow (i.e. snow particles which are starting to melt)
     7 = Mixture of rain and snow
     8 = Ice pellets
     12 = Freezing drizzle (i.e. supercooled drizzle which freezes on contact with the ground and other surfaces)
     */
    case precipitation_type
    /// only in AIFS025_single
    case snowfall_water_equivalent
    /// only in AIFS025_single
    case showers
    /// only in aifs
    case dew_point_2m
    case runoff
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case cape
    case shortwave_radiation
    case surface_temperature
    case geopotential_height_1000hPa
    case geopotential_height_925hPa
    case geopotential_height_850hPa
    case geopotential_height_700hPa
    case geopotential_height_600hPa
    case geopotential_height_500hPa
    case geopotential_height_400hPa
    case geopotential_height_300hPa
    case geopotential_height_250hPa
    case geopotential_height_200hPa
    case geopotential_height_100hPa
    case geopotential_height_50hPa
    case wind_v_component_1000hPa
    case wind_v_component_925hPa
    case wind_v_component_850hPa
    case wind_v_component_700hPa
    case wind_v_component_600hPa
    case wind_v_component_500hPa
    case wind_v_component_400hPa
    case wind_v_component_300hPa
    case wind_v_component_250hPa
    case wind_v_component_200hPa
    case wind_v_component_100hPa
    case wind_v_component_50hPa
    case wind_u_component_1000hPa
    case wind_u_component_925hPa
    case wind_u_component_850hPa
    case wind_u_component_700hPa
    case wind_u_component_600hPa
    case wind_u_component_500hPa
    case wind_u_component_400hPa
    case wind_u_component_300hPa
    case wind_u_component_250hPa
    case wind_u_component_200hPa
    case wind_u_component_100hPa
    case wind_u_component_50hPa
    case vertical_velocity_1000hPa
    case vertical_velocity_925hPa
    case vertical_velocity_850hPa
    case vertical_velocity_700hPa
    case vertical_velocity_600hPa
    case vertical_velocity_500hPa
    case vertical_velocity_400hPa
    case vertical_velocity_300hPa
    case vertical_velocity_250hPa
    case vertical_velocity_200hPa
    case vertical_velocity_100hPa
    case vertical_velocity_50hPa
    case temperature_1000hPa
    case temperature_925hPa
    case temperature_850hPa
    case temperature_700hPa
    case temperature_600hPa
    case temperature_500hPa
    case temperature_400hPa
    case temperature_300hPa
    case temperature_250hPa
    case temperature_200hPa
    case temperature_100hPa
    case temperature_50hPa
    case relative_humidity_1000hPa
    case relative_humidity_925hPa
    case relative_humidity_850hPa
    case relative_humidity_700hPa
    case relative_humidity_600hPa
    case relative_humidity_500hPa
    case relative_humidity_400hPa
    case relative_humidity_300hPa
    case relative_humidity_250hPa
    case relative_humidity_200hPa
    case relative_humidity_100hPa
    case relative_humidity_50hPa
    case pressure_msl
    case total_column_integrated_water_vapour
    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_100m
    case wind_u_component_100m
    case specific_humidity_1000hPa
    case specific_humidity_925hPa
    case specific_humidity_850hPa
    case specific_humidity_700hPa
    case specific_humidity_600hPa
    case specific_humidity_500hPa
    case specific_humidity_400hPa
    case specific_humidity_300hPa
    case specific_humidity_250hPa
    case specific_humidity_200hPa
    case specific_humidity_100hPa
    case specific_humidity_50hPa
    case temperature_2m
    case temperature_2m_min
    case temperature_2m_max
    /*case relative_vorticity_1000hPa
    case relative_vorticity_925hPa
    case relative_vorticity_850hPa
    case relative_vorticity_700hPa
    case relative_vorticity_600hPa
    case relative_vorticity_500hPa
    case relative_vorticity_400hPa
    case relative_vorticity_300hPa
    case relative_vorticity_250hPa
    case relative_vorticity_200hPa
    case relative_vorticity_100hPa
    case relative_vorticity_50hPa
    case divergence_of_wind_1000hPa
    case divergence_of_wind_925hPa
    case divergence_of_wind_850hPa
    case divergence_of_wind_700hPa
    case divergence_of_wind_600hPa
    case divergence_of_wind_500hPa
    case divergence_of_wind_400hPa
    case divergence_of_wind_300hPa
    case divergence_of_wind_250hPa
    case divergence_of_wind_200hPa
    case divergence_of_wind_100hPa
    case divergence_of_wind_50hPa*/

    case wind_gusts_10m

    // Cloudcover is calculated while downloading
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high

    /// Generated while downloading
    case relative_humidity_2m

    enum DownloadOrProcess {
        /// Only download the selected variable, bu to not create a om database
        case downloadOnly
        /// Download and reate database
        case downloadAndProcess
    }

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_v_component_10m, .wind_u_component_10m: return true
        case .wind_v_component_100m, .wind_u_component_100m: return true
        // case .weather_code: return true
        default: return false
        }
    }

    /// If true, download
    var includeInEnsemble: DownloadOrProcess? {
        switch self {
        case .precipitation, .runoff, .soil_temperature_0_to_7cm, .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .surface_temperature, .relative_humidity_2m, .shortwave_radiation, .cape, .pressure_msl, .wind_v_component_10m, .wind_v_component_100m, .wind_u_component_10m, .wind_u_component_100m, .wind_gusts_10m, .temperature_2m, .cloud_cover, .temperature_500hPa, .temperature_850hPa, .geopotential_height_500hPa, .geopotential_height_850hPa:
            return .downloadAndProcess
        case .dew_point_2m, .relative_humidity_925hPa, .relative_humidity_1000hPa, .relative_humidity_850hPa, .relative_humidity_700hPa, .relative_humidity_500hPa, .relative_humidity_300hPa, .relative_humidity_250hPa, .relative_humidity_200hPa, .relative_humidity_600hPa, .relative_humidity_400hPa, .relative_humidity_100hPa, .relative_humidity_50hPa:
            return .downloadOnly
        default: return nil
        }
    }

    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_max, .temperature_2m_min:
            return true
        default:
            return false
        }
    }

    static let pressure_levels = [1000, 925, 850, 700, 500, 300, 250, 200, 50]

    var omFileName: (file: String, level: Int) {
        return (nameInFiles, 0)
    }

    var nameInFiles: String {
        return rawValue
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    var unit: SiUnit {
        switch self {
        case .precipitation_type: return .dimensionless
        case .precipitation, .snowfall_water_equivalent, .showers, .runoff: return .millimetre
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .surface_temperature: return .celsius
        case .geopotential_height_1000hPa, .geopotential_height_925hPa, .geopotential_height_850hPa, .geopotential_height_700hPa, .geopotential_height_600hPa, .geopotential_height_500hPa, .geopotential_height_400hPa, .geopotential_height_300hPa, .geopotential_height_250hPa, .geopotential_height_200hPa, .geopotential_height_100hPa, .geopotential_height_50hPa: return .metre
        case .wind_v_component_1000hPa, .wind_v_component_925hPa, .wind_v_component_850hPa, .wind_v_component_700hPa, .wind_v_component_600hPa, .wind_v_component_500hPa, .wind_v_component_400hPa, .wind_v_component_300hPa, .wind_v_component_250hPa, .wind_v_component_200hPa, .wind_v_component_100hPa, .wind_v_component_50hPa, .wind_u_component_1000hPa, .wind_u_component_925hPa, .wind_u_component_850hPa, .wind_u_component_600hPa, .wind_u_component_700hPa, .wind_u_component_500hPa, .wind_u_component_400hPa, .wind_u_component_300hPa, .wind_u_component_250hPa, .wind_u_component_200hPa, .wind_u_component_100hPa, .wind_u_component_50hPa: return .metrePerSecond
        case .vertical_velocity_1000hPa, .vertical_velocity_925hPa, .vertical_velocity_850hPa, .vertical_velocity_600hPa, .vertical_velocity_700hPa, .vertical_velocity_500hPa, .vertical_velocity_400hPa, .vertical_velocity_300hPa, .vertical_velocity_250hPa, .vertical_velocity_200hPa, .vertical_velocity_100hPa, .vertical_velocity_50hPa: return .metrePerSecondNotUnitConverted
        case .temperature_1000hPa, .temperature_925hPa, .temperature_850hPa, .temperature_700hPa, .temperature_600hPa, .temperature_500hPa, .temperature_400hPa, .temperature_300hPa, .temperature_250hPa, .temperature_200hPa, .temperature_100hPa, .temperature_50hPa: return .celsius
        case .relative_humidity_1000hPa, .relative_humidity_925hPa, .relative_humidity_850hPa, .relative_humidity_700hPa, .relative_humidity_600hPa, .relative_humidity_500hPa, .relative_humidity_400hPa, .relative_humidity_300hPa, .relative_humidity_250hPa, .relative_humidity_200hPa, .relative_humidity_100hPa, .relative_humidity_50hPa: return .percentage
        case .pressure_msl: return .hectopascal
        case .total_column_integrated_water_vapour: return .kilogramPerSquareMetre
        case .wind_v_component_10m: return .metrePerSecond
        case .wind_u_component_10m: return .metrePerSecond
        case .specific_humidity_1000hPa, .specific_humidity_925hPa, .specific_humidity_850hPa, .specific_humidity_700hPa, .specific_humidity_600hPa, .specific_humidity_500hPa, .specific_humidity_400hPa, .specific_humidity_300hPa, .specific_humidity_250hPa, .specific_humidity_200hPa, .specific_humidity_100hPa, .specific_humidity_50hPa: return .gramPerKilogram
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min: return .celsius
        /*case .relative_vorticity_1000hPa, .relative_vorticity_925hPa, .relative_vorticity_850hPa, .relative_vorticity_700hPa, .relative_vorticity_600hPa, .relative_vorticity_500hPa, .relative_vorticity_400hPa, .relative_vorticity_300hPa, .relative_vorticity_250hPa, .relative_vorticity_200hPa, .relative_vorticity_100hPa, .relative_vorticity_50hPa: return .perSecond
        case .divergence_of_wind_1000hPa, .divergence_of_wind_925hPa, .divergence_of_wind_850hPa, .divergence_of_wind_700hPa, .divergence_of_wind_600hPa, .divergence_of_wind_500hPa, .divergence_of_wind_400hPa, .divergence_of_wind_300hPa, .divergence_of_wind_250hPa, .divergence_of_wind_200hPa, .divergence_of_wind_100hPa, .divergence_of_wind_50hPa: return .perSecond*/
        case .cloud_cover:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .dew_point_2m:
            return .celsius
        case .relative_humidity_2m:
            return .percentage
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return .cubicMetrePerCubicMetre
        case .cape:
            return .joulePerKilogram
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .wind_v_component_100m:
            return .metrePerSecond
        case .wind_u_component_100m:
            return .metrePerSecond
        case .wind_gusts_10m:
            return .metrePerSecond
        }
    }

    /// pressure level in hPa or meter in the grib files
    var level: Int? {
        switch self {
        case .precipitation, .precipitation_type, .snowfall_water_equivalent, .showers, .runoff: return nil
        case .soil_temperature_0_to_7cm: return 1
        case .soil_temperature_7_to_28cm: return 2
        case .soil_temperature_28_to_100cm: return 3
        case .soil_temperature_100_to_255cm: return 4
        case .surface_temperature: return nil
        case .geopotential_height_1000hPa: return 1000
        case .geopotential_height_925hPa: return 925
        case .geopotential_height_850hPa: return 850
        case .geopotential_height_700hPa: return 700
        case .geopotential_height_600hPa: return 600
        case .geopotential_height_500hPa: return 500
        case .geopotential_height_400hPa: return 400
        case .geopotential_height_300hPa: return 300
        case .geopotential_height_250hPa: return 250
        case .geopotential_height_200hPa: return 200
        case .geopotential_height_100hPa: return 100
        case .geopotential_height_50hPa: return 50
        case .wind_v_component_1000hPa: return 1000
        case .wind_v_component_925hPa: return 925
        case .wind_v_component_850hPa: return 850
        case .wind_v_component_700hPa: return 700
        case .wind_v_component_600hPa: return 600
        case .wind_v_component_500hPa: return 500
        case .wind_v_component_400hPa: return 400
        case .wind_v_component_300hPa: return 300
        case .wind_v_component_250hPa: return 250
        case .wind_v_component_200hPa: return 200
        case .wind_v_component_100hPa: return 100
        case .wind_v_component_50hPa: return 50
        case .wind_u_component_1000hPa: return 1000
        case .wind_u_component_925hPa: return 925
        case .wind_u_component_850hPa: return 850
        case .wind_u_component_700hPa: return 700
        case .wind_u_component_600hPa: return 600
        case .wind_u_component_500hPa: return 500
        case .wind_u_component_400hPa: return 400
        case .wind_u_component_300hPa: return 300
        case .wind_u_component_250hPa: return 250
        case .wind_u_component_200hPa: return 200
        case .wind_u_component_100hPa: return 100
        case .wind_u_component_50hPa: return 50
        case .vertical_velocity_1000hPa: return 1000
        case .vertical_velocity_925hPa: return 925
        case .vertical_velocity_850hPa: return 850
        case .vertical_velocity_700hPa: return 700
        case .vertical_velocity_600hPa: return 600
        case .vertical_velocity_500hPa: return 500
        case .vertical_velocity_400hPa: return 400
        case .vertical_velocity_300hPa: return 300
        case .vertical_velocity_250hPa: return 250
        case .vertical_velocity_200hPa: return 200
        case .vertical_velocity_100hPa: return 100
        case .vertical_velocity_50hPa: return 50
        case .temperature_1000hPa: return 1000
        case .temperature_925hPa: return 925
        case .temperature_850hPa: return 850
        case .temperature_700hPa: return 700
        case .temperature_600hPa: return 600
        case .temperature_500hPa: return 500
        case .temperature_400hPa: return 400
        case .temperature_300hPa: return 300
        case .temperature_250hPa: return 250
        case .temperature_200hPa: return 200
        case .temperature_100hPa: return 100
        case .temperature_50hPa: return 50
        case .relative_humidity_1000hPa: return 1000
        case .relative_humidity_925hPa: return 925
        case .relative_humidity_850hPa: return 850
        case .relative_humidity_700hPa: return 700
        case .relative_humidity_600hPa: return 600
        case .relative_humidity_500hPa: return 500
        case .relative_humidity_400hPa: return 400
        case .relative_humidity_300hPa: return 300
        case .relative_humidity_250hPa: return 250
        case .relative_humidity_200hPa: return 200
        case .relative_humidity_100hPa: return 100
        case .relative_humidity_50hPa: return 50
        case .pressure_msl: return nil
        case .total_column_integrated_water_vapour: return nil
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .specific_humidity_1000hPa: return 1000
        case .specific_humidity_925hPa: return 925
        case .specific_humidity_850hPa: return 850
        case .specific_humidity_700hPa: return 700
        case .specific_humidity_600hPa: return 600
        case .specific_humidity_500hPa: return 500
        case .specific_humidity_400hPa: return 400
        case .specific_humidity_300hPa: return 300
        case .specific_humidity_250hPa: return 250
        case .specific_humidity_200hPa: return 200
        case .specific_humidity_100hPa: return 100
        case .specific_humidity_50hPa: return 50
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min: return 2
        /*case .relative_vorticity_1000hPa: return 1000
        case .relative_vorticity_925hPa: return 925
        case .relative_vorticity_850hPa: return 850
        case .relative_vorticity_700hPa: return 700
        case .relative_vorticity_600hPa: return 600
        case .relative_vorticity_500hPa: return 500
        case .relative_vorticity_400hPa: return 400
        case .relative_vorticity_300hPa: return 300
        case .relative_vorticity_250hPa: return 250
        case .relative_vorticity_200hPa: return 200
        case .relative_vorticity_100hPa: return 100
        case .relative_vorticity_50hPa: return 50
        case .divergence_of_wind_1000hPa: return 1000
        case .divergence_of_wind_925hPa: return 925
        case .divergence_of_wind_850hPa: return 850
        case .divergence_of_wind_700hPa: return 700
        case .divergence_of_wind_600hPa: return 600
        case .divergence_of_wind_500hPa: return 500
        case .divergence_of_wind_400hPa: return 400
        case .divergence_of_wind_300hPa: return 300
        case .divergence_of_wind_250hPa: return 250
        case .divergence_of_wind_200hPa: return 200
        case .divergence_of_wind_100hPa: return 100
        case .divergence_of_wind_50hPa: return 50*/
        case .cloud_cover:
            return nil
        case .cloud_cover_low:
            return nil
        case .cloud_cover_mid:
            return nil
        case .cloud_cover_high:
            return nil
        case .dew_point_2m:
            return 2
        case .relative_humidity_2m:
            return 2
        case .soil_moisture_0_to_7cm:
            return 1
        case .soil_moisture_7_to_28cm:
            return 2
        case .soil_moisture_28_to_100cm:
            return 3
        case .soil_moisture_100_to_255cm:
            return 4
        case .cape:
            return nil
        case .shortwave_radiation:
            return nil
        case .wind_v_component_100m:
            return nil
        case .wind_u_component_100m:
            return nil
        case .wind_gusts_10m:
            return nil
        }
    }

    var gribName: String? {
        switch self {
        case .precipitation_type: return "ptype"
        case .precipitation: return "tp"
        case .snowfall_water_equivalent: return "sf"
        case .showers: return "cp"
        case .runoff: return "ro"
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm: return "sot" // sot?
        case .surface_temperature: return "skt"
        case .geopotential_height_1000hPa: return "gh"
        case .geopotential_height_925hPa: return "gh"
        case .geopotential_height_850hPa: return "gh"
        case .geopotential_height_700hPa: return "gh"
        case .geopotential_height_600hPa: return "gh"
        case .geopotential_height_500hPa: return "gh"
        case .geopotential_height_400hPa: return "gh"
        case .geopotential_height_300hPa: return "gh"
        case .geopotential_height_250hPa: return "gh"
        case .geopotential_height_200hPa: return "gh"
        case .geopotential_height_100hPa: return "gh"
        case .geopotential_height_50hPa: return "gh"
        case .wind_v_component_1000hPa: return "v"
        case .wind_v_component_925hPa: return "v"
        case .wind_v_component_850hPa: return "v"
        case .wind_v_component_700hPa: return "v"
        case .wind_v_component_600hPa: return "v"
        case .wind_v_component_500hPa: return "v"
        case .wind_v_component_400hPa: return "v"
        case .wind_v_component_300hPa: return "v"
        case .wind_v_component_250hPa: return "v"
        case .wind_v_component_200hPa: return "v"
        case .wind_v_component_100hPa: return "v"
        case .wind_v_component_50hPa: return "v"
        case .wind_u_component_1000hPa: return "u"
        case .wind_u_component_925hPa: return "u"
        case .wind_u_component_850hPa: return "u"
        case .wind_u_component_700hPa: return "u"
        case .wind_u_component_600hPa: return "u"
        case .wind_u_component_500hPa: return "u"
        case .wind_u_component_400hPa: return "u"
        case .wind_u_component_300hPa: return "u"
        case .wind_u_component_250hPa: return "u"
        case .wind_u_component_200hPa: return "u"
        case .wind_u_component_100hPa: return "u"
        case .wind_u_component_50hPa: return "u"
        case .vertical_velocity_1000hPa, .vertical_velocity_925hPa, .vertical_velocity_850hPa, .vertical_velocity_600hPa, .vertical_velocity_700hPa, .vertical_velocity_500hPa, .vertical_velocity_400hPa, .vertical_velocity_300hPa, .vertical_velocity_250hPa, .vertical_velocity_200hPa, .vertical_velocity_100hPa, .vertical_velocity_50hPa: return "w"
        case .temperature_1000hPa: return "t"
        case .temperature_925hPa: return "t"
        case .temperature_850hPa: return "t"
        case .temperature_700hPa: return "t"
        case .temperature_600hPa: return "t"
        case .temperature_500hPa: return "t"
        case .temperature_400hPa: return "t"
        case .temperature_300hPa: return "t"
        case .temperature_250hPa: return "t"
        case .temperature_200hPa: return "t"
        case .temperature_100hPa: return "t"
        case .temperature_50hPa: return "t"
        case .relative_humidity_1000hPa: return "r"
        case .relative_humidity_925hPa: return "r"
        case .relative_humidity_850hPa: return "r"
        case .relative_humidity_700hPa: return "r"
        case .relative_humidity_600hPa: return "r"
        case .relative_humidity_500hPa: return "r"
        case .relative_humidity_400hPa: return "r"
        case .relative_humidity_300hPa: return "r"
        case .relative_humidity_250hPa: return "r"
        case .relative_humidity_200hPa: return "r"
        case .relative_humidity_100hPa: return "r"
        case .relative_humidity_50hPa: return "r"
        case .pressure_msl: return "msl"
        case .total_column_integrated_water_vapour: return "tcwv"
        case .wind_v_component_10m: return "10v"
        case .wind_u_component_10m: return "10u"
        case .specific_humidity_1000hPa: return "q"
        case .specific_humidity_925hPa: return "q"
        case .specific_humidity_850hPa: return "q"
        case .specific_humidity_700hPa: return "q"
        case .specific_humidity_600hPa: return "q"
        case .specific_humidity_500hPa: return "q"
        case .specific_humidity_400hPa: return "q"
        case .specific_humidity_300hPa: return "q"
        case .specific_humidity_250hPa: return "q"
        case .specific_humidity_200hPa: return "q"
        case .specific_humidity_100hPa: return "q"
        case .specific_humidity_50hPa: return "q"
        case .temperature_2m: return "2t"
        case .temperature_2m_min: return "mn2t3"
        case .temperature_2m_max: return "mx2t3"
        /*case .relative_vorticity_1000hPa: return "vo"
        case .relative_vorticity_925hPa: return "vo"
        case .relative_vorticity_850hPa: return "vo"
        case .relative_vorticity_700hPa: return "vo"
        case .relative_vorticity_600hPa: return "vo"
        case .relative_vorticity_500hPa: return "vo"
        case .relative_vorticity_400hPa: return "vo"
        case .relative_vorticity_300hPa: return "vo"
        case .relative_vorticity_250hPa: return "vo"
        case .relative_vorticity_200hPa: return "vo"
        case .relative_vorticity_100hPa: return "vo"
        case .relative_vorticity_50hPa: return "vo"
        case .divergence_of_wind_1000hPa: return "d"
        case .divergence_of_wind_925hPa: return "d"
        case .divergence_of_wind_850hPa: return "d"
        case .divergence_of_wind_700hPa: return "d"
        case .divergence_of_wind_600hPa: return "d"
        case .divergence_of_wind_500hPa: return "d"
        case .divergence_of_wind_400hPa: return "d"
        case .divergence_of_wind_300hPa: return "d"
        case .divergence_of_wind_250hPa: return "d"
        case .divergence_of_wind_200hPa: return "d"
        case .divergence_of_wind_100hPa: return "d"
        case .divergence_of_wind_50hPa: return "d"*/
        case .cloud_cover:
            return "tcc"
        case .cloud_cover_low:
            return "lcc"
        case .cloud_cover_mid:
            return "mcc"
        case .cloud_cover_high:
            return "hcc"
        case .dew_point_2m:
            return "2d"
        case .relative_humidity_2m:
            return "2r"
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return "vsw"
        // case .soil_moisture_7_to_28cm:
        //    return "swvl2"
        case .cape:
            return "mucape"
        case .shortwave_radiation:
            return "ssrd"
        case .wind_v_component_100m:
            return "100v"
        case .wind_u_component_100m:
            return "100u"
        case .wind_gusts_10m:
            return "10fg"
        }
    }

    var scalefactor: Float {
        switch self {
        case .precipitation_type: return 1
        case .precipitation, .snowfall_water_equivalent, .showers, .runoff: return 10
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm: return 20
        case .surface_temperature: return 20
        case .geopotential_height_1000hPa, .geopotential_height_925hPa, .geopotential_height_850hPa, .geopotential_height_700hPa, .geopotential_height_600hPa, .geopotential_height_500hPa, .geopotential_height_400hPa, .geopotential_height_300hPa, .geopotential_height_250hPa, .geopotential_height_200hPa, .geopotential_height_100hPa, .geopotential_height_50hPa: return 1
        case .wind_v_component_1000hPa, .wind_v_component_925hPa, .wind_v_component_850hPa, .wind_v_component_700hPa, .wind_v_component_600hPa, .wind_v_component_500hPa, .wind_v_component_400hPa, .wind_v_component_300hPa, .wind_v_component_250hPa, .wind_v_component_200hPa, .wind_v_component_100hPa, .wind_v_component_50hPa: return 10
        case .wind_u_component_1000hPa, .wind_u_component_925hPa, .wind_u_component_850hPa, .wind_u_component_700hPa, .wind_u_component_600hPa, .wind_u_component_500hPa, .wind_u_component_400hPa, .wind_u_component_300hPa, .wind_u_component_250hPa, .wind_u_component_200hPa, .wind_u_component_100hPa, .wind_u_component_50hPa: return 10
        case .vertical_velocity_1000hPa, .vertical_velocity_925hPa, .vertical_velocity_850hPa, .vertical_velocity_600hPa, .vertical_velocity_700hPa, .vertical_velocity_500hPa, .vertical_velocity_400hPa, .vertical_velocity_300hPa, .vertical_velocity_250hPa, .vertical_velocity_200hPa, .vertical_velocity_100hPa, .vertical_velocity_50hPa: return (20..<100).interpolated(atFraction: (0..<500).fraction(of: Float(level ?? 0)))
        case .temperature_1000hPa, .temperature_925hPa, .temperature_850hPa, .temperature_700hPa, .temperature_600hPa, .temperature_500hPa, .temperature_400hPa, .temperature_300hPa, .temperature_250hPa, .temperature_200hPa, .temperature_100hPa, .temperature_50hPa: return 20
        case .relative_humidity_1000hPa, .relative_humidity_925hPa, .relative_humidity_850hPa, .relative_humidity_700hPa, .relative_humidity_600hPa, .relative_humidity_500hPa, .relative_humidity_400hPa, .relative_humidity_300hPa, .relative_humidity_250hPa, .relative_humidity_200hPa, .relative_humidity_100hPa, .relative_humidity_50hPa: return 1
        case .pressure_msl: return 10
        case .total_column_integrated_water_vapour: return 10
        case .wind_v_component_10m, .wind_u_component_100m: return 10
        case .wind_u_component_10m, .wind_v_component_100m: return 10
        case .specific_humidity_1000hPa, .specific_humidity_925hPa, .specific_humidity_850hPa, .specific_humidity_700hPa, .specific_humidity_600hPa, .specific_humidity_500hPa, .specific_humidity_400hPa, .specific_humidity_300hPa, .specific_humidity_250hPa, .specific_humidity_200hPa, .specific_humidity_100hPa, .specific_humidity_50hPa: return 100
        case .temperature_2m, .temperature_2m_min, .temperature_2m_max: return 20
        /*case .relative_vorticity_1000hPa, .relative_vorticity_925hPa, .relative_vorticity_850hPa, .relative_vorticity_700hPa, .relative_vorticity_600hPa, .relative_vorticity_500hPa, .relative_vorticity_400hPa, .relative_vorticity_300hPa, .relative_vorticity_250hPa, .relative_vorticity_200hPa, .relative_vorticity_100hPa, .relative_vorticity_50hPa: return 100
        case .divergence_of_wind_1000hPa, .divergence_of_wind_925hPa, .divergence_of_wind_850hPa, .divergence_of_wind_700hPa, .divergence_of_wind_600hPa, .divergence_of_wind_500hPa, .divergence_of_wind_400hPa, .divergence_of_wind_300hPa, .divergence_of_wind_250hPa, .divergence_of_wind_200hPa, .divergence_of_wind_100hPa, .divergence_of_wind_50hPa: return 100*/
        case .cloud_cover:
            return 1
        case .cloud_cover_low:
            return 1
        case .cloud_cover_mid:
            return 1
        case .cloud_cover_high:
            return 1
        case .dew_point_2m:
            return 20
        case .relative_humidity_2m:
            return 1
        case .soil_moisture_0_to_7cm, .soil_moisture_7_to_28cm, .soil_moisture_28_to_100cm, .soil_moisture_100_to_255cm:
            return 1000
        case .cape:
            return 0.1
        case .shortwave_radiation:
            return 1
        case .wind_gusts_10m:
            return 10
        }
    }

    func multiplyAdd(domain: EcmwfDomain, dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .surface_temperature, .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_1000hPa, .temperature_925hPa, .temperature_850hPa, .temperature_700hPa, .temperature_600hPa, .temperature_500hPa, .temperature_400hPa, .temperature_300hPa, .temperature_250hPa, .temperature_200hPa, .temperature_100hPa, .temperature_50hPa, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .precipitation, .showers, .snowfall_water_equivalent, .runoff:
            if domain == .aifs025_single {
                // AIFS Single is already kg/m2
                return (1, 0)
            }
            return (1000, 0) // meters to millimeter
        case .specific_humidity_1000hPa, .specific_humidity_925hPa, .specific_humidity_850hPa, .specific_humidity_700hPa, .specific_humidity_600hPa, .specific_humidity_500hPa, .specific_humidity_400hPa, .specific_humidity_300hPa, .specific_humidity_250hPa, .specific_humidity_200hPa, .specific_humidity_100hPa, .specific_humidity_50hPa:
            return (1000, 0)
        case .shortwave_radiation: return (1 / Float(dtSeconds), 0) // joules to watt
        default:
            return nil
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .precipitation, .showers, .snowfall_water_equivalent, .runoff: return .backwards_sum
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high, .relative_humidity_1000hPa, .relative_humidity_925hPa, .relative_humidity_850hPa, .relative_humidity_700hPa, .relative_humidity_600hPa, .relative_humidity_500hPa, .relative_humidity_400hPa, .relative_humidity_300hPa, .relative_humidity_250hPa, .relative_humidity_200hPa, .relative_humidity_100hPa, .relative_humidity_50hPa, .relative_humidity_2m: return .hermite(bounds: 0...100)
        case .shortwave_radiation: return .solar_backwards_averaged
        case .wind_gusts_10m: return .hermite(bounds: 0...1000)
        case .temperature_2m_min, .temperature_2m_max: return .backwards
        default: return .hermite(bounds: nil)
        }
    }
}

enum EcmwfVariableDerived: String, GenericVariableMixable {
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m
    case apparent_temperature
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case et0_fao_evapotranspiration
    case windspeed_10m
    case windspeed_100m
    case windspeed_1000hPa
    case windspeed_925hPa
    case windspeed_850hPa
    case windspeed_700hPa
    case windspeed_600hPa
    case windspeed_500hPa
    case windspeed_400hPa
    case windspeed_300hPa
    case windspeed_250hPa
    case windspeed_200hPa
    case windspeed_100hPa
    case windspeed_50hPa
    case wind_speed_10m
    case wind_speed_100m
    case wind_speed_1000hPa
    case wind_speed_925hPa
    case wind_speed_850hPa
    case wind_speed_700hPa
    case wind_speed_600hPa
    case wind_speed_500hPa
    case wind_speed_400hPa
    case wind_speed_300hPa
    case wind_speed_250hPa
    case wind_speed_200hPa
    case wind_speed_100hPa
    case wind_speed_50hPa
    case winddirection_10m
    case winddirection_100m
    case winddirection_1000hPa
    case winddirection_925hPa
    case winddirection_850hPa
    case winddirection_700hPa
    case winddirection_600hPa
    case winddirection_500hPa
    case winddirection_400hPa
    case winddirection_300hPa
    case winddirection_250hPa
    case winddirection_200hPa
    case winddirection_100hPa
    case winddirection_50hPa
    case wind_direction_10m
    case wind_direction_100m
    case wind_direction_1000hPa
    case wind_direction_925hPa
    case wind_direction_850hPa
    case wind_direction_700hPa
    case wind_direction_600hPa
    case wind_direction_500hPa
    case wind_direction_400hPa
    case wind_direction_300hPa
    case wind_direction_250hPa
    case wind_direction_200hPa
    case wind_direction_100hPa
    case wind_direction_50hPa
    case cloudcover_1000hPa
    case cloudcover_925hPa
    case cloudcover_850hPa
    case cloudcover_700hPa
    case cloudcover_600hPa
    case cloudcover_500hPa
    case cloudcover_400hPa
    case cloudcover_300hPa
    case cloudcover_250hPa
    case cloudcover_200hPa
    case cloudcover_100hPa
    case cloudcover_50hPa
    case cloud_cover_1000hPa
    case cloud_cover_925hPa
    case cloud_cover_850hPa
    case cloud_cover_700hPa
    case cloud_cover_600hPa
    case cloud_cover_500hPa
    case cloud_cover_400hPa
    case cloud_cover_300hPa
    case cloud_cover_250hPa
    case cloud_cover_200hPa
    case cloud_cover_100hPa
    case cloud_cover_50hPa
    case relativehumidity_1000hPa
    case relativehumidity_925hPa
    case relativehumidity_850hPa
    case relativehumidity_700hPa
    case relativehumidity_600hPa
    case relativehumidity_500hPa
    case relativehumidity_400hPa
    case relativehumidity_300hPa
    case relativehumidity_250hPa
    case relativehumidity_200hPa
    case relativehumidity_100hPa
    case relativehumidity_50hPa
    case dewpoint_1000hPa
    case dewpoint_925hPa
    case dewpoint_850hPa
    case dewpoint_700hPa
    case dewpoint_600hPa
    case dewpoint_500hPa
    case dewpoint_400hPa
    case dewpoint_300hPa
    case dewpoint_250hPa
    case dewpoint_200hPa
    case dewpoint_100hPa
    case dewpoint_50hPa
    case dew_point_1000hPa
    case dew_point_925hPa
    case dew_point_850hPa
    case dew_point_700hPa
    case dew_point_600hPa
    case dew_point_500hPa
    case dew_point_400hPa
    case dew_point_300hPa
    case dew_point_250hPa
    case dew_point_200hPa
    case dew_point_100hPa
    case dew_point_50hPa
    case soil_temperature_0_7cm
    case soil_temperature_0_10cm
    case soil_temperature_0_to_10cm
    case weathercode
    case weather_code
    case snowfall
    case is_day
    case surface_air_pressure
    case surface_pressure
    case skin_temperature
    case soil_temperature_0cm
    case rain
    case showers
    case wet_bulb_temperature_2m

    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high

    case terrestrial_radiation
    case terrestrial_radiation_instant
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
