/// On demand calculated variables
enum ArpaeVariableDerived: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case relative_humidity_2m
    case dewpoint_2m
    case windspeed_10m
    case wind_speed_10m
    case winddirection_10m
    case wind_direction_10m
    
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case surface_pressure
    case weathercode
    case weather_code
    case is_day
    case rain
    case snowfall
    case showers
    case wet_bulb_temperature_2m
    case cloudcover
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias ArpaeVariableCombined = VariableOrDerived<ArpaeSurfaceVariable, ArpaeVariableDerived>

struct ArpaeReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = ArpaeDomain
    
    typealias Variable = ArpaeSurfaceVariable
    
    typealias Derived = ArpaeVariableDerived
    
    typealias MixingVar = ArpaeVariableCombined
    
    let reader: GenericReaderCached<ArpaeDomain, ArpaeSurfaceVariable>
    
    let options: GenericReaderOptions
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        let reader = try GenericReader<Domain, Variable>(domain: domain, position: gridpoint)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    func get(raw: ArpaeSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: ArpaeSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func prefetchData(derived: ArpaeVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
        case .relativehumidity_2m, .relative_humidity_2m:
            try prefetchData(raw: .dew_point_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .wind_speed_10m, .wind_direction_10m:
            fallthrough
        case .windspeed_10m, .winddirection_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .dewpoint_2m:
            try prefetchData(raw: .dew_point_2m, time: time)
        case .weathercode, .weather_code:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .cloud_cover, time: time)
        case .is_day:
            break
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
        case .cloudcover:
            try prefetchData(raw: .cloud_cover, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .showers:
            try prefetchData(raw: .precipitation, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        }
    }
    
    func get(derived: ArpaeVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m,. wind_speed_10m:
            let u = try get(raw: .wind_u_component_10m, time: time).data
            let v = try get(raw: .wind_v_component_10m, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .winddirection_10m, .wind_direction_10m:
            let u = try get(raw: .wind_u_component_10m, time: time).data
            let v = try get(raw: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .apparent_temperature:
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time)
            let relhum = zip(temperature, dewpoint.data).map(Meteorology.relativeHumidity)
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: nil), .celsius)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .relativehumidity_2m, .relative_humidity_2m:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time)
            let relhum = zip(temperature, dewpoint.data).map(Meteorology.relativeHumidity)
            return DataAndUnit(relhum, .percentage)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
        case .dewpoint_2m:
            return try get(raw: .dew_point_2m, time: time)
        case .weathercode, .weather_code:
            let cloudcover = try get(raw: .cloud_cover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
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
        case .wet_bulb_temperature_2m:
            let dewpoint = try get(raw: .dew_point_2m, time: time)
            let temperature = try get(raw: .temperature_2m, time: time)
            let relhum = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
            return DataAndUnit(zip(temperature.data, relhum).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover:
            return try get(raw: .cloud_cover, time: time)
        case .rain:
            let precipitation = try get(raw: .precipitation, time: time)
            let snoweq = try get(raw: .snowfall_water_equivalent, time: time)
            return DataAndUnit(zip(precipitation.data, snoweq.data).map({max($0 - $1, 0)}), precipitation.unit)
        case .snowfall:
            let snoweq = try get(raw: .snowfall_water_equivalent, time: time)
            return DataAndUnit(snoweq.data.map{$0*0.7}, .centimetre)
        case .showers:
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(precipitation.data.map({min($0, 0)}), precipitation.unit)
        }
    }
}


struct ArpaeMixer: GenericReaderMixer {
    let reader: [ArpaeReader]
    
    static func makeReader(domain: ArpaeReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> ArpaeReader? {
        return try ArpaeReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
