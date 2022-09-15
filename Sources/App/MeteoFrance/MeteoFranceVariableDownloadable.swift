
/// Required additions to a MeteoFrance variable to make it downloadable
protocol MeteoFranceVariableDownloadable: GenericVariableMixing {
    var skipHour0: Bool { get }
    var interpolationType: Interpolation2StepType { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var isAveragedOverForecastTime: Bool { get }
    var isAccumulatedSinceModelStart: Bool { get }
    func toGribIndexName(hour: Int) -> String
    var inPackage: MfVariablePackages { get }
}

extension MeteoFranceSurfaceVariable: MeteoFranceVariableDownloadable {
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
        }
    }
    
    func toGribIndexName(hour: Int) -> String {
        let hourStr = hour == 0 ? "anl" : "\(hour) hour fcst"
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
            return ":TPRATE:surface:0-\(hour) hour acc fcst:"
        case .snowfall_water_equivalent:
            return ":SPRATE:surface:0-\(hour) hour acc fcst:"
        case .wind_v_component_10m:
            return "VGRD:10 m above ground:\(hourStr):"
        case .wind_u_component_10m:
            return "UGRD:10 m above ground:\(hourStr):"
        case .windgusts_10m:
            return ":GUST:10 m above ground:\(hour-1)-\(hour) hour max fcst:"
        case .shortwave_radiation:
            return ":DSWRF:surface:0-\(hour) hour acc fcst:"
        case .cape:
            return ":CAPE:surface - 3000 m above ground:\(hourStr):"
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .shortwave_radiation: return true
        case .windgusts_10m: return true
        default: return false
        }
    }
    
    var interpolationType: Interpolation2StepType {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloudcover:
            return .hermite(bounds: 0...100)
        case .cloudcover_low:
            return .hermite(bounds: 0...100)
        case .cloudcover_mid:
            return .hermite(bounds: 0...100)
        case .cloudcover_high:
            return .hermite(bounds: 0...100)
        case .relativehumidity_2m:
            return .hermite(bounds: 0...100)
        case .precipitation:
            return .linear
        case .windgusts_10m:
            return .linear
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: nil)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .linear
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 1)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .shortwave_radiation: return true
        default: return false
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .snowfall_water_equivalent: return true
        default: return false
        }
    }
}

extension MeteoFrancePressureVariable: MeteoFranceVariableDownloadable {
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
    
    var skipHour0: Bool {
        return false
    }
    
    var interpolationType: Interpolation2StepType {
        switch variable {
        case .cloudcover: fallthrough
        case .relativehumidity: return .hermite(bounds: 0...100)
        default: return .hermite(bounds: nil)
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
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
