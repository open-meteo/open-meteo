import Foundation

/**
 List of all integrated domains
 */
enum DomainRegistry: String, CaseIterable {
    case meteofrance_arome_france0025
    case meteofrance_arome_france_hd
    case meteofrance_arome_france0025_15min
    case meteofrance_arome_france_hd_15min
    case meteofrance_arpege_europe
    case meteofrance_arpege_world025
    case meteofrance_arpege_europe_probabilities
    case meteofrance_arpege_world025_probabilities
    case meteofrance_wave
    case meteofrance_currents
    case meteofrance_sea_surface_temperature

    case cams_europe
    case cams_global
    case cams_global_greenhouse_gases
    case cams_europe_reanalysis_interim
    case cams_europe_reanalysis_validated
    case cams_europe_reanalysis_validated_pre2020
    case cams_europe_reanalysis_validated_pre2018

    case copernicus_dem90
    case copernicus_cerra
    case copernicus_era5
    case copernicus_era5_ensemble
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
    case ncep_gfswave025
    case ncep_gfswave016
    case ncep_gefswave025
    case ncep_gefs025
    case ncep_gefs05
    case ncep_hrrr_conus
    case ncep_hrrr_conus_15min
    case ncep_cfsv2
    case ncep_gfs_graphcast025
    case ncep_nbm_conus
    case ncep_nbm_alaska

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
    case ecmwf_ifs025
    case ecmwf_ifs025_ensemble
    case ecmwf_aifs025
    case ecmwf_aifs025_single
    case ecmwf_aifs025_ensemble
    case ecmwf_wam025
    case ecmwf_wam025_ensemble
    case ecmwf_ifs_analysis
    case ecmwf_ifs_analysis_long_window
    case ecmwf_ifs_long_window

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

    case arpae_cosmo_2i
    case arpae_cosmo_2i_ruc
    case arpae_cosmo_5m

    case knmi_harmonie_arome_europe
    case knmi_harmonie_arome_netherlands
    case dmi_harmonie_arome_europe

    case ukmo_global_deterministic_10km
    case ukmo_global_ensemble_20km
    case ukmo_uk_deterministic_2km
    case ukmo_uk_ensemble_2km

    case eumetsat_sarah3_30min
    case jma_jaxa_himawari_10min
    case eumetsat_lsa_saf_msg_15min
    case eumetsat_lsa_saf_iodc_15min

    case kma_gdps
    case kma_ldps

    case italia_meteo_arpae_icon_2i
    
    case meteoswiss_icon_ch1
    case meteoswiss_icon_ch2
    case meteoswiss_icon_ch1_ensemble
    case meteoswiss_icon_ch2_ensemble

    var directory: String {
        return "\(OpenMeteo.dataDirectory)\(rawValue)/"
    }
    
    var directorySpatial: String? {
        return OpenMeteo.dataSpatialDirectory.map { "\($0)\(rawValue)/" }
    }

