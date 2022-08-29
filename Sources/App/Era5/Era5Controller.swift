import Foundation
import Vapor


/**
 TODO time arrays in large history responses are very inefficient
 */
struct Era5Controller {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "archive-api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(Era5Query.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            
            let allowedRange = Timestamp(1959, 1, 1) ..< Timestamp.now()
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            guard let reader = try Era5Reader(domain: Era5.era5, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised, time: hourlyTime) else {
                fatalError("Not possible, ERA5 is global")
            }
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                try reader.prefetchData(variables: hourlyVariables)
            }
            if let dailyVariables = params.daily {
                try reader.prefetchData(variables: dailyVariables)
            }
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count)
                for variable in variables {
                    let d = try reader.get(variable: variable).convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit).toApi(name: variable.name)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            let daily: ApiSection? = try params.daily.map { dailyVariables in
                var res = [ApiColumn]()
                res.reserveCapacity(dailyVariables.count)
                var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                
                for variable in dailyVariables {
                    if variable == .sunrise || variable == .sunset {
                        // only calculate sunrise/set once
                        let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.range, lat: params.latitude, lon: params.longitude, utcOffsetSeconds: time.utcOffsetSeconds)
                        riseSet = times
                        if variable == .sunset {
                            res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.set)))
                        } else {
                            res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.rise)))
                        }
                        continue
                    }
                    let d = try reader.getDaily(variable: variable, params: params).toApi(name: variable.rawValue)
                    assert(dailyTime.count == d.data.count)
                    res.append(d)
                }
                return ApiSection(name: "daily", time: dailyTime, columns: res)
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.modelElevation,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly, daily].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            //let response = Response()
            //try response.content.encode(out, as: .json)

            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

typealias Era5HourlyVariable = VariableOrDerived<Era5Variable, Era5VariableDerived>

enum Era5VariableDerived: String, Codable {
    case apparent_temperature
    case relativehumidity_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case vapor_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case direct_normal_irradiance
}

enum Era5DailyWeatherVariable: String, Codable {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case snowfall_sum
    case rain_sum
    case shortwave_radiation_sum
    // cloudcover_total_max?
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
    /// TODO implement aggregation
    //case sunshine_hours
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
}

struct Era5Query: Content, QueryWithTimezone {
    let latitude: Float
    let longitude: Float
    let hourly: [Era5HourlyVariable]?
    let daily: [Era5DailyWeatherVariable]?
    //let current_weather: Bool?
    let elevation: Float?
    //let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let format: ForecastResultFormat?
    let timezone: String?
    
    /// iso starting date `2022-02-01`
    let start_date: IsoDate
    /// included end date `2022-06-01`
    let end_date: IsoDate
    
    func validate() throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        guard end_date.date >= start_date.date else {
            throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
        }
        guard start_date.year >= 1959, start_date.year <= 2030 else {
            throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: Timestamp(1959,1,1)..<Timestamp(2031,1,1))
        }
        guard end_date.year >= 1959, end_date.year <= 2030 else {
            throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: Timestamp(1959,1,1)..<Timestamp(2031,1,1))
        }
        if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }
    }
    
    func getTimerange(timezone: TimeZone, allowedRange: Range<Timestamp>) throws -> TimerangeLocal {
        let start = start_date.toTimestamp()
        let includedEnd = end_date.toTimestamp()
        guard includedEnd.timeIntervalSince1970 >= start.timeIntervalSince1970 else {
            throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
        }
        guard allowedRange.contains(start) else {
            throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: allowedRange)
        }
        guard allowedRange.contains(includedEnd) else {
            throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: allowedRange)
        }
        let utcOffsetSeconds = (timezone.secondsFromGMT() / 3600) * 3600
        
        return TimerangeLocal(range: start.add(-1 * utcOffsetSeconds) ..< includedEnd.add(86400 - utcOffsetSeconds), utcOffsetSeconds: utcOffsetSeconds)
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
    
    /*func getUtcOffsetSeconds() throws -> Int {
        guard let timezone = timezone else {
            return 0
        }
        guard let tz = TimeZone(identifier: timezone) else {
            throw ForecastapiError.invalidTimezone
        }
        return (tz.secondsFromGMT() / 3600) * 3600
    }*/
}

typealias Era5Reader = GenericReader<Era5, Era5Variable>

