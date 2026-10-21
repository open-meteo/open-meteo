import Foundation

/// A complete grid: point ordering, geometry, selection policy, and static fields.
/// Names retain existing static directory names; equal geometry alone does not imply equal grids.
enum SyncGridRegistry: String, CaseIterable, Sendable {
    case bom_access_global
    case bom_access_global_ensemble
    case cams_europe
    case cams_europe_reanalysis_interim
    case cams_europe_reanalysis_validated
    case cams_europe_reanalysis_validated_pre2018
    case cams_europe_reanalysis_validated_pre2020
    case cams_global
    case cams_global_greenhouse_gases
    case chmi_aladin_central_europe_2km
    case chmi_aladin_cz_1km
    case cma_grapes_global
    case cmc_gem_gdps
    case cmc_gem_gdps_15km
    case cmc_gem_geps
    case cmc_gem_hrdps
    case cmc_gem_hrdps_west
    case cmc_gem_rdps
    case cmc_gem_rdps_10km
    case cmip_CMCC_CM2_VHR4
    case cmip_EC_Earth3P_HR
    case cmip_FGOALS_f3_H
    case cmip_HiRAM_SIT_HR
    case cmip_MPI_ESM1_2_XR
    case cmip_MRI_AGCM3_2_S
    case cmip_NICAM16_8S
    case copernicus_cerra
    case copernicus_era5
    case copernicus_era5_ensemble
    case copernicus_era5_land
    case copernicus_era5_ocean
    case dmi_harmonie_arome_europe
    case dwd_ewam
    case dwd_gwam
    case dwd_icon
    case dwd_icon_d2
    case dwd_icon_d2_eps
    case dwd_icon_eps
    case dwd_icon_eu
    case dwd_icon_eu_eps
    case dwd_sis_europe_africa_v4
    case ecmwf_aifs_europe_ensemble
    case ecmwf_ifs
    case ecmwf_ifs025
    case ecmwf_ifs025_ensemble
    case ecmwf_ifs04
    case ecmwf_ifs04_ensemble
    case ecmwf_ifs_analysis
    case ecmwf_ifs_europe_ensemble
    case ecmwf_seas5
    case ecmwf_seas5_12hourly
    case ecmwf_wam
    case ecmwf_wam025_ensemble
    case eumetsat_lsa_saf_iodc_15min
    case eumetsat_lsa_saf_msg_15min
    case eumetsat_sarah3_30min
    case geosphere_arome_austria
    case glofas_v3
    case glofas_v4
    case italia_meteo_arpae_icon_2i
    case jma_gsm
    case jma_jaxa_himawari_10min
    case jma_jaxa_himawari_70e_10min
    case jma_jaxa_mtg_fci_10min
    case jma_msm
    case jma_msm_upper_level
    case kma_gdps
    case kma_ldps
    case knmi_harmonie_arome_europe
    case knmi_harmonie_arome_netherlands
    case meteofrance_arome_france0025
    case meteofrance_arome_france_hd
    case meteofrance_arpege_europe
    case meteofrance_arpege_world025
    case meteofrance_currents
    case meteofrance_sea_surface_temperature
    case meteofrance_wave
    case meteoswiss_icon_ch1
    case meteoswiss_icon_ch2
    case metno_nordic_pp
    case nasa_imerg_daily
    case ncep_gefs025
    case ncep_gefs05
    case ncep_gefswave025
    case ncep_gfs013
    case ncep_gfs025
    case ncep_gfswave016
    case ncep_hrrr_conus
    case ncep_nam_conus
    case ncep_nbm_alaska
    case ncep_nbm_conus
    case ukmo_global_deterministic_10km
    case ukmo_global_ensemble_20km
    case ukmo_uk_deterministic_2km
    case ukmo_uk_ensemble_2km

