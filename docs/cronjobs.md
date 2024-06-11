#  Cronjobs

This document lists all required cronjobs to download data. However, downloading all data generates 4-8 TB traffic daily! It is highly recommended to use the open-data distribution of the Open-Meteo database and select only the required weather variables.

## Weather forecast models

```bash
# DWD
41 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group surface > ~/log/icon.log 2>&1 || cat ~/log/icon.log
41 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group surface > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group surface > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
#41 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group pressureLevelGt500 > ~/log/icon_upper-levelgt500.log 2>&1 || cat ~/log/icon_upper-levelgt500.log
#41 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group pressureLevelLtE500 > ~/log/icon_upper-levellte500.log 2>&1 || cat ~/log/icon_upper-levellte500.log
#41 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group pressureLevel > ~/log/icon-eu_upper-level.log 2>&1 || cat ~/log/icon-eu_upper-level.log
#44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group pressureLevel > ~/log/icon-d2_upper-level.log 2>&1 || cat ~/log/icon-d2_upper-level.log
#41 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group modelLevel > ~/log/icon_model-level.log 2>&1 || cat ~/log/icon_model-level.log
#41 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group modelLevel > ~/log/icon-eu_model-level.log 2>&1 || cat ~/log/icon-eu_model-level.log
#44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group modelLevel > ~/log/icon-d2_model-level.log 2>&1 || cat ~/log/icon-d2_model-level.log

# GFS
40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 > ~/log/gfs025.log 2>&1 || cat ~/log/gfs025.log
40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs013 > ~/log/gfs013.log 2>&1 || cat ~/log/gfs013.log
40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025_ensemble > ~/log/gfs025_ensemble.log 2>&1 || cat ~/log/gfs025_ensemble.log

# HRRR
55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus > ~/log/hrrr_conus.log 2>&1 || cat ~/log/hrrr_conus.log
55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus_15min > ~/log/hrrr_conus_15min.log 2>&1 || cat ~/log/hrrr_conus_15min.log
#40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 --upper-level > ~/log/gfs025_upper-level.log 2>&1 || cat ~/log/gfs025_upper-level.log
#55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus --upper-level > ~/log/hrrr_conus_upper-level.log 2>&1 || cat ~/log/hrrr_conus_upper-level.log

# GEM
7 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gem gem_hrdps_continental > ~/log/gem_hrdps_continental.log 2>&1 || cat ~/log/gem_hrdps_continental.log
47 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-gem gem_regional > ~/log/gem_regional.log 2>&1 || cat ~/log/gem_regional.log
39 3,15 * * * /usr/local/bin/openmeteo-api download-gem gem_global > ~/log/gem_global.log 2>&1 || cat ~/log/gem_global.log

# GFS GraphCast
0 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs-graphcast graphcast025 --concurrent 4 > ~/log/graphcast025.log  2>&1 || cat ~/log/graphcast025.log

# ECMWF
45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain ifs025 > ~/log/ecmwf025.log 2>&1 || cat ~/log/ecmwf025.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain ifs025 > ~/log/ecmwf025.log 2>&1 || cat ~/log/ecmwf025.log
45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain aifs025 > ~/log/ecmwfa025.log 2>&1 || cat ~/log/ecmwfa025.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain aifs025 > ~/log/ecmwfa025.log 2>&1 || cat ~/log/ecmwfa025.log

# metno
27 * * * * /usr/local/bin/openmeteo-api download-metno nordic_pp > ~/log/nordic_pp.log 2>&1 || cat ~/log/nordic_pp.log

# Arpae Cosmo Italy
40 4,16 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_2i --concurrent 4 > ~/log/cosmo_2i.log 2>&1 || cat ~/log/cosmo_2i.log
45 3,15 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_5m --concurrent 4 > ~/log/cosmo_5m.log 2>&1 || cat ~/log/cosmo_5m.log
00 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_2i_ruc --concurrent 4 > ~/log/cosmo_2i_ruc.log 2>&1 || cat ~/log/cosmo_2i_ruc.log

# MeteoFrance
15 3,9,15,21 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arpege_world > ~/log/arpege_world.log 2>&1 || cat ~/log/arpege_world.log"
15 2,5,8,11,14,17,20,23 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arome_france > ~/log/arome_france.log 2>&1 || cat ~/log/arome_france.log"
15 3,9,15,21 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arpege_europe > ~/log/arpege_europe.log 2>&1 || cat ~/log/arpege_europe.log"
15 2,5,8,11,14,17,20,23 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arome_france_hd > ~/log/arome_france_hd.log 2>&1 || cat ~/log/arome_france_hd.log"
#15 3,9,15,21 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arpege_world --upper-level > ~/log/arpege_world_upper-level.log 2>&1 || cat ~/log/arpege_world_upper-level.log"
#15 2,5,8,11,14,17,20,23 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arome_france --upper-level > ~/log/arome_france_upper-level.log 2>&1 || cat ~/log/arome_france_upper-level.log"
#15 3,9,15,21 * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arpege_europe --upper-level > ~/log/arpege_europe_upper-level.log 2>&1 || cat ~/log/arpege_europe_upper-level.log"
17 * * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arome_france_15min > ~/log/arome_france_15min.log 2>&1 || cat ~/log/arome_france_15min.log"
17 * * * * bash -c "source ~/mfkey.env; /usr/local/bin/openmeteo-api download-meteofrance arome_france_hd_15min > ~/log/arome_france_hd_15min.log 2>&1 || cat ~/log/arome_france_hd_15min.log"

# JMA
#30 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-jma gsm --server "xxxxxxxx" > ~/log/jma_gsm.log 2>&1 || cat ~/log/jma_gsm.log
#18 2,5,8,11,14,17,20,23 * * * /usr/local/bin/openmeteo-api download-jma msm --server "xxxxxx"  > ~/log/jma_msm.log 2>&1 || cat ~/log/jma_msm.log

# CMA
#20 4,10,16,22 * * * /usr/local/bin/openmeteo-api download-cma grapes_global --server xxxxxxx --concurrent 8 > ~/log/grapes_global.log 2>&1 || cat ~/log/grapes_global.log

# BOM
#50 8,20 * * * /usr/local/bin/openmeteo-api download-bom access_global --server xxxxxxx --concurrent 4> ~/log/bom_access_global.log 2>&1 || cat ~/log/bom_access_global.log
#10 1,13 * * * /usr/local/bin/openmeteo-api download-bom access_global --server xxxxxxx --concurrent 4 > ~/log/bom_access_global_6z.log 2>&1 || cat ~/log/bom_access_global_6z.log
#30 9,21 * * * /usr/local/bin/openmeteo-api download-bom access_global --server xxxxxxx --concurrent 4 --upper-level > ~/log/bom_access_global_upper.log 2>&1 || cat ~/log/bom_access_global_upper.log
#15 14,2 * * * /usr/local/bin/openmeteo-api download-bom access_global --server xxxxxxx --concurrent 4 --upper-level > ~/log/bom_access_global_upper_6z.log 2>&1 || cat ~/log/bom_access_global_upper_6z.log
```

