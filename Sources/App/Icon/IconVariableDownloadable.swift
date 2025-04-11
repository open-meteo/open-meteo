
/// Define functions to download surface and pressure level variables for ICON
protocol IconVariableDownloadable: GenericVariable, Hashable {
    func skipHour(hour: Int, domain: IconDomains, forDownload: Bool, run: Timestamp) -> Bool
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?)?
}

extension IconSurfaceVariable: IconVariableDownloadable {
    /// Vmax and precip always are empty in the first hour. Weather codes differ a lot in hour 0.
    func skipHour(hour: Int, domain: IconDomains, forDownload: Bool, run: Timestamp) -> Bool {
        if self == .direct_radiation && domain == .iconEps && hour % 3 != 0 {
            // ICON-EPS only has 3-hourly data for direct radiation
            return true
        }
        if domain == .iconEuEps &&
            [.wind_u_component_80m, .wind_v_component_80m, .temperature_80m].contains(self) &&
            [57, 63, 69].contains(hour) {
            // Upper levels have fewer timestamps
            return true
        }
        if domain == .iconEuEps &&
            [Self.snowfall_convective_water_equivalent, .snowfall_water_equivalent].contains(self) &&
            [6,18].contains(run.hour) &&
            hour % 6 != 0 {
            return true
        }
        // only 6h pressure in icon
        if domain == .iconEps && self == .pressure_msl && hour % 6 != 0 {
            return true
        }
        // only 6h cape in icon-eu for 6 and 18z run
        if domain == .iconEuEps && self == .cape && [6,18].contains(run.hour) && (hour % 6 != 0 || hour == 0) {
            return true
        }
        if hour != 0 {
            return false
        }
        // download hour0 from ICON-D2, because it still contains 15 min data
        if forDownload && domain == .iconD2 && self != .weather_code {
            return false
        }
        
        switch self {
        case .wind_gusts_10m: return true
        case .sensible_heat_flux: return true
        case .latent_heat_flux: return true
        case .direct_radiation: return true
        case .diffuse_radiation: return true
        case .weather_code: return true
        case .snowfall_water_equivalent: fallthrough
        case .snowfall_convective_water_equivalent: fallthrough
        case .precipitation: fallthrough
        case .showers: fallthrough
        case .rain: return true
        case .updraft: return true
        default: return false
        }
    }
    
    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?)? {
        if domain == .iconEps || domain == .iconEuEps || domain == .iconD2Eps {
            switch self {
            case .diffuse_radiation:
                if domain == .iconEps {
                    // ICON-EPS does not have diffuse radiation
                    // Put regular shortwave radiation into this field
                    return ("asob_s", "single-level", nil)
                }
                break
            case .pressure_msl:
                if domain == .iconEps || domain == .iconEuEps {
                    // use surface pressure instead of sea level pressure
                    return ("ps", "single-level", nil)
                }
                break
            case .direct_radiation:
                break // ICON-EPS has only 3-hourly data
            case .cloud_cover:
                break
            case .temperature_2m:
                break
            case .relative_humidity_2m:
                if domain == .iconEps {
                    // use dewpoint, because relative humidity is only 6 hourly
                    return ("td_2m", "single-level", nil)
                }
                if domain == .iconEuEps {
                    // No dewpoint or relative humidity available in EU-EPS
                    return nil
                }
                break
            case .precipitation:
                break
            case .wind_u_component_10m:
                break
            case .wind_v_component_10m:
                break
                // all variables below are not in the global EPS model
            case .wind_u_component_80m:
                fallthrough
            case .wind_v_component_80m:
                fallthrough
            case .temperature_80m:
                fallthrough
            case .wind_gusts_10m:
                fallthrough
            case .snowfall_convective_water_equivalent:
                fallthrough
            case .snowfall_water_equivalent:
                fallthrough
            case .cape:
                if domain == .iconEps {
                    return nil // not in global
                }
                break
                
                // all variables below are only in the D2 EPS model
            case .wind_u_component_120m:
                fallthrough
            case .wind_v_component_120m:
                fallthrough
            case .temperature_120m:
                fallthrough
            case .wind_u_component_180m:
                fallthrough
            case .wind_v_component_180m:
                fallthrough
            case .rain:
                fallthrough
            case .showers:
                fallthrough
            case .snow_depth:
                fallthrough
            case .temperature_180m:
                if domain != .iconD2Eps {
                    return nil
                }
                break
            default:
                return nil
            }
        }
        
        if domain == .iconD2_15min {
            switch self {
            case .direct_radiation:
                break
            case .diffuse_radiation:
                break
            case .precipitation:
                break
            case .cape:
                break
            case .lightning_potential:
                break
            case .snowfall_height:
                break
            case .snowfall_water_equivalent:
                break
            case .freezing_level_height:
                break
            case .rain:
                break
            default:
                return nil
                // All other variables are not in ICON-D2 15 minutes
            }
        }
        
        switch self {
        case .soil_temperature_0cm: return ("t_so", "soil-level", 0)
        case .soil_temperature_6cm: return ("t_so", "soil-level", 6)
        case .soil_temperature_18cm: return ("t_so", "soil-level", 18)
        case .soil_temperature_54cm: return ("t_so", "soil-level", 54)
        case .soil_moisture_0_to_1cm: return ("w_so", "soil-level", 0)
        case .soil_moisture_1_to_3cm: return ("w_so", "soil-level", 1)
        case .soil_moisture_3_to_9cm: return ("w_so", "soil-level", 3)
        case .soil_moisture_9_to_27cm: return ("w_so", "soil-level", 9)
        case .soil_moisture_27_to_81cm: return ("w_so", "soil-level", 27)
        case .wind_u_component_80m: return ("u", "model-level", domain.numberOfModelFullLevels-2)
        case .wind_v_component_80m: return ("v", "model-level", domain.numberOfModelFullLevels-2)
        case .wind_u_component_120m: return ("u", "model-level", domain.numberOfModelFullLevels-3)
        case .wind_v_component_120m: return ("v", "model-level", domain.numberOfModelFullLevels-3)
        case .wind_u_component_180m: return ("u", "model-level", domain.numberOfModelFullLevels-4)
        case .wind_v_component_180m: return ("v", "model-level", domain.numberOfModelFullLevels-4)
        case .temperature_80m: return ("t", "model-level", domain.numberOfModelFullLevels-2)
        case .temperature_120m: return ("t", "model-level", domain.numberOfModelFullLevels-3)
        case .temperature_180m: return ("t", "model-level", domain.numberOfModelFullLevels-4)
        case .temperature_2m: return ("t_2m", "single-level", nil)
        case .cloud_cover: return ("clct", "single-level", nil)
        case .cloud_cover_low: return ("clcl", "single-level", nil)
        case .cloud_cover_mid: return ("clcm", "single-level", nil)
        case .cloud_cover_high: return ("clch", "single-level", nil)
        case .convective_cloud_top: 
            let shallowOrDeepConvectionTop = domain == .iconD2 ? "htop_sc" : "htop_con"
            return (shallowOrDeepConvectionTop, "single-level", nil)
        case .convective_cloud_base: 
            let shallowOrDeepConvectionBase = domain == .iconD2 ? "hbas_sc" : "hbas_con"
            return (shallowOrDeepConvectionBase, "single-level", nil)
        case .precipitation: return ("tot_prec", "single-level", nil)
        case .weather_code: return ("ww", "single-level", nil)
        case .wind_v_component_10m: return ("v_10m", "single-level", nil)
        case .wind_u_component_10m: return ("u_10m", "single-level", nil)
        case .snow_depth: return ("h_snow", "single-level", nil)
        case .sensible_heat_flux: return ("ashfl_s", "single-level", nil)
        case .latent_heat_flux: return ("alhfl_s", "single-level", nil)
        case .showers: return ("rain_con", "single-level", nil)
        case .rain: return ("rain_gsp", "single-level", nil)
        case .wind_gusts_10m: return ("vmax_10m", "single-level", nil)
        case .freezing_level_height: return ("hzerocl", "single-level", nil)
        case .relative_humidity_2m: return ("relhum_2m", "single-level", nil)
        case .pressure_msl: return ("pmsl", "single-level", nil)
        case .diffuse_radiation: return ("aswdifd_s", "single-level", nil)
        case .direct_radiation: return ("aswdir_s", "single-level", nil)
        case .snowfall_convective_water_equivalent: return ("snow_con", "single-level", nil)
        case .snowfall_water_equivalent: return ("snow_gsp", "single-level", nil)
        case .cape: return ("cape_ml", "single-level", nil)
        case .lightning_potential:
            return domain == .iconD2 ? ("lpi", "single-level", nil) : nil // only in icon d2
        case .snowfall_height:
            return domain == .icon ? nil : ("snowlmt", "single-level", nil) // not in icon global
        case .updraft:
            return domain == .iconD2 ? ("w_ctmax", "single-level", nil) : nil // only in icon d2
        case .visibility:
            return domain == .icon ? nil : ("vis", "single-level", nil) // not in icon global
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m: fallthrough
        case .temperature_80m: fallthrough
        case .temperature_120m: fallthrough
        case .temperature_180m: fallthrough
        case .soil_temperature_0cm: fallthrough
        case .soil_temperature_6cm: fallthrough
        case .soil_temperature_18cm: fallthrough
        case .soil_temperature_54cm:
            return (1, -273.15) // Temperature is stored in kelvin. Convert to celsius
        case .pressure_msl:
            return (1/100, 0) // convert to hPa
        case .soil_moisture_0_to_1cm:
            return (0.001 / 0.01, 0) // 1cm depth
        case .soil_moisture_1_to_3cm:
            return (0.001 / 0.02, 0) // 2cm depth
        case .soil_moisture_3_to_9cm:
            return (0.001 / 0.06, 0) // 6cm depth
        case .soil_moisture_9_to_27cm:
            return (0.001 / 0.18, 0) // 18cm depth
        case .soil_moisture_27_to_81cm:
            return (0.001 / 0.54, 0) // 54cm depth
        default:
            return nil
        }
    }
}

extension IconPressureVariable: IconVariableDownloadable {
    func skipHour(hour: Int, domain: IconDomains, forDownload: Bool, run: Timestamp) -> Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case.geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            return (1/9.80665, 0)
        default:
            return nil
        }
    }
    
    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?)? {
        if domain == .iconD2_15min {
            return nil
        }
        switch variable {
        case .temperature:
        return ("t", "pressure-level", level)
        case .wind_u_component:
            return ("u", "pressure-level", level)
        case .wind_v_component:
            return ("v", "pressure-level", level)
        case .geopotential_height:
            return ("fi", "pressure-level", level)
        case .relative_humidity:
            return ("relhum", "pressure-level", level)
        }
    }
}
