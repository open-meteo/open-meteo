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
| Pressure | `pressure_msl` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `snow_depth`, `snow_depth_water_equivalent`, `categorical_freezing_rain` |
| Aerosols | `pm2_5_total_organic_matter`, `pm2_5`, `pm10`, `aerosol_optical_depth` |
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
| Pressure | `pressure_msl` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `snow_depth`, `snow_depth_water_equivalent`, `categorical_freezing_rain` |
| Aerosols | `pm2_5_total_organic_matter`, `pm2_5`, `pm10`, `aerosol_optical_depth` |
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
| Pressure | `pressure_msl` |
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
| Pressure | `pressure_msl` |
| Precipitation and snow | `precipitation`, `freezing_rain`, `snowfall`, `snowfall_water_equivalent`, `categorical_freezing_rain` |
| Aerosols | `aerosol_optical_depth` |
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

## Available fields not yet implemented

The table below groups unused physical fields in the checked-in `.idx` inventories. API names are **suggestions**, not registered variables or commitments to add them. Availability means a field appears in the supplied files; analysis and forecast steps can differ. **D** = both hourly deterministic domains (`ncep_rrfs_conus` and `ncep_rrfs_north_america`), **Q** = `ncep_rrfs_conus_15min`, **E** = `ncep_rrfs_conus_ensemble`. A missing model letter means the supplied inventory does not contain the field.

Units show the native GRIB unit, with a proposed API conversion where useful. `{depth}` means the nine soil point depths listed above. Braced alternatives consolidate related fields; levels and statistical intervals must still be selected explicitly when implementing them. Fields already used or derived by the API are discussed separately below.

