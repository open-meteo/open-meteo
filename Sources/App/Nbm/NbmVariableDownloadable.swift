/// Required additions to a GFS variable to make it downloadable
protocol NbmVariableDownloadable: GenericVariable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int) -> String?
    func multiplyAdd(domain: NbmDomain) -> (multiply: Float, add: Float)?
}

extension NbmSurfaceVariable: NbmVariableDownloadable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int) -> String? {
        //switch domain {
        //case .nbm_conus:
            switch self {
            case .temperature_2m:
                return ":TMP:2 m above ground:\(timestep) hour fcst:"
            case .cape:
                return ":CAPE:surface:\(timestep) hour fcst:"
            case .shortwave_radiation:
                if timestep - previousTimestep > 1 {
                    // Instantaneous radiation can be processed with 1-hour intervals. Disregard the 3-hourly and 6-hourly data.
                    return nil
                }
                return ":DSWRF:surface:\(timestep) hour fcst:"
            case .precipitation:
                return ":APCP:surface:\(timestep-1)-\(timestep) hour acc fcst:"
            case .relative_humidity_2m:
                return ":RH:2 m above ground:\(timestep) hour fcst:"
            case .cloud_cover:
                return ":TCDC:surface:\(timestep) hour fcst:"
            case .wind_speed_10m:
                return ":WIND:10 m above ground:\(timestep) hour fcst:"
            case .wind_speed_80m:
                return ":WIND:80 m above ground:\(timestep) hour fcst:"
            case .wind_direction_10m:
                return ":WDIR:10 m above ground:\(timestep) hour fcst:"
            case .wind_direction_80m:
                return ":WDIR:80 m above ground:\(timestep) hour fcst:"
            case .snow_fall_water_equivalent:
                return ":ASNOW:surface:\(timestep-1)-\(timestep) hour acc fcst:"
            case .wind_gusts_10m:
                return ":GUST:10 m above ground:\(timestep) hour fcst:"
            case .visibility:
                return ":VIS:surface:\(timestep) hour fcst:"
            case .thunderstorm_probability:
                return ":TSTM:surface:\(previousTimestep)-\(timestep) hour acc fcst:probability forecast"
            case .precipitation_probability:
                return ":APCP:surface:\(timestep-1)-\(timestep) hour acc fcst:prob >0.254:prob fcst 255/255"
            }
        //}
    }
    
    func multiplyAdd(domain: NbmDomain) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        default:
            return nil
        }
    }
}

extension NbmPressureVariable: NbmVariableDownloadable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int) -> String? {
        return nil
    }
    
    func skipHour0(for domain: NbmDomain) -> Bool {
        return false
    }
    
    func multiplyAdd(domain: NbmDomain) -> (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        default:
            return nil
        }
    }
}