Notes:
- All upper level variables are commented out
- MeteoFrance requires an API key which needs to be placed in `~mfkey.eny`. Format. `export METEOFRANCE_API_KEY="eyJ4NXQi...`
- JMA, BOM and CMA require a server URL with username and password combination, which is not publicly disclosed

## Ensemble models

```bash
# DWD
37 2,14  * * * /usr/local/bin/openmeteo-api download icon-eps > ~/log/icon-eps.log 2>&1 || cat ~/log/icon-eps.log
37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon-eu-eps > ~/log/icon-eu-eps.log 2>&1 || cat ~/log/icon-eu-eps.log
30 1,4,7,10,13,16,19,22  * * * /usr/local/bin/openmeteo-api download icon-d2-eps > ~/log/icon-d2-eps.log 2>&1 || cat ~/log/icon-d2-eps.log
30 1,4,7,10,13,16,19,22  * * * /usr/local/bin/openmeteo-api download icon-d2-eps --only-variables temperature_850hPa,temperature_500hPa,geopotential_height_850hPa,geopotential_height_500hPa > ~/log/icon-d2-eps_upper.log 2>&1 || cat ~/log/icon-d2-eps_upper.log

# ECMWF
45 7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs04_ensemble > ~/log/ifs04_ensemble.log 2>&1 || cat ~/log/ifs04_ensemble.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs04_ensemble > ~/log/ifs04_ensemble.log 2>&1 || cat ~/log/ifs04_ensemble.log
45 7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs025_ensemble --concurrent 4 > ~/log/ifs025_ensemble.log 2>&1 || cat ~/log/ifs025_ensemble.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs025_ensemble --concurrent 4 > ~/log/ifs025_ensemble.log 2>&1 || cat ~/log/ifs025_ensemble.log

# GEM
45 4,16 * * * /usr/local/bin/openmeteo-api download-gem gem_global_ensemble > ~/log/gem_global_ensemble.log 2>&1 || cat ~/log/gem_global_ensemble.log
45 4,16 * * * /usr/local/bin/openmeteo-api download-gem gem_global_ensemble --only-variables temperature_850hPa,temperature_500hPa,geopotential_height_850hPa,geopotential_height_500hPa > ~/log/gem_global_ensemble_upper.log 2>&1 || cat ~/log/gem_global_ensemble_upper.log

# GFS
40 3,15 * * * /usr/local/bin/openmeteo-api download-gfs gfs025_ens > ~/log/gfs025_ens.log 2>&1 || cat ~/log/gfs025_ens.log
40 3,15 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens > ~/log/gfs05_ens.log 2>&1 || cat ~/log/gfs05_ens.log
40 9,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025_ens > ~/log/gfs025_ens2.log 2>&1 || cat ~/log/gfs025_ens2.log
40 9,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens > ~/log/gfs05_ens2.log 2>&1 || cat ~/log/gfs05_ens2.log
40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --only-variables temperature_850hPa,temperature_500hPa,geopotential_height_850hPa,geopotential_height_500hPa > ~/log/gfs05_ens_upper.log 2>&1 || cat ~/log/gfs05_ens_upper.log
55 23 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --second-flush --run 0 > ~/log/gfs05_ens-second-flush.log 2>&1 || cat ~/log/gfs05_ens-second-flush.log
55 23 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --second-flush --run 0 --only-variables temperature_850hPa,temperature_500hPa,geopotential_height_850hPa,geopotential_height_500hPa > ~/log/gfs05_ens-second-flush_upper.log 2>&1 || cat ~/log/gfs05_ens-second-flush_upper.log

# BOM
15 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-bom access_global_ensemble --server xxxxxx --concurrent 4 > ~/log/bom_access_global_ensemble.log 2>&1 || cat ~/log/bom_access_global_ensemble.log
```