    func getDomain() -> GenericDomain? {
        switch self {
        case .meteofrance_arome_france0025:
            return MeteoFranceDomain.arome_france
        case .meteofrance_arome_france_hd:
            return MeteoFranceDomain.arome_france_hd
        case .meteofrance_arpege_europe:
            return MeteoFranceDomain.arpege_europe
        case .meteofrance_arpege_world025:
            return MeteoFranceDomain.arpege_world
        case .meteofrance_arpege_europe_probabilities:
            return MeteoFranceDomain.arpege_europe_probabilities
        case .meteofrance_arpege_world025_probabilities:
            return MeteoFranceDomain.arpege_world_probabilities
        case .meteofrance_wave:
            return MfWaveDomain.mfwave
        case .meteofrance_currents:
            return MfWaveDomain.mfcurrents
        case .cams_europe:
            return CamsDomain.cams_europe
        case .cams_global:
            return CamsDomain.cams_global
        case .cams_global_greenhouse_gases:
            return CamsDomain.cams_global_greenhouse_gases
        case .copernicus_cerra:
            return CdsDomain.cerra
        case .copernicus_dem90:
            return Dem90()
        case .ecmwf_ifs:
            return CdsDomain.ecmwf_ifs
        case .ecmwf_ifs_analysis_long_window:
            return CdsDomain.ecmwf_ifs_analysis_long_window
        case .ecmwf_ifs_analysis:
            return CdsDomain.ecmwf_ifs_analysis
        case .ecmwf_ifs_long_window:
            return CdsDomain.ecmwf_ifs_long_window
        case .copernicus_era5:
            return CdsDomain.era5
        case .copernicus_era5_land:
            return CdsDomain.era5_land
        case .copernicus_era5_ocean:
            return CdsDomain.era5_ocean
        case .copernicus_era5_ensemble:
            return CdsDomain.era5_ensemble
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
        case .ecmwf_ifs025:
            return EcmwfDomain.ifs025
        case .ecmwf_ifs025_ensemble:
            return EcmwfDomain.ifs025_ensemble
        case .ecmwf_aifs025:
            return EcmwfDomain.aifs025
        case .ecmwf_aifs025_single:
            return EcmwfDomain.aifs025_single
        case .ecmwf_aifs025_ensemble:
            return EcmwfDomain.aifs025_ensemble
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
        case .meteofrance_arome_france0025_15min:
            return MeteoFranceDomain.arome_france_15min
        case .meteofrance_arome_france_hd_15min:
            return MeteoFranceDomain.arome_france_hd_15min
        case .arpae_cosmo_2i, .arpae_cosmo_2i_ruc, .arpae_cosmo_5m:
            /// Deprecated since 2025-04-05
            return nil
        case .ncep_gfs_graphcast025:
            return GfsGraphCastDomain.graphcast025
        case .ecmwf_wam025:
            return EcmwfDomain.wam025
        case .ecmwf_wam025_ensemble:
            return EcmwfDomain.wam025_ensemble
        case .ncep_gfswave025:
            return GfsDomain.gfswave025
        case .ncep_gefswave025:
            return GfsDomain.gfswave025_ens
        case .knmi_harmonie_arome_europe:
            return KnmiDomain.harmonie_arome_europe
        case .knmi_harmonie_arome_netherlands:
            return KnmiDomain.harmonie_arome_netherlands
        case .dmi_harmonie_arome_europe:
            return DmiDomain.harmonie_arome_europe
        case .ukmo_global_deterministic_10km:
            return UkmoDomain.global_deterministic_10km
        case .ukmo_uk_deterministic_2km:
            return UkmoDomain.uk_deterministic_2km
        case .cams_europe_reanalysis_interim:
            return CamsDomain.cams_europe_reanalysis_interim
        case .cams_europe_reanalysis_validated:
            return CamsDomain.cams_europe_reanalysis_validated
        case .cams_europe_reanalysis_validated_pre2020:
            return CamsDomain.cams_europe_reanalysis_validated_pre2020
        case .cams_europe_reanalysis_validated_pre2018:
            return CamsDomain.cams_europe_reanalysis_validated_pre2018
        case .ncep_gfswave016:
            return GfsDomain.gfswave016
        case .ncep_nbm_conus:
            return NbmDomain.nbm_conus
        case .ncep_nbm_alaska:
            return NbmDomain.nbm_alaska
        case .ukmo_global_ensemble_20km:
            return UkmoDomain.global_ensemble_20km
        case .eumetsat_sarah3_30min:
            return EumetsatSarahDomain.sarah3_30min
        case .jma_jaxa_himawari_10min:
            return JaxaHimawariDomain.himawari_10min
        case .eumetsat_lsa_saf_msg_15min:
            return EumetsatLsaSafDomain.msg
        case .eumetsat_lsa_saf_iodc_15min:
            return EumetsatLsaSafDomain.iodc
        case .meteofrance_sea_surface_temperature:
            return MfWaveDomain.mfsst
        case .kma_gdps:
            return KmaDomain.gdps
        case .kma_ldps:
            return KmaDomain.ldps
        case .italia_meteo_arpae_icon_2i:
            return ItaliaMeteoArpaeDomain.icon_2i
        case .ukmo_uk_ensemble_2km:
            return UkmoDomain.uk_ensemble_2km
        case .meteoswiss_icon_ch1:
            return MeteoSwissDomain.icon_ch1
        case .meteoswiss_icon_ch2:
            return MeteoSwissDomain.icon_ch2
        case .meteoswiss_icon_ch1_ensemble:
            return MeteoSwissDomain.icon_ch1_ensemble
        case .meteoswiss_icon_ch2_ensemble:
            return MeteoSwissDomain.icon_ch2_ensemble
        }
    }
}
