import Foundation

/**
 List of all integrated domains
 */
enum DomainRegistry: String, CaseIterable {
    case meteofrance_arome_france0025
    case meteofrance_arome_france_hd
    case meteofrance_arpege_europe
    case meteofrance_arpege_world025
    
    case cams_europe
    case cams_global
    
    case copernicus_dem90
    case copernicus_cerra
    case copernicus_era5
    case copernicus_era5_daily
    case copernicus_era5_land
    case copernicus_era5_land_daily
    case copernicus_era5_ocean
    
    case cmc_gem_gdps
    case cmc_gem_geps
    case cmc_gem_hrdps
    case cmc_gem_rdps
    
    case ncep_gfs013
    case ncep_gfs025
    case ncep_gefs025
    case ncep_gefs025_probability
    case ncep_gefs05
    case ncep_hrrr_conus
    case ncep_hrrr_conus_15min
    case ncep_cfsv2
    
    case glofas_consolidated_v4
    case glofas_consolidated_v3
    case glofas_forecast_v4
    case glofas_forecast_v3
    case glofas_intermediate_v4
    case glofas_intermediate_v3
    case glofas_seasonal_v3
    case glofas_seasonal_v4
    
    case dwd_icon
    case dwd_icon_eu
    case dwd_icon_d2
    case dwd_icon_d2_15min
    case dwd_icon_eps
    case dwd_icon_eu_eps
    case dwd_icon_d2_eps
    case dwd_ewam
    case dwd_gwam
    
    case ecmwf_ifs
    case ecmwf_ifs04
    case ecmwf_ifs04_ensemble
    
    case jma_msm
    case jma_gsm

    case metno_nordic_pp
    
    case nasa_imerg_daily
    
    case cma_grapes_global
    
    case bom_access_global
    case bom_access_global_ensemble
    
    case cmip_CMCC_CM2_VHR4
    case cmip_EC_Earth3P_HR
    case cmip_FGOALS_f3_H
    case cmip_HiRAM_SIT_HR
    case cmip_MPI_ESM1_2_XR
    case cmip_MRI_AGCM3_2_S
    case cmip_NICAM16_8S
    
    var directory: String {
        return "\(OpenMeteo.dataDirectory)\(rawValue)/"
    }
    
    func getDomain() -> GenericDomain {
        switch self {
        case .meteofrance_arome_france0025:
            return MeteoFranceDomain.arome_france
        case .meteofrance_arome_france_hd:
            return MeteoFranceDomain.arome_france_hd
        case .meteofrance_arpege_europe:
            return MeteoFranceDomain.arpege_europe
        case .meteofrance_arpege_world025:
            return MeteoFranceDomain.arpege_world
        case .cams_europe:
            return CamsDomain.cams_europe
        case .cams_global:
            return CamsDomain.cams_global
        case .copernicus_cerra:
            return CdsDomain.cerra
        case .copernicus_dem90:
            return Dem90()
        case .ecmwf_ifs:
            return CdsDomain.ecmwf_ifs
        case .copernicus_era5:
            return CdsDomain.era5
        case .copernicus_era5_land:
            return CdsDomain.era5_land
        case .copernicus_era5_ocean:
            return CdsDomain.era5_ocean
        case .dwd_ewam:
            return IconWaveDomain.ewam
        case .cmc_gem_gdps:
            return GemDomain.gem_global
        case .cmc_gem_geps:
            return GemDomain.gem_global_ensemble
        case .cmc_gem_hrdps:
            return GemDomain.gem_hrdps_continental
        case .cmc_gem_rdps:
            return GemDomain.gem_regional
        case .ncep_gfs013:
            return GfsDomain.gfs013
        case .ncep_gfs025:
            return GfsDomain.gfs025
        case .ncep_gefs025:
            return GfsDomain.gfs025_ens
        case .ncep_gefs025_probability:
            return GfsDomain.gfs025_ensemble
        case .ncep_gefs05:
            return GfsDomain.gfs05_ens
        case .glofas_consolidated_v4:
            return GloFasDomain.consolidated
        case .glofas_consolidated_v3:
            return GloFasDomain.consolidatedv3
        case .glofas_forecast_v4:
            return GloFasDomain.forecast
        case .glofas_forecast_v3:
            return GloFasDomain.forecastv3
        case .glofas_intermediate_v4:
            return GloFasDomain.intermediate
        case .glofas_intermediate_v3:
            return GloFasDomain.intermediatev3
        case .glofas_seasonal_v4:
            return GloFasDomain.seasonal
        case .glofas_seasonal_v3:
            return GloFasDomain.seasonalv3
        case .jma_gsm:
            return JmaDomain.gsm
        case .dwd_gwam:
            return IconWaveDomain.gwam
        case .ncep_hrrr_conus:
            return GfsDomain.hrrr_conus
        case .ncep_hrrr_conus_15min:
            return GfsDomain.hrrr_conus_15min
        case .dwd_icon:
            return IconDomains.icon
        case .dwd_icon_d2:
            return IconDomains.iconD2
        case .dwd_icon_d2_15min:
            return IconDomains.iconD2_15min
        case .dwd_icon_d2_eps:
            return IconDomains.iconD2Eps
        case .dwd_icon_eps:
            return IconDomains.iconEps
        case .dwd_icon_eu:
            return IconDomains.iconEu
        case .dwd_icon_eu_eps:
            return IconDomains.iconEuEps
        case .ecmwf_ifs04:
            return EcmwfDomain.ifs04
        case .ecmwf_ifs04_ensemble:
            return EcmwfDomain.ifs04_ensemble
        case .jma_msm:
            return JmaDomain.msm
        case .ncep_cfsv2:
            return SeasonalForecastDomain.ncep
        case .metno_nordic_pp:
            return MetNoDomain.nordic_pp
        case .nasa_imerg_daily:
            return SatelliteDomain.imerg_daily
        case .cmip_CMCC_CM2_VHR4:
            return Cmip6Domain.CMCC_CM2_VHR4
        case .cmip_EC_Earth3P_HR:
            return Cmip6Domain.EC_Earth3P_HR
        case .cmip_FGOALS_f3_H:
            return Cmip6Domain.FGOALS_f3_H
        case .cmip_HiRAM_SIT_HR:
            return Cmip6Domain.HiRAM_SIT_HR
        case .cmip_MPI_ESM1_2_XR:
            return Cmip6Domain.MPI_ESM1_2_XR
        case .cmip_MRI_AGCM3_2_S:
            return Cmip6Domain.MRI_AGCM3_2_S
        case .cmip_NICAM16_8S:
            return Cmip6Domain.NICAM16_8S
        case .copernicus_era5_daily:
            return CdsDomain.era5_daily
        case .copernicus_era5_land_daily:
            return CdsDomain.era5_land_daily
        case .cma_grapes_global:
            return CmaDomain.grapes_global
        case .bom_access_global:
            return BomDomain.access_global
        case .bom_access_global_ensemble:
            return BomDomain.access_global_ensemble
        }
    }
}
