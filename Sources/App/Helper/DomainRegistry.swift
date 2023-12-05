import Foundation

/**
 List of all integrated domains
 */
enum DomainRegistry: String, CaseIterable {
    case arome_france
    case arome_france_hd
    case arpege_europe
    case arpege_world
    
    case cams_europe
    case cams_global
    
    case dem90
    case cerra
    case era5
    case era5_land
    case era5_ocean
    
    case gem_global
    case gem_global_ensemble
    case gem_hrdps_continental
    case gem_regional
    
    case gfs013
    case gfs025
    case gfs025_ens
    case gfs025_ensemble
    case gfs05_ens
    case hrrr_conus
    case hrrr_conus_15min
    case cfsv2
    
    case glofas_consolidated_v4
    case glofas_consolidated_v3
    case glofas_forecast_v4
    case glofas_forecast_v3
    case glofas_intermediate_v4
    case glofas_intermediate_v3
    case glofas_seasonal_v3
    case glofas_seasonal_v4
    
    case icon
    case icon_eu
    case icon_d2
    case icon_d2_15min
    case icon_eps
    case icon_eu_eps
    case icon_d2_eps
    case icon_ewam
    case icon_gwam
    
    case ecmwf_ifs
    case ecmwf_ifs04
    case ecmwf_ifs04_ensemble
    
    case jma_msm
    case jma_gsm

    case nordic_pp
    
    case imerg_daily
    
    case cmip_CMCC_CM2_VHR4
    case cmip_EC_Earth3P_HR
    case cmip_FGOALS_f3_H
    case cmip_HiRAM_SIT_HR
    case cmip_MPI_ESM1_2_XR
    case cmip_MRI_AGCM3_2_S
    case cmip_NICAM16_8S
    
    func getDomain() -> GenericDomain {
        switch self {
        case .arome_france:
            return MeteoFranceDomain.arome_france
        case .arome_france_hd:
            return MeteoFranceDomain.arome_france_hd
        case .arpege_europe:
            return MeteoFranceDomain.arpege_europe
        case .arpege_world:
            return MeteoFranceDomain.arpege_world
        case .cams_europe:
            return CamsDomain.cams_europe
        case .cams_global:
            return CamsDomain.cams_global
        case .cerra:
            return CdsDomain.cerra
        case .dem90:
            fatalError()
        case .ecmwf_ifs:
            return CdsDomain.ecmwf_ifs
        case .era5:
            return CdsDomain.era5
        case .era5_land:
            return CdsDomain.era5_land
        case .era5_ocean:
            return CdsDomain.era5_ocean
        case .icon_ewam:
            return IconWaveDomain.ewam
        case .gem_global:
            return GemDomain.gem_global
        case .gem_global_ensemble:
            return GemDomain.gem_global_ensemble
        case .gem_hrdps_continental:
            return GemDomain.gem_hrdps_continental
        case .gem_regional:
            return GemDomain.gem_regional
        case .gfs013:
            return GfsDomain.gfs013
        case .gfs025:
            return GfsDomain.gfs025
        case .gfs025_ens:
            return GfsDomain.gfs025_ens
        case .gfs025_ensemble:
            return GfsDomain.gfs025_ensemble
        case .gfs05_ens:
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
        case .icon_gwam:
            return IconWaveDomain.gwam
        case .hrrr_conus:
            return GfsDomain.hrrr_conus
        case .hrrr_conus_15min:
            return GfsDomain.hrrr_conus_15min
        case .icon:
            return IconDomains.icon
        case .icon_d2:
            return IconDomains.iconD2
        case .icon_d2_15min:
            return IconDomains.iconD2_15min
        case .icon_d2_eps:
            return IconDomains.iconD2Eps
        case .icon_eps:
            return IconDomains.iconEps
        case .icon_eu:
            return IconDomains.iconEu
        case .icon_eu_eps:
            return IconDomains.iconEuEps
        case .ecmwf_ifs04:
            return EcmwfDomain.ifs04
        case .ecmwf_ifs04_ensemble:
            return EcmwfDomain.ifs04_ensemble
        case .jma_msm:
            return JmaDomain.msm
        case .cfsv2:
            return SeasonalForecastDomain.ncep
        case .nordic_pp:
            return MetNoDomain.nordic_pp
        case .imerg_daily:
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
        }
    }
}
