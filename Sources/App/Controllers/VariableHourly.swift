/// Define all available surface weather variables
enum ForecastSurfaceVariable: String, GenericVariableMixable {
    /// Maps to `temperature_2m`. Used for compatibility with `current_weather` block
    case temperature
    /// Maps to `windspeed_10m`. Used for compatibility with `current_weather` block
    case windspeed
    /// Maps to `winddirection_10m`. Used for compatibility with `current_weather` block
    case winddirection

    case wet_bulb_temperature_2m
    case apparent_temperature
    case cape
    case cloudcover
    case cloudcover_high
    case cloudcover_low
    case cloudcover_mid
    case cloud_cover
    case cloud_cover_high
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_2m
    case cloud_base
    case cloud_top
    case convective_cloud_base
    case convective_cloud_top
    case dewpoint_2m
    case dew_point_2m
    case diffuse_radiation
    case diffuse_radiation_instant
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case et0_fao_evapotranspiration
    case evapotranspiration
    case freezinglevel_height
    case freezing_level_height
    case growing_degree_days_base_0_limit_50
    case is_day
    case latent_heatflux
    case latent_heat_flux
    case lifted_index
    case convective_inhibition
    case leaf_wetness_probability
    case lightning_potential
    case mass_density_8m
    case precipitation
    case precipitation_probability
    case precipitation_type
    case pressure_msl
    case rain
    case relativehumidity_2m
    case relative_humidity_2m
    case runoff
    case sensible_heatflux
    case sensible_heat_flux
    case shortwave_radiation
    case shortwave_radiation_instant
    case showers
    case skin_temperature
    case snow_density
    case snow_depth
    case snow_depth_water_equivalent
    case snow_height
    case hail
    case snowfall
    case snowfall_water_equivalent
    case sunshine_duration
    case soil_moisture_0_1cm
    case soil_moisture_0_to_1cm
    case soil_moisture_0_to_100cm
    case soil_moisture_0_to_10cm
    case soil_moisture_0_to_7cm
    case soil_moisture_100_to_200cm
    case soil_moisture_100_to_255cm
    case soil_moisture_10_to_40cm
    case soil_moisture_1_3cm
    case soil_moisture_1_to_3cm
    case soil_moisture_27_81cm
    case soil_moisture_27_to_81cm
    case soil_moisture_28_to_100cm
    case soil_moisture_3_9cm
    case soil_moisture_3_to_9cm
    case soil_moisture_40_to_100cm
    case soil_moisture_7_to_28cm
    case soil_moisture_9_27cm
    case soil_moisture_9_to_27cm
    case soil_moisture_81_to_243cm
    case soil_moisture_243_to_729cm
    case soil_moisture_729_to_2187cm
    case soil_moisture_index_0_to_100cm
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_7_to_28cm
    case soil_temperature_0_to_100cm
    case soil_temperature_0_to_10cm
    case soil_temperature_0_to_7cm
    case soil_temperature_0cm
    case soil_temperature_100_to_200cm
    case soil_temperature_100_to_255cm
    case soil_temperature_10_to_40cm
    case soil_temperature_18cm
    case soil_temperature_28_to_100cm
    case soil_temperature_40_to_100cm
    case soil_temperature_54cm
    case soil_temperature_6cm
    case soil_temperature_7_to_28cm
    case soil_temperature_162cm
    case soil_temperature_486cm
    case soil_temperature_1458cm
    case surface_air_pressure
    case snowfall_height
    case surface_pressure
    case surface_temperature
    case temperature_100m
    case temperature_120m
    case temperature_150m
    case temperature_180m
    case temperature_2m
    case temperature_20m
    case temperature_200m
    case temperature_50m
    case temperature_40m
    case temperature_80m
    case temperature_2m_max
    case temperature_2m_min
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case total_column_integrated_water_vapour
    case updraft
    case uv_index
    case uv_index_clear_sky
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case visibility
    case weathercode
    case weather_code
    case winddirection_100m
    case winddirection_10m
    case winddirection_120m
    case winddirection_150m
    case winddirection_180m
    case winddirection_200m
    case winddirection_20m
    case winddirection_40m
    case winddirection_50m
    case winddirection_80m
    case windgusts_10m
    case windspeed_100m
    case windspeed_10m
    case windspeed_120m
    case windspeed_150m
    case windspeed_180m
    case windspeed_200m
    case windspeed_20m
    case windspeed_40m
    case windspeed_50m
    case windspeed_80m
    case wind_direction_250m
    case wind_direction_300m
    case wind_direction_350m
    case wind_direction_450m
    case wind_direction_100m
    case wind_direction_10m
    case wind_direction_120m
    case wind_direction_140m
    case wind_direction_150m
    case wind_direction_160m
    case wind_direction_180m
    case wind_direction_200m
    case wind_direction_20m
    case wind_direction_40m
    case wind_direction_30m
    case wind_direction_50m
    case wind_direction_80m
    case wind_direction_70m
    case wind_gusts_10m
    case wind_speed_250m
    case wind_speed_300m
    case wind_speed_350m
    case wind_speed_450m
    case wind_speed_100m
    case wind_speed_10m
    case wind_speed_120m
    case wind_speed_140m
    case wind_speed_150m
    case wind_speed_160m
    case wind_speed_180m
    case wind_speed_200m
    case wind_speed_20m
    case wind_speed_40m
    case wind_speed_30m
    case wind_speed_50m
    case wind_speed_70m
    case wind_speed_80m
    case soil_temperature_10_to_35cm
    case soil_temperature_35_to_100cm
    case soil_temperature_100_to_300cm
    case soil_moisture_10_to_35cm
    case soil_moisture_35_to_100cm
    case soil_moisture_100_to_300cm
    case shortwave_radiation_clear_sky
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case boundary_layer_height
    case thunderstorm_probability
    case rain_probability
    case freezing_rain_probability
    case ice_pellets_probability
    case snowfall_probability
    case albedo
    case k_index
    case roughness_length
    case potential_evapotranspiration

