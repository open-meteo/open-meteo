/// Required additions to a GFS variable to make it downloadable
protocol GfsVariableDownloadable: GenericVariable {
    func gribIndexName(for domain: GfsDomain, timestep: Int?) -> String?
    func skipHour0(for domain: GfsDomain) -> Bool
    func multiplyAdd(domain: GfsDomain) -> (multiply: Float, add: Float)?
}

extension GfsSurfaceVariable: GfsVariableDownloadable {
    func gribIndexName(for domain: GfsDomain, timestep: Int?) -> String? {
        switch domain {
        case .gfs013:
            // gfs013 https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20230510/00/atmos/gfs.t00z.sfluxgrbf000.grib2.idx
            switch self {
            case .temperature_2m:
                return ":TMP:2 m above ground:"
            case .surface_temperature:
                return ":TMP:surface:"
            case .cloud_cover:
                return ":TCDC:entire atmosphere:"
            case .cloud_cover_low:
                return ":LCDC:low cloud layer:"
            case .cloud_cover_mid:
                return ":MCDC:middle cloud layer:"
            case .cloud_cover_high:
                return ":HCDC:high cloud layer:"
            case .relative_humidity_2m:
                // use specific humidity and convert to relative humidity
                return ":SPFH:2 m above ground:"
            case .pressure_msl:
                // only used temporaily to convert specific humidity
                return ":PRES:surface:"
            case .precipitation:
                // PRATE:surface:6-7 hour ave fcst:
                return ":PRATE:surface:"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:"
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
            case .sensible_heat_flux:
                return ":SHTFL:surface:"
            case .latent_heat_flux:
                return ":LHTFL:surface:"
            case .showers:
                return ":CPRAT:surface:"
            case .shortwave_radiation:
                return ":DSWRF:surface:"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface"
            case .diffuse_radiation:
                return ":VDDSF:surface:"
            case .uv_index:
                return ":DUVB:surface:"
            case .uv_index_clear_sky:
                return ":CDUVB:surface:"
            default:
                return nil
            }
        case .gfs025:
            // gfs025 https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20230510/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
            switch self {
            case .pressure_msl:
                // mean sea level pressure using eta reduction
                // https://luckgrib.com/tutorials/2018/08/28/gfs-prmsl-vs-mslet.html
                return ":MSLET:mean sea level:"
            case .categorical_freezing_rain:
                return ":CFRZR:"
            case .temperature_80m:
                return ":TMP:80 m above ground:"
            case .temperature_100m:
                return ":TMP:100 m above ground:"
            case .wind_v_component_80m:
                return ":VGRD:80 m above ground:"
            case .wind_u_component_80m:
                return ":UGRD:80 m above ground:"
            case .wind_v_component_100m:
                return ":VGRD:100 m above ground:"
            case .wind_u_component_100m:
                return ":UGRD:100 m above ground:"
            case .wind_gusts_10m:
                return ":GUST:surface:"
            case .freezing_level_height:
                return ":HGT:0C isotherm:"
            case .cape:
                return ":CAPE:surface:"
            case .lifted_index:
                return ":LFTX:surface:"
            case .convective_inhibition:
                return ":CIN:surface:"
            case .visibility:
                return ":VIS:surface:"
            default:
                return nil
            }
        case .hrrr_conus:
            // hrrr https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.20230510/conus/hrrr.t00z.wrfnatf00.grib2.idx
            // https://home.chpc.utah.edu/~u0553130/Brian_Blaylock/HRRR_archive/hrrr_sfc_table.html
            switch self {
            case .pressure_msl:
                return ":MSLMA:mean sea level:"
            case .lifted_index:
                return ":LFTX:500-1000 mb:"
            case .showers:
                // there is no parameterised convective precipitation field
                // NAM and HRRR are convection-allowing models https://learningweather.psu.edu/node/90
                return nil
            case .temperature_2m:
                return ":TMP:2 m above ground:"
            case .cloud_cover:
                return ":TCDC:entire atmosphere:"
            case .cloud_cover_low:
                return ":LCDC:low cloud layer:"
            case .cloud_cover_mid:
                return ":MCDC:middle cloud layer:"
            case .cloud_cover_high:
                return ":HCDC:high cloud layer:"
            case .relative_humidity_2m:
                return ":RH:2 m above ground:"
            case .precipitation:
                return ":PRATE:surface:"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:"
            case .wind_v_component_80m:
                return ":VGRD:80 m above ground:"
            case .wind_u_component_80m:
                return ":UGRD:80 m above ground:"
            case .surface_temperature:
                return ":TMP:surface:"
            case .snow_depth:
                return ":SNOD:surface:"
            case .sensible_heat_flux:
                return ":SHTFL:surface:"
            case .latent_heat_flux:
                return ":LHTFL:surface:"
            case .convective_inhibition:
                return ":CIN:surface:"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface"
            case .categorical_freezing_rain:
                return ":CFRZR:surface:"
            case .wind_gusts_10m:
                return ":GUST:surface:"
            case .freezing_level_height:
                return ":HGT:0C isotherm:"
            case .shortwave_radiation:
                return ":DSWRF:surface:"
            case .diffuse_radiation:
                return ":VDDSF:surface:"
            case .cape:
                return ":CAPE:surface:"
            case .visibility:
                return ":VIS:surface:"
            case .precipitation_probability:
                return nil
            default:
                return nil
            }
        case .hrrr_conus_15min:
            guard let timestep else {
                return nil
            }
            let avg15 = timestep == 0 ? "anl" : "\(timestep-15)-\(timestep) min ave fcst"
            let fcst = timestep == 0 ? "anl" : "\(timestep) min fcst"
            switch self {
            case .temperature_2m:
                return ":TMP:2 m above ground:\(fcst):"
            case .precipitation:
                return ":PRATE:surface:\(fcst):"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface:\(fcst):"
            case .categorical_freezing_rain:
                return ":CFRZR:surface:\(fcst):"
            case .wind_gusts_10m:
                return ":GUST:surface:\(fcst):"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:\(fcst):"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:\(fcst):"
            case .wind_v_component_80m:
                return ":VGRD:80 m above ground:\(fcst):"
            case .wind_u_component_80m:
                return ":UGRD:80 m above ground:\(fcst):"
            case .shortwave_radiation:
                // 15 min backwards averaged
                return ":DSWRF:surface:\(avg15):"
            case .diffuse_radiation:
                // instantanous, will be backwards averaged later
                return ":VDDSF:surface:\(fcst):"
            case .visibility:
                return ":VIS:surface:\(fcst):"
            default:
                return nil
            }
        case .gfs025_ensemble:
            switch self {
            case .precipitation_probability:
                return ":APCP:surface:"
            default:
                return nil
            }
        case .gfs025_ens:
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.20230427/00/atmos/pgrb2sp25/geavg.t00z.pgrb2s.0p25.f003.idx
            switch self {
            case .visibility:
                return ":VIS:surface:"
            case .wind_gusts_10m:
                return ":GUST:surface:"
            case .pressure_msl:
                return ":MSLET:mean sea level:"
            case .soil_temperature_0_to_10cm:
                return ":TSOIL:0-0.1 m below ground:"
            case .soil_moisture_0_to_10cm:
                return ":SOILW:0-0.1 m below ground:"
            case .snow_depth:
                return ":SNOD:surface:"
            case .temperature_2m:
                return ":TMP:2 m above ground:"
            case .relative_humidity_2m:
                return ":RH:2 m above ground:"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface:"
            case .precipitation:
                return ":APCP:surface:"
            case .categorical_freezing_rain:
                return ":CFRZR:surface:"
            case .latent_heat_flux:
                return ":LHTFL:surface:"
            case .sensible_heat_flux:
                return ":SHTFL:surface:"
            case .convective_inhibition:
                return ":CIN:surface:"
            case .cape:
                return ":CAPE:surface:"
            case .cloud_cover:
                return ":TCDC:entire atmosphere:"
            case .shortwave_radiation:
                return ":DSWRF:surface:"
            default:
                return nil
            }
        case .gfs05_ens:
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.20230427/00/atmos/pgrb2bp5/gec00.t00z.pgrb2b.0p50.f003.idx
            switch self {
            case .visibility:
                return ":VIS:surface:"
            case .wind_gusts_10m:
                return ":GUST:surface:"
            case .pressure_msl:
                return ":MSLET:mean sea level:"
            case .snow_depth:
                return ":SNOD:surface:"
            case .temperature_2m:
                return ":TMP:2 m above ground:"
            case .temperature_80m:
                return ":TMP:80 m above ground:"
            case .temperature_100m:
                return ":TMP:100 m above ground:"
            case .relative_humidity_2m:
                return ":RH:2 m above ground:"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:"
            case .wind_u_component_80m:
                return ":UGRD:80 m above ground:"
            case .wind_v_component_80m:
                return ":VGRD:80 m above ground:"
            case .wind_u_component_100m:
                return ":UGRD:100 m above ground:"
            case .wind_v_component_100m:
                return ":VGRD:100 m above ground:"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface:"
            case .precipitation:
                return ":APCP:surface:"
            case .categorical_freezing_rain:
                return ":CFRZR:surface:"
            case .latent_heat_flux:
                return ":LHTFL:surface:"
            case .sensible_heat_flux:
                return ":SHTFL:surface:"
            case .cape:
                return ":CAPE:surface:"
            case .cloud_cover:
                return ":TCDC:entire atmosphere:"
            case .shortwave_radiation:
                return ":DSWRF:surface:"
            case .lifted_index:
                return ":LFTX:surface:"
            case .convective_inhibition:
                return ":CIN:surface:"
            case .freezing_level_height:
                return ":HGT:0C isotherm:"
            case .surface_temperature:
                return ":TMP:surface:"
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
            case .uv_index:
                return ":DUVB:surface:"
            case .uv_index_clear_sky:
                return ":CDUVB:surface:"
            default:
                return nil
            }
        }
    }
    
