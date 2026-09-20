# NOAA RRFS ingestion

Run `swift run openmeteo-api download-noaa-rrfs DOMAIN --run YYYYMMDDHH --concurrent 4`.

| Domain | Interval | Cycles | Forecast | Members |
| --- | --- | --- | --- | --- |
| `ncep_rrfs_conus` | 1 hour | 00/06/12/18 UTC | 84 hours | 1 |
| `ncep_rrfs_conus_15min` | 15 minutes | Hourly | 18 hours | 1 |
| `ncep_rrfs_conus_ensemble` | 1 hour | 00/06/12/18 UTC | 60 hours | 5 |

Without `--run`, the cycle is selected with a 3-hour-45-minute availability delay. The default source is `https://noaa-rrfs-ops-pds.s3.amazonaws.com`; `--server` overrides the root while retaining the RRFS directory layout. `--timeinterval YYYYMMDD-YYYYMMDD` downloads historical cycles. `--max-forecast-hour` limits processing for a smoke run. Standard `--create-netcdf`, `--skip-timeseries`, and `--upload-s3-bucket` options are supported.

The downloader defines the required inputs through `CurlIndexedVariable` and calls `curl.downloadIndexedGrib`, which fetches the `.idx` inventory and requests only the matching byte ranges. Exact inventory matches preserve distinct subhourly timestamps and statistical intervals. Decoding and compression run concurrently. Accumulations and averages are processed in chronological order per variable and member, including across subhourly file boundaries. Each subhourly file contains four timestamps; no subhourly forecast-hour-zero file is requested. A GRIB/inventory count mismatch or missing wind component fails the download.

The three domains share an exact 1799 × 1059 Lambert conformal grid with 3000-metre spacing. Terrain and land mask come from the deterministic analysis. Ensemble members `m001` through `m005` are stored as members 0 through 4.

Grid-relative winds become speed and true-north direction. Wind and temperature height variables use names such as `wind_speed_305m` and `temperature_305m`. The supplied 305, 457, 610, 914, 1524, 1829, 2134, 2743, 3658 and 4572 m levels are above mean sea level; the other height levels are above ground. The deterministic catalog includes every supplied wind height through 4572 m MSL. The ensemble catalog reflects its smaller NOMADS field selection. Pressure levels use separate deterministic and ensemble schemas. The forecast API model `ncep_rrfs_seamless` prioritizes RRFS 15-minute data (when requested), RRFS hourly, GFS 0.25°, and finally GEFS 0.5° (`gfs05`), using the corresponding variable catalog for each reader.

Stored fields include temperature, humidity, pressure, precipitation, snowfall and snowfall water equivalent, cloud cover, radiation, CAPE, CIN, visibility and gusts. The deterministic product additionally supplies boundary-layer height, soil fields, heat fluxes and freezing-level height. For solar fluxes, the last-hour average is preferred over instantaneous data, independent of inventory order. When that average is unavailable, instantaneous fluxes are converted to backward averages using `backwardsAveragedToInstantFactor`; temperatures use Celsius, pressure hPa, snowfall centimetres, and CIN a positive magnitude.

Snowfall water equivalent uses cumulative `TSNOWP` where available, differenced into hourly or 15-minute amounts in mm. If the inventory lacks `TSNOWP` (as in the reduced ensemble files), the downloader selects `CPOFP` from the same index and estimates snowfall water equivalent from precipitation times the frozen fraction. Only the selected input is downloaded.

Run the inventory, conversion and scheduling tests with `swift test --filter NcepRrfsTests`. To additionally decode an existing ensemble GRIB sample, set `RRFS_TEST_GRIB=/path/to/file.grib2` with its `.idx` alongside it. `RRFS_TEST_DOMAIN` can select another RRFS domain for another sample.

The forecast controller also accepts each individual model: `ncep_rrfs_conus`, `ncep_rrfs_conus_15min`, and `ncep_rrfs_conus_ensemble` (five members). RRFS model identifiers are not yet available in the installed FlatBuffers SDK, so binary responses currently encode the model as `undefined`.

RRFS ensemble processing also writes hourly `precipitation_probability`: the percentage of the five members with at least 0.1 mm of precipitation in that hour. It is calculated from the deaccumulated member fields, stored once as member zero, and exposed by all RRFS controller models. Forecast hour zero has no precipitation probability.
