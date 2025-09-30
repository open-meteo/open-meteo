
import Foundation

enum EcmwfEcdpsIfsVariableDerived: String, GenericVariableMixable {
    case relativehumidity_2m
    case relative_humidity_2m
    case dewpoint_2m
    case apparent_temperature
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case et0_fao_evapotranspiration
    case windspeed_10m
    case windspeed_100m
    case windspeed_200m
    case wind_speed_10m
    case wind_speed_100m
    case wind_speed_200m
    case wind_direction_10m
    case wind_direction_100m
    case wind_direction_200m
    case winddirection_10m
    case winddirection_100m
    case winddirection_200m
    case soil_temperature_0_7cm
    case soil_temperature_0_10cm
    case soil_temperature_0_to_10cm
    case weathercode
    case weather_code
    case snowfall
    case is_day
    case surface_air_pressure
    case skin_temperature
    case surface_pressure
    case soil_temperature_0cm
    case rain
    case wet_bulb_temperature_2m

    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high

    case sunshine_duration
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    
    case soil_moisture_0_to_100cm
    case soil_temperature_0_to_100cm
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_7_to_28cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_0_to_100cm

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}


struct EcmwfEcpdsReader: GenericReaderDerived, GenericReaderProtocol {
    let reader: GenericReaderCached<EcmwfEcpdsDomain, Variable>

    let options: GenericReaderOptions

    typealias Domain = EcmwfEcpdsDomain

    typealias Variable = EcmwfEcdpsIfsVariable

    typealias Derived = EcmwfEcdpsIfsVariableDerived

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, Variable>(domain: domain, position: gridpoint, options: options)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func prefetchData(raw: Variable, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }

    func get(raw: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await reader.get(variable: raw, time: time)
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .wind_speed_10m, .windspeed_10m:
            let v = try await get(raw: .wind_v_component_10m, time: time)
            let u = try await get(raw: .wind_u_component_10m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_10m, .winddirection_10m:
            let v = try await get(raw: .wind_v_component_10m, time: time)
            let u = try await get(raw: .wind_u_component_10m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_100m, .windspeed_100m:
            let v = try await get(raw: .wind_v_component_100m, time: time)
            let u = try await get(raw: .wind_u_component_100m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_200m, .windspeed_200m:
            let v = try await get(raw: .wind_v_component_200m, time: time)
            let u = try await get(raw: .wind_u_component_200m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_100m, .winddirection_100m:
            let v = try await get(raw: .wind_v_component_100m, time: time)
            let u = try await get(raw: .wind_u_component_100m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_200m, .winddirection_200m:
            let v = try await get(raw: .wind_v_component_200m, time: time)
            let u = try await get(raw: .wind_u_component_200m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_to_10cm, .soil_temperature_0_10cm, .soil_temperature_0_7cm:
            return try await get(raw: .soil_temperature_0_to_7cm, time: time)
        case .weather_code, .weathercode:
            let cloudcover = try await get(raw: .cloud_cover, time: time).data
            let precipitation = try await get(raw: .precipitation, time: time).data
            let snowfall = try await get(derived: .snowfall, time: time).data
            let cape = try await get(raw: .cape, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: cape,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        case .snowfall:
            let snow = try await get(raw: .snowfall_water_equivalent, time: time).data.map({ $0 * 0.7 })
            return DataAndUnit(snow, .centimetre)
        case .rain:
            let precipitation = try await get(raw: .precipitation, time: time)
            let snow = try await get(raw: .snowfall_water_equivalent, time: time).data
            let showers = try await get(raw: .showers, time: time).data
            return DataAndUnit(zip(precipitation.data, zip(snow, showers)).map { max($0 - $1.0 - $1.1, 0) }, .millimetre)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .soil_temperature_0cm, .skin_temperature:
            return try await get(raw: .surface_temperature, time: time)
        case .surface_air_pressure, .surface_pressure:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let pressure = try await get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
        case .relativehumidity_2m, .relative_humidity_2m:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let dew = try await get(raw: .dew_point_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percentage)
        case .dewpoint_2m:
            return try await get(raw: .dew_point_2m, time: time)
        case .apparent_temperature:
            let windspeed = try await get(derived: .windspeed_10m, time: time).data
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let relhum = try await get(derived: .relativehumidity_2m, time: time).data
            let swrad = try await get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: swrad), .celsius)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let rh = try await get(derived: .relativehumidity_2m, time: time).data
            let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
            return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .wet_bulb_temperature_2m:
            let temperature = try await get(raw: .temperature_2m, time: time)
            let rh = try await get(derived: .relativehumidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover:
            return try await get(raw: .cloud_cover, time: time)
        case .cloudcover_low:
            return try await get(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            return try await get(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            return try await get(raw: .cloud_cover_high, time: time)
        case .terrestrial_radiation:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .terrestrial_radiation_instant:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .shortwave_radiation_instant:
            let sw = try await get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance:
            let dhi = try await get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .direct_normal_irradiance_instant:
            let direct = try await get(raw: .direct_radiation, time: time)
            let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
            return DataAndUnit(dni, direct.unit)
        case .diffuse_radiation:
            let swrad = try await get(raw: .shortwave_radiation, time: time).data
            let direct = try await get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad, direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMetre)
        case .direct_radiation_instant:
            let direct = try await get(raw: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try await get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .global_tilted_irradiance:
            let directRadiation = try await get(raw: .direct_radiation, time: time).data
            let diffuseRadiation = try await get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try await get(raw: .direct_radiation, time: time).data
            let diffuseRadiation = try await get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time.time)
            let swrad = try await get(raw: .shortwave_radiation, time: time).data
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let windspeed = try await get(derived: .windspeed_10m, time: time).data
            let dewpoint = try await get(raw: .dew_point_2m, time: time).data
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation.numeric, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
            }
            return DataAndUnit(et0, .millimetre)
        case .sunshine_duration:
            let directRadiation = try await get(raw: .direct_radiation, time: time)
            let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(duration, .seconds)
        case .soil_moisture_0_to_100cm:
            let sm0_7 = try await get(raw: .soil_moisture_0_to_7cm, time: time)
            let sm7_28 = try await get(raw: .soil_moisture_7_to_28cm, time: time).data
            let sm28_100 = try await get(raw: .soil_moisture_28_to_100cm, time: time).data
            return DataAndUnit(zip(sm0_7.data, zip(sm7_28, sm28_100)).map({
                let (sm0_7, (sm7_28, sm28_100)) = $0
                return sm0_7 * 0.07 + sm7_28 * (0.28 - 0.07) + sm28_100 * (1 - 0.28)
            }), sm0_7.unit)
        case .soil_temperature_0_to_100cm:
            let st0_7 = try await get(raw: .soil_temperature_0_to_7cm, time: time)
            let st7_28 = try await get(raw: .soil_temperature_7_to_28cm, time: time).data
            let st28_100 = try await get(raw: .soil_temperature_28_to_100cm, time: time).data
            return DataAndUnit(zip(st0_7.data, zip(st7_28, st28_100)).map({
                let (st0_7, (st7_28, st28_100)) = $0
                return st0_7 * 0.07 + st7_28 * (0.28 - 0.07) + st28_100 * (1 - 0.28)
            }), st0_7.unit)
        case .growing_degree_days_base_0_limit_50:
            let base: Float = 0
            let limit: Float = 50
            let t2m = try await get(raw: .temperature_2m, time: time).data
            return DataAndUnit(t2m.map({ t2m in
                max(min(t2m, limit) - base, 0) / 24
            }), .gddCelsius)
        case .leaf_wetness_probability:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let dewpoint = try await get(raw: .dew_point_2m, time: time).data
            let precipitation = try await get(raw: .precipitation, time: time).data
            return DataAndUnit(zip(zip(temperature, dewpoint), precipitation).map( {
                let ((temperature, dewpoint), precipitation) = $0
                return Meteorology.leafwetnessPorbability(temperature2mCelsius: temperature, dewpointCelsius: dewpoint, precipitation: precipitation)
            }), .percentage)
        case .soil_moisture_index_0_to_7cm:
            guard let soilType = try await self.getStatic(type: .soilType) else {
                throw ForecastApiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try await get(raw: .soil_moisture_0_to_7cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_7_to_28cm:
            guard let soilType = try await self.getStatic(type: .soilType) else {
                throw ForecastApiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try await get(raw: .soil_moisture_7_to_28cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_28_to_100cm:
            guard let soilType = try await self.getStatic(type: .soilType) else {
                throw ForecastApiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try await get(raw: .soil_moisture_28_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_100_to_255cm:
            guard let soilType = try await self.getStatic(type: .soilType) else {
                throw ForecastApiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try await get(raw: .soil_moisture_100_to_255cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_0_to_100cm:
            guard let soilType = try await self.getStatic(type: .soilType) else {
                throw ForecastApiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try await get(derived: .soil_moisture_0_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        }
    }

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .terrestrial_radiation, .terrestrial_radiation_instant:
            break
        case .shortwave_radiation_instant:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .diffuse_radiation_instant:
            try await prefetchData(derived: .diffuse_radiation, time: time)
        case .direct_radiation_instant:
            try await prefetchData(raw: .direct_radiation, time: time)
        case .direct_normal_irradiance_instant:
            try await prefetchData(raw: .direct_radiation, time: time)
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .direct_normal_irradiance:
            try await prefetchData(raw: .direct_radiation, time: time)
        case .global_tilted_irradiance, .global_tilted_irradiance_instant, .diffuse_radiation:
            try await prefetchData(raw: .shortwave_radiation, time: time)
            try await prefetchData(raw: .direct_radiation, time: time)
        case .windspeed_100m, .wind_speed_100m, .winddirection_100m, .wind_direction_100m:
            try await prefetchData(raw: .wind_u_component_100m, time: time)
            try await prefetchData(raw: .wind_v_component_100m, time: time)
        case .windspeed_200m, .wind_speed_200m, .winddirection_200m, .wind_direction_200m:
            try await prefetchData(raw: .wind_u_component_200m, time: time)
            try await prefetchData(raw: .wind_v_component_200m, time: time)
        case .windspeed_10m, .wind_speed_10m, .wind_direction_10m, .winddirection_10m:
            try await prefetchData(raw: .wind_u_component_10m, time: time)
            try await prefetchData(raw: .wind_v_component_10m, time: time)
        case .soil_temperature_0_to_10cm, .soil_temperature_0_10cm, .soil_temperature_0_7cm:
            try await prefetchData(raw: .soil_temperature_0_to_7cm, time: time)
        case .weather_code, .weathercode:
            try await prefetchData(raw: .cloud_cover, time: time)
            try await prefetchData(derived: .snowfall, time: time)
            try await prefetchData(raw: .precipitation, time: time)
            try await prefetchData(raw: .cape, time: time)
        case .rain:
            try await prefetchData(raw: .precipitation, time: time)
            try await prefetchData(raw: .snowfall_water_equivalent, time: time)
            try await prefetchData(raw: .showers, time: time)
        case .snowfall:
            try await prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .is_day:
            break
        case .skin_temperature, .soil_temperature_0cm:
            try await prefetchData(raw: .surface_temperature, time: time)
        case .surface_air_pressure, .surface_pressure:
            try await prefetchData(raw: .pressure_msl, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .relativehumidity_2m, .relative_humidity_2m:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
        case .dewpoint_2m:
            try await prefetchData(raw: .dew_point_2m, time: time)
        case .apparent_temperature:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .wind_u_component_10m, time: time)
            try await prefetchData(raw: .wind_v_component_10m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .direct_radiation, time: time)
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            try await prefetchData(derived: .relative_humidity_2m, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .wet_bulb_temperature_2m:
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .cloudcover:
            try await prefetchData(raw: .cloud_cover, time: time)
        case .cloudcover_low:
            try await prefetchData(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            try await prefetchData(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            try await prefetchData(raw: .cloud_cover_high, time: time)
        case .et0_fao_evapotranspiration:
            try await prefetchData(raw: .shortwave_radiation, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(derived: .wind_speed_10m, time: time)
        case .soil_moisture_0_to_100cm:
            try await prefetchData(raw: .soil_moisture_0_to_7cm, time: time)
            try await prefetchData(raw: .soil_moisture_7_to_28cm, time: time)
            try await prefetchData(raw: .soil_moisture_28_to_100cm, time: time)
        case .soil_temperature_0_to_100cm:
            try await prefetchData(raw: .soil_temperature_0_to_7cm, time: time)
            try await prefetchData(raw: .soil_temperature_7_to_28cm, time: time)
            try await prefetchData(raw: .soil_temperature_28_to_100cm, time: time)
        case .growing_degree_days_base_0_limit_50:
            try await prefetchData(raw: .temperature_2m, time: time)
        case .leaf_wetness_probability:
            try await prefetchData(raw: .precipitation, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .soil_moisture_index_0_to_7cm:
            try await prefetchData(raw: .soil_moisture_0_to_7cm, time: time)
        case .soil_moisture_index_7_to_28cm:
            try await prefetchData(raw: .soil_moisture_7_to_28cm, time: time)
        case .soil_moisture_index_28_to_100cm:
            try await prefetchData(raw: .soil_moisture_28_to_100cm, time: time)
        case .soil_moisture_index_100_to_255cm:
            try await prefetchData(raw: .soil_moisture_100_to_255cm, time: time)
        case .soil_moisture_index_0_to_100cm:
            try await prefetchData(derived: .soil_moisture_0_to_100cm, time: time)
        case .sunshine_duration:
            try await prefetchData(raw: .direct_radiation, time: time)
        }
    }
}
