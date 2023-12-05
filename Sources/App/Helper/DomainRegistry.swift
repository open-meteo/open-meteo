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
    case cerra
    case dem90
    case ecmwf_ifs
    case era5
    case era5_land
    case era5_ocean
    case ewam
    case gem_global
    case gem_global_ensemble
    case gem_hrdps_continental
    case gem_regional
    case gfs013
    case gfs025
    case gfs025_ens
    case gfs025_ensemble
    case gfs05_ens
    case glofas_consolidated = "glofas-consolidated"
    case glofas_consolidatedv3 = "glofas-glofas_consolidatedv3"
    case glofas_forecast = "glofas-forecast"
    case glofas_forecastv3 = "glofas-forecastv3"
    case glofas_intermediate = "glofas-intermediate"
    case glofas_intermediatev3 = "glofas-intermediatev3"
    case glofas_seasonalv3 = "glofas-seasonalv3"
    case glofas_seasonal = "glofas-seasonal"
    case gsm
    case gwam
    case hrrr_conus
    case hrrr_conus_15min
    case icon
    case icon_eu = "icon-eu"
    case icon_d2 = "icon-d2"
    case icon_d2_15min = "icon-d2-15min"
    case icon_eps = "icon-eps"
    case icon_eu_eps = "icon-eu-eps"
    case icon_d2_eps = "icon-d2-eps"
    case ifs04
    case ifs04_ensemble
    case msm
    case ncep
    case nordic_pp
    case CMCC_CM2_VHR4
    case EC_Earth3P_HR
    case FGOALS_f3_H
    case HiRAM_SIT_HR
    case imerg_daily
    case MPI_ESM1_2_XR
    case MRI_AGCM3_2_S
    case NICAM16_8S
    
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
        case .ewam:
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
        case .glofas_consolidated:
            return GloFasDomain.consolidated
        case .glofas_consolidatedv3:
            return GloFasDomain.consolidatedv3
        case .glofas_forecast:
            return GloFasDomain.forecast
        case .glofas_forecastv3:
            return GloFasDomain.forecastv3
        case .glofas_intermediate:
            return GloFasDomain.intermediate
        case .glofas_intermediatev3:
            return GloFasDomain.intermediatev3
        case .glofas_seasonal:
            return GloFasDomain.seasonal
        case .glofas_seasonalv3:
            return GloFasDomain.seasonalv3
        case .gsm:
            return JmaDomain.gsm
        case .gwam:
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
        case .ifs04:
            return EcmwfDomain.ifs04
        case .ifs04_ensemble:
            return EcmwfDomain.ifs04_ensemble
        case .msm:
            return JmaDomain.msm
        case .ncep:
            return SeasonalForecastDomain.ncep
        case .nordic_pp:
            return MetNoDomain.nordic_pp
        case .CMCC_CM2_VHR4:
            return Cmip6Domain.CMCC_CM2_VHR4
        case .EC_Earth3P_HR:
            return Cmip6Domain.EC_Earth3P_HR
        case .FGOALS_f3_H:
            return Cmip6Domain.FGOALS_f3_H
        case .HiRAM_SIT_HR:
            return Cmip6Domain.HiRAM_SIT_HR
        case .imerg_daily:
            return SatelliteDomain.imerg_daily
        case .MPI_ESM1_2_XR:
            return Cmip6Domain.MPI_ESM1_2_XR
        case .MRI_AGCM3_2_S:
            return Cmip6Domain.MRI_AGCM3_2_S
        case .NICAM16_8S:
            return Cmip6Domain.NICAM16_8S
        }
    }
}
