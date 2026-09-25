# NCEP RRFS models

## Domains and model grids

| Domain | Resolution | Interval | Cycles | Forecast | Members |
| --- | --- | --- | --- | --- | --- |
| `ncep_rrfs_north_america` | 13 km (nominal) | 1 hour | 00/06/12/18 UTC | 84 hours | 1 |
| `ncep_rrfs_conus` | 3 km | 1 hour | 00/06/12/18 UTC | 84 hours | 1 |
| `ncep_rrfs_conus_15min` | 3 km | 15 minutes | Hourly | 18 hours | 1 |
| `ncep_rrfs_conus_ensemble` | 3 km | 1 hour | 00/06/12/18 UTC | 60 hours | 5 |

The three CONUS domains share an exact 1799 × 1059 Lambert conformal grid with 3000-metre spacing. Terrain and land mask come from the deterministic analysis. Ensemble members `m001` through `m005` are stored as members 0 through 4.

`ncep_rrfs_north_america` uses its own 1127 × 683 rotated latitude/longitude grid, with 0.1083° spacing in rotated coordinates (the nominal 13 km product). Its rotated origin is 36.9303°S, 61°W, and the GRIB southern pole is 35°S, 247°E, with zero additional rotation. Terrain and land mask come from its own `2dfld.13km.f000.na` analysis. Grid-relative winds are rotated using the spherical bearing toward geographic north. Missing values outside the model footprint remain NaN.

The forecast controller also accepts each individual model: `ncep_rrfs_conus`, `ncep_rrfs_conus_15min`, `ncep_rrfs_conus_ensemble` (five members), and `ncep_rrfs_north_america`.

The forecast API model `ncep_rrfs_seamless` prioritizes RRFS 15-minute data (when requested), RRFS hourly, GFS 0.25°, and finally GEFS 0.5° (`gfs05`), using the corresponding variable catalog for each reader.

## Variable catalogs

These are the stored model variables defined in [NcepRrfsVariable.swift](../../Sources/App/NcepRrfs/NcepRrfsVariable.swift), including fields calculated during ingestion. Additional variables derived by the forecast reader are outside this list. GRIB input mappings are defined in [NcepRrfsVariableDownloadable.swift](../../Sources/App/NcepRrfs/NcepRrfsVariableDownloadable.swift).

In the compact names below, replace `{height}`, `{depth}` or `{pressure}` with each listed value. Heights marked AGL are above ground. Soil depths are in centimetres below ground. For example, `temperature_{height}m` at 320 m AGL is `temperature_320m`, and `temperature_{pressure}hPa` at 500 hPa is `temperature_500hPa`.

### `ncep_rrfs_north_america`

| Group | Variables |
| --- | --- |
| Temperature and humidity | `temperature_2m`, `relative_humidity_2m`, `surface_temperature` |
| Pressure | `pressure_msl`, `surface_pressure` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `snow_depth`, `snow_depth_water_equivalent`, `categorical_freezing_rain` |
| Radar reflectivity | `radar_reflectivity` |
| Clouds and visibility | `cloud_base`, `cloud_ceiling`, `cloud_top`, `cloud_cover`, `cloud_cover_low`, `cloud_cover_mid`, `cloud_cover_high`, `visibility` |
| Radiation and heat fluxes | `shortwave_radiation`, `diffuse_radiation`, `sensible_heat_flux`, `latent_heat_flux` |
| Convection and atmosphere | `cape`, `convective_inhibition`, `lifted_index`, `boundary_layer_height`, `total_column_integrated_water_vapour`, `freezing_level_height` |
| Wind gusts | `wind_gusts_10m` |
| Wind above ground | `wind_speed_{height}m`, `wind_direction_{height}m` at 10, 30, 50, 80, 100, 160, 320 m AGL |
| Temperature above ground | `temperature_{height}m` at 30, 50, 80, 100, 160, 320 m AGL |
| Soil | `soil_temperature_{depth}cm`, `soil_moisture_{depth}cm` at 0, 1, 4, 10, 30, 60, 100, 160, 300 cm |

Pressure-level variables: `temperature_{pressure}hPa`, `relative_humidity_{pressure}hPa`, `geopotential_height_{pressure}hPa`, `wind_speed_{pressure}hPa`, `wind_direction_{pressure}hPa`, `vertical_velocity_{pressure}hPa`.

Pressure levels: **50, 70, 100 hPa**, then **125–1000 hPa in steps of 25 hPa** (39 levels).

### `ncep_rrfs_conus`

