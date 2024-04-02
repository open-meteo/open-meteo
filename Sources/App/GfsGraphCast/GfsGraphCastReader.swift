

enum GfsGraphCastVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case windspeed_10m
    case winddirection_10m
    case wind_speed_10m
    case wind_direction_10m
    case surface_pressure
    case weathercode
    case weather_code
    case is_day
    case rain
    case snowfall
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum GfsGraphCastPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case wind_speed
    case wind_direction
    case dew_point
    case relativehumidity
    case cloudcover
    case cloud_cover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsGraphCastPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: GfsGraphCastPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias GfsGraphCastVariableDerived = SurfaceAndPressureVariable<GfsGraphCastVariableDerivedSurface, GfsGraphCastPressureVariableDerived>

typealias GfsGraphCastVariableCombined = VariableOrDerived<GfsGraphCastVariable, GfsGraphCastVariableDerived>

struct GfsGraphCastReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = GfsGraphCastDomain
    
    typealias Variable = GfsGraphCastVariable
    
    typealias Derived = GfsGraphCastVariableDerived
    
    typealias MixingVar = GfsGraphCastVariableCombined
    
    let reader: GenericReaderCached<GfsGraphCastDomain, GfsGraphCastVariable>
    
    let options: GenericReaderOptions
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    func get(raw: GfsGraphCastVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: GfsGraphCastVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func prefetchData(variable: GfsGraphCastSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }
    
    func get(raw: GfsGraphCastSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(derived: GfsGraphCastVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .wind_speed_10m, .windspeed_10m, .wind_direction_10m, .winddirection_10m:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .surface_pressure:
                try prefetchData(variable: .pressure_msl, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
            case .weather_code, .weathercode:
                try prefetchData(variable: .cloud_cover, time: time)
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
            case .is_day:
                break
            case .cloudcover:
                try prefetchData(variable: .cloud_cover, time: time)
            case .cloudcover_low:
                try prefetchData(variable: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try prefetchData(variable: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try prefetchData(variable: .cloud_cover_high, time: time)
            case .rain, .snowfall:
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed:
                fallthrough
            case .winddirection, .wind_direction:
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .relativehumidity:
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try prefetchData(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: GfsGraphCastVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m, .wind_speed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_10m, .wind_direction_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let pressure = try get(raw: .pressure_msl, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .weathercode, .weather_code:
                let cloudcover = try get(raw: .cloud_cover, time: time).data
                let precipitation = try get(raw: .precipitation, time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
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
            case .cloudcover:
                return try get(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                return try get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try get(raw: .cloud_cover_high, time: time)
            case .snowfall:
                let temperature = try get(raw: .temperature_2m, time: time)
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimetre)
            case .rain:
                let temperature = try get(raw: .temperature_2m, time: time)
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 1 : 0) }), .millimetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed:
                let u = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection, .wind_direction:
                let u = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint, .dew_point:
                let temperature = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percentage)
            case .relativehumidity:
                return try get(raw: .pressure(GfsGraphCastPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}