## Historical Weather API

Notes:
- ERA5 requires an CDS API key
- ECMWF IFS requires an ECMWF API account. This is not publicly available and involves licenses cost.

```bash
30 0 * * * /usr/local/bin/openmeteo-api download-era5 era5 --cdskey 10xxxx:8exxxxxxx > ~/log/era5.log 2>&1 || cat ~/log/era5.log
0  0 * * * /usr/local/bin/openmeteo-api download-era5 era5_land --cdskey 10xxxx:8exxxxxxx > ~/log/era5_land.log 2>&1 || cat ~/log/era5_land.log
1  1 * * * /usr/local/bin/openmeteo-api download-era5 ecmwf_ifs --cdskey xxxxxxx --email xxxxxxxx > ~/log/ecmwf_archive.log 2>&1 || cat ~/log/ecmwf_archive.log
```

## Marine models

Note:
- ERA5 ocean requires a CDS API key

```bash
# DWD
40  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave gwam > ~/log/iconwave_gwam.log 2>&1 || cat ~/log/iconwave_gwam.log
30  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave ewam > ~/log/iconwave_ewam.log 2>&1 || cat ~/log/iconwave_ewam.log

# ERA5 Ocean
30 0 * * * /usr/local/bin/openmeteo-api download-era5 era5_ocean --only-variables wave_height,wave_direction,wave_period --cdskey 10xxxx:8ecxxxx > ~/log/era5_ocean.log 2>&1 || cat ~/log/era5_ocean.log

# ECMWF WAM
45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain wam025 > ~/log/ecmwf_wam025.log 2>&1 || cat ~/log/ecmwf_wam025.log
0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --concurrent 4 --domain wam025 > ~/log/ecmwf_wam025.log 2>&1 || cat ~/log/ecmwf_wam025.log

# MeteoFrance
0  0,12 * * * /usr/local/bin/openmeteo-api download-mfwave mfwave --concurrent 4 > ~/log/mfwave.log 2>&1 || cat ~/log/mfwave.log
0    12 * * * /usr/local/bin/openmeteo-api download-mfwave mfcurrents --concurrent 4 > ~/log/mfcurrents.log 2>&1 || cat ~/log/mfcurrents.log

```

## Air Quality
Note:
- Global forecasts require FTP access credentials to the CAMS global project
- European forecasts require a ADS API key

```bash
30 8,20 * * * /usr/local/bin/openmeteo-api download-cams cams_global --ftpuser xxxxx --ftppassword xxxxx > ~/log/cams_global.log 2>&1 || cat ~/log/cams_global.log
30 9 * * * /usr/local/bin/openmeteo-api download-cams cams_europe --cdskey 10xxxx:2bb439xxxxxx > ~/log/cams_europe.log 2>&1 || cat ~/log/cams_europe.log
```

## Floods
Note:
- Requires FTP access credentials to the GloFAS project

```bash
0 12 * * *  /usr/local/bin/openmeteo-api download-glofas forecast --ftpuser xxxxx --ftppassword xxxxx > ~/log/glofas_forecast.log 2>&1 || cat ~/log/glofas_forecast.log
0 14 10 * * /usr/local/bin/openmeteo-api download-glofas seasonal --ftpuser xxxxx --ftppassword xxxxx > ~/log/glofas_seasonal.log 2>&1 || cat ~/log/glofas_seasonal.log
```

## Seasonal forecast

Note: Not yet released

```bash
20 5,11,17,23 * * * /usr/local/bin/openmeteo-api download-seasonal-forecast ncep > ~/log/seasonal_ncep.log 2>&1 || cat ~/log/seasonal_ncep.log
```

## General cleanup
```bash
# Delete forecasts older than 30 days
5 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -mtime +30 -delete
```