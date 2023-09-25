import Foundation

protocol DecodableApiVariable {
    static func from(api: ApiVariable) -> Self?
}

/// Decodable variable that can be specified in an URL
struct ApiVariable {
    /// Reference to the original. Could be `soil_moisture_7_to_28cm` or `soil_moisture_7_28cm`
    let original: Substring
    let variable: com_openmeteo_api_result_VariableType
    let aggregation: com_openmeteo_api_result_Aggregation
    let altitude: Int32
    let pressure: Int32
    let depth: Int32
    let depthUpper: Int32
    let gddBase: Int32
    let gddLimit: Int32
    let inclination: Int32
    let facing: Int32
    
    /// Decode from URL. Takes substrings to save allocations
    static func from(_ s: Substring) -> Self? {
        // decode variable
        // switch pressure / model decoding
        // switch depth decoding
        // switch aggregation decoding
        
        return nil
    }
}

/// Returned API data
struct ApiVariableAndModel {
    let variable: ApiVariable
    let model: com_openmeteo_api_result_Model
    let unit: SiUnit
    let ensembleMember: Int32
    let values: ApiArray
}


extension com_openmeteo_api_result_VariableType {
    /// Find the longest matching variable name and return it along with its length
    static func startsWith(s: Substring) -> (Self, Int)? {
        var match: (Self, Int)? = nil
        for i in Self.min.rawValue...Self.max.rawValue {
            guard let variable = Self.init(rawValue: i) else {
                continue
            }
            if s.starts(with: variable.string) {
                if variable.string.count > match?.1 ?? 0 {
                    match = (variable, variable.string.count)
                }
            }
        }
        return match
    }
    
    /// Variable can have data on pressure level like 850 hPa
    var hasPressureLevel: Bool {
        switch self {
        case .temperature: true
        case .geopotentialHeight: true
        case .relativehumidity: true
        case .windspeed: true
        case .winddirection: true
        case .dewpoint: true
        case .cloudcover: true
        case .verticalVelocity: true
        default: false
        }
    }
    
    /// Variable can be defined on an altitude. E.g. 10 m above ground
    var hasAltitudeLevel: Bool {
        switch self {
        case .temperature: true
        case .relativehumidity: true
        case .windspeed: true
        case .winddirection: true
        case .dewpoint: true
        default: false
        }
    }
    
    /// Variable has depth/soil level. E.g. 10 cm below ground
    var hasDepthLevel: Bool {
        switch self {
        case .soilTemperature: true
        case .soilMoisture: true
        case .soilMoistureIndex: true
        default: false
        }
    }
    
    /// Variable has gdd base and limit
    var hasGddBase: Bool {
        self == .growingDegreeDays
    }
    
    var hasInclinationFacing: Bool {
        false
    }
    
    /// String how it is used in the URL
    var string: String {
        switch self {
        case .undefined:
            "undefined"
        case .temperature:
            "temperature"
        case .cloudcover:
            "cloudcover"
        case .cloudcoverLow:
            "cloudcover_low"
        case .cloudcoverMid:
            "cloudcover_mid"
        case .cloudcoverHigh:
            "cloudcover_high"
        case .pressureMsl:
            "pressure_msl"
        case .relativehumidity:
            "relativehumidity"
        case .precipitation:
            "precipitation"
        case .precipitationProbability:
            "precipitation_probability"
        case .weathercode:
            "weathercode"
        case .soilTemperature:
            "soil_temperature"
        case .soilMoisture:
            "soil_moisture"
        case .snowDepth:
            "snow_depth"
        case .snowHeight:
            "snow_height"
        case .sensibleHeatflux:
            "sensible_heatflux"
        case .latentHeatflux:
            "latent_heatflux"
        case .showers:
            "showers"
        case .rain:
            "rain"
        case .windgusts:
            "windgusts"
        case .freezinglevelHeight:
            "freezinglevel_height"
        case .dewpoint:
            "dewpoint"
        case .diffuseRadiation:
            "diffuse_radiation"
        case .directRadiation:
            "direct_radiation"
        case .apparentTemperature:
            "apparent_temperature"
        case .windspeed:
            "windspeed"
        case .winddirection:
            "winddirection"
        case .directNormalIrradiance:
            "direct_normal_irradiance"
        case .evapotranspiration:
            "evapotranspiration"
        case .et0FaoEvapotranspiration:
            "et0_fao_evapotranspiration"
        case .vaporPressureDeficit:
            "vapor_pressure_deficit"
        case .shortwaveRadiation:
            "shortwave_radiation"
        case .snowfall:
            "snowfall"
        case .surfacePressure:
            "surface_pressure"
        case .terrestrialRadiation:
            "terrestrial_radiation"
        case .terrestrialRadiationInstant:
            "terrestrial_radiation_instant"
        case .shortwaveRadiationInstant:
            "shortwave_radiation_instant"
        case .diffuseRadiationInstant:
            "diffuse_radiation_instant"
        case .directRadiationInstant:
            "direct_radiation_instant"
        case .directNormalIrradianceInstant:
            "direct_normal_irradiance_instant"
        case .visibility:
            "visibility"
        case .cape:
            "cape"
        case .uvIndex:
            "uv_index"
        case .uvIndexClearSky:
            "uv_index_clear_sky"
        case .isDay:
            "is_day"
        case .growingDegreeDays:
            "growing_degree_days"
        case .leafWetnessProbability:
            "leaf_wetness_probability"
        case .soilMoistureIndex:
            "soil_moisture_index"
        case .geopotentialHeight:
            "geopotential_height"
        case .verticalVelocity:
            "vertical_velocity"
        case .daylightDuration:
            "daylight_duration"
        case .sunrise:
            "sunrise"
        case .sunset:
            "sunset"
        case .pm10:
            "pm10"
        case .pm25:
            "pm2_5"
        case .dust:
            "dust"
        case .aerosolOpticalDepth:
            "aerosol_optical_depth"
        case .carbonMonoxide:
            "carbon_monoxide"
        case .nitrogenDioxide:
            "nitrogen_dioxide"
        case .ammonia:
            "ammonia"
        case .ozone:
            "ozone"
        case .sulphurDioxide:
            "sulphur_dioxide"
        case .alderPollen:
            "alder_pollen"
        case .birchPollen:
            "birch_pollen"
        case .grassPollen:
            "grass_pollen"
        case .mugwortPollen:
            "mugwort_pollen"
        case .olivePollen:
            "olive_pollen"
        case .ragweedPollen:
            "ragweed_pollen"
        case .waveHeight:
            "wave_height"
        case .wavePeriod:
            "wave_period"
        case .waveDirection:
            "wave_direction"
        case .windWaveHeight:
            "wind_wave_height"
        case .windWavePeriod:
            "wind_wave_period"
        case .windWavePeakPeriod:
            "wind_wave_peak_period"
        case .windWaveDirection:
            "wind_wave_direction"
        case .swellWaveHeight:
            "swell_wave_height"
        case .swellWavePeriod:
            "swell_wave_period"
        case .swellWavePeakPeriod:
            "swell_wave_peak_period"
        case .swellWaveDirection:
            "swell_wave_direction"
        case .riverDischarge:
            "river_discharge"
        }
    }
}
