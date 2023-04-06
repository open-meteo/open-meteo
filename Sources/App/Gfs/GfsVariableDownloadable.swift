/// Required additions to a GFS variable to make it downloadable
protocol GfsVariableDownloadable: GenericVariable {
    func gribIndexName(for domain: GfsDomain) -> String?
    func skipHour0(for domain: GfsDomain) -> Bool
    var interpolationType: Interpolation2StepType { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
}

extension GfsSurfaceVariable: GfsVariableDownloadable {
    func gribIndexName(for domain: GfsDomain) -> String? {
        // NAM has different definitons
        /*if domain == .nam_conus {
            switch variable {
            case .lifted_index:
                return ":LFTX:500-1000 mb:"
            case .cloudcover:
                return ":TCDC:entire atmosphere (considered as a single layer):"
            case .precipitation:
                // only 3h accumulation is availble
                return ":APCP:surface:"
            case .showers:
                // there is no parameterised convective precipitation field
                // NAM and HRRR are convection-allowing models https://learningweather.psu.edu/node/90
                return nil
            default: break
            }
        }*/
        
        if domain == .gfs025_ensemble {
            switch self {
            case .precipitation_probability:
                return ":APCP:surface:"
            default:
                return nil
            }
        }
        
        if domain == .hrrr_conus {
            switch self {
            case .lifted_index:
                return ":LFTX:500-1000 mb:"
            case .showers:
                // there is no parameterised convective precipitation field
                // NAM and HRRR are convection-allowing models https://learningweather.psu.edu/node/90
                return nil
            case .soil_moisture_0_to_10cm:
                fallthrough
            case .soil_moisture_10_to_40cm:
                fallthrough
            case .soil_moisture_40_to_100cm:
                fallthrough
            case .soil_moisture_100_to_200cm:
                fallthrough
            case .soil_temperature_0_to_10cm:
                fallthrough
            case .soil_temperature_10_to_40cm:
                fallthrough
            case .soil_temperature_40_to_100cm:
                fallthrough
            case .soil_temperature_100_to_200cm:
                return nil
            case .uv_index:
                return nil
            case .uv_index_clear_sky:
                return nil
            default: break
            }
        }
        
        if domain == .gfs013 {
            switch self {
            case .relativehumidity_2m:
                // Download specific humidity and convert it later
                return ":SPFH:2 m above ground:"
            case .categorical_freezing_rain:
                return nil
            case .wind_u_component_80m:
                return nil
            case .wind_v_component_80m:
                return nil
            case .windgusts_10m:
                return nil
            case .freezinglevel_height:
                return nil
            case .cape:
                return nil
            case .lifted_index:
                return nil
            case .visibility:
                return nil
            default: break
            }
        }
        
        if domain == .gfs025 {
            // if variable is in gfs013, it is not required for gfs025
            if self.gribIndexName(for: .gfs013) != nil {
                return nil
            }
        }
        
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:"
        case .cloudcover:
            return ":TCDC:entire atmosphere:"
        case .cloudcover_low:
            return ":LCDC:low cloud layer:"
        case .cloudcover_mid:
            return ":MCDC:middle cloud layer:"
        case .cloudcover_high:
            return ":HCDC:high cloud layer:"
        case .surface_pressure:
            return ":PRES:surface:"
        case .relativehumidity_2m:
            return ":RH:2 m above ground:"
        case .precipitation:
            // PRATE:surface:6-7 hour ave fcst:
            return ":PRATE:surface:"
        case .wind_v_component_10m:
            return ":VGRD:10 m above ground:"
        case .wind_u_component_10m:
            return ":UGRD:10 m above ground:"
        case .wind_v_component_80m:
            return ":VGRD:80 m above ground:"
        case .wind_u_component_80m:
            return ":UGRD:80 m above ground:"
        case .soil_temperature_0_to_10cm:
            return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm:
            return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm:
            return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm:
            return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm:
            return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm:
            return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm:
            return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm:
            return ":SOILW:1-2 m below ground:"
        case .snow_depth:
            return ":SNOD:surface:"
        case .sensible_heatflux:
            return ":SHTFL:surface:"
        case .latent_heatflux:
            return ":LHTFL:surface:"
        case .showers:
            return ":CPRAT:surface:"
        case .windgusts_10m:
            return ":GUST:surface:"
        case .freezinglevel_height:
            return ":HGT:0C isotherm:"
        case .shortwave_radiation:
            return ":DSWRF:surface:"
        case .frozen_precipitation_percent:
            return ":CPOFP:surface"
        case .cape:
            return ":CAPE:surface:"
        case .lifted_index:
            return ":LFTX:surface:"
        case .visibility:
            return ":VIS:surface:"
        case .diffuse_radiation:
            return ":VDDSF:surface:"
        case .uv_index:
            return ":DUVB:surface:"
        case .uv_index_clear_sky:
            return ":CDUVB:surface:"
        case .precipitation_probability:
            return nil
        case .categorical_freezing_rain:
            return ":CFRZR:"
        }
    }
    