    /// Existing storage owner. Nil means this grid has no static fields (GloFAS).
    var staticDomain: DomainRegistry? {
        switch self {
        case .glofas_v3, .glofas_v4:
            return nil
        case .bom_access_global:
            return .bom_access_global
        case .bom_access_global_ensemble:
            return .bom_access_global_ensemble
        case .cams_europe:
            return .cams_europe
        case .cams_europe_reanalysis_interim:
            return .cams_europe_reanalysis_interim
        case .cams_europe_reanalysis_validated:
            return .cams_europe_reanalysis_validated
        case .cams_europe_reanalysis_validated_pre2018:
            return .cams_europe_reanalysis_validated_pre2018
        case .cams_europe_reanalysis_validated_pre2020:
            return .cams_europe_reanalysis_validated_pre2020
        case .cams_global:
            return .cams_global
        case .cams_global_greenhouse_gases:
            return .cams_global_greenhouse_gases
        case .chmi_aladin_central_europe_2km:
            return .chmi_aladin_central_europe_2km
        case .chmi_aladin_cz_1km:
            return .chmi_aladin_cz_1km
        case .cma_grapes_global:
            return .cma_grapes_global
        case .cmc_gem_gdps:
            return .cmc_gem_gdps
        case .cmc_gem_gdps_15km:
            return .cmc_gem_gdps_15km
        case .cmc_gem_geps:
            return .cmc_gem_geps
        case .cmc_gem_hrdps:
            return .cmc_gem_hrdps
        case .cmc_gem_hrdps_west:
            return .cmc_gem_hrdps_west
        case .cmc_gem_rdps:
            return .cmc_gem_rdps
        case .cmc_gem_rdps_10km:
            return .cmc_gem_rdps_10km
        case .cmip_CMCC_CM2_VHR4:
            return .cmip_CMCC_CM2_VHR4
        case .cmip_EC_Earth3P_HR:
            return .cmip_EC_Earth3P_HR
        case .cmip_FGOALS_f3_H:
            return .cmip_FGOALS_f3_H
        case .cmip_HiRAM_SIT_HR:
            return .cmip_HiRAM_SIT_HR
        case .cmip_MPI_ESM1_2_XR:
            return .cmip_MPI_ESM1_2_XR
        case .cmip_MRI_AGCM3_2_S:
            return .cmip_MRI_AGCM3_2_S
        case .cmip_NICAM16_8S:
            return .cmip_NICAM16_8S
        case .copernicus_cerra:
            return .copernicus_cerra
        case .copernicus_era5:
            return .copernicus_era5
        case .copernicus_era5_ensemble:
            return .copernicus_era5_ensemble
        case .copernicus_era5_land:
            return .copernicus_era5_land
        case .copernicus_era5_ocean:
            return .copernicus_era5_ocean
        case .dmi_harmonie_arome_europe:
            return .dmi_harmonie_arome_europe
        case .dwd_ewam:
            return .dwd_ewam
        case .dwd_gwam:
            return .dwd_gwam
        case .dwd_icon:
            return .dwd_icon
        case .dwd_icon_d2:
            return .dwd_icon_d2
        case .dwd_icon_d2_eps:
            return .dwd_icon_d2_eps
        case .dwd_icon_eps:
            return .dwd_icon_eps
        case .dwd_icon_eu:
            return .dwd_icon_eu
        case .dwd_icon_eu_eps:
            return .dwd_icon_eu_eps
        case .dwd_sis_europe_africa_v4:
            return .dwd_sis_europe_africa_v4
        case .ecmwf_aifs_europe_ensemble:
            return .ecmwf_aifs_europe_ensemble
        case .ecmwf_ifs:
            return .ecmwf_ifs
        case .ecmwf_ifs025:
            return .ecmwf_ifs025
        case .ecmwf_ifs025_ensemble:
            return .ecmwf_ifs025_ensemble
        case .ecmwf_ifs04:
            return .ecmwf_ifs04
        case .ecmwf_ifs04_ensemble:
            return .ecmwf_ifs04_ensemble
        case .ecmwf_ifs_analysis:
            return .ecmwf_ifs_analysis
        case .ecmwf_ifs_europe_ensemble:
            return .ecmwf_ifs_europe_ensemble
        case .ecmwf_seas5:
            return .ecmwf_seas5
        case .ecmwf_seas5_12hourly:
            return .ecmwf_seas5_12hourly
        case .ecmwf_wam:
            return .ecmwf_wam
        case .ecmwf_wam025_ensemble:
            return .ecmwf_wam025_ensemble
        case .eumetsat_lsa_saf_iodc_15min:
            return .eumetsat_lsa_saf_iodc_15min
        case .eumetsat_lsa_saf_msg_15min:
            return .eumetsat_lsa_saf_msg_15min
        case .eumetsat_sarah3_30min:
            return .eumetsat_sarah3_30min
        case .geosphere_arome_austria:
            return .geosphere_arome_austria
        case .italia_meteo_arpae_icon_2i:
            return .italia_meteo_arpae_icon_2i
        case .jma_gsm:
            return .jma_gsm
        case .jma_jaxa_himawari_10min:
            return .jma_jaxa_himawari_10min
        case .jma_jaxa_himawari_70e_10min:
            return .jma_jaxa_himawari_70e_10min
        case .jma_jaxa_mtg_fci_10min:
            return .jma_jaxa_mtg_fci_10min
        case .jma_msm:
            return .jma_msm
        case .jma_msm_upper_level:
            return .jma_msm_upper_level
        case .kma_gdps:
            return .kma_gdps
        case .kma_ldps:
            return .kma_ldps
        case .knmi_harmonie_arome_europe:
            return .knmi_harmonie_arome_europe
        case .knmi_harmonie_arome_netherlands:
            return .knmi_harmonie_arome_netherlands
        case .meteofrance_arome_france0025:
            return .meteofrance_arome_france0025
        case .meteofrance_arome_france_hd:
            return .meteofrance_arome_france_hd
        case .meteofrance_arpege_europe:
            return .meteofrance_arpege_europe
        case .meteofrance_arpege_world025:
            return .meteofrance_arpege_world025
        case .meteofrance_currents:
            return .meteofrance_currents
        case .meteofrance_sea_surface_temperature:
            return .meteofrance_sea_surface_temperature
        case .meteofrance_wave:
            return .meteofrance_wave
        case .meteoswiss_icon_ch1:
            return .meteoswiss_icon_ch1
        case .meteoswiss_icon_ch2:
            return .meteoswiss_icon_ch2
        case .metno_nordic_pp:
            return .metno_nordic_pp
        case .nasa_imerg_daily:
            return .nasa_imerg_daily
        case .ncep_gefs025:
            return .ncep_gefs025
        case .ncep_gefs05:
            return .ncep_gefs05
        case .ncep_gefswave025:
            return .ncep_gefswave025
        case .ncep_gfs013:
            return .ncep_gfs013
        case .ncep_gfs025:
            return .ncep_gfs025
        case .ncep_gfswave016:
            return .ncep_gfswave016
        case .ncep_hrrr_conus:
            return .ncep_hrrr_conus
        case .ncep_nam_conus:
            return .ncep_nam_conus
        case .ncep_nbm_alaska:
            return .ncep_nbm_alaska
        case .ncep_nbm_conus:
            return .ncep_nbm_conus
        case .ukmo_global_deterministic_10km:
            return .ukmo_global_deterministic_10km
        case .ukmo_global_ensemble_20km:
            return .ukmo_global_ensemble_20km
        case .ukmo_uk_deterministic_2km:
            return .ukmo_uk_deterministic_2km
        case .ukmo_uk_ensemble_2km:
            return .ukmo_uk_ensemble_2km
        }
    }