| Group | Variables |
| --- | --- |
| Temperature and humidity | `temperature_2m`, `relative_humidity_2m`, `surface_temperature` |
| Pressure | `pressure_msl`, `surface_pressure` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `snow_depth`, `snow_depth_water_equivalent`, `categorical_freezing_rain` |
| Radar reflectivity | `radar_reflectivity` |
| Clouds and visibility | `cloud_base`, `cloud_ceiling`, `cloud_top`, `cloud_cover`, `cloud_cover_low`, `cloud_cover_mid`, `cloud_cover_high`, `visibility` |
| Radiation and heat fluxes | `shortwave_radiation`, `diffuse_radiation`, `sensible_heat_flux`, `latent_heat_flux` |
| Convection and atmosphere | `cape`, `convective_inhibition`, `lifted_index`, `boundary_layer_height`, `total_column_integrated_water_vapour`, `freezing_level_height` |
| Wind gusts | `wind_gusts_10m` |
| Wind above ground | `wind_speed_{height}m`, `wind_direction_{height}m` at 10, 30, 50, 80, 100, 160, 320 m AGL |
| Temperature above ground | `temperature_{height}m` at 30, 50, 80, 100, 160, 320 m AGL |
| Soil | `soil_temperature_{depth}cm`, `soil_moisture_{depth}cm` at 0, 1, 4, 10, 30, 60, 100, 160, 300 cm |

Pressure-level variables: `temperature_{pressure}hPa`, `relative_humidity_{pressure}hPa`, `geopotential_height_{pressure}hPa`, `wind_speed_{pressure}hPa`, `wind_direction_{pressure}hPa`, `vertical_velocity_{pressure}hPa`.

Pressure levels: **50, 70, 100 hPa**, then **125–1000 hPa in steps of 25 hPa** (39 levels).

### `ncep_rrfs_conus_15min`

| Group | Variables |
| --- | --- |
| Temperature and humidity | `temperature_2m`, `relative_humidity_2m` |
| Pressure | `pressure_msl`, `surface_pressure` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `categorical_freezing_rain` |
| Radar reflectivity | `radar_reflectivity` |
| Clouds and visibility | `cloud_base`, `cloud_ceiling`, `cloud_top`, `visibility` |
| Radiation and heat fluxes | `shortwave_radiation`, `diffuse_radiation` |
| Wind gusts | `wind_gusts_10m` |
| Wind above ground | `wind_speed_{height}m`, `wind_direction_{height}m` at 10, 80 m AGL |

This product has no pressure-level fields.

### `ncep_rrfs_conus_ensemble`

| Group | Variables |
| --- | --- |
| Temperature and humidity | `temperature_2m`, `relative_humidity_2m` |
| Pressure | `pressure_msl`, `surface_pressure` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `categorical_freezing_rain` |
| Radar reflectivity | `radar_reflectivity` |
| Clouds and visibility | `cloud_cover`, `cloud_cover_low`, `cloud_cover_mid`, `cloud_cover_high`, `visibility` |
| Radiation and heat fluxes | `shortwave_radiation` |
| Convection and atmosphere | `cape`, `convective_inhibition`, `total_column_integrated_water_vapour` |
| Wind gusts | `wind_gusts_10m` |
| Wind above ground | `wind_speed_{height}m`, `wind_direction_{height}m` at 10, 80, 160, 320 m AGL |

Pressure-level variables: `temperature_{pressure}hPa`, `relative_humidity_{pressure}hPa`, `geopotential_height_{pressure}hPa`, `wind_speed_{pressure}hPa`, `wind_direction_{pressure}hPa`.

Pressure levels: **250, 300, 400, 500, 600, 700, 750, 800, 850, 900, 925, 950, 975, 1000 hPa** (14 levels).

The variables above are stored separately for all five members. The additional `precipitation_probability` field is calculated across the members and stored once as member zero.

### Probability and seamless readers

The three CONUS RRFS forecast-controller models also expose `precipitation_probability` from `ncep_rrfs_conus_ensemble`; it is an hourly ensemble statistic, not a separate probability calculated from the deterministic or 15-minute product. `ncep_rrfs_seamless` combines the underlying readers and does not have a separate stored variable catalog.

The North America reader has no ensemble precipitation-probability supplement: the available RRFS ensemble covers CONUS only. `ncep_rrfs_seamless` retains its existing CONUS/GFS composition.

## Variable processing

### Wind, temperature and units

Grid-relative winds become speed and true-north direction. Wind height variables use above-ground levels, such as `wind_speed_320m`. Temperature height levels are also above ground. The ensemble catalog reflects its smaller NOMADS field selection. Pressure levels use separate deterministic and ensemble schemas.

Temperatures are stored in Celsius, pressure in hPa, snowfall in centimetres, and CIN as a positive magnitude.

### Radar reflectivity