    func skipHour0(for domain: GfsDomain) -> Bool {
        switch self {
        case .precipitation_probability: return true
        case .precipitation: return true
        case .categorical_freezing_rain: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .uv_index: return true
        case .uv_index_clear_sky: return true
        case .cloudcover: fallthrough // cloud cover not available in hour 0 in GFS013
        case .cloudcover_low: fallthrough
        case .cloudcover_mid: fallthrough
        case .cloudcover_high: return domain == .gfs013
        default: return false
        }
    }
    
    var interpolationType: Interpolation2StepType {
        switch self {
        case .temperature_2m: return .hermite(bounds: nil)
        case .cloudcover: return .hermite(bounds: 0...100)
        case .cloudcover_low: return .hermite(bounds: 0...100)
        case .cloudcover_mid: return .hermite(bounds: 0...100)
        case .cloudcover_high: return .hermite(bounds: 0...100)
        case .relativehumidity_2m: return .hermite(bounds: 0...100)
        case .precipitation: return .nearest
        case .wind_v_component_10m: return .hermite(bounds: nil)
        case .wind_u_component_10m: return .hermite(bounds: nil)
        case .snow_depth: return .linear
        case .sensible_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .latent_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .windgusts_10m: return .linear
        case .freezinglevel_height: return .hermite(bounds: nil)
        case .shortwave_radiation: return .solar_backwards_averaged
        case .uv_index: return .solar_backwards_averaged
        case .uv_index_clear_sky: return .solar_backwards_averaged
        case .soil_temperature_0_to_10cm: return .hermite(bounds: nil)
        case .soil_temperature_10_to_40cm: return .hermite(bounds: nil)
        case .soil_temperature_40_to_100cm: return .hermite(bounds: nil)
        case .soil_temperature_100_to_200cm: return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm: return .hermite(bounds: nil)
        case .soil_moisture_10_to_40cm: return .hermite(bounds: nil)
        case .soil_moisture_40_to_100cm: return .hermite(bounds: nil)
        case .soil_moisture_100_to_200cm: return .hermite(bounds: nil)
        case .wind_v_component_80m: return .hermite(bounds: nil)
        case .wind_u_component_80m: return .hermite(bounds: nil)
        case .showers: return .nearest
        case .surface_pressure: return .hermite(bounds: nil)
        case .frozen_precipitation_percent: return .nearest
        case .diffuse_radiation: return .solar_backwards_averaged
        case .cape: return .hermite(bounds: 0...1e9)
        case .lifted_index: return .hermite(bounds: 0...1e9)
        case .visibility: return .hermite(bounds: 0...1e9)
        case .precipitation_probability: return .linear
        case .categorical_freezing_rain: return .nearest
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .surface_pressure:
            return (1/100, 0)
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200cm:
            return (1, -273.15)
        case .showers:
            return (3600, 0)
        case .precipitation:
            return (3600, 0)
        case .uv_index:
            fallthrough
        case .uv_index_clear_sky:
            // UVB to etyhemally UV factor 18.9 https://link.springer.com/article/10.1039/b312985c
            // 0.025 m2/W to get the uv index
            // compared to https://www.aemet.es/es/eltiempo/prediccion/radiacionuv
            return (18.9 * 0.025, 0)
        default:
            return nil
        }
    }
}

extension GfsPressureVariable: GfsVariableDownloadable {
    func gribIndexName(for domain: GfsDomain) -> String? {
        switch variable {
        case .temperature:
            return ":TMP:\(level) mb:"
        case .wind_u_component:
            return ":UGRD:\(level) mb:"
        case .wind_v_component:
            return ":VGRD:\(level) mb:"
        case .geopotential_height:
            return ":HGT:\(level) mb:"
        case .cloudcover:
            if domain != .gfs025 {
                // no cloud cover in HRRR and NAM
                return nil
            }
            if level < 50 || level == 70 {
                return nil
            }
            return ":TCDC:\(level) mb:"
        case .relativehumidity:
            return ":RH:\(level) mb:"
        case .vertical_velocity:
            switch domain {
            case .gfs013:
                return nil
            case .gfs025:
                // Vertical Velocity (Geometric) [m/s]
                return ":DZDT:\(level) mb:"
            case .hrrr_conus:
                // Vertical Velocity (Pressure) [Pa/s]
                // Converted later while downlading
                return ":VVEL:\(level) mb:"
            case .gfs025_ensemble:
                return nil
            }
        }
    }
    
    func skipHour0(for domain: GfsDomain) -> Bool {
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
}
