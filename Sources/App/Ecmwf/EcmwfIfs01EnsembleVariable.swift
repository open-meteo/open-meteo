import Foundation

/// Native IFS 0.1° ensemble fields. Only unit conversion and deaccumulation happen at ingestion.
protocol EcmwfEnsembleVariable: EcmwfVariableDownloadable, CaseIterable {
    var storageMetadata: EcmwfVariable { get }
    var gribName: String { get }
    var level: Int? { get }
    var isPressureLevel: Bool { get }
}

extension EcmwfEnsembleVariable {
    var omFileName: (file: String, level: Int) { (rawValue, 0) }
    var scalefactor: Float { storageMetadata.scalefactor }
    var interpolation: ReaderInterpolation { storageMetadata.interpolation }
    var unit: SiUnit { storageMetadata.unit }
    var isElevationCorrectable: Bool { storageMetadata.isElevationCorrectable }
    var storePreviousForecast: Bool { storageMetadata.storePreviousForecast }
    var level: Int? { storageMetadata.level }
    var gribName: String { storageMetadata.gribName! }

    func matches(_ entry: Curl.EcmwfIndexEntry) -> Bool {
        guard (entry.levtype == .pl) == isPressureLevel else { return false }
        if isPressureLevel && entry.level != level { return false }
        if entry.levtype == .sol, let entryLevel = entry.level, entryLevel != level { return false }
        return matchesParameter(entry.param)
    }

    func matches(shortName: String, level: Int) -> Bool {
        if let expected = self.level, expected != level { return false }
        return matchesParameter(shortName)
    }

    private func matchesParameter(_ parameter: String) -> Bool {
        if parameter == gribName { return true }
        switch gribName {
        case "gh": return parameter == "z"
        case "10fg": return parameter == "max_i10fg"
        case "mx2t3": return ["max_2t", "mx2t6"].contains(parameter)
        case "mn2t3": return ["min_2t", "mn2t6"].contains(parameter)
        default: return false
        }
    }

    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        storageMetadata.multiplyAdd(domain: .ifs01_ensemble, dtSeconds: dtSeconds)
    }

    var skipHourZero: Bool {
        ["10fg", "mx2t3", "mn2t3", "ssrd", "tp", "sf", "ro"].contains(gribName)
    }
}

/// Surface fields are stored independently, including dewpoint and snow density.
enum EcmwfIfs01EnsembleSurfaceVariable: String, EcmwfEnsembleVariable {
    case precipitation
    case precipitation_type
    case snowfall_water_equivalent
    case snow_depth_water_equivalent
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
    case pressure_msl
    case total_column_integrated_water_vapour
    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_100m
    case wind_u_component_100m
    case temperature_2m
    case temperature_2m_min
    case temperature_2m_max
    case wind_gusts_10m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case ocean_u_current
    case ocean_v_current
    case sea_ice_thickness
    case sea_level_height_msl
    case dew_point_2m
    case snow_density

    var isPressureLevel: Bool { false }

    var storageMetadata: EcmwfVariable {
        switch self {
        case .dew_point_2m: return .temperature_2m
        case .snow_density: return .snow_depth
        default: return EcmwfVariable(rawValue: rawValue)!
        }
    }

    var gribName: String {
        switch self {
        case .dew_point_2m: return "2d"
        case .snow_density: return "rsn"
        default: return storageMetadata.gribName!
        }
    }

    var unit: SiUnit { self == .snow_density ? .kilogramPerCubicMetre : storageMetadata.unit }
    var scalefactor: Float { self == .snow_density ? 1 : storageMetadata.scalefactor }
}

/// Pressure vertical velocity is omega in Pa/s, never geometric velocity in m/s.
enum EcmwfIfs01EnsemblePressureVariable: String, EcmwfEnsembleVariable {
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
    case geopotential_height_150hPa
    case geopotential_height_100hPa
    case geopotential_height_50hPa
    case geopotential_height_10hPa
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
    case wind_v_component_150hPa
    case wind_v_component_100hPa
    case wind_v_component_50hPa
    case wind_v_component_10hPa
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
    case wind_u_component_150hPa
    case wind_u_component_100hPa
    case wind_u_component_50hPa
    case wind_u_component_10hPa
    case vertical_velocity_pressure_1000hPa
    case vertical_velocity_pressure_925hPa
    case vertical_velocity_pressure_850hPa
    case vertical_velocity_pressure_700hPa
    case vertical_velocity_pressure_600hPa
    case vertical_velocity_pressure_500hPa
    case vertical_velocity_pressure_400hPa
    case vertical_velocity_pressure_300hPa
    case vertical_velocity_pressure_250hPa
    case vertical_velocity_pressure_200hPa
    case vertical_velocity_pressure_150hPa
    case vertical_velocity_pressure_100hPa
    case vertical_velocity_pressure_50hPa
    case vertical_velocity_pressure_10hPa
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
    case temperature_150hPa
    case temperature_100hPa
    case temperature_50hPa
    case temperature_10hPa
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
    case relative_humidity_150hPa
    case relative_humidity_100hPa
    case relative_humidity_50hPa
    case relative_humidity_10hPa
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
    case specific_humidity_150hPa
    case specific_humidity_100hPa
    case specific_humidity_50hPa
    case specific_humidity_10hPa

    var isPressureLevel: Bool { true }
    var isPressureVelocity: Bool { rawValue.hasPrefix("vertical_velocity_pressure_") }

    var storageMetadata: EcmwfVariable {
        EcmwfVariable(rawValue: rawValue.replacingOccurrences(of: "vertical_velocity_pressure_", with: "vertical_velocity_"))!
    }

    // The SDK has no Pa/s unit. Do not label native omega as m/s or Pa.
    var unit: SiUnit { isPressureVelocity ? .undefined : storageMetadata.unit }
    var scalefactor: Float { isPressureVelocity ? 100 : storageMetadata.scalefactor }
}
