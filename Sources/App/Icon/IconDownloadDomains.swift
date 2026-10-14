/// Upstream ICON feeds. Download metadata does not require a loaded storage grid.
enum IconDownloadDomains: String, CaseIterable, Sendable {
    case icon
    case iconEu = "icon-eu"
    case iconD2 = "icon-d2"
    case iconD2Ruc = "icon-d2-ruc"
    case iconEps = "icon-eps"
    case iconEuEps = "icon-eu-eps"
    case iconD2Eps = "icon-d2-eps"

    /// Regular output domain used when remapping this feed.
    var regularDomain: IconDomains {
        switch self {
        case .icon: return .icon
        case .iconEu: return .iconEu
        case .iconD2, .iconD2Ruc: return .iconD2
        case .iconEps: return .iconEps
        case .iconEuEps: return .iconEuEps
        case .iconD2Eps: return .iconD2Eps
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .iconD2Ruc: return 3600
        case .iconEu, .iconD2, .iconD2Eps: return 3 * 3600
        case .icon, .iconEuEps: return 6 * 3600
        case .iconEps: return 12 * 3600
        }
    }

    func getVarAndLevel(_ variable: any IconVariableDownloadable) -> (variable: String, cat: String, level: Int?)? {
        if let surface = variable as? IconSurfaceVariable {
            return getSurfaceVarAndLevel(surface)
        }
        guard let pressure = variable as? IconPressureVariable else { return nil }
        if self == .iconD2Ruc && !levels.contains(pressure.level) { return nil }
        let name: String
        switch pressure.variable {
        case .temperature: name = "t"
        case .wind_u_component: name = "u"
        case .wind_v_component: name = "v"
        case .geopotential_height: name = "fi"
        case .relative_humidity: name = requiresSpecificHumidityConversion(pressure) ? "QV" : "relhum"
        }
        return (name, "pressure-level", pressure.level)
    }

    func requiresSpecificHumidityConversion(_ variable: IconPressureVariable) -> Bool {
        self == .iconD2Ruc && variable.variable == .relative_humidity && ![500, 700].contains(variable.level)
    }

    func hasQuarterHourlyData(_ variable: IconSurfaceVariable) -> Bool {
        switch self {
        case .iconD2Ruc:
            return [.direct_radiation, .diffuse_radiation, .precipitation, .rain, .snowfall_water_equivalent, .cape, .convective_inhibition, .lightning_potential, .snowfall_height, .freezing_level_height, .updraft, .visibility].contains(variable)
        case .iconD2:
            return [.direct_radiation, .diffuse_radiation, .precipitation, .cape, .lightning_potential, .snowfall_height, .snowfall_water_equivalent, .snowfall_convective_water_equivalent, .freezing_level_height, .rain, .showers].contains(variable)
        default:
            return false
        }
    }

    var deadlineHours: Double {
        switch self {
        case .iconD2, .iconD2Ruc, .iconD2Eps: return 2
        default: return 5
        }
    }