extension Era5Reader {
    func prefetchData(variables: [Era5HourlyVariable]) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(variable: v)
            case .derived(let v):
                try prefetchData(derived: v)
            }
        }
    }
    
    func prefetchData(derived: Era5VariableDerived) throws {
        switch derived {
        case .windspeed_10m:
            try prefetchData(variable: .wind_u_component_10m)
            try prefetchData(variable: .wind_v_component_10m)
        case .apparent_temperature:
            try prefetchData(variable: .temperature_2m)
            try prefetchData(variable: .wind_u_component_10m)
            try prefetchData(variable: .wind_v_component_10m)
            try prefetchData(variable: .dewpoint_2m)
            try prefetchData(variable: .direct_radiation)
            try prefetchData(variable: .shortwave_radiation)
        case .relativehumidity_2m:
            try prefetchData(variable: .temperature_2m)
            try prefetchData(variable: .dewpoint_2m)
        case .winddirection_10m:
            try prefetchData(variable: .wind_u_component_10m)
            try prefetchData(variable: .wind_v_component_10m)
        case .windspeed_100m:
            try prefetchData(variable: .wind_u_component_100m)
            try prefetchData(variable: .wind_v_component_100m)
        case .winddirection_100m:
            try prefetchData(variable: .wind_u_component_100m)
            try prefetchData(variable: .wind_v_component_100m)
        case .vapor_pressure_deficit:
            try prefetchData(variable: .temperature_2m)
            try prefetchData(variable: .dewpoint_2m)
        case .diffuse_radiation:
            try prefetchData(variable: .shortwave_radiation)
            try prefetchData(variable: .direct_radiation)
        case .et0_fao_evapotranspiration:
            try prefetchData(variable: .direct_radiation)
            try prefetchData(derived: .diffuse_radiation)
            try prefetchData(variable: .temperature_2m)
            try prefetchData(variable: .dewpoint_2m)
            try prefetchData(variable: .wind_u_component_100m)
            try prefetchData(variable: .wind_v_component_100m)
        case .surface_pressure:
            try prefetchData(variable: .pressure_msl)
        case .snowfall:
            try prefetchData(variable: .snowfall_water_equivalent)
        case .cloudcover:
            try prefetchData(variable: .cloudcover_low)
            try prefetchData(variable: .cloudcover_mid)
            try prefetchData(variable: .cloudcover_high)
        case .direct_normal_irradiance:
            try prefetchData(variable: .direct_radiation)
        case .rain:
            try prefetchData(variable: .precipitation)
            try prefetchData(variable: .snowfall_water_equivalent)
        }
    }
    
    func prefetchData(variables: [Era5DailyWeatherVariable]) throws {
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(variable: .temperature_2m)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(variable: .temperature_2m)
                try prefetchData(variable: .wind_u_component_10m)
                try prefetchData(variable: .wind_v_component_10m)
                try prefetchData(variable: .dewpoint_2m)
                try prefetchData(variable: .shortwave_radiation)
            case .precipitation_sum:
                try prefetchData(variable: .precipitation)
            case .shortwave_radiation_sum:
                try prefetchData(variable: .shortwave_radiation)
            case .windspeed_10m_max:
                try prefetchData(variable: .wind_u_component_10m)
                try prefetchData(variable: .wind_v_component_10m)
            case .windgusts_10m_max:
                try prefetchData(variable: .windgusts_10m)
            case .winddirection_10m_dominant:
                try prefetchData(variable: .wind_u_component_10m)
                try prefetchData(variable: .wind_v_component_10m)
            case .precipitation_hours:
                try prefetchData(variable: .precipitation)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .shortwave_radiation)
                try prefetchData(variable: .temperature_2m)
                try prefetchData(variable: .dewpoint_2m)
                try prefetchData(variable: .wind_u_component_10m)
                try prefetchData(variable: .wind_v_component_10m)
            case .snowfall_sum:
                try prefetchData(variable: .snowfall_water_equivalent)
            case .rain_sum:
                try prefetchData(variable: .precipitation)
                try prefetchData(variable: .snowfall_water_equivalent)
            }
        }
    }
    
    func get(variable: Era5HourlyVariable) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(variable: variable)
        case .derived(let variable):
            return try get(derived: variable)
        }
    }
    
    
    func get(derived: Era5VariableDerived) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m:
            let u = try get(variable: .wind_u_component_10m)
            let v = try get(variable: .wind_v_component_10m)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .apparent_temperature:
            let windspeed = try get(derived: .windspeed_10m).data
            let temperature = try get(variable: .temperature_2m).data
            let relhum = try get(derived: .relativehumidity_2m).data
            let radiation = try get(variable: .shortwave_radiation).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .relativehumidity_2m:
            let temperature = try get(variable: .temperature_2m).data
            let dew = try get(variable: .dewpoint_2m).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percent)
        case .winddirection_10m:
            let u = try get(variable: .wind_u_component_10m).data
            let v = try get(variable: .wind_v_component_10m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_100m:
            let u = try get(variable: .wind_u_component_100m)
            let v = try get(variable: .wind_v_component_100m)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_100m:
            let u = try get(variable: .wind_u_component_100m).data
            let v = try get(variable: .wind_v_component_100m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .vapor_pressure_deficit:
            let temperature = try get(variable: .temperature_2m).data
            let dewpoint = try get(variable: .dewpoint_2m).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time)
            let swrad = try get(variable: .shortwave_radiation).data
            let temperature = try get(variable: .temperature_2m).data
            let windspeed = try get(derived: .windspeed_10m).data
            let dewpoint = try get(variable: .dewpoint_2m).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .diffuse_radiation:
            let swrad = try get(variable: .shortwave_radiation).data
            let direct = try get(variable: .direct_radiation).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMeter)
        case .surface_pressure:
            let temperature = try get(variable: .temperature_2m).data
            let pressure = try get(variable: .pressure_msl)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: modelElevation), pressure.unit)
        case .cloudcover:
            let low = try get(variable: .cloudcover_low).data
            let mid = try get(variable: .cloudcover_mid).data
            let high = try get(variable: .cloudcover_high).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .snowfall:
            let snowwater = try get(variable: .snowfall_water_equivalent).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimeter)
        case .direct_normal_irradiance:
            let dhi = try get(variable: .direct_radiation).data
            let dni = Zensun.caluclateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .rain:
            let snowwater = try get(variable: .snowfall_water_equivalent)
            let precip = try get(variable: .precipitation)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        }
    }
    
    
    func getDaily(variable: Era5DailyWeatherVariable, params: Era5Query) throws -> DataAndUnit {
        switch variable {
        case .temperature_2m_max:
            let data = try get(variable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(variable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(derived: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(derived: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(variable: .precipitation).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: .shortwave_radiation).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(derived: .windspeed_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(variable: .windgusts_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(variable: .wind_u_component_10m).data.sum(by: 24)
            let v = try get(variable: .wind_v_component_10m).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .precipitation_hours:
            let data = try get(variable: .precipitation).conertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(derived: .et0_fao_evapotranspiration).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(derived: .snowfall).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .rain_sum:
            let data = try get(derived: .rain).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
}