    case wind_speed_10m_spread
    case wind_speed_100m_spread
    case wind_direction_10m_spread
    case wind_direction_100m_spread
    case snowfall_spread
    case temperature_2m_spread
    case wind_gusts_10m_spread
    case dew_point_2m_spread
    case cloud_cover_low_spread
    case cloud_cover_mid_spread
    case cloud_cover_high_spread
    case pressure_msl_spread
    case snowfall_water_equivalent_spread
    case snow_depth_spread
    case soil_temperature_0_to_7cm_spread
    case soil_temperature_7_to_28cm_spread
    case soil_temperature_28_to_100cm_spread
    case soil_temperature_100_to_255cm_spread
    case soil_moisture_0_to_7cm_spread
    case soil_moisture_7_to_28cm_spread
    case soil_moisture_28_to_100cm_spread
    case soil_moisture_100_to_255cm_spread
    case shortwave_radiation_spread
    case precipitation_spread
    case direct_radiation_spread
    case boundary_layer_height_spread
    case sea_surface_temperature
    
    /*case wind_u_component_10m
    case wind_v_component_10m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_200m
    case wind_v_component_200m
    case wind_u_component_70m
    case wind_v_component_70m
    case wind_u_component_170m
    case wind_v_component_170m*/
    
    case pm10
    case pm2_5
    case dust
    case aerosol_optical_depth
    case carbon_monoxide
    case carbon_dioxide
    case nitrogen_dioxide
    case ammonia
    case ozone
    case sulphur_dioxide
    case methane
    case alder_pollen
    case birch_pollen
    case grass_pollen
    case mugwort_pollen
    case olive_pollen
    case ragweed_pollen

    case formaldehyde
    case glyoxal
    case non_methane_volatile_organic_compounds
    case pm10_wildfires
    case peroxyacyl_nitrates
    case secondary_inorganic_aerosol
    case residential_elementary_carbon
    case total_elementary_carbon
    case pm2_5_total_organic_matter
    case sea_salt_aerosol
    case nitrogen_monoxide
    
    case european_aqi
    case european_aqi_pm2_5
    case european_aqi_pm10
    case european_aqi_no2
    case european_aqi_o3
    case european_aqi_so2
    case european_aqi_nitrogen_dioxide
    case european_aqi_ozone
    case european_aqi_sulphur_dioxide

    case us_aqi
    case us_aqi_pm2_5
    case us_aqi_pm10
    case us_aqi_no2
    case us_aqi_o3
    case us_aqi_so2
    case us_aqi_co
    case us_aqi_nitrogen_dioxide
    case us_aqi_ozone
    case us_aqi_sulphur_dioxide
    case us_aqi_carbon_monoxide
    
    case wave_direction
    case wave_height
    case wave_period
    case wave_peak_period
    case wind_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    case secondary_swell_wave_height
    case secondary_swell_wave_period
    case secondary_swell_wave_direction
    case tertiary_swell_wave_height
    case tertiary_swell_wave_period
    case tertiary_swell_wave_direction
    case ocean_current_velocity
    case ocean_current_direction
    case sea_level_height_msl
    case invert_barometer_height


