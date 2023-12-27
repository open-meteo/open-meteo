/// Required additions to a MeteoFrance variable to make it downloadable
protocol MeteoFranceVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    func skipHour0(domain: MeteoFranceDomain) -> Bool
    var isAveragedOverForecastTime: Bool { get }
    var isAccumulatedSinceModelStart: Bool { get }
    
    /// AROME france HD has very few variables
    func availableFor(domain: MeteoFranceDomain) -> Bool
    
    /// Return the `coverage` id for the given variable or nil if it is not available for this domain
    func getCoverageId() -> (variable: String, height: Int?, isPeriod: Bool)
}

extension MeteoFranceSurfaceVariable: MeteoFranceVariableDownloadable {
    func getCoverageId() -> (variable: String, height: Int?, isPeriod: Bool) {
        // add Surface temperature TEMPERATURE__GROUND_OR_WATER_SURFACE
        switch self {
        case .temperature_2m:
            // only 2 arome 0.01
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2, false)
        case .cloud_cover:
            // not for arome 0.01
            return ("TOTAL_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, false)
        case .cloud_cover_low:
            return ("LOW_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, false)
        case .cloud_cover_mid:
            return ("HIGH_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, false)
        case .cloud_cover_high:
            return ("MEDIUM_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, false)
        case .pressure_msl:
            return ("PRESSURE__MEAN_SEA_LEVEL", nil, false)
            // TODO arome 0.01 has surface pressure
            //return ("PRESSURE__GROUND_OR_WATER_SURFACE", nil)
        case .relative_humidity_2m:
            // 2 10 20 50 100
            // arome 0.25: 2 10 20 35 50 75 100 150 200 250 375 500 625 750 875 1000 1125 1250 1375 1500 1750 2000 2250 2500 2750 3000
            return ("RELATIVE_HUMIDITY__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2, false)
        case .wind_v_component_10m:
            // arome 0.01 10 20 50 100
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, false)
        case .wind_u_component_10m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, false)
        case .wind_v_component_20m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, false)
        case .wind_u_component_20m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, false)
        case .wind_v_component_50m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, false)
        case .wind_u_component_50m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, false)
        case .wind_v_component_100m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, false)
        case .wind_u_component_100m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, false)
        case .wind_v_component_150m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, false)
        case .wind_u_component_150m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, false)
        case .wind_v_component_200m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, false)
        case .wind_u_component_200m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, false)
        case .temperature_20m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, false)
        case .temperature_50m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, false)
        case .temperature_100m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, false)
        case .temperature_150m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, false)
        case .temperature_200m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, false)
        case .precipitation:
            return ("TOTAL_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil, true)
        case .snowfall_water_equivalent:
            return ("TOTAL_SNOW_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil, true)
        case .wind_gusts_10m:
            return ("WIND_SPEED_GUST__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, false)
        case .shortwave_radiation:
            // Note: There is also "regular" short wave radiation which subtracted upwelling raditiation
            return ("DOWNWARD_SHORT_WAVE_RADIATION_FLUX__GROUND_OR_WATER_SURFACE", nil, true)
        case .cape:
            return ("CONVECTIVE_AVAILABLE_POTENTIAL_ENERGY__GROUND_OR_WATER_SURFACE", nil, false)
        }
    }
    
    
    func availableFor(domain: MeteoFranceDomain) -> Bool {
        if domain == .arome_france_hd {
            switch self {
            case .temperature_2m:
                return true
            case .relative_humidity_2m:
                return true
            case .wind_v_component_10m:
                return true
            case .wind_u_component_10m:
                return true
            case .wind_v_component_20m:
                return true
            case .wind_u_component_20m:
                return true
            case .wind_v_component_50m:
                return true
            case .wind_u_component_50m:
                return true
            case .wind_v_component_100m:
                return true
            case .wind_u_component_100m:
                return true
            case .precipitation:
                return true
            case .snowfall_water_equivalent:
                return true
            case .wind_gusts_10m:
                return true
            case .cape:
                return true
            default:
                return false
            }
        }
        return true
    }
    
    func skipHour0(domain: MeteoFranceDomain) -> Bool {
        switch self {
        case .cloud_cover: return domain.family == .arome
        case .cloud_cover_low: return domain.family == .arome
        case .cloud_cover_mid: return domain.family == .arome
        case .cloud_cover_high: return domain.family == .arome
        case .precipitation: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m: return true
        case .snowfall_water_equivalent: return true
        default: return false
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            fallthrough
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .shortwave_radiation:
            return (3600/10_000_000, 0)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        return false
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .snowfall_water_equivalent: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
}

extension MeteoFrancePressureVariable: MeteoFranceVariableDownloadable {
    func availableFor(domain: MeteoFranceDomain) -> Bool {
        if variable == .cloud_cover && domain == .arome_france {
            return false
        }
        return true
    }
    
    func getCoverageId() -> (variable: String, height: Int?, isPeriod: Bool)  {
        // consider vertical velocity
        switch variable {
        case .temperature:
            return ("TEMPERATURE__ISOBARIC_SURFACE", level, false)
        case .wind_u_component:
            return ("U_COMPONENT_OF_WIND__ISOBARIC_SURFACE", level, false)
        case .wind_v_component:
            return ("V_COMPONENT_OF_WIND__ISOBARIC_SURFACE", level, false)
        case .geopotential_height:
            return ("GEOPOTENTIAL__ISOBARIC_SURFACE", level, false)
        case .cloud_cover:
            return ("SPECIFIC_CLOUD_ICE_WATER_CONTENT__ISOBARIC_SURFACE", level, false)
        case .relative_humidity:
            // 100 125 150 175 200 225 250 275 300 350 400 450 500 550 600 650 700 750 800 850 900 925 950 1000
            return ("RELATIVE_HUMIDITY__ISOBARIC_SURFACE", level, false)
        }
    }
    
    func skipHour0(domain: MeteoFranceDomain) -> Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case .cloud_cover:
            return (100, 0)
        case .geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            return (1/9.80665, 0)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        return false
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
}
