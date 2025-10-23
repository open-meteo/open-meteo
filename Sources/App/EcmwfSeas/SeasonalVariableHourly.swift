enum SeasonalVariableHourly: String, RawRepresentableString, GenericVariableMixable, FlatBuffersVariable {
    case temperature_2m
    case dew_point_2m
    case pressure_msl
    case sea_surface_temperature
    case wind_u_component_10m
    case wind_v_component_10m
    case snowfall_water_equivalent
    case precipitation
    case shortwave_radiation
    case cloud_cover
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_200m
    case wind_v_component_200m
    case wind_u_component_70m
    case wind_v_component_70m
    case wind_u_component_170m
    case wind_v_component_170m
    case direct_radiation
    case temperature_2m_max
    case temperature_2m_min
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case showers
    case wind_gusts_10m
    case sunshine_duration
    case apparent_temperature
    case dewpoint_2m
    case relativehumidity_2m
    case relative_humidity_2m
    case windspeed_10m
    case wind_speed_10m
    case winddirection_10m
    case wind_direction_10m
    case windspeed_100m
    case wind_speed_100m
    case winddirection_100m
    case wind_direction_100m
    case windspeed_200m
    case wind_speed_200m
    case winddirection_200m
    case wind_direction_200m
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
   
    case direct_normal_irradiance
    case weathercode
    case weather_code
    case is_day
    
    case diffuse_radiation
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case wet_bulb_temperature_2m
    
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature_2m:
            return .init(variable: .temperature, altitude: 2)
        case .dew_point_2m:
            return .init(variable: .dewPoint, altitude: 2)
        case .pressure_msl:
            return .init(variable: .pressureMsl)
        case .sea_surface_temperature:
            return .init(variable: .seaSurfaceTemperature)
        case .wind_u_component_10m:
            return .init(variable: .windUComponent, altitude: 10)
        case .wind_v_component_10m:
            return .init(variable: .windVComponent, altitude: 10)
        case .wind_u_component_70m:
            return .init(variable: .windUComponent, altitude: 70)
        case .wind_v_component_70m:
            return .init(variable: .windVComponent, altitude: 70)
        case .wind_u_component_170m:
            return .init(variable: .windUComponent, altitude: 170)
        case .wind_v_component_170m:
            return .init(variable: .windVComponent, altitude: 170)
        case .snowfall_water_equivalent:
            return .init(variable: .snowfallWaterEquivalent)
        case .precipitation:
            return .init(variable: .precipitation)
        case .shortwave_radiation:
            return .init(variable: .shortwaveRadiation)
        case .soil_temperature_0_to_7cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 7)
        case .soil_temperature_7_to_28cm:
            return .init(variable: .soilTemperature, depth: 7, depthTo: 28)
        case .soil_temperature_28_to_100cm:
            return .init(variable: .soilTemperature, depth: 28, depthTo: 100)
        case .soil_temperature_100_to_255cm:
            return .init(variable: .soilTemperature, depth: 100, depthTo: 255)
        case .soil_moisture_0_to_7cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 7)
        case .soil_moisture_7_to_28cm:
            return .init(variable: .soilMoisture, depth: 7, depthTo: 28)
        case .soil_moisture_28_to_100cm:
            return .init(variable: .soilMoisture, depth: 28, depthTo: 100)
        case .soil_moisture_100_to_255cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 255)
        case .cloud_cover:
            return .init(variable: .cloudCover)
        case .apparent_temperature:
            return .init(variable: .apparentTemperature)
        case .dewpoint_2m:
            return .init(variable: .dewPoint, altitude: 2)
        case .relativehumidity_2m, .relative_humidity_2m:
            return .init(variable: .relativeHumidity, altitude: 2)
        case .windspeed_10m, .wind_speed_10m:
            return .init(variable: .windSpeed, altitude: 10)
        case .winddirection_10m, .wind_direction_10m:
            return .init(variable: .windDirection, altitude: 10)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            return .init(variable: .vapourPressureDeficit)
        case .surface_pressure:
            return .init(variable: .surfacePressure)
        case .snowfall:
            return .init(variable: .snowfall)
        case .rain:
            return .init(variable: .rain)
        case .et0_fao_evapotranspiration:
            return .init(variable: .et0FaoEvapotranspiration)
        case .cloudcover:
            return .init(variable: .cloudCover)
        case .direct_normal_irradiance:
            return .init(variable: .directNormalIrradiance)
        case .weathercode, .weather_code:
            return .init(variable: .weatherCode)
        case .is_day:
            return .init(variable: .isDay)
        case .diffuse_radiation:
            return .init(variable: .diffuseRadiation)
        case .direct_radiation:
            return .init(variable: .directRadiation)
        case .terrestrial_radiation:
            return .init(variable: .terrestrialRadiation)
        case .terrestrial_radiation_instant:
            return .init(variable: .terrestrialRadiationInstant)
        case .shortwave_radiation_instant:
            return .init(variable: .shortwaveRadiationInstant)
        case .diffuse_radiation_instant:
            return .init(variable: .diffuseRadiationInstant)
        case .direct_radiation_instant:
            return .init(variable: .directRadiationInstant)
        case .direct_normal_irradiance_instant:
            return .init(variable: .directNormalIrradianceInstant)
        case .wet_bulb_temperature_2m:
            return .init(variable: .wetBulbTemperature, altitude: 2)
        case .global_tilted_irradiance:
            return .init(variable: .globalTiltedIrradiance)
        case .global_tilted_irradiance_instant:
            return .init(variable: .globalTiltedIrradianceInstant)
        case .wind_u_component_100m:
            return .init(variable: .windUComponent, altitude: 100)
        case .wind_v_component_100m:
            return .init(variable: .windVComponent, altitude: 100)
        case .wind_u_component_200m:
            return .init(variable: .windUComponent, altitude: 200)
        case .wind_v_component_200m:
            return .init(variable: .windVComponent, altitude: 200)
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .showers:
            return .init(variable: .showers)
        case .wind_gusts_10m:
            return .init(variable: .windGusts, altitude: 10)
        case .sunshine_duration:
            return .init(variable: .sunshineDuration)
        case .windspeed_100m, .wind_speed_100m:
            return .init(variable: .windSpeed, altitude: 100)
        case .winddirection_100m, .wind_direction_100m:
            return .init(variable: .windDirection, altitude: 100)
        case .windspeed_200m, .wind_speed_200m:
            return .init(variable: .windSpeed, altitude: 200)
        case .winddirection_200m, .wind_direction_200m:
            return .init(variable: .windDirection, altitude: 200)
        }
    }
}

struct SeasonalForecastDeriverHourly<Reader: GenericReaderProtocol>: GenericDeriverProtocol {
    typealias MixingVar = DerivedMapping<Reader.MixingVar>
    typealias SourceVariable = SeasonalVariableHourly
    
    let reader: Reader
    let options: GenericReaderOptions
    
    func getDeriverMap(variable: SeasonalVariableHourly) -> DerivedMapping<Reader.MixingVar>? {
        if let variable = Reader.variableFromString(variable.rawValue) {
            return .direct(variable)
        }
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
}