    /// Some variables are kept for backwards compatibility
    var remapped: Self {
        switch self {
        case .temperature:
            return .temperature_2m
        case .windspeed:
            return .wind_speed_10m
        case .winddirection:
            return .wind_direction_10m
        case .surface_air_pressure:
            return .surface_pressure
        default:
            return self
        }
    }
}

/// Available pressure level variables
enum ForecastPressureVariableType: String, GenericVariableMixable {
    case temperature
    case geopotential_height
    case relativehumidity
    case relative_humidity
    case windspeed
    case wind_speed
    case winddirection
    case wind_direction
    case wind_u_component
    case wind_v_component
    case dewpoint
    case dew_point
    case cloudcover
    case cloud_cover
    case vertical_velocity
}

struct ForecastPressureVariable: PressureVariableRespresentable, GenericVariableMixable {
    let variable: ForecastPressureVariableType
    let level: Int
}

/// Available pressure level variables
enum ForecastHeightVariableType: String, GenericVariableMixable {
    case temperature
    case relativehumidity
    case relative_humidity
    case windspeed
    case wind_speed
    case winddirection
    case wind_direction
    case wind_u_component
    case wind_v_component
    case dewpoint
    case dew_point
    case cloudcover
    case cloud_cover
    case vertical_velocity
}

struct ForecastHeightVariable: HeightVariableRespresentable, GenericVariableMixable {
    let variable: ForecastHeightVariableType
    let level: Int
}

typealias ForecastVariable = SurfacePressureAndHeightVariable<VariableAndPreviousDay, ForecastPressureVariable, ForecastHeightVariable>

extension ForecastVariable {
    var variableAndPreviousDay: (ForecastVariable, Int) {
        switch self {
        case .surface(let surface):
            return (ForecastVariable.surface(.init(surface.variable.remapped, 0)), surface.previousDay)
        case .pressure(let pressure):
            return (ForecastVariable.pressure(pressure), 0)
        case .height(let height):
            return (ForecastVariable.height(height), 0)
        }
    }
}