| Suggested API name / family | GRIB code and distinguishing level or qualifier | Models | Unit / processing notes |
| --- | --- | --- | --- |
| `longwave_radiation`, `longwave_radiation_upwards`, `shortwave_radiation_upwards` | `DLWRF`, `ULWRF`, `USWRF`: surface | D, Q | W/m²; D has hourly averages and instantaneous fields, Q instantaneous only |
| `outgoing_longwave_radiation`, `outgoing_shortwave_radiation` | `ULWRF`, `USWRF`: top of atmosphere | D; Q has `ULWRF` only | W/m²; preserve instantaneous versus averaged intervals |
| `shortwave_radiation_clear_sky_instant` | `CSDSF`: surface | D | W/m²; native clear-sky flux, distinct from the API's solar-geometry estimate |
| `albedo`, `snow_albedo_max` | `ALBDO`, `MXSALB`: surface | D | % |
| `ground_heat_flux`, `snow_phase_change_heat_flux` | `GFLUX`, `SNOHF`: surface | D | W/m²; hourly averages; `GFLUX` also instantaneous |
| `soil_moisture_liquid_{depth}cm` | `SOILL`: point soil depths 0–300 cm | D | m³/m³; liquid component of the stored total soil moisture |
| `soil_water_column`, `canopy_water` | `CISOILM`: underground column; `CNWAT`: surface | D | kg/m² → mm of water |
| `soil_moisture_availability`, `soil_moisture_{wilting_point,stress_threshold,evaporation_threshold,porosity}` | `MSTAV`; `WILT`, `SMREF`, `SMDRY`, `POROS` | D | `MSTAV`: %; other fields: fraction (volumetric soil water or pore space) |
| `potential_evaporation`, `potential_evaporation_heat_flux`, `snow_sublimation_heat_flux` | `PEVAP`, `PEVPR`, `SBSNO`: surface | D | `PEVAP`: accumulated kg/m² → interval mm; `PEVPR`/`SBSNO`: W/m², not mm/h |
| `surface_runoff`, `snow_melt` | `SSRUN`, `SNOM`: surface | D | Accumulated kg/m² → interval mm |
| `snow_cover`, `snow_density` | `SNOWC`, `SDEN`: surface | D | %, kg/m³ respectively |
| `vegetation_cover`, `leaf_area_index`, `vegetation_type`, `soil_type`, `root_zone_layer_count` | `VEG`, `LAI`, `VGTYP`, `SOTYP`, `RLYRS` | D | %, dimensionless area ratio, category codes, category codes, count respectively |
| `surface_roughness`, `friction_velocity`, `surface_drag_coefficient`, `surface_exchange_coefficient`, `stomatal_resistance_min` | `SFCR`, `FRICV`, `CD`, `SFEXC`, `RSMIN` | D | m, m/s, dimensionless, kg/(m²·s), s/m respectively |
| `water_surface_temperature`, `sea_ice_cover`, `ice_growth_rate` | `WTMP`, `ICEC`, `ICEG` (10 m ASL) | D | K → °C, fraction → %, m/s respectively; `ICEG` needs product-specific interpretation before exposure |
| `pm2_5_dust`, `pm2_5_to_10_dust` | `MASSDEN`: 8 m AGL, dust `<2.5e-06` m and `>=2.5e-06,<1e-05` m | D | kg/m³ → µg/m³; instantaneous; sum both to obtain dust below 10 µm |
| `column_mass_{organic_matter,pm2_5_dust,coarse_dust,pm10_dust}` | `COLMD`: entire atmosphere, organic/dust species and particle-size qualifiers | D | kg/m² → mg/m²; column burden, not near-surface concentration |
| `aerosol_layer_{base,top}`, `aerosol_mass_density_height` | `HGTMD`: lowest/highest level above `1e-09 kg/m³`, plus entire-atmosphere diagnostic | D | m; verify vertical reference and meaning of the column diagnostic before implementation |
| `{organic_aerosol,dust}_emission_flux` | `AEMFLX`: organic matter `<2.5e-06` m; dust `<1e-05` m | D | kg/(m²·s) |
| `ventilation_rate`, `boundary_layer_wind_{speed,direction}` | `VRATE`; `UGRD`/`VGRD`: planetary boundary layer | D | m²/s; wind components m/s → speed m/s and direction ° |
| `precipitation_rate`, `precipitation_rate_max` | `PRATE`: surface | D, Q; max only D | kg/(m²·s) → mm/h; distinguish instantaneous and hourly maximum |
| `frozen_rain` | `FROZR`: surface | D, Q | Accumulated kg/m² → interval mm; distinct from implemented freezing rain (`FRZR`) |
| `categorical_{rain,snow,ice_pellets}` | `CRAIN`, `CSNOW`, `CICEP`: surface | D, Q, E | Categorical flags |
| `temperature_2m_{min,max}_hourly`, `relative_humidity_2m_{min,max}_hourly` | `TMIN`/`TMAX`, `MINRH`/`MAXRH`: 2 m AGL | D; E has humidity only | K → °C, %; native within-hour extrema, not extrema of sampled hourly values |
| `wind_speed_10m_max_hourly`, `wind_{u,v}_10m_at_max_speed` | `WIND`; `MAXUW`/`MAXVW`: 10 m AGL | D, E; components only D | m/s; hourly maxima, separate from `GUST` |
| `radar_echo_top`, `vertically_integrated_liquid` | `RETOP`, `VIL`: entire atmosphere | D, Q, E for `RETOP`; D, Q for `VIL` | m, kg/m² respectively |
| `radar_reflectivity_{1000m,4000m,minus10c}`, `radar_reflectivity_{1000m,minus10c}_max` | `REFD`: 1000/4000 m AGL and 263 K level; `MAXREF`: 1000 m and 263 K | D; Q has instantaneous 1000/4000 m only | dBZ; `MAXREF` is hourly maximum |
| `updraft_velocity_max`, `downdraft_velocity_max`, `hail_size_max` | `MAXUVV`, `MAXDVV`: 100–1000 mb; `HAIL`: surface | D, E for velocities; D for hail | m/s; hail m → mm; hourly maxima, not hail accumulation |
| `lightning_potential`, `lightning_strike_density_{type}` | `LTNG`: entire atmosphere; `LTNGSD`: 1/2 m level labels | D, E for `LTNG`; D for `LTNGSD` | `LTNG`: dimensionless diagnostic; `LTNGSD`: m⁻² s⁻¹; verify RRFS type labels/scaling, do not interpret 1/2 m as measurement heights |
| `updraft_helicity_2_to_5km`, `updraft_helicity_{0_to_3km,2_to_5km}_{min,max}` | `UPHL`; `MNUPHL`/`MXUPHL` | D, Q for instantaneous; D, E for extrema | m²/s² |
| `storm_relative_helicity_{0_to_1km,0_to_3km}`, `effective_storm_relative_helicity` | `HLCY`; `EFHL` | D, E for `HLCY`; D for `EFHL` | m²/s² |
| `wind_shear_{u,v}_{0_to_1km,0_to_6km}`, `storm_motion_{u,v}` | `VUCSH`/`VVCSH`; `USTM`/`VSTM` at 0–6 km | D, E for shear; D for storm motion | m/s |
| `cape_{parcel}`, `convective_inhibition_{parcel}`, `cape_0_to_3km`, `downdraft_cape`, `lifted_index_best` | `CAPE`/`CIN`: 180–0, 90–0, 255–0 mb above ground; `CAPE`: 0–3000 m; `DCAPE`; `4LFTX` | D | J/kg; lifted index K; preserve parcel definition and CIN sign convention |
| `relative_vorticity_{layer}_max`, `critical_angle` | `RELV`: 0–1 km, 0–2 km, first hybrid level; `CANGLE`: 0–500 m | D | s⁻¹, ° respectively |
| `cloud_cover_boundary_layer`, `cloud_top_temperature`, `cloud_{base,top}_pressure` | `TCDC`: boundary-layer clouds; `TMP`: cloud top; `PRES`: cloud base/top and grid-scale cloud boundaries | D, E for boundary-layer cover; D for others | %, K → °C, Pa → hPa respectively |
| `wet_bulb_zero_height`, `supercooled_liquid_{base,top}`, `condensation_level_height`, `equilibrium_level_height`, `freezing_level_height_highest`, `minus20c_height` | `HGT`: corresponding diagnostic levels | D | m; verify ASL/AGL reference before exposing |
| `tropopause_{temperature,potential_temperature,pressure,height,wind_speed,wind_direction,wind_shear}`, `maximum_wind_{pressure,height,speed,direction}` | `TMP`/`POT`/`PRES`/`HGT`/`UGRD`/`VGRD`/`VWSH`: tropopause; `PRES`/`HGT`/`UGRD`/`VGRD`: max wind | D | K (TMP → °C), Pa → hPa, m, m/s, °; `VWSH`: s⁻¹ |
| `specific_humidity_{level}`, `potential_temperature_{level}`, `dew_point_depression_2m`, `relative_humidity_column` | `SPFH`: surface/2 m/80 m/305 m ASL/pressure layers; `POT`: surface and 30–0 mb; `DEPR`; `RHPW` | D; Q has 2 m `SPFH`; E has pressure-level `SPFH` | kg/kg → g/kg; K; K temperature difference; % respectively |
| `absolute_vorticity_{pressure}hPa`, `{cloud_water,cloud_ice,rain,snow,graupel}_mixing_ratio_{pressure}hPa`, `stream_function_{pressure}hPa` | `ABSV`; `CLMR`/`ICMR`/`RWMR`/`SNMR`/`GRLE`; `STRM` at 250/500 hPa | D; E has `ABSV` only | s⁻¹; kg/kg → g/kg; m²/s respectively; consolidate all native pressure levels |
| `moisture_convergence_{level}`, `parcel_lifted_index`, `parcel_pressure`, `condensation_level_pressure`, `freezing_level_{pressure,relative_humidity}` | `MCONV`: column/850/950 hPa/30–0 mb; `PLI`; `PLPL`; `PRES`: condensation/freezing levels; `RH`: freezing levels | D | `MCONV`: kg/(kg·s); `PLI`: K; pressures Pa → hPa; RH %; confirm column-MCONV normalization |
| `wildfire_potential`, `fire_radiative_power` | Unnamed `discipline=2, parmcat=4, parm=26` (`WFIREPOT`) and `parm=36` (`FRADPOW`) | D, E for potential; D for power | Dimensionless, W respectively; names resolved from NCEP's current table |
| `brightness_temperature_goes16_band_{7…16}`, `brightness_temperature_goes18_band_{8…16}`, `brightness_temperature` | `SBTA167`…`SBTA1616`; unnamed `3/192/77…85` (`SBTA188`…`SBTA1816`); `BRTEMP` | D | K; simulated outgoing infrared brightness temperatures |

