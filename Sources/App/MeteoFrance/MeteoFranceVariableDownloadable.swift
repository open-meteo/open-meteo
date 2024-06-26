/// Required additions to a MeteoFrance variable to make it downloadable
protocol MeteoFranceVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    func skipHour0(domain: MeteoFranceDomain) -> Bool
    
    /// AROME france HD has very few variables
    func availableFor(domain: MeteoFranceDomain, forecastSecond: Int) -> Bool
    
    /// Return the `coverage` id for the given variable or nil if it is not available for this domain
    func getCoverageId() -> (variable: String, height: Int?, pressure: Int?, isPeriod: Bool)
}

extension MeteoFranceSurfaceVariable: MeteoFranceVariableDownloadable {
    func getCoverageId() -> (variable: String, height: Int?, pressure: Int?, isPeriod: Bool) {
        // add Surface temperature TEMPERATURE__GROUND_OR_WATER_SURFACE
        switch self {
        case .temperature_2m:
            // only 2 arome 0.01
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2, nil, false)
        case .cloud_cover:
            // not for arome 0.01
            return ("TOTAL_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, nil, false)
        case .cloud_cover_low:
            return ("LOW_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, nil, false)
        case .cloud_cover_mid:
            return ("HIGH_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, nil, false)
        case .cloud_cover_high:
            return ("MEDIUM_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil, nil, false)
        case .pressure_msl:
            return ("PRESSURE__MEAN_SEA_LEVEL", nil, nil, false)
            // TODO arome 0.01 has surface pressure
            //return ("PRESSURE__GROUND_OR_WATER_SURFACE", nil)
        case .relative_humidity_2m:
            // 2 10 20 50 100
            // arome 0.25: 2 10 20 35 50 75 100 150 200 250 375 500 625 750 875 1000 1125 1250 1375 1500 1750 2000 2250 2500 2750 3000
            return ("RELATIVE_HUMIDITY__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2, nil, false)
        case .wind_v_component_10m:
            // arome 0.01 10 20 50 100
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, nil, false)
        case .wind_u_component_10m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, nil, false)
        case .wind_v_component_20m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, nil, false)
        case .wind_u_component_20m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, nil, false)
        case .wind_v_component_50m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, nil, false)
        case .wind_u_component_50m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, nil, false)
        case .wind_v_component_100m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, nil, false)
        case .wind_u_component_100m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, nil, false)
        case .wind_v_component_150m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, nil, false)
        case .wind_u_component_150m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, nil, false)
        case .wind_v_component_200m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, nil, false)
        case .wind_u_component_200m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, nil, false)
        case .temperature_20m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20, nil, false)
        case .temperature_50m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50, nil, false)
        case .temperature_100m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100, nil, false)
        case .temperature_150m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150, nil, false)
        case .temperature_200m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200, nil, false)
        case .precipitation:
            return ("TOTAL_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil, nil, true)
        case .snowfall_water_equivalent:
            return ("TOTAL_SNOW_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil, nil, true)
        case .wind_gusts_10m:
            return ("WIND_SPEED_GUST__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10, nil, false)
        case .shortwave_radiation:
            // Note: There is also "regular" short wave radiation which subtracted upwelling raditiation
            return ("DOWNWARD_SHORT_WAVE_RADIATION_FLUX__GROUND_OR_WATER_SURFACE", nil, nil, true)
        case .cape:
            return ("CONVECTIVE_AVAILABLE_POTENTIAL_ENERGY__GROUND_OR_WATER_SURFACE", nil, nil, false)
        }
    }
    
    
    func availableFor(domain: MeteoFranceDomain, forecastSecond: Int) -> Bool {
        let forecastHour = forecastSecond / 3600
        
        switch domain {
        case .arpege_europe:
            switch self {
                /// upper level variables after hour 48 only 3 hourly data
            case .temperature_20m, .temperature_50m, .temperature_100m, .temperature_150m, .temperature_200m:
                fallthrough
            case .wind_v_component_20m, .wind_v_component_50m, .wind_v_component_100m, .wind_v_component_150m, .wind_v_component_200m:
                fallthrough
            case .wind_u_component_20m, .wind_u_component_50m, .wind_u_component_100m, .wind_u_component_150m, .wind_u_component_200m:
                fallthrough
            case .cape:
                if (forecastHour % 3 != 0 && forecastHour > 48) {
                    return false
                }
                return true
            case .shortwave_radiation:
                // Note: 2024-06-21 MeteoFrance removed shortwave radiation
                return false
            default:
                return true
            }
        case .arpege_world:
            switch self {
            case .shortwave_radiation:
                // Note: 2024-06-21 MeteoFrance removed shortwave radiation
                return false
            default:
                return true
            }
        case .arome_france:
            switch self {
            case .shortwave_radiation:
                // Note: 2024-06-21 MeteoFrance removed shortwave radiation
                return false
            default:
                return true
            }
        case .arome_france_hd:
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
        case .arome_france_15min:
            switch self {
            //case .temperature_2m:
            //    return true
            //case .relative_humidity_2m:
            //    return true // 10 meter!?!?!?
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
            //case .precipitation:
            //    return true
            //case .snowfall_water_equivalent:
            //    return true
            //case .wind_gusts_10m: // only hourly
            //    return forecastSecond % 3600 == 0
            //case .shortwave_radiation: // only hourly
            //    return forecastSecond % 3600 == 0
            //case .pressure_msl:
            //    return true
            default:
                return false
            }
        case .arome_france_hd_15min:
            switch self {
            case .cape:
                return true
            case .precipitation:
                return true
            case .snowfall_water_equivalent:
                return true
           //case .wind_gusts_10m:
                //return true
            case .relative_humidity_2m:
                return true
            case .temperature_2m:
                return true
            default:
                return false
            }
        }
    }
    
    func skipHour0(domain: MeteoFranceDomain) -> Bool {
        switch self {
        case .cloud_cover: return domain.family == .arome || domain.family == .aromepi
        case .cloud_cover_low: return domain.family == .arome || domain.family == .aromepi
        case .cloud_cover_mid: return domain.family == .arome || domain.family == .aromepi
        case .cloud_cover_high: return domain.family == .arome || domain.family == .aromepi
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
            /// Note: This is actually wrong. Correct value would be `1/3600`.
            /// Data is corrected in the reader afterwards
            return (3600/10_000_000, 0)
        default:
            return nil
        }
    }
}

