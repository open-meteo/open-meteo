/// Required additions to a MeteoFrance variable to make it downloadable
protocol MeteoFranceVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    func skipHour0(domain: MeteoFranceDomain) -> Bool
    var isAveragedOverForecastTime: Bool { get }
    var isAccumulatedSinceModelStart: Bool { get }
    func toGribIndexName(hour: Int) -> String
    var inPackage: MfVariablePackages { get }
    
    /// AROME france HD has very few variables
    func availableFor(domain: MeteoFranceDomain) -> Bool
    
    /// In ARPEGE EUROPE some variables are hourly
    /// Others start hourly and then switch to 3/6 hourly resolution
    /// Obviously, if hourly data is available, it will be used
    var isAlwaysHourlyInArgegeEurope: Bool { get }
}

enum MfVariablePackages: String, CaseIterable {
    case SP1
    case SP2
    case IP1
    case IP2
    case IP3
    case HP1
}

extension MeteoFranceSurfaceVariable: MeteoFranceVariableDownloadable {
    func getCoverageId(domain: MeteoFranceDomain) -> (variable: String, height: Int?)?  {
        // add Surface temperature TEMPERATURE__GROUND_OR_WATER_SURFAC?
        // GEOMETRIC_HEIGHT__GROUND_OR_WATER_SURFACE___2023-12-20T12.00.00Z
        if domain == .arome_france_hd {
            switch self {
            case .cloud_cover: return nil
            case .wind_u_component_150m, .wind_u_component_200m:
                return nil
            case .wind_v_component_150m, .wind_v_component_200m:
                return nil
            case .temperature_20m, .temperature_50m, .temperature_100m, .temperature_150m, .temperature_200m:
                return nil
            case .shortwave_radiation:
                return nil
            case .pressure_msl:
                // only surface
                return nil
            default:
                break
            }
        }
        switch self {
        case .temperature_2m:
            // only 2 arome 0.01
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2)
        case .cloud_cover:
            // not for arome 0.01
            return ("TOTAL_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil)
        case .cloud_cover_low:
            return ("LOW_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil)
        case .cloud_cover_mid:
            return ("HIGH_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil)
        case .cloud_cover_high:
            return ("MEDIUM_CLOUD_COVER__GROUND_OR_WATER_SURFACE", nil)
        case .pressure_msl:
            return ("PRESSURE__MEAN_SEA_LEVEL", nil)
            // TODO arome 0.01 has surface pressure
            //return ("PRESSURE__GROUND_OR_WATER_SURFACE", nil)
        case .relative_humidity_2m:
            // 2 10 20 50 100
            // arome 0.25: 2 10 20 35 50 75 100 150 200 250 375 500 625 750 875 1000 1125 1250 1375 1500 1750 2000 2250 2500 2750 3000
            return ("RELATIVE_HUMIDITY__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 2)
        case .wind_v_component_10m:
            // arome 0.01 10 20 50 100
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10)
        case .wind_u_component_10m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10)
        case .wind_v_component_20m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20)
        case .wind_u_component_20m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20)
        case .wind_v_component_50m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50)
        case .wind_u_component_50m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50)
        case .wind_v_component_100m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100)
        case .wind_u_component_100m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100)
        case .wind_v_component_150m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150)
        case .wind_u_component_150m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150)
        case .wind_v_component_200m:
            return ("V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200)
        case .wind_u_component_200m:
            return ("U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200)
        case .temperature_20m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 20)
        case .temperature_50m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 50)
        case .temperature_100m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 100)
        case .temperature_150m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 150)
        case .temperature_200m:
            return ("TEMPERATURE__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 200)
        case .precipitation:
            // needs PT1H suffix
            return ("TOTAL_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil)
        case .snowfall_water_equivalent:
            // needs PT1H suffix
            return ("TOTAL_SNOW_PRECIPITATION__GROUND_OR_WATER_SURFACE", nil)
        case .wind_gusts_10m:
            return ("WIND_SPEED_GUST__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", 10)
        case .shortwave_radiation:
            // needs PT1H suffix
            // OR just SHORT_WAVE_RADIATION_FLUX__GROUND_OR_WATER_SURFACE
            return ("DOWNWARD_SHORT_WAVE_RADIATION_FLUX__GROUND_OR_WATER_SURFACE", nil)
        case .cape:
            return ("CONVECTIVE_AVAILABLE_POTENTIAL_ENERGY__GROUND_OR_WATER_SURFACE", nil)
        }
    }
    
    
    func availableFor(domain: MeteoFranceDomain) -> Bool {
        guard domain == .arome_france_hd else {
            return true
        }
        switch self {
        case .temperature_2m:
            fallthrough
        case .relative_humidity_2m:
            fallthrough
        case .wind_u_component_10m:
            fallthrough
        case .wind_v_component_10m:
            return true
        case .wind_u_component_20m:
            fallthrough
        case .wind_v_component_20m:
            return true
        case .wind_u_component_50m:
            fallthrough
        case .wind_v_component_50m:
            return true
        case .wind_u_component_100m:
            fallthrough
        case .wind_v_component_100m:
            return true
        case .wind_gusts_10m:
            return true
        case .cape:
            return true
        case .precipitation:
            return true
        case .snowfall_water_equivalent: return true
        case .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high: return true
        case .pressure_msl: return true
        default:
            return false
        }
    }
    
    var isAlwaysHourlyInArgegeEurope: Bool {
        switch self {
        case .cloud_cover_low:
            fallthrough
        case .cloud_cover_mid:
            fallthrough
        case .cloud_cover_high:
            return true
        default:
            return inPackage == .SP1
        }
    }
    
    var inPackage: MfVariablePackages {
        switch self {
        case .temperature_2m:
            return .SP1
        case .cloud_cover:
            return .SP1
        case .cloud_cover_low:
            return .SP2
        case .cloud_cover_mid:
            return .SP2
        case .cloud_cover_high:
            return .SP2
        case .pressure_msl:
            return .SP1
        case .relative_humidity_2m:
            return .SP1
        case .precipitation:
            return .SP1
        case .snowfall_water_equivalent:
            return .SP1
        case .wind_v_component_10m:
            return .SP1
        case .wind_u_component_10m:
            return .SP1
        case .wind_gusts_10m:
            return .SP1
        case .cape:
            return .SP2
        case .shortwave_radiation:
            return .SP1
        case .wind_v_component_20m:
            fallthrough
        case .wind_u_component_20m:
            fallthrough
        case .wind_v_component_50m:
            fallthrough
        case .wind_u_component_50m:
            fallthrough
        case .wind_v_component_100m:
            fallthrough
        case .wind_u_component_100m:
            fallthrough
        case .wind_v_component_150m:
            fallthrough
        case .wind_u_component_150m:
            fallthrough
        case .wind_v_component_200m:
            fallthrough
        case .wind_u_component_200m:
            fallthrough
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            return .HP1
        }
    }
    
    func toGribIndexName(hour: Int) -> String {
        let hourStr = hour == 0 ? "anl" : "\(hour) hour fcst"
        let hourOrDay = hour % 24 == 0 ? "\(hour/24) day" : "\(hour) hour"
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:\(hourStr):"
        case .cloud_cover:
            return ":TCDC:surface:\(hourStr):"
        case .cloud_cover_low:
            return ":LCDC:surface:\(hourStr):"
        case .cloud_cover_mid:
            return ":MCDC:surface:\(hourStr):"
        case .cloud_cover_high:
            return ":HCDC:surface:\(hourStr):"
        case .pressure_msl:
            return ":PRMSL:mean sea level:\(hourStr):"
        case .relative_humidity_2m:
            return ":RH:2 m above ground:\(hourStr):"
        case .precipitation:
            return ":TPRATE:surface:0-\(hourOrDay) acc fcst:"
        case .snowfall_water_equivalent:
            return ":SPRATE:surface:0-\(hourOrDay) acc fcst:"
        case .wind_v_component_10m:
            return "VGRD:10 m above ground:\(hourStr):"
        case .wind_u_component_10m:
            return "UGRD:10 m above ground:\(hourStr):"
        case .wind_gusts_10m:
            return ":GUST:10 m above ground:\(hour-1)-\(hour) hour max fcst:"
        case .shortwave_radiation:
            return ":DSWRF:surface:0-\(hourOrDay) acc fcst:"
        case .cape:
            return ":CAPE:surface - 3000 m above ground:\(hourStr):"
        case .wind_v_component_20m:
            return "VGRD:20 m above ground:\(hourStr):"
        case .wind_u_component_20m:
            return "UGRD:20 m above ground:\(hourStr):"
        case .wind_v_component_50m:
            return "VGRD:50 m above ground:\(hourStr):"
        case .wind_u_component_50m:
            return "UGRD:50 m above ground:\(hourStr):"
        case .wind_v_component_100m:
            return "VGRD:100 m above ground:\(hourStr):"
        case .wind_u_component_100m:
            return "UGRD:100 m above ground:\(hourStr):"
        case .wind_v_component_150m:
            return "VGRD:150 m above ground:\(hourStr):"
        case .wind_u_component_150m:
            return "UGRD:150 m above ground:\(hourStr):"
        case .wind_v_component_200m:
            return "VGRD:200 m above ground:\(hourStr):"
        case .wind_u_component_200m:
            return "UGRD:200 m above ground:\(hourStr):"
        case .temperature_20m:
            return ":TMP:20 m above ground:\(hourStr):"
        case .temperature_50m:
            return ":TMP:50 m above ground:\(hourStr):"
        case .temperature_100m:
            return ":TMP:100 m above ground:\(hourStr):"
        case .temperature_150m:
            return ":TMP:150 m above ground:\(hourStr):"
        case .temperature_200m:
            return ":TMP:200 m above ground:\(hourStr):"
        }
    }
    
    func skipHour0(domain: MeteoFranceDomain) -> Bool {
        switch self {
        case .cloud_cover: return domain == .arome_france
        case .cloud_cover_low: return domain == .arome_france
        case .cloud_cover_mid: return domain == .arome_france
        case .cloud_cover_high: return domain == .arome_france
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
            return (1/10_000, 0)
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
    
    func getCoverageId(domain: MeteoFranceDomain) -> (variable: String, height: Int?)?  {
        // consider vertical velocity
        switch variable {
        case .temperature:
            return ("TEMPERATURE__ISOBARIC_SURFACE", level)
        case .wind_u_component:
            return ("U_COMPONENT_OF_WIND__ISOBARIC_SURFACE", level)
        case .wind_v_component:
            return ("V_COMPONENT_OF_WIND__ISOBARIC_SURFACE", level)
        case .geopotential_height:
            return ("GEOPOTENTIAL__ISOBARIC_SURFACE", level)
        case .cloud_cover:
            return ("SPECIFIC_CLOUD_ICE_WATER_CONTENT__ISOBARIC_SURFACE", level)
        case .relative_humidity:
            // 100 125 150 175 200 225 250 275 300 350 400 450 500 550 600 650 700 750 800 850 900 925 950 1000
            return ("RELATIVE_HUMIDITY__ISOBARIC_SURFACE", level)
        }
    }
    
    var isAlwaysHourlyInArgegeEurope: Bool {
        return false
    }
    
    func toGribIndexName(hour: Int) -> String {
        let hourStr = hour == 0 ? "anl" : "\(hour) hour fcst"
        switch variable {
        case .temperature:
            return ":TMP:\(level) mb:\(hourStr):"
        case .wind_u_component:
            return ":UGRD:\(level) mb:\(hourStr):"
        case .wind_v_component:
            return ":VGRD:\(level) mb:\(hourStr):"
        case .geopotential_height:
            return ":GP:\(level) mb:\(hourStr):"
        case .cloud_cover:
            return ":FRACCC:\(level) mb:\(hourStr):"
        case .relative_humidity:
            return ":RH:\(level) mb:\(hourStr):"
        }
    }
    
    var inPackage: MfVariablePackages {
        switch variable {
        case .temperature:
            return .IP1
        case .wind_u_component:
            return .IP1
        case .wind_v_component:
            return .IP1
        case .geopotential_height:
            return .IP1
        case .cloud_cover:
            return .IP3
        case .relative_humidity:
            return .IP1
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