The inventory is not itself proof that a field has useful non-missing values. Before adding a candidate, check a GRIB sample for units, missing-value sentinels, time ranges and level semantics. In particular, the supplied potential-evaporation messages are unusually small, and several specialist diagnostics require more validation.

### Alternate inputs and deliberately omitted fields

| Suggested API name / family | Unused GRIB input | Models | Unit / reason not stored |
| --- | --- | --- | --- |
| `surface_pressure` | `PRES`: surface | D, Q, E | Pa → hPa; already derived from mean-sea-level pressure, temperature and elevation |
| `dew_point_2m`, `dew_point_{pressure}hPa` | `DPT`: 2 m and pressure levels | D, E; Q already uses 2 m DPT to obtain RH | K → °C; API derives dew point from temperature/RH, so no additional stored field is needed |
| `direct_radiation` | `VBDSF`: surface | D, Q | W/m²; native instantaneous beam field not ingested; API derives direct radiation from total and diffuse radiation |
| `frozen_precipitation_percent` | `CPOFP`: surface | D, Q; E already uses it internally | %; deterministic products use native snowfall water equivalent instead |
| `cloud_ceiling` in the ensemble | `CEIL`: cloud ceiling | D, E | m; D already uses `HGT:cloud ceiling`; E has a possible additional input requiring reference/sentinel validation |
| `temperature_{height}m_asl`, `wind_{speed,direction}_{height}m_asl` | `TMP`, `UGRD`, `VGRD`: 305, 457, 610, 914, 1524, 1829, 2134, 2743, 3658, 4572 m ASL | D | K → °C, m/s, °; deliberately removed; names here explicitly distinguish ASL from AGL |
| Existing pressure-variable families at additional levels | `TMP`, `RH`, `HGT`, `UGRD`, `VGRD`, `DZDT`: 2, 5, 7, 10, 20, 30 hPa | D | Existing family units; native inventories extend above the implemented 50 hPa minimum |
| `boundary_layer_{temperature,humidity,pressure,wind}_{layer}` | `TMP`, `RH`, `SPFH`, `PRES`, `UGRD`, `VGRD`: six 30-hPa layers from 0 to 180 hPa above ground; also `DPT`, `POT`, `PWAT` in the lowest layer | D | K → °C, % / kg/kg, Pa → hPa, m/s; separate pressure-relative layers, not standard isobaric levels |

