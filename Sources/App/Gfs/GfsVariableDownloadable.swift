/// Required additions to a GFS variable to make it downloadable
protocol GfsVariableDownloadable: GenericVariable {
    func gribIndexName(for domain: GfsDomain) -> String?
    func skipHour0(for domain: GfsDomain) -> Bool
    var interpolationType: Interpolation2StepType { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var isAveragedOverForecastTime: Bool { get }
    var isAccumulatedSinceModelStart: Bool { get }
}

extension GfsSurfaceVariable: GfsVariableDownloadable {
    func gribIndexName(for domain: GfsDomain) -> String? {
        // NAM has eoms different definitons
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
            case .pressure_msl:
                return nil
            default: break
            }
        }
        
        if domain == .gfs013 {
            switch self {
            case .pressure_msl:
                return nil // only specific humidity
            case .relativehumidity_2m:
                return nil
            case .precipitation:
                return nil // only PRATE grib code
            case .showers:
                return nil
            case .wind_u_component_80m:
                return nil
            case .wind_v_component_80m:
                return nil
            case .windgusts_10m:
                return nil
            case .freezinglevel_height:
                return nil
            case .frozen_precipitation_percent:
                return nil
            case .categorical_ice_pellets:
                return nil
            case .categorical_freezing_rain:
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
        case .pressure_msl:
            return ":PRMSL:mean sea level:"
        case .relativehumidity_2m:
            return ":RH:2 m above ground:"
        case .precipitation:
            return ":APCP:surface:0-"
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
            return ":ACPCP:surface:0-"
        case .windgusts_10m:
            return ":GUST:surface:"
        case .freezinglevel_height:
            return ":HGT:0C isotherm:"
        case .shortwave_radiation:
            return ":DSWRF:surface:"
        case .frozen_precipitation_percent:
            return ":CSNOW:surface:"
        case .categorical_freezing_rain:
            return ":CFRZR:surface:"
        case .categorical_ice_pellets:
            return ":CICEP:surface:"
        case .cape:
            return ":CAPE:surface:"
        case .lifted_index:
            return ":LFTX:surface:"
        case .visibility:
            return ":VIS:surface:"
        case .diffuse_radiation:
            // not in gfs025
            if domain == .gfs025 {
                return nil
            }
            return ":VDDSF:surface:"
        }
    }
    
    func skipHour0(for domain: GfsDomain) -> Bool {
        switch self {
        case .precipitation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
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
        case .precipitation: return .linear
        case .wind_v_component_10m: return .hermite(bounds: nil)
        case .wind_u_component_10m: return .hermite(bounds: nil)
        case .snow_depth: return .linear
        case .sensible_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .latent_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .windgusts_10m: return .linear
        case .freezinglevel_height: return .hermite(bounds: nil)
        case .shortwave_radiation: return .solar_backwards_averaged
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
        case .showers: return .linear
        case .pressure_msl: return .hermite(bounds: nil)
        case .frozen_precipitation_percent: return .nearest
        case .categorical_ice_pellets: return .nearest
        case .categorical_freezing_rain: return .nearest
        case .diffuse_radiation: return .solar_backwards_averaged
        case .cape: return .hermite(bounds: 0...1e9)
        case .lifted_index: return .hermite(bounds: 0...1e9)
        case .visibility: return .hermite(bounds: 0...1e9)
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200cm:
            return (1, -273.15)
        case .frozen_precipitation_percent:
            return (100, 0)
        case .categorical_freezing_rain:
            return (100, 0)
        case .categorical_ice_pellets:
            return (100, 0)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        default: return false
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .showers: return true
        default: return false
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
    
    var isAveragedOverForecastTime: Bool {
        return false
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
}