`radar_reflectivity` uses instantaneous `REFC` at the entire-atmosphere level in all four domains. It represents the maximum simulated radar reflectivity over the atmospheric column, in dBZ. Values are stored unchanged at 0.1 dBZ precision, including negative values, with linear time interpolation. No accumulation or averaging conversion is applied.

### Radiation

Hourly deterministic and ensemble shortwave radiation selects the last-hour average. Diffuse radiation and the 15-minute product only provide instantaneous solar fluxes, converted to backward averages using `backwardsAveragedToInstantFactor`.

### Snowfall water equivalent

Snowfall water equivalent uses cumulative `TSNOWP` for the deterministic hourly and 15-minute products, differenced into interval amounts in mm. The reduced ensemble product supplies `CPOFP` instead, used to estimate snowfall water equivalent from precipitation times the frozen fraction.

### Cloud heights and frozen water

- `cloud_base`, `cloud_ceiling` and `cloud_top` are available in both hourly deterministic domains and the 15-minute CONUS domain. Cloud base is the lowest detected cloud base, ceiling is the lowest broken/overcast cloud-base diagnostic, and cloud top is the upper cloud boundary. Each uses its distinct `HGT` GRIB level. The GRIB heights are above sea level; ingestion subtracts model terrain to store metres above ground, with sea elevation treated as zero and negative resulting heights clamped to zero. Missing coverage and no-cloud values remain NaN. See the [UPP field definitions](https://upp.readthedocs.io/en/upp_v10.1.0/UPP_GRIB2_Table.html).
- `freezing_rain` uses `FRZR` in all four domains. Cumulative water-equivalent precipitation is differenced into hourly or 15-minute amounts, in mm. It is separate from the existing `categorical_freezing_rain` flag.
- `snow_depth_water_equivalent` uses instantaneous `WEASD` in both hourly deterministic domains. It is the water stored in the existing snowpack, in mm (1 kg/m² = 1 mm), and is not deaccumulated. `snowfall_water_equivalent` remains the amount of new snowfall during an interval.

### Precipitation probability

RRFS ensemble processing also writes hourly `precipitation_probability`: the percentage of the five members with at least 0.1 mm of precipitation in that hour. It is calculated from the deaccumulated member fields, stored once as member zero, and exposed by the CONUS RRFS controller models. Forecast hour zero has no precipitation probability.

## Downloader implementation

### Running the downloader

Run `swift run openmeteo-api download-noaa-rrfs DOMAIN --run YYYYMMDDHH --concurrent 4`.

Without `--run`, the cycle is selected with a 3-hour-45-minute availability delay. The default source is `https://noaa-rrfs-ops-pds.s3.amazonaws.com`; `--server` overrides the root while retaining the RRFS directory layout. `--timeinterval YYYYMMDD-YYYYMMDD` downloads historical cycles. `--max-forecast-hour` limits processing for a smoke run. Standard `--create-netcdf`, `--skip-timeseries`, and `--upload-s3-bucket` options are supported.

### File selection and processing

Both `2dfld.13km.fFFF.na` and `prslev.13km.fFFF.na` files are downloaded, following the [NCEP RRFS product naming](https://www.nco.ncep.noaa.gov/pmb/products/rrfs/). The supplied surface inventories and the verified pressure inventory match the CONUS deterministic catalog, so both domains use `NcepRrfsVariable`.

Each variable enum declares its product-specific GRIB attributes, unit conversions, solar-radiation handling and wind output pairs through `NcepRrfsVariableDownloadable`. Only the declared inputs are downloaded, with one index request per file.

The downloader defines the required inputs through `CurlIndexedVariable` and calls `curl.downloadIndexedGrib`, which fetches the `.idx` inventory and requests only the matching byte ranges. Exact inventory matches preserve distinct subhourly timestamps and statistical intervals. Decoding and compression run concurrently. Accumulations and averages are processed in chronological order per variable and member, including across subhourly file boundaries. Each subhourly file contains four timestamps; no subhourly forecast-hour-zero file is requested. A GRIB/inventory count mismatch or missing wind component fails the download.

### Tests

Run the inventory, conversion and scheduling tests with `swift test --filter NcepRrfsTests`. To additionally decode an existing ensemble GRIB sample, set `RRFS_TEST_GRIB=/path/to/file.grib2` with its `.idx` alongside it. `RRFS_TEST_DOMAIN` can select another RRFS domain for another sample.

### API encoding limitation

RRFS model identifiers are not yet available in the installed FlatBuffers SDK, so binary responses currently encode the model as `undefined`.

The installed FlatBuffers SDK also lacks `categorical_freezing_rain`, `radar_reflectivity` and the dBZ unit. These variables encode as `undefined` in binary responses. The radar-reflectivity unit currently uses an `undefined` placeholder in all response formats, with a TODO to use dBZ when the SDK supports it. The stored values remain in dBZ.