Grid coordinates, model-level counts and static terrain/land-mask records (`NLAT`, `ELON`, `LMH`, `LMV`, `HGT:surface`, `LAND`) are infrastructure rather than proposed weather API variables. Duplicate statistical versions of implemented fields are not separate candidates. Less common records `ELMELT`, `UESH`/`VESH`, `UEID`/`VEID`, `LAYTH`, and unnamed hydrological probability parameters `1/1/196–197` are left without API names pending verification of their exact diagnostics, units and threshold definitions; their presence alone is not sufficient to expose them.

Parameter units and unnamed-code interpretations can be checked against NCEP's [moisture](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-0-1.shtml), [soil](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-2-3.shtml), [land surface](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-2-0.shtml), [convection](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-0-7.shtml), [lightning](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-0-17.shtml), [aerosols](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-0-20.shtml), [fire weather](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-2-4.shtml) and [satellite imagery](https://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_doc/grib2_table4-2-3-192.shtml) tables.

## Variable processing

`surface_pressure` is calculated on demand by the forecast API from `pressure_msl`, `temperature_2m` and the requested elevation. RRFS surface-pressure GRIB fields are not downloaded or stored.

### Soil layer averages

The hourly deterministic CONUS and North America products store soil temperature and moisture at point depths of 0, 1, 4, 10, 30, 60, 100, 160 and 300 cm. The forecast API additionally derives the legacy GFS/HRRR layers `soil_temperature_{layer}cm` and `soil_moisture_{layer}cm`, where `{layer}` is `0_to_10`, `10_to_40`, `40_to_100` or `100_to_200`.

For each layer, the deriver assumes a linear profile between adjacent point depths, interpolates values at the layer boundaries, integrates using trapezoids, and divides by the layer thickness. This gives a depth-weighted mean rather than an equal average of the available points. The resulting weights apply to both temperature and moisture:

| Layer | Input depths (cm) | Weights, in the same order |
| --- | --- | --- |
| 0–10 cm | 0, 1, 4, 10 | 0.05, 0.20, 0.45, 0.30 |
| 10–40 cm | 10, 30, 60 | 1/3, 11/18, 1/18 |
| 40–100 cm | 30, 60, 100 | 1/9, 5/9, 1/3 |
| 100–200 cm | 100, 160, 300 | 3/10, 9/14, 2/35 |