extension MeteoFrancePressureVariable: MeteoFranceVariableDownloadable {
    func availableFor(domain: MeteoFranceDomain, forecastSecond: Int) -> Bool {
        let forecastHour = forecastSecond / 3600
        if level <= 70 && forecastHour % 3 != 0 {
            // level 10-70 only have 3-hourly data
            return false
        }
        if domain == .arpege_europe && forecastHour % 3 != 0 && forecastHour > 48 {
            /// after hour 48 only 3 hourly data
            return false
        }
        return true
    }
    
    func getCoverageId() -> (variable: String, height: Int?, pressure: Int?, isPeriod: Bool)  {
        // consider vertical velocity
        switch variable {
        case .temperature:
            return ("TEMPERATURE__ISOBARIC_SURFACE", nil, level, false)
        case .wind_u_component:
            return ("U_COMPONENT_OF_WIND__ISOBARIC_SURFACE", nil, level, false)
        case .wind_v_component:
            return ("V_COMPONENT_OF_WIND__ISOBARIC_SURFACE", nil, level, false)
        case .geopotential_height:
            return ("GEOPOTENTIAL__ISOBARIC_SURFACE", nil, level, false)
        case .relative_humidity:
            return ("RELATIVE_HUMIDITY__ISOBARIC_SURFACE", nil, level, false)
        }
    }
    
    func skipHour0(domain: MeteoFranceDomain) -> Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case .geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            return (1/9.80665, 0)
        default:
            return nil
        }
    }
}
