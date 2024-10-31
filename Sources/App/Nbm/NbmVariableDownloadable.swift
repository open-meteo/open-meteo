/// Required additions to a GFS variable to make it downloadable
protocol NbmVariableDownloadable: GenericVariable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int, run: Int) -> String?
    func multiplyAdd(domain: NbmDomain) -> (multiply: Float, add: Float)?
}

extension NbmSurfaceVariable: NbmVariableDownloadable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int, run: Int) -> String? {
        // Note: Aggregations are only available every 6 hours, while instant values are 3 hourly after hour 40
        
        /// NBM uses 6 hourly models below. Probabilities are emited to 6 hours alignments
        let relTime = timestep + run % 6
        
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:\(timestep) hour fcst:"
        case .surface_temperature:
            return ":TMP:surface:\(timestep) hour fcst:"
        case .cape:
            return ":CAPE:surface:\(timestep) hour fcst:"
        case .shortwave_radiation:
            if timestep - previousTimestep > 1 {
                // Instantaneous radiation can be processed with 1-hour intervals. Disregard the 3-hourly and 6-hourly data.
                return nil
            }
            return ":DSWRF:surface:\(timestep) hour fcst:"
        case .precipitation:
            if timestep > 36 {
                return relTime % 6 != 0 ? nil : ":APCP:surface:\(timestep-6)-\(timestep) hour acc fcst:"
            }
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
        case .snowfall_water_equivalent:
            if timestep > 36 {
                return relTime % 6 != 0 ? nil : ":ASNOW:surface:\(timestep-6)-\(timestep) hour acc fcst:"
            }
            return ":ASNOW:surface:\(timestep-1)-\(timestep) hour acc fcst:"
        case .wind_gusts_10m:
            return ":GUST:10 m above ground:\(timestep) hour fcst:"
        case .visibility:
            return timestep > 78 ? nil : ":VIS:surface:\(timestep) hour fcst:"
        case .thunderstorm_probability:
            if timestep > 36 {
                return relTime % 6 != 0 || relTime >= 192 ? nil : ":TSTM:surface:\(timestep-6)-\(timestep) hour acc fcst:probability forecast"
            }
            return ":TSTM:surface:\(timestep-1)-\(timestep) hour acc fcst:probability forecast"
        case .precipitation_probability:
            if timestep > 36 {
                return relTime % 6 != 0 ? nil : ":APCP:surface:\(timestep-6)-\(timestep) hour acc fcst:prob >0.254:prob fcst 255/255"
            }
            return ":APCP:surface:\(timestep-1)-\(timestep) hour acc fcst:prob >0.254:prob fcst 255/255"
        case .rain_probability:
            // PTYPE codes: https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-201.shtml
            return ":PTYPE:surface:\(timestep) hour fcst:prob >=1 <2:prob fcst 1/1"
        case .freezing_rain_probability:
            return ":PTYPE:surface:\(timestep) hour fcst:prob >=3 <4:prob fcst 1/1"
        case .ice_pellets_probability:
            return ":PTYPE:surface:\(timestep) hour fcst:prob >=8 <9:prob fcst 1/1"
        case .snowfall_probability:
            return ":PTYPE:surface:\(timestep) hour fcst:prob >=5 <7:prob fcst 1/1"
        }
    }
    
    func multiplyAdd(domain: NbmDomain) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .surface_temperature:
            return (1, -273.15)
        default:
            return nil
        }
    }
}

extension NbmPressureVariable: NbmVariableDownloadable {
    func gribIndexName(for domain: NbmDomain, timestep: Int, previousTimestep: Int, run: Int) -> String? {
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