    /// E.g. icon global 0z has 180 as a last value, but 6z only 120
    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch self {
        case .iconEps:
            // Note ICON-EPS has only 6 hourly data for 6/18z runs, not used here
            if run == 6 || run == 18 {
                fatalError("ICON-EPS 06/18 UTC runs are not supported. Select a 00 or 12 UTC run.")
            }
            // Hourly data until 48h, 3 hourly until 72, 6 hourly until 120h (same as ICON-EU-EPS) and 12 hourly until 180h
            return Array(0...48) + Array(stride(from: 51, through: 72, by: 3)) + Array(stride(from: 78, through: 120, by: 6)) + Array(stride(from: 132, through: 180, by: 12))
        case .icon:
            if  run == 6 || run == 18 {
                // only up to 120
                return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
            } else {
                // full 180
                return Array(0...78) + Array(stride(from: 81, through: 180, by: 3))
            }
        case .iconEuEps:
            // Hourly data until 48h, 3 hourly until 72, then 6 hourly until 120h (same as ICON-EPS)
            // no side runs
            return Array(0...48) + Array(stride(from: 51, through: 72, by: 3)) + Array(stride(from: 78, through: 120, by: 6))
        case .iconEu:
            if run % 6 == 0 {
                return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
            }
            // side runs
            return Array(0...30)
        case .iconD2Ruc:
            return Array(0...27)
        case .iconD2Eps, .iconD2:
            return Array(0...48)
        }
    }

    func downloadLeadSeconds(hour: Int, quarterHourly: Bool) -> [Int] {
        let offsets = quarterHourly ? [0, 900, 1800, 2700] : [0]
        return offsets.map { hour * 3600 + $0 }.filter { self != .iconD2Ruc || $0 <= 27 * 3600 }
    }

    func getGribUrl(field: (variable: String, cat: String, level: Int?), run: Timestamp, leadSeconds: Int, member: Int = 0) -> String {
        let levelPath: String
        switch field.cat {
        case "pressure-level": levelPath = "lvt1/100/lv1/\(field.level! * 100)/"
        case "model-level": levelPath = "lvt1/150/lv1/\(field.level!)/"
        case "soil-level": levelPath = "lvt1/106/lv1/\(Double(field.level!) / 100)/"
        default: levelPath = ""
        }
        let ensemble = countEnsembleMember > 1 ? "e/\((member + 1).zeroPadded(len: 2))/" : ""
        let hours = (leadSeconds / 3600).zeroPadded(len: 3)
        let minutes = ((leadSeconds % 3600) / 60).zeroPadded(len: 2)
        return "https://opendata.dwd.de/weather/nwp/v1/m/\(rawValue)/p/\(field.variable.uppercased())/\(levelPath)r/\(run.iso8601_YYYY_MM_dd_HH_mm)/\(ensemble)s/PT\(hours)H\(minutes)M.grib2"
    }

    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .iconEps:
            return t.subtract(hours: 2).floor(toNearestHour: 12)
        case .icon:
            // Icon has a delay of 2-3 hours after initialisation  with 4 runs a day
            return t.subtract(hours: 2).floor(toNearestHour: 6)
        case .iconEuEps:
            return t.subtract(hours: 2).floor(toNearestHour: 6)
        case .iconEu:
            // Icon-eu has a delay of 2:40 hours after initialisation with 8 runs a day
            return t.subtract(hours: 2).floor(toNearestHour: 3)
        case .iconD2Eps, .iconD2:
            // Icon d2 has a delay of 44 minutes and runs every 3 hours
            return t.floor(toNearestHour: 3)
        case .iconD2Ruc:
            return t.add(-1800).floor(toNearestHour: 1)
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .iconEps:
            return 40
        case .iconEuEps:
            return 40
        case .iconD2Eps:
            return 20
        default:
            return 1
        }
    }

    /// All available pressure levels for the current domain
    var levels: [Int] {
        switch self {
        case .icon:
            return [30, 50, 70, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 850, 900, 925, 950, 1000]
        case .iconEu:
            return [    50, 70, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 850, 900, 925, 950, 1000] // disabled: 775, 825, 875
        case .iconD2, .iconD2Ruc:
            return [                      200, 250, 300, 400, 500, 600, 700, 850, 950, 975, 1000]
        case .iconEps:
            return []
        case .iconEuEps:
            return [] // 300, 500, 850 only temperature and wind
        case .iconD2Eps:
            return [] // 500, 700, 850, 950, 975, 1000
        }
    }

    /// model level standard heights, full levels
    /// icon wind level 1-90 88=98m, 87-174m
    /// icon-eu 1-60 58,57
    /// icon-d2 1-65.... 63=78m, 62=126m
    var numberOfModelFullLevels: Int {
        switch self {
        case .iconEps, .icon:
            return 120 // was 90
        case .iconEuEps, .iconEu:
            return 74 // was 60
        case .iconD2Eps, .iconD2Ruc, .iconD2:
            return 65
        }
    }

    /// Vmax and precip always are empty in the first hour. Weather codes differ a lot in hour 0.
    func skipHour(_ variable: any IconVariableDownloadable, hour: Int, forDownload: Bool, run: Timestamp) -> Bool {
        guard let variable = variable as? IconSurfaceVariable else { return false }
        if variable == .direct_radiation && self == .iconEps && hour % 3 != 0 {
            // ICON-EPS only has 3-hourly data for direct radiation
            return true
        }
        if self == .iconEuEps &&
            [.wind_u_component_80m, .wind_v_component_80m, .temperature_80m].contains(variable) &&
            [57, 63, 69].contains(hour) {
            // Upper levels have fewer timestamps
            return true
        }
        if self == .iconEuEps &&
            [IconSurfaceVariable.snowfall_convective_water_equivalent, .snowfall_water_equivalent].contains(variable) &&
            [6, 18].contains(run.hour) &&
            hour % 6 != 0 {
            return true
        }
        // only 6h pressure in icon
        if self == .iconEps && variable == .pressure_msl && hour % 6 != 0 {
            return true
        }
        // only 6h cape in icon-eu for 6 and 18z run
        if self == .iconEuEps && variable == .cape && [6, 18].contains(run.hour) && (hour % 6 != 0 || hour == 0) {
            return true
        }
        if hour != 0 {
            return false
        }
        // download hour0 from ICON-D2, because it still contains 15 min data
        if forDownload && (self == .iconD2 || self == .iconD2Ruc) && variable != .weather_code {
            return false
        }

        switch variable {
        case .wind_gusts_10m: return true
        case .sensible_heat_flux: return true
        case .latent_heat_flux: return true
        case .direct_radiation: return true
        case .diffuse_radiation: return true
        case .weather_code: return true
        case .snowfall_water_equivalent, .snowfall_convective_water_equivalent, .precipitation, .showers, .rain: return true
        case .updraft: return true
        default: return false
        }
    }

    private func getSurfaceVarAndLevel(_ variable: IconSurfaceVariable) -> (variable: String, cat: String, level: Int?)? {
        if self == .iconD2Ruc {
            switch variable {
            case .soil_temperature_0cm, .soil_temperature_6cm, .soil_temperature_18cm, .soil_temperature_54cm,
                 .soil_moisture_0_to_1cm, .soil_moisture_1_to_3cm, .soil_moisture_3_to_9cm, .soil_moisture_9_to_27cm, .soil_moisture_27_to_81cm,
                 .sensible_heat_flux, .latent_heat_flux, .convective_cloud_base, .convective_cloud_top, .showers, .snowfall_convective_water_equivalent:
                return nil
            case .visibility: return ("VIS", "single-level", nil)
            default: break
            }
        }
        if self == .iconEps || self == .iconEuEps || self == .iconD2Eps {
            switch variable {
            case .diffuse_radiation:
                if self == .iconEps {
                    // ICON-EPS does not have diffuse radiation
                    // Put regular shortwave radiation into this field
                    return ("asob_s", "single-level", nil)
                }
            case .pressure_msl:
                if self == .iconEps || self == .iconEuEps {
                    // use surface pressure instead of sea level pressure
                    return ("ps", "single-level", nil)
                }
            case .direct_radiation:
                break // ICON-EPS has only 3-hourly data
            case .cloud_cover:
                break
            case .temperature_2m:
                break
            case .relative_humidity_2m:
                if self == .iconEps {
                    // use dewpoint, because relative humidity is only 6 hourly
                    return ("td_2m", "single-level", nil)
                }
                if self == .iconEuEps {
                    // No dewpoint or relative humidity available in EU-EPS
                    return nil
                }
            case .precipitation:
                break
            case .wind_u_component_10m:
                break
            case .wind_v_component_10m:
                break
                // In EPS selfs, these variables are not available in global ICON-EPS.
            case .wind_u_component_80m, .wind_v_component_80m, .temperature_80m, .wind_gusts_10m, .snowfall_convective_water_equivalent, .snowfall_water_equivalent, .cape:
                if self == .iconEps {
                    return nil // not in global
                }

                // In EPS selfs, these variables are only available in ICON-D2-EPS.
                // Deterministic ICON-EU/ICON-D2 bypass this EPS-only block.
            case .wind_u_component_120m, .wind_v_component_120m, .temperature_120m, .wind_u_component_180m, .wind_v_component_180m, .rain, .showers, .snow_depth, .temperature_180m, .convective_inhibition:
                if self != .iconD2Eps {
                    return nil
                }
            default:
                return nil
            }
        }

        switch variable {
        case .soil_temperature_0cm: return ("t_so", "soil-level", 0)
        case .soil_temperature_6cm: return ("t_so", "soil-level", 6)
        case .soil_temperature_18cm: return ("t_so", "soil-level", 18)
        case .soil_temperature_54cm: return ("t_so", "soil-level", 54)
        case .soil_moisture_0_to_1cm: return ("w_so", "soil-level", 0)
        case .soil_moisture_1_to_3cm: return ("w_so", "soil-level", 1)
        case .soil_moisture_3_to_9cm: return ("w_so", "soil-level", 3)
        case .soil_moisture_9_to_27cm: return ("w_so", "soil-level", 9)
        case .soil_moisture_27_to_81cm: return ("w_so", "soil-level", 27)
        case .wind_u_component_80m: return ("u", "model-level", self.numberOfModelFullLevels - 2)
        case .wind_v_component_80m: return ("v", "model-level", self.numberOfModelFullLevels - 2)
        case .wind_u_component_120m: return ("u", "model-level", self.numberOfModelFullLevels - 3)
        case .wind_v_component_120m: return ("v", "model-level", self.numberOfModelFullLevels - 3)
        case .wind_u_component_180m: return ("u", "model-level", self.numberOfModelFullLevels - 4)
        case .wind_v_component_180m: return ("v", "model-level", self.numberOfModelFullLevels - 4)
        case .temperature_80m: return ("t", "model-level", self.numberOfModelFullLevels - 2)
        case .temperature_120m: return ("t", "model-level", self.numberOfModelFullLevels - 3)
        case .temperature_180m: return ("t", "model-level", self.numberOfModelFullLevels - 4)
        case .temperature_2m: return ("t_2m", "single-level", nil)
        case .cloud_cover: return ("clct", "single-level", nil)
        case .cloud_cover_low: return ("clcl", "single-level", nil)
        case .cloud_cover_mid: return ("clcm", "single-level", nil)
        case .cloud_cover_high: return ("clch", "single-level", nil)
        case .convective_cloud_top:
            let shallowOrDeepConvectionTop = (self == .iconD2 || self == .iconD2Ruc) ? "htop_sc" : "htop_con"
            return (shallowOrDeepConvectionTop, "single-level", nil)
        case .convective_cloud_base:
            let shallowOrDeepConvectionBase = (self == .iconD2 || self == .iconD2Ruc) ? "hbas_sc" : "hbas_con"
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
        case .convective_inhibition:
            return [IconDownloadDomains.iconEu, .iconD2, .iconD2Ruc, .iconD2Eps].contains(self) ? ("cin_ml", "single-level", nil) : nil
        case .lightning_potential:
            return (self == .iconD2 || self == .iconD2Ruc) ? ("lpi", "single-level", nil) : nil // only in icon d2
        case .snowfall_height:
            return self == .icon ? nil : ("snowlmt", "single-level", nil) // not in icon global
        case .updraft:
            return (self == .iconD2 || self == .iconD2Ruc) ? ("w_ctmax", "single-level", nil) : nil // only in icon d2
        case .visibility:
            return nil // VIS is not published in the v1 feed. Keep the identifier for historical data.
        }
    }

}
