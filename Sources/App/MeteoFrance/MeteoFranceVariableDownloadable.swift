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
    func availableFor(domain: MeteoFranceDomain) -> Bool {
        guard domain == .arome_france_hd else {
            return true
        }
        switch self {
        case .temperature_2m:
            fallthrough
        case .relativehumidity_2m:
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
        case .windgusts_10m:
            return true
        case .cape:
            return true
        default:
            return false
        }
    }
    
    var isAlwaysHourlyInArgegeEurope: Bool {
        switch self {
        case .cloudcover_low:
            fallthrough
        case .cloudcover_mid:
            fallthrough
        case .cloudcover_high:
            return true
        default:
            return inPackage == .SP1
        }
    }
    
    var inPackage: MfVariablePackages {
        switch self {
        case .temperature_2m:
            return .SP1
        case .cloudcover:
            return .SP1
        case .cloudcover_low:
            return .SP2
        case .cloudcover_mid:
            return .SP2
        case .cloudcover_high:
            return .SP2
        case .pressure_msl:
            return .SP1
        case .relativehumidity_2m:
            return .SP1
        case .precipitation:
            return .SP1
        case .snowfall_water_equivalent:
            return .SP1
        case .wind_v_component_10m:
            return .SP1
        case .wind_u_component_10m:
            return .SP1
        case .windgusts_10m:
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
        case .cloudcover:
            return ":TCDC:surface:\(hourStr):"
        case .cloudcover_low:
            return ":LCDC:surface:\(hourStr):"
        case .cloudcover_mid:
            return ":MCDC:surface:\(hourStr):"
        case .cloudcover_high:
            return ":HCDC:surface:\(hourStr):"
        case .pressure_msl:
            return ":PRMSL:mean sea level:\(hourStr):"
        case .relativehumidity_2m:
            return ":RH:2 m above ground:\(hourStr):"
        case .precipitation:
            return ":TPRATE:surface:0-\(hourOrDay) acc fcst:"
        case .snowfall_water_equivalent:
            return ":SPRATE:surface:0-\(hourOrDay) acc fcst:"
        case .wind_v_component_10m:
            return "VGRD:10 m above ground:\(hourStr):"
        case .wind_u_component_10m:
            return "UGRD:10 m above ground:\(hourStr):"
        case .windgusts_10m:
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
        case .cloudcover: return domain == .arome_france
        case .cloudcover_low: return domain == .arome_france
        case .cloudcover_mid: return domain == .arome_france
        case .cloudcover_high: return domain == .arome_france
        case .precipitation: return true
        case .shortwave_radiation: return true
        case .windgusts_10m: return true
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
        if variable == .cloudcover && domain == .arome_france {
            return false
        }
        return true
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
        case .cloudcover:
            return ":FRACCC:\(level) mb:\(hourStr):"
        case .relativehumidity:
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
        case .cloudcover:
            return .IP3
        case .relativehumidity:
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
        case .cloudcover:
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