    func skipHour0(for domain: GfsDomain) -> Bool {
        if domain == .hrrr_conus_15min {
            switch self {
            case .shortwave_radiation:
                return true
            case .diffuse_radiation:
                return true
            default:
                return false
            }
        }
        switch self {
        case .precipitation_probability: return true
        case .precipitation: return true
        case .categorical_freezing_rain: return true
        case .sensible_heat_flux: return true
        case .latent_heat_flux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .uv_index: return true
        case .uv_index_clear_sky: return true
        case .cloud_cover: fallthrough // cloud cover not available in hour 0 in GFS013
        case .cloud_cover_low: fallthrough
        case .cloud_cover_mid: fallthrough
        case .cloud_cover_high: return domain == .gfs013 || domain == .gfs025_ens || domain == .gfs05_ens
        default: return false
        }
    }
    
    func multiplyAdd(domain: GfsDomain) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_80m:
            fallthrough
        case .temperature_100m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .surface_temperature:
            fallthrough
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200cm:
            return (1, -273.15)
        case .showers:
            fallthrough
        case .precipitation:
            switch domain {
            case .gfs013:
                fallthrough
            case .gfs025:
                fallthrough
            case .hrrr_conus_15min:
                fallthrough
            case .hrrr_conus:
                // precipitation rate per second to hourly precipitation
                return (Float(domain.dtSeconds), 0)
            case .gfs025_ensemble:
                fallthrough
            case .gfs025_ens:
                fallthrough
            case .gfs05_ens:
                return nil
            }
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
    func gribIndexName(for domain: GfsDomain, timestep: Int?) -> String? {
        switch variable {
        case .temperature:
            return ":TMP:\(level) mb:"
        case .wind_u_component:
            return ":UGRD:\(level) mb:"
        case .wind_v_component:
            return ":VGRD:\(level) mb:"
        case .geopotential_height:
            return ":HGT:\(level) mb:"
        case .cloud_cover:
            if domain != .gfs025 {
                // no cloud cover in HRRR and NAM
                return nil
            }
            if level < 50 || level == 70 {
                return nil
            }
            return ":TCDC:\(level) mb:"
        case .relative_humidity:
            return ":RH:\(level) mb:"
        case .vertical_velocity:
            switch domain {
            case .gfs013:
                return nil
            case .gfs025:
                // Vertical Velocity (Geometric) [m/s]
                return ":DZDT:\(level) mb:"
            case .gfs05_ens:
                fallthrough
            case .hrrr_conus_15min:
                fallthrough
            case .hrrr_conus:
                // Vertical Velocity (Pressure) [Pa/s]
                // Converted later while downlading
                return ":VVEL:\(level) mb:"
            case .gfs025_ens:
                return nil
            case .gfs025_ensemble:
                return nil
            }
        }
    }
    
    func skipHour0(for domain: GfsDomain) -> Bool {
        return false
    }
    
    func multiplyAdd(domain: GfsDomain) -> (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        default:
            return nil
        }
    }
}