For example, the 40 cm boundary is interpolated between the 30 and 60 cm samples; the 200 cm boundary uses the 160 and 300 cm samples. No extrapolation is needed. Temperature remains in °C and moisture in m³/m³. These are approximations from point samples, not native model layer means. Missing input values propagate as NaN; an unavailable required depth makes the derivation unavailable. Existing native layer fields take precedence, so GFS and HRRR retain their stored layer values. The RRFS 15-minute and ensemble products have no soil profiles and do not gain these derived layers.

### Wind, temperature and units

Grid-relative winds become speed and true-north direction. Wind height variables use above-ground levels, such as `wind_speed_320m`. Temperature height levels are also above ground. The ensemble catalog reflects its smaller NOMADS field selection. Pressure levels use separate deterministic and ensemble schemas.

Temperatures are stored in Celsius, pressure in hPa, snowfall in centimetres, and CIN as a positive magnitude.

### Aerosol optical depth

`aerosol_optical_depth` selects instantaneous `AOTK` for the entire atmospheric column in both hourly deterministic domains and the CONUS ensemble. It is dimensionless, stored at 0.01 precision, and interpolated linearly without unit conversion or deaveraging. Ensemble values are stored separately for each member. The 15-minute product does not provide this field. AOD describes aerosol extinction through the full column, not near-surface particulate concentration.

### Aerosol mass density

`pm2_5_total_organic_matter` is available in the hourly deterministic CONUS and North America products, including analysis time. It selects instantaneous `MASSDEN` at 8 m above ground with `aerosol=Particulate organic matter dry` and `aerosol_size <2.5e-06`. Explicit aerosol qualifiers exclude the dust fields and hourly averaged total-aerosol PM2.5/PM10 fields. This is the organic-aerosol component used for smoke concentration, not total PM2.5.

As in HRRR, values are converted from kg/m³ to µg/m³ by multiplying by 10⁹, stored with a scale factor of 0.1, and interpolated linearly. No deaccumulation or averaging conversion is applied. The existing forecast API and FlatBuffers mappings for `pm2_5_total_organic_matter` are reused. The RRFS 15-minute and ensemble inventories do not provide this field. The legacy API name `mass_density_8m` derives directly from `pm2_5_total_organic_matter`, without changing values or units. RRFS stores only the new name; HRRR retains its native `mass_density_8m` field.

`pm2_5` and `pm10` select the **total aerosol** `MASSDEN` fields at 8 m above ground, with particle-size cutoffs `<2.5e-06` m and `<1e-05` m respectively. They are available in both hourly deterministic domains from forecast hour 1; analysis, 15-minute and ensemble products lack these fields. Each forecast hour selects the preceding hour's average (for example, `2-3 hour ave fcst` at hour 3), with no instantaneous fallback. Values are converted from kg/m³ to µg/m³ using 10⁹ and stored at 0.1 µg/m³ precision. Backward interpolation preserves the preceding-hour interpretation at finer output intervals. The existing `pm2_5` and `pm10` forecast API and FlatBuffers mappings are reused.

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

The downloader defines the required inputs through `CurlIndexedVariable` and calls `curl.downloadIndexedGrib`, which fetches the `.idx` inventory and requests only the matching byte ranges. Exact inventory matches preserve distinct subhourly timestamps and statistical intervals. Whole-day accumulation selectors use the inventory’s day notation (`0-1 day acc fcst` at hour 24, `0-2 day acc fcst` at hour 48); instantaneous forecasts retain hours, and deaccumulation continues to use minutes internally. Decoding and compression run concurrently. Accumulations and averages are processed in chronological order per variable and member, including across subhourly file boundaries. Each subhourly file contains four timestamps; no subhourly forecast-hour-zero file is requested. A GRIB/inventory count mismatch or missing wind component fails the download.

### Tests

Run the inventory, conversion and scheduling tests with `swift test --filter NcepRrfsTests`. To additionally decode an existing ensemble GRIB sample, set `RRFS_TEST_GRIB=/path/to/file.grib2` with its `.idx` alongside it. `RRFS_TEST_DOMAIN` can select another RRFS domain for another sample.

### API encoding limitation

RRFS model identifiers are not yet available in the installed FlatBuffers SDK, so binary responses currently encode the model as `undefined`.

The installed FlatBuffers SDK also lacks `categorical_freezing_rain`, `radar_reflectivity` and the dBZ unit. These variables encode as `undefined` in binary responses. The radar-reflectivity unit currently uses an `undefined` placeholder in all response formats, with a TODO to use dBZ when the SDK supports it. The stored values remain in dBZ.
