enum EcmwfEC46Variable6HourlyDerived: String, RawRepresentableString, GenericVariableMixable {
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

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct EcmwfEC46Controller6Hourly: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>

    let options: GenericReaderOptions

    typealias Domain = EcmwfSeasDomain

    typealias Variable = VariableOrDerived<EcmwfEC46Variable6Hourly, EcmwfEC46Variable6HourlyDerived>

    typealias Derived = EcmwfEC46Variable6HourlyDerived

    public init?(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, EcmwfEC46Variable6Hourly>(domain: .seas5_6hourly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    public init(gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, EcmwfEC46Variable6Hourly>(domain: .seas5_6hourly, position: gridpoint, options: options)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try await prefetchData(raw: v, time: time)
            case .derived(let v):
                try await prefetchData(derived: v, time: time)
            }
        }
    }

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .wind_speed_10m, .windspeed_10m, .wind_direction_10m, .winddirection_10m:
            try await prefetchData(raw: .wind_u_component_10m, time: time)
            try await prefetchData(raw: .wind_v_component_10m, time: time)
        case .wind_speed_100m, .windspeed_100m, .wind_direction_100m, .winddirection_100m:
            try await prefetchData(raw: .wind_u_component_100m, time: time)
            try await prefetchData(raw: .wind_v_component_100m, time: time)
        case .wind_speed_200m, .windspeed_200m, .wind_direction_200m, .winddirection_200m:
            try await prefetchData(raw: .wind_u_component_200m, time: time)
            try await prefetchData(raw: .wind_v_component_200m, time: time)
        case .apparent_temperature:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .wind_u_component_10m, time: time)
            try await prefetchData(raw: .wind_v_component_10m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .relative_humidity_2m, .relativehumidity_2m:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
        case .global_tilted_irradiance, .global_tilted_irradiance_instant, .diffuse_radiation:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try await prefetchData(raw: .shortwave_radiation, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .wind_u_component_10m, time: time)
            try await prefetchData(raw: .wind_v_component_10m, time: time)
        case .surface_pressure:
            try await prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try await prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloudcover:
            try await prefetchData(raw: .cloud_cover, time: time)
        case .direct_normal_irradiance:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .rain:
            try await prefetchData(raw: .precipitation, time: time)
            try await prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .weather_code, .weathercode:
            try await prefetchData(raw: .cloud_cover, time: time)
            try await prefetchData(raw: .precipitation, time: time)
            try await prefetchData(raw: .showers, time: time)
            try await prefetchData(derived: .snowfall, time: time)
        case .is_day:
            break
        case .terrestrial_radiation:
            break
        case .terrestrial_radiation_instant:
            break
        case .shortwave_radiation_instant:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .diffuse_radiation_instant:
            try await prefetchData(derived: .diffuse_radiation, time: time)
        case .direct_radiation_instant:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .direct_normal_irradiance_instant:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .wet_bulb_temperature_2m:
            try await prefetchData(raw: .dew_point_2m, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .dewpoint_2m:
            try await prefetchData(raw: .dew_point_2m, time: time)
        }
    }

    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try await get(raw: variable, time: time)
        case .derived(let variable):
            return try await get(derived: variable, time: time)
        }
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .wind_speed_10m, .windspeed_10m:
            let u = try await get(raw: .wind_u_component_10m, time: time)
            let v = try await get(raw: .wind_v_component_10m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_10m, .winddirection_10m:
            let u = try await get(raw: .wind_u_component_10m, time: time).data
            let v = try await get(raw: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_100m, .windspeed_100m:
            let u = try await get(raw: .wind_u_component_100m, time: time)
            let v = try await get(raw: .wind_v_component_100m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_100m, .winddirection_100m:
            let u = try await get(raw: .wind_u_component_10m, time: time).data
            let v = try await get(raw: .wind_v_component_100m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_200m, .windspeed_200m:
            let u = try await get(raw: .wind_u_component_200m, time: time)
            let v = try await get(raw: .wind_v_component_200m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_200m, .winddirection_200m:
            let u = try await get(raw: .wind_u_component_200m, time: time).data
            let v = try await get(raw: .wind_v_component_200m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .apparent_temperature:
            let windspeed = try await get(derived: .windspeed_10m, time: time).data
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let relhum = try await get(derived: .relativehumidity_2m, time: time).data
            let radiation = try await get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
        case .relative_humidity_2m, .relativehumidity_2m:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let dew = try await get(raw: .dew_point_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percentage)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let dewpoint = try await get(raw: .dew_point_2m, time: time).data
            return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
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
        case .diffuse_radiation:
            let swrad = try await get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(diffuse, .wattPerSquareMetre)
        case .surface_pressure:
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let pressure = try await get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: targetElevation), pressure.unit)
        case .cloudcover:
            return try await get(raw: .cloud_cover, time: time)
        case .snowfall:
            let snowwater = try await get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimetre)
        case .direct_normal_irradiance:
            let dhi = try await get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .rain:
            let snowwater = try await get(raw: .snowfall_water_equivalent, time: time)
            let precip = try await get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0 - $0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .weather_code, .weathercode:
            let cloudcover = try await get(derived: .cloudcover, time: time).data
            let precipitation = try await get(raw: .precipitation, time: time).data
            let showers = try await get(raw: .showers, time: time).data
            let snowfall = try await get(derived: .snowfall, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: precipitation,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .terrestrial_radiation:
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .terrestrial_radiation_instant:
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .shortwave_radiation_instant:
            let sw = try await get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance_instant:
            let direct = try await get(raw: .direct_radiation, time: time)
            let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
            return DataAndUnit(dni, direct.unit)
        case .direct_radiation_instant:
            let direct = try await get(raw: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try await get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .wet_bulb_temperature_2m:
            let temperature = try await get(raw: .temperature_2m, time: time)
            let dew = try await get(raw: .dew_point_2m, time: time).data
            let rh = zip(temperature.data, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(zip(temperature.data, rh).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .dewpoint_2m:
            return try await get(raw: .dew_point_2m, time: time)
        case .global_tilted_irradiance:
            let directRadiation = try await get(raw: .direct_radiation, time: time).data
            let ghi = try await get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try await get(raw: .direct_radiation, time: time).data
            let ghi = try await get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        }
    }
}