struct VariableHourlyDeriver<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias VariableOpt = ForecastVariable
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: ForecastSurfaceVariable) -> DerivedMapping<Reader.MixingVar>? {
        switch variable {
        case .windspeed_10m:
            return getDeriverMap(variable: .wind_speed_10m)
        case .wind_speed_10m:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_10m"), v: Reader.variableFromString("wind_v_component_10m"))
        case .winddirection_10m:
            return getDeriverMap(variable: .wind_direction_10m)
        case .wind_direction_10m:
            return .windDirection(u: Reader.variableFromString("wind_u_component_10m"), v: Reader.variableFromString("wind_v_component_10m"))
        case .windspeed_100m:
            return getDeriverMap(variable: .wind_speed_100m)
        case .wind_speed_100m:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_100m"), v: Reader.variableFromString("wind_v_component_100m")) ?? .windSpeed(u: Reader.variableFromString("wind_u_component_70m"), v: Reader.variableFromString("wind_v_component_70m"), levelFrom: 70, levelTo: 100)
        case .winddirection_100m:
            return getDeriverMap(variable: .wind_direction_100m)
        case .wind_direction_100m:
            return .windDirection(u: Reader.variableFromString("wind_u_component_100m"), v: Reader.variableFromString("wind_v_component_100m")) ?? .windDirection(u: Reader.variableFromString("wind_u_component_70m"), v: Reader.variableFromString("wind_v_component_70m"))
        case .windspeed_200m:
            return getDeriverMap(variable: .wind_speed_200m)
        case .wind_speed_200m:
            return .windSpeed(u: Reader.variableFromString("wind_u_component_200m"), v: Reader.variableFromString("wind_v_component_200m")) ?? .windSpeed(u: Reader.variableFromString("wind_u_component_170m"), v: Reader.variableFromString("wind_v_component_170m"), levelFrom: 170, levelTo: 200)
        case .winddirection_200m:
            return getDeriverMap(variable: .wind_direction_200m)
        case .wind_direction_200m:
            return .windDirection(u: Reader.variableFromString("wind_u_component_200m"), v: Reader.variableFromString("wind_v_component_200m")) ?? .windDirection(u: Reader.variableFromString("wind_u_component_170m"), v: Reader.variableFromString("wind_v_component_170m"))
        case .apparent_temperature:
            guard
                let wind = getDeriverMap(variable: .windspeed_10m),
                let temp = Reader.variableFromString("temperature_2m"),
                let relhum = getDeriverMap(variable: .relative_humidity_2m),
                let radiation = getDeriverMap(variable: .shortwave_radiation)
            else {
                return nil
            }
            return .four(.mapped(wind), .raw(temp), .mapped(relhum), .mapped(radiation)) {
                windspeed, temperature, relhum, radiation, time in
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature.data, relativehumidity_2m: relhum.data, windspeed_10m: windspeed.data, shortwave_radiation: radiation.data), .celsius)
            }
        case .relativehumidity_2m:
            return getDeriverMap(variable: .relative_humidity_2m)
        case .relative_humidity_2m:
            guard
                let temperature = Reader.variableFromString("temperature_2m"),
                let dew = Reader.variableFromString("dew_point_2m")
            else {
                return nil
            }
            return .two(.raw(temperature), .raw(dew)) { temperature, dew, _ in
                let relativeHumidity = zip(temperature.data, dew.data).map(Meteorology.relativeHumidity)
                return DataAndUnit(relativeHumidity, .percentage)
            }
        case .dewpoint_2m:
            return getDeriverMap(variable: .dew_point_2m)
        case .dew_point_2m:
            guard
                let temperature = Reader.variableFromString("temperature_2m"),
                let rh = Reader.variableFromString("relative_humidity_2m")
            else {
                return nil
            }
            return .two(.raw(temperature), .raw(rh)) { temperature, rh, _ in
                let dewpoint = zip(temperature.data, rh.data).map(Meteorology.dewpoint)
                return DataAndUnit(dewpoint, .percentage)
            }
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            guard
                let temperature = Reader.variableFromString("temperature_2m"),
                let rh = self.getDeriverMap(variable: .relativehumidity_2m)
            else {
                return nil
            }
            return .two(.raw(temperature), .mapped(rh)) { temperature, dewpoint, _ in
                return DataAndUnit(zip(temperature.data, dewpoint.data).map(Meteorology.vaporPressureDeficit), .kilopascal)
            }
        case .et0_fao_evapotranspiration:
            guard
                let wind = getDeriverMap(variable: .windspeed_10m),
                let temp = Reader.variableFromString("temperature_2m"),
                let dew = getDeriverMap(variable: .dewpoint_2m),
                let radiation = getDeriverMap(variable: .shortwave_radiation)
            else {
                return nil
            }
            return .four(.mapped(radiation), .raw(temp), .mapped(wind), .mapped(dew)) { swrad, temperature, windspeed, dewpoint, time in
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let et0 = swrad.data.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature.data[i], windspeed10mMeterPerSecond: windspeed.data[i], dewpointCelsius: dewpoint.data[i], shortwaveRadiationWatts: swrad.data[i], elevation: reader.modelElevation.numeric, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            }
        case .diffuse_radiation:
            guard let swrad = Reader.variableFromString("shortwave_radiation") else {
                return nil
            }
            if let direct = Reader.variableFromString("direct_radiation") {
                return .two(.raw(swrad), .raw(direct)) { swrad, direct, _ in
                    return DataAndUnit(zip(swrad.data, direct.data).map(-), swrad.unit)
                }
            }
            return .one(.raw(swrad)) { swrad, time in
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, .wattPerSquareMetre)
            }
        case .direct_radiation:
            guard let swrad = Reader.variableFromString("shortwave_radiation") else {
                return nil
            }
            if let diffuse = Reader.variableFromString("diffuse_radiation") {
                return .two(.raw(swrad), .raw(diffuse)) { swrad, diffuse, _ in
                    return DataAndUnit(zip(swrad.data, diffuse.data).map(-), swrad.unit)
                }
            }
            return .one(.raw(swrad)) { swrad, time in
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let direct = zip(swrad.data, diffuse).map(-)
                return DataAndUnit(direct, .wattPerSquareMetre)
            }
        case .surface_pressure:
            guard
                let temperature = Reader.variableFromString("temperature_2m"),
                let pressure = Reader.variableFromString("pressure_msl")
            else {
                return nil
            }
            return .two(.raw(temperature), .raw(pressure)) { temperature, pressure, _ in
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature.data, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            }
        case .cloudcover:
            return getDeriverMap(variable: .cloud_cover)
        case .snowfall:
            guard let snowWater = Reader.variableFromString("snowfall_water_equivalent") else {
                return nil
            }
            return .one(.raw(snowWater)) { snowWater, time in
                let snowfall = snowWater.data.map { $0 * 0.7 }
                return DataAndUnit(snowfall, .centimetre)
            }
        case .direct_normal_irradiance:
            guard let directRadiation  = getDeriverMap(variable: .direct_radiation) else {
                return nil
            }
            return .one(.mapped(directRadiation)) { dhi, time in
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            }
        case .rain:
            guard
                let snowwater = Reader.variableFromString("snowfall_water_equivalent"),
                let precip = Reader.variableFromString("precipitation")
            else {
                return nil
            }
            if let showers = Reader.variableFromString("showers") {
                return .three(.raw(precip), .raw(snowwater), .raw(showers)) { precip, snowwater, showers, _ in
                    let rain = zip(precip.data, zip(snowwater.data, showers.data)).map({
                        return max($0.0 - $0.1.0 - $0.1.1, 0)
                    })
                    return DataAndUnit(rain, precip.unit)
                }

            }
            return .two(.raw(precip), .raw(snowwater)) { precip, snowwater, _ in
                let rain = zip(precip.data, snowwater.data).map({
                    return max($0.0 - $0.1, 0)
                })
                return DataAndUnit(rain, precip.unit)
            }
        case .weather_code, .weathercode:
            guard
                let cloudCover = getDeriverMap(variable: .cloud_cover),
                let snowfall = getDeriverMap(variable: .snowfall),
                let precipitation = Reader.variableFromString("precipitation")
            else {
                return nil
            }
            return .weatherCode(
                cloudcover: .mapped(cloudCover),
                precipitation: precipitation,
                convectivePrecipitation: Reader.variableFromString("showers"),
                snowfallCentimeters: .mapped(snowfall),
                gusts: Reader.variableFromString("wind_gusts_10m"),
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil
            )
        case .is_day:
            return .independent({ time in
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            })

        case .terrestrial_radiation:
            return .independent({ time in
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            })
        case .terrestrial_radiation_instant:
            return .independent({ time in
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            })
        case .shortwave_radiation_instant:
            guard let radiation = getDeriverMap(variable: .shortwave_radiation) else {
                return nil
            }
            return .one(.mapped(radiation)) { sw, time in
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            }
        case .direct_normal_irradiance_instant:
            guard let directRadiation  = getDeriverMap(variable: .direct_radiation) else {
                return nil
            }
            return .one(.mapped(directRadiation)) { direct, time in
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            }
        case .direct_radiation_instant:
            guard let directRadiation  = getDeriverMap(variable: .direct_radiation) else {
                return nil
            }
            return .one(.mapped(directRadiation)) { direct, time in
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            }
        case .diffuse_radiation_instant:
            guard let diffuseRadiation  = getDeriverMap(variable: .diffuse_radiation) else {
                return nil
            }
            return .one(.mapped(diffuseRadiation)) { diff, time in
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            }
        case .wet_bulb_temperature_2m:
            guard
                let temperature = Reader.variableFromString("temperature_2m"),
                let rh = self.getDeriverMap(variable: .relativehumidity_2m)
            else {
                return nil
            }
            return .two(.raw(temperature), .mapped(rh)) { temperature, rh, _ in
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)

            }
        case .global_tilted_irradiance:
            guard
                let directRadiation = getDeriverMap(variable: .direct_radiation),
                let diffuseRadiation = getDeriverMap(variable: .diffuse_radiation)
            else {
                return nil
            }
            return .two(.mapped(directRadiation), .mapped(diffuseRadiation)) { directRadiation, diffuseRadiation, time in
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation.data, diffuseRadiation: diffuseRadiation.data, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }

        case .global_tilted_irradiance_instant:
            guard
                let directRadiation = getDeriverMap(variable: .direct_radiation),
                let diffuseRadiation = getDeriverMap(variable: .diffuse_radiation)
            else {
                return nil
            }
            return .two(.mapped(directRadiation), .mapped(diffuseRadiation)) { directRadiation, diffuseRadiation, time in
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation.data, diffuseRadiation: diffuseRadiation.data, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        default:
            return nil
        }
    }
    
    
    func getDeriverMap(variable: ForecastVariable) -> DerivedMapping<Reader.MixingVar>? {
        if let variable = Reader.variableFromString(variable.rawValue) {
            return .direct(variable)
        }
        switch variable {
        case .surface(let variable):
            return getDeriverMap(variable: variable.variable)
        case .pressure(_):
            return nil
        case .height(_):
            return nil
        }
        
    }
}
