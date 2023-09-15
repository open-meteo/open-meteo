import Foundation
import Vapor

public struct JmaController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 12)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let paramsHourly = try JmaVariableCombined.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try JmaDailyWeatherVariable.load(commaSeparatedOptional: params.daily)
        let nVariables = (paramsHourly?.count ?? 0) * (paramsDaily?.count ?? 0)
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = [JmaDomain.gsm, .msm]
            
            guard let reader = try JmaMixer(domains: domains, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                    }
                    if let dailyVariables = paramsDaily {
                        try reader.prefetchData(variables: dailyVariables, time: dailyTime)
                    }
                },
                current_weather: params.current_weather == true ? {
                    let starttime = currentTime.floor(toNearest: 3600)
                    let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
                    return {
                        let temperature = try reader.get(variable: .temperature_2m, time: time).convertAndRound(params: params)
                        let winddirection = try reader.get(variable: .winddirection_10m, time: time).convertAndRound(params: params)
                        let windspeed = try reader.get(variable: .windspeed_10m, time: time).convertAndRound(params: params)
                        let weathercode = try reader.get(variable: .weathercode, time: time).convertAndRound(params: params)
                        return ForecastapiResult.CurrentWeather(
                            temperature: temperature.data[0],
                            windspeed: windspeed.data[0],
                            winddirection: winddirection.data[0],
                            weathercode: weathercode.data[0],
                            is_day: try reader.get(variable: .is_day, time: time).convertAndRound(params: params).data[0],
                            temperature_unit: temperature.unit,
                            windspeed_unit: windspeed.unit,
                            winddirection_unit: winddirection.unit,
                            weathercode_unit: weathercode.unit,
                            time: starttime
                        )
                    }
                }() : nil,
                hourly: paramsHourly.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count)
                        for variable in variables {
                            let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name)
                            assert(hourlyTime.count == d.data.count)
                            res.append(d)
                        }
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: paramsDaily.map { dailyVariables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(dailyVariables.count)
                        var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                        
                        for variable in dailyVariables {
                            if variable == .sunrise || variable == .sunset {
                                // only calculate sunrise/set once
                                let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.range, lat: coordinates.latitude, lon: coordinates.longitude, utcOffsetSeconds: time.utcOffsetSeconds)
                                riseSet = times
                                if variable == .sunset {
                                    res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.set)))
                                } else {
                                    res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.rise)))
                                }
                                continue
                            }
                            let d = try reader.getDaily(variable: variable, params: params, time: dailyTime).toApi(name: variable.rawValue)
                            assert(dailyTime.count == d.data.count)
                            res.append(d)
                        }
                        return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: res)
                    }
                },
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}


enum JmaDailyWeatherVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case shortwave_radiation_sum
    case windspeed_10m_max
    case winddirection_10m_dominant
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
    case weathercode
    case snowfall_sum
}

enum JmaVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumitidy_2m
    case dewpoint_2m
    case windspeed_10m
    case winddirection_10m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case snowfall
    case is_day
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum JmaPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct JmaPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: JmaPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias JmaVariableDerived = SurfaceAndPressureVariable<JmaVariableDerivedSurface, JmaPressureVariableDerived>

typealias JmaVariableCombined = VariableOrDerived<JmaVariable, JmaVariableDerived>

struct JmaReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = JmaVariableCombined
    
    typealias Domain = JmaDomain
    
    typealias Variable = JmaVariable
    
    typealias Derived = JmaVariableDerived
    
    var reader: GenericReaderCached<JmaDomain, JmaVariable>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(raw: JmaSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(raw: .surface(raw), time: time)
    }
    
    func get(raw: JmaSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        try get(raw: .surface(raw), time: time)
    }
    
    func prefetchData(derived: JmaVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .relativehumitidy_2m:
                try prefetchData(raw: .relativehumidity_2m, time: time)
            case .windspeed_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .winddirection_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .vapor_pressure_deficit:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .shortwave_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .surface_pressure:
                try prefetchData(raw: .pressure_msl, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dewpoint_2m:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
            case .diffuse_radiation:
                fallthrough
            case .diffuse_radiation_instant:
                fallthrough
            case .direct_normal_irradiance:
                fallthrough
            case .direct_normal_irradiance_instant:
                fallthrough
            case .direct_radiation:
                fallthrough
            case .direct_radiation_instant:
                fallthrough
            case .shortwave_radiation_instant:
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .weathercode:
                try prefetchData(raw: .cloudcover, time: time)
                try prefetchData(variable: .derived(.surface(.snowfall)), time: time)
                try prefetchData(raw: .precipitation, time: time)
            case .snowfall:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .precipitation, time: time)
            case .is_day:
                break
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
            case .cloudcover:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: JmaVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let relhum = try get(raw: .relativehumidity_2m, time: time).data
                let radiation = try get(raw: .shortwave_radiation, time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let rh = try get(raw: .relativehumidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(raw: .shortwave_radiation, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try get(raw: .relativehumidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimeter)
            case .relativehumitidy_2m:
                return try get(raw: .relativehumidity_2m, time: time)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let pressure = try get(raw: .pressure_msl, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .dewpoint_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relativehumidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .shortwave_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(derived: .surface(.direct_radiation), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, .wattPerSquareMeter)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation_instant), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weathercode:
                let cloudcover = try get(raw: .cloudcover, time: time).data
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
                    modelDtHours: time.dtSeconds / 3600), .wmoCode
                )
            case .snowfall:
                let temperature = try get(raw: .temperature_2m, time: time)
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimeter)
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionless_integer)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                let u = try get(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint:
                let temperature = try get(raw: .pressure(JmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(JmaPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                let rh = try get(raw: .pressure(JmaPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percent)
            }
        }
    }
}

struct JmaMixer: GenericReaderMixer {
    let reader: [JmaReader]
    
    static func makeReader(domain: JmaReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> JmaReader? {
        return try JmaReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}

extension JmaMixer {
    func prefetchData(variable: JmaSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }
    
    func get(variable: JmaSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(variable)), time: time)
    }
    
    func get(variable: JmaVariableDerivedSurface, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .derived(.surface(variable)), time: time)
    }
    
    func getDaily(variable: JmaDailyWeatherVariable, params: ApiQueryParameter, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: 3600)
        switch variable {
        case .temperature_2m_max:
            let data = try get(variable: .temperature_2m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(variable: .temperature_2m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(variable: .apparent_temperature, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(variable: .apparent_temperature, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(variable: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: .shortwave_radiation, time: time).convertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(variable: .windspeed_10m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(variable: .wind_u_component_10m, time: time).data.sum(by: 24)
            let v = try get(variable: .wind_v_component_10m, time: time).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .precipitation_hours:
            let data = try get(variable: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(variable: .et0_fao_evapotranspiration, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            let data = try get(variable: .weathercode, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .snowfall_sum:
            let data = try get(variable: .snowfall, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
    
    func prefetchData(variables: [JmaDailyWeatherVariable], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(variable: .temperature_2m, time: time)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .precipitation_sum:
                try prefetchData(variable: .precipitation, time: time)
            case .shortwave_radiation_sum:
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .windspeed_10m_max:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .winddirection_10m_dominant:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .precipitation_hours:
                try prefetchData(variable: .precipitation, time: time)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .shortwave_radiation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .weathercode:
                try prefetchData(variable: .derived(.surface(.weathercode)), time: time)
            case .snowfall_sum:
                try prefetchData(variable: .derived(.surface(.snowfall)), time: time)
            }
        }
    }
}