    /// Geometry that can be constructed without loading external files.
    var grid: any Gridable {
        switch self {
        case .bom_access_global:
            return RegularGrid(nx: 2048, ny: 1536, latMin: -89.941406, lonMin: -179.912109, dx: 360 / 2048, dy: 180 / 1536)
        case .bom_access_global_ensemble:
            return RegularGrid(nx: 800, ny: 600, latMin: -89.85, lonMin: -179.775, dx: 360 / 800, dy: 180 / 600)
        case .cma_grapes_global:
            return RegularGrid(nx: 2880, ny: 1440, latMin: -89.9375, lonMin: -180, dx: 0.125, dy: 0.125)
        case .cams_global:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .cams_global_greenhouse_gases, .copernicus_era5_land:
            return RegularGrid(nx: 3600, ny: 1801, latMin: -90, lonMin: -180, dx: 0.1, dy: 0.1)
        case .cams_europe:
            // IMPORTANT: GRID is flipped! Therefore dy negative!
            return RegularGrid(nx: 700, ny: 420, latMin: /*30.05*/ 71.95, lonMin: -24.95, dx: 0.1, dy: -0.1)
        case .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated:
            return RegularGrid(nx: 700, ny: 420, latMin: 30.05 /*71.95*/, lonMin: -24.95, dx: 0.1, dy: 0.1)
        case .cams_europe_reanalysis_validated_pre2020:
            return RegularGrid(nx: 701, ny: 421, latMin: 30, lonMin: -25, dx: 0.1, dy: 0.1)
        case .cams_europe_reanalysis_validated_pre2018:
            return RegularGrid(nx: 701, ny: 401, latMin: 30, lonMin: -25, dx: 0.1, dy: 0.1)
        case .cmip_CMCC_CM2_VHR4:
            return RegularGrid(nx: 1152, ny: 768, latMin: -90, lonMin: -180, dx: 0.3125, dy: 180 / 768)
        case .cmip_FGOALS_f3_H:
            // fallthrough
        // case .FGOALS_f3_H_highresSST:
            return RegularGrid(nx: 1440, ny: 720, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .cmip_HiRAM_SIT_HR:
            return RegularGrid(nx: 1536, ny: 768, latMin: -90, lonMin: -180, dx: 360 / 1536, dy: 180 / 768)
        case .cmip_MRI_AGCM3_2_S:
            return RegularGrid(nx: 1920, ny: 960, latMin: -90, lonMin: -180, dx: 0.1875, dy: 0.1875)
        case .cmip_EC_Earth3P_HR:
            return RegularGrid(nx: 1024, ny: 512, latMin: -90, lonMin: -180, dx: 360 / 1024, dy: 180 / 512)
        // case .HadGEM3_GC31_HM:
        //    return RegularGrid(nx: 1024, ny: 768, latMin: -90, lonMin: -180, dx: 360/1024, dy: 180/768)
        case .cmip_MPI_ESM1_2_XR:
            return RegularGrid(nx: 768, ny: 384, latMin: -90, lonMin: -180, dx: 360 / 768, dy: 180 / 384)
        case .cmip_NICAM16_8S:
            return RegularGrid(nx: 1280, ny: 640, latMin: -90, lonMin: -180, dx: 360 / 1280, dy: 180 / 640)
        case .dmi_harmonie_arome_europe:
            /*
             (key: "Nx", value: "1906")
             (key: "Ny", value: "1606")
             (key: "Latin1InDegrees", value: "55.5")
             (key: "Latin2InDegrees", value: "55.5")
             (key: "LaDInDegrees", value: "55.5")
             (key: "LoVInDegrees", value: "352")
             (key: "latitudeOfSouthernPoleInDegrees", value: "-90")
             (key: "longitudeOfSouthernPoleInDegrees", value: "0")
             (key: "gridType", value: "lambert")
             Coords(i: 0, x: 0, y: 0, latitude: 39.671, longitude: -25.421997)
             Coords(i: 3061035, x: 1905, y: 1605, latitude: 62.667614, longitude: 40.069885)
             +proj=lcc +lon_0=352.000000 +lat_0=55.500000 +lat_1=55.500000 +lat_2=55.500000 +R=6371229.000000
             */
            return ProjectionGrid(
                nx: 1906,
                ny: 1606,
                latitude: 39.671,
                longitude: -25.421997,
                dx: 2000,
                dy: 2000,
                projection: LambertConformalConicProjection(λ0: 352, ϕ0: 55.5, ϕ1: 55.5, ϕ2: 55.5, radius: 6371229)
            )
        case .ecmwf_ifs04, .ecmwf_ifs04_ensemble:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 360 / 900, dy: 180 / 450)
        case .ecmwf_ifs025, .ecmwf_ifs025_ensemble, .ecmwf_wam025_ensemble:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 360 / 1440, dy: 180 / (721 - 1))
        case .copernicus_era5, .ncep_gfs025, .ncep_gefs025, .ncep_gefswave025, .meteofrance_arpege_world025:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .copernicus_era5_ocean, .copernicus_era5_ensemble, .cmc_gem_geps, .ncep_gefs05, .jma_gsm:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .copernicus_cerra:
            return ProjectionGrid(nx: 1069, ny: 1069, latitude: 20.29228...63.769516, longitude: -17.485962...74.10509, projection: LambertConformalConicProjection(λ0: 8, ϕ0: 50, ϕ1: 50, ϕ2: 50, radius: 6371229))
        case .ecmwf_ifs, .ecmwf_ifs_analysis, .ecmwf_wam:
            return GaussianGrid(type: .o1280)
        case .cmc_gem_gdps, .cmc_gem_gdps_15km:
            return RegularGrid(nx: 2400, ny: 1201, latMin: -90, lonMin: -180, dx: 0.15, dy: 0.15)
        case .cmc_gem_rdps:
            return ProjectionGrid(nx: 935, ny: 824, latitude: 18.14503...45.405453, longitude: 217.10745...349.8256, projection: StereographicProjection(latitude: 90, longitude: 249, radius: 6371229))
        case .cmc_gem_rdps_10km:
            /**
             Note: lat/lon coordinates are in projection space!
             latitudeOfFirstGridPointInDegrees = -48.806;
             longitudeOfFirstGridPointInDegrees = 306.141;
             latitudeOfLastGridPointInDegrees = 45.4649;
             longitudeOfLastGridPointInDegrees = 48.9906;
             iDirectionIncrementInDegrees = 0.090298;
             jDirectionIncrementInDegrees = 0.090298;
             latitudeOfSouthernPoleInDegrees = -31.7583;
             longitudeOfSouthernPoleInDegrees = 267.597;
             */
            return ProjectionGrid(
                nx: 1140,
                ny: 1045,
                latitudeProjectionOrigin: -48.806,
                longitudeProjectionOrigin: 306.141 - 360,
                dx: 0.090298,
                dy: 0.090298,
                projection: RotatedLatLonProjection(latitude: -31.7583 * -1, longitude: 267.597 + 180 - 360)
            )
        case .cmc_gem_hrdps:
            return ProjectionGrid(nx: 2540, ny: 1290, latitude: 39.626034...47.876457, longitude: -133.62952...(-40.708557), projection: RotatedLatLonProjection(latitude: -36.0885, longitude: 245.305))
        case .cmc_gem_hrdps_west:
            // 1km resolution BC domain: 1330x1180 grid
            // GDAL reports southern pole: lat=-33.443381, lon=-93.536426
            // Convert to north pole: negate lat, add 180 to lon
            // GDAL origin is top-left with dy=-0.00899, so we flip to bottom-left
            return ProjectionGrid(
                nx: 1330,
                ny: 1180,
                latitudeProjectionOrigin: 5.308595 + (1180 * -0.00899),  // Bottom-left
                longitudeProjectionOrigin: -22.18489,
                dx: 0.00899,
                dy: 0.00899,
                projection: RotatedLatLonProjection(latitude: 33.443381, longitude: 86.463574)
            )
        case .ncep_gfs013:
            // Coordinates confirmed with eccodes coordinate output
            return RegularGrid(nx: 3072, ny: 1536, latMin: -0.11714935 * (1536 - 1) / 2, lonMin: -180, dx: 360 / 3072, dy: 0.11714935)
        case .ncep_hrrr_conus, .ncep_nam_conus:
            /// labert conformal grid https://www.emc.ncep.noaa.gov/mmb/namgrids/hrrrspecs.html
            /*
             (key: "Nx", value: "1799")
             (key: "Ny", value: "1059")
             (key: "latitudeOfFirstGridPointInDegrees", value: "21.1381")
             (key: "longitudeOfFirstGridPointInDegrees", value: "237.28")
             (key: "LaDInDegrees", value: "38.5")
             (key: "LoVInDegrees", value: "262.5") 262.5-360=-97.5
             (key: "Latin1InDegrees", value: "38.5")
             (key: "Latin2InDegrees", value: "38.5")
             */
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5, ϕ2: 38.5, radius: 6371229)
            return ProjectionGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        case .ncep_gfswave016:
            /// 0.166° resolution
            return RegularGrid(nx: 2160, ny: 406, latMin: -15, lonMin: -180, dx: 360 / 2160, dy: (52.5 + 15) / (406 - 1))
        case .glofas_v4:
            return RegularGrid(nx: 7200, ny: 3000, latMin: -59.975, lonMin: -180.025, dx: 0.05, dy: 0.05)
        case .glofas_v3:
            return RegularGrid(nx: 3600, ny: 1500, latMin: -60, lonMin: -180, dx: 0.1, dy: 0.1)
        case .dwd_icon:
            return RegularGrid(nx: 2879, ny: 1441, latMin: -90, lonMin: -180, dx: 0.125, dy: 0.125)
        case .dwd_icon_eu:
            return RegularGrid(nx: 1377, ny: 657, latMin: 29.5, lonMin: -23.5, dx: 0.0625, dy: 0.0625)
        case .dwd_icon_d2:
            return RegularGrid(nx: 1215, ny: 746, latMin: 43.18, lonMin: -3.94, dx: 0.02, dy: 0.02)
        case .dwd_icon_eps:
            // R03B06 avg 26.5 km
            return RegularGrid(nx: 1439, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .dwd_icon_eu_eps:
            // R03B07 avg 13.2 km
            return RegularGrid(nx: 689, ny: 329, latMin: 29.5, lonMin: -23.5, dx: 0.125, dy: 0.125)
        case .dwd_icon_d2_eps:
            // R19B07 avg 2 km
            // Retain the existing extent, one point smaller per axis than deterministic D2.
            return RegularGrid(nx: 1214, ny: 745, latMin: 43.18, lonMin: -3.94, dx: 0.02, dy: 0.02)
        case .dwd_gwam:
            return RegularGrid(nx: 1440, ny: 699, latMin: -85.25, lonMin: -180, dx: 0.25, dy: 0.25)
        case .dwd_ewam:
            return RegularGrid(nx: 526, ny: 721, latMin: 30, lonMin: -10.5, dx: 0.1, dy: 0.05)
        case .jma_msm:
            return RegularGrid(nx: 481, ny: 505, latMin: 22.4, lonMin: 120, dx: 0.0625, dy: 0.05)
        case .jma_msm_upper_level:
            return RegularGrid(nx: 241, ny: 253, latMin: 22.4, lonMin: 120, dx: 0.125, dy: 0.1)
        case .knmi_harmonie_arome_europe:
            return ProjectionGrid(
                nx: 676,
                ny: 564,
                latitude: 39.740627...62.619324,
                longitude: -25.162262...38.75702,
                projection: RotatedLatLonProjection(latitude: -35, longitude: -8)
            )
        case .knmi_harmonie_arome_netherlands:
            return RegularGrid(nx: 390, ny: 390, latMin: 49, lonMin: 0, dx: 0.029, dy: 0.018)
        case .metno_nordic_pp:
            return ProjectionGrid(nx: 1796, ny: 2321, latitude: 52.30272...72.18527, longitude: 1.9184653...41.764282, projection: LambertConformalConicProjection(λ0: 15, ϕ0: 63, ϕ1: 63, ϕ2: 63, radius: 6371229))
        case .meteofrance_arpege_europe:
            return RegularGrid(nx: 741, ny: 521, latMin: 20, lonMin: -32, dx: 0.1, dy: 0.1)
        case .meteofrance_arome_france0025:
            return RegularGrid(nx: 1121, ny: 717, latMin: 37.5, lonMin: -12.0, dx: 0.025, dy: 0.025)
        case .meteofrance_arome_france_hd:
            return RegularGrid(nx: 2801, ny: 1791, latMin: 37.5, lonMin: -12.0, dx: 0.01, dy: 0.01)
        case .meteofrance_wave, .meteofrance_currents, .meteofrance_sea_surface_temperature:
            /// Note: sea land mask is slighly differnet for each model
            // Important: GRID needs to be aligned to center points by dx/2 and dy/2
            return RegularGrid(nx: 4320, ny: 2041, latMin: -80 + 1 / 24, lonMin: -180 + 1 / 24, dx: 1 / 12, dy: 1 / 12, searchRadius: 2)
        case .ncep_nbm_conus:
            /** grib dump
             Nx = 2345;
             Ny = 1597;
             latitudeOfFirstGridPointInDegrees = 19.229;
             longitudeOfFirstGridPointInDegrees = 233.723;
             LaDInDegrees = 25;
             LoVInDegrees = 265;    -360 => -95
             DxInMetres = 2539.7;
             DyInMetres = 2539.7;
             Latin1InDegrees = 25;
             Latin2 = 25000000;
             Latin2InDegrees = 25;
             */
            let proj = LambertConformalConicProjection(λ0: 265 - 360, ϕ0: 0, ϕ1: 25, ϕ2: 25, radius: 6371200)
            return ProjectionGrid(nx: 2345, ny: 1597, latitude: 19.229, longitude: 233.723 - 360, dx: 2539.7, dy: 2539.7, projection: proj)
        case .ncep_nbm_alaska:
            /**
             Nx = 1649;
             Ny = 1105;
             latitudeOfFirstGridPointInDegrees = 40.53;
             longitudeOfFirstGridPointInDegrees = 181.429;
             LaDInDegrees = 60;
             orientationOfTheGridInDegrees = 210;
             DxInMetres = 2976.56;
             DyInMetres = 2976.56;
             iScansNegatively = 0;
             jScansPositively = 1;
             jPointsAreConsecutive = 0;
             alternativeRowScanning = 1;
             gridType = polar_stereographic;
             */
            let proj = StereographicProjection(latitude: 90, longitude: 210, radius: 6371200)
            // Note dx/dy would need to be scaled, because they are defined as 60° latitude
            // ProjectionGrid(nx: 1649, ny: 1105, latitude: 40.53, longitude: 181.429-360, dx: 2976.56, dy: 2976.56, projection: proj)
            return ProjectionGrid(nx: 1649, ny: 1105, latitude: 40.53...63.97579, longitude: (181.429 - 360)...(-93.689514), projection: proj)
        case .nasa_imerg_daily:
            return RegularGrid(nx: 3600, ny: 1800, latMin: -89.95, lonMin: -179.95, dx: 0.1, dy: 0.1)
        case .ukmo_global_deterministic_10km:
            return RegularGrid(
                nx: 2560,
                ny: 1920,
                latMin: -90,
                lonMin: -180,
                dx: 360 / 2560,
                dy: 180 / 1920
            )
        case .ukmo_uk_deterministic_2km, .ukmo_uk_ensemble_2km:
            let projection = LambertAzimuthalEqualAreaProjection(λ0: -2.5, ϕ1: 54.9, radius: 6371229)
            return ProjectionGrid(
                nx: 1042,
                ny: 970,
                latitudeProjectionOrigin: -1036000,
                longitudeProjectionOrigin: -1158000,
                dx: 2000,
                dy: 2000,
                projection: projection
            )
        case .ukmo_global_ensemble_20km:
            return RegularGrid(
                nx: 1280,
                ny: 960,
                latMin: -90,
                lonMin: -180,
                dx: 360 / 1280,
                dy: 180 / 960
            )
        case .eumetsat_lsa_saf_msg_15min:
            return RegularGrid(nx: 3201, ny: 3201, latMin: -80, lonMin: -80, dx: 0.05, dy: 0.05)
        case .eumetsat_lsa_saf_iodc_15min:
            return RegularGrid(nx: 3201, ny: 3201, latMin: -80, lonMin: -40, dx: 0.05, dy: 0.05)
        case .eumetsat_sarah3_30min:
            return RegularGrid(nx: 2600, ny: 2600, latMin: -65, lonMin: -65, dx: 0.05, dy: 0.05)
        case .jma_jaxa_himawari_10min:
            return RegularGrid(nx: 2401, ny: 2401, latMin: -60, lonMin: 80, dx: 0.05, dy: 0.05)
        case .jma_jaxa_himawari_70e_10min:
            return RegularGrid(nx: 2801, ny: 2401, latMin: -60, lonMin: 70, dx: 0.05, dy: 0.05)
        case .jma_jaxa_mtg_fci_10min:
            return RegularGrid(nx: 2801, ny: 2401, latMin: -60, lonMin: -70, dx: 0.05, dy: 0.05)
        case .kma_gdps:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90 + 180 / 1920 / 2, lonMin: -180 + 360 / 2560 / 2, dx: 360 / 2560, dy: 180 / 1920)
        case .kma_ldps:
            /**
             # Lambert Conformal (can be secant or tangent, conical or bipolar)  (grib2/tables/4/3.1.table)
               gridDefinitionTemplateNumber = 30;
               # Earth assumed spherical with radius of 6,371,229.0 m (grib2/tables/4/3.2.table)
               shapeOfTheEarth = 6;
               Nx = 602;
               Ny = 781;
               latitudeOfFirstGridPointInDegrees = 32.2569;
               longitudeOfFirstGridPointInDegrees = 121.834;
               LaDInDegrees = 38;
               LoVInDegrees = 126;
               DxInMetres = 1500;
               DyInMetres = 1500;
               # (1=0)  North Pole is on the projection plane;(2=0)  Only one projection centre is used:grib2/tables/4/3.5.table
               # flags: 00000000
               projectionCentreFlag = 0;
               iScansNegatively = 0;
               jScansPositively = 1;
               jPointsAreConsecutive = 0;
               alternativeRowScanning = 0;
               Latin1InDegrees = 30;
               Latin2 = 60000000;
               Latin2InDegrees = 60;
               latitudeOfSouthernPoleInDegrees = 0;
               longitudeOfSouthernPoleInDegrees = 0;
               gridType = lambert;
               NV = 0;
             */
            return ProjectionGrid(
                nx: 602,
                ny: 781,
                latitude: 32.2569,
                longitude: 121.834,
                dx: 1500,
                dy: 1500,
                projection: LambertConformalConicProjection(λ0: 126, ϕ0: 38, ϕ1: 30, ϕ2: 60, radius: 6371229)
            )
        case .italia_meteo_arpae_icon_2i:
            return RegularGrid(nx: 761, ny: 761, latMin: 33.7, lonMin: 3, dx: 0.025, dy: 0.02)
        case .meteoswiss_icon_ch1:
            let projection = RotatedLatLonProjection(latitude: 43.0, longitude: 190.0)
            // Domain area selected by OpenMeteo to exclude
            // ICON CH2: 2 pixel at the boarder contain invalid data. Additional 18 pixel are removed because the model is not stable at the border
            let dx: Float = 0.01, dy: Float = 0.01
            return ProjectionGrid(
                nx: 1089,
                ny: 705,
                latitudeProjectionOrigin: -4.06,
                longitudeProjectionOrigin: -6.46,
                dx: dx,
                dy: dy,
                projection: projection
            )
        case .meteoswiss_icon_ch2:
            let projection = RotatedLatLonProjection(latitude: 43.0, longitude: 190.0)
            // Domain area selected by OpenMeteo to exclude
            // ICON CH2: 2 pixel at the boarder contain invalid data. Additional 18 pixel are removed because the model is not stable at the border
            let dx: Float = 0.02, dy: Float = 0.02
            return ProjectionGrid(
                nx: 545,
                ny: 353,
                latitudeProjectionOrigin: -4.06,
                longitudeProjectionOrigin: -6.46,
                dx: dx,
                dy: dy,
                projection: projection
            )
        case .ecmwf_ifs_europe_ensemble:
            return GaussianGridArea(type: .o1280, bounds: BoundingBoxWGS84(latitude: 33.005..<70.967, longitude: -11..<37))
        case .ecmwf_aifs_europe_ensemble:
            return GaussianGridArea(type: .n320, bounds: BoundingBoxWGS84(latitude: 33.0211..<70.9601, longitude: -11..<37))
        case .ecmwf_seas5:
            return GaussianGrid(type: .o320)
        case .ecmwf_seas5_12hourly:
            return GaussianGrid(type: .n160)
        case .dwd_sis_europe_africa_v4:
            // latitude = -38 ... 65
            // longitude = -20 ... 60
            return RegularGrid(nx: 3201, ny: 4121, latMin: -38, lonMin: -20, dx: 0.025, dy: 0.025)
        case .geosphere_arome_austria:
            // lon=594, lat=492, south-to-north
            return RegularGrid(nx: 594, ny: 492, latMin: 42.981, lonMin: 5.498, dx: 0.028, dy: 0.018)
        case .chmi_aladin_cz_1km:
            // regular_ll, Ni=501, Nj=290, south-to-north, west-to-east.
            // Corner coordinates from the GRIB header; dx/dy are derived to land the last
            // grid point on (51.098, 18.995).
            return RegularGrid(nx: 501, ny: 290, latitude: 48.5...51.098, longitude: 12.0...18.995)
        case .chmi_aladin_central_europe_2km:
            // Lambert Conformal Conic, Ni=1053, Nj=837, Dx=Dy=2325m.
            // First grid point: 38.599N, 1.334E. LaD=46.244°, LoV=17°. Earth radius=6371229m.
            return ProjectionGrid(
                nx: 1053,
                ny: 837,
                latitude: 38.599,
                longitude: 1.334,
                dx: 2325,
                dy: 2325,
                projection: LambertConformalConicProjection(λ0: 17, ϕ0: 46.244, ϕ1: 46.244, ϕ2: 46.244, radius: 6371229)
            )
        }
    }
}
