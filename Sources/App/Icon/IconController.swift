import Foundation
import Vapor


public struct IconController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 16)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let paramsMinutely = try IconApiVariable.load(commaSeparatedOptional: params.minutely_15)
        let paramsHourly = try IconApiVariable.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try DailyWeatherVariable.load(commaSeparatedOptional: params.daily)
        let nVariables = (paramsHourly?.count ?? 0) + (paramsMinutely?.count ?? 0) + (paramsDaily?.count ?? 0)
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            // limited to 3 forecast days
            let minutelyTime = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 3, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92).range.range(dtSeconds: 3600/4)
            
            guard let reader = try IconMixer(domains: [.icon, .iconEu, .iconD2], lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            guard let readerMinutely = try IconMixer(domains: [.icon, .iconEu, .iconD2, .iconD2_15min], lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let minutelyVariables = paramsMinutely {
                        for variable in minutelyVariables {
                            switch variable {
                            case .raw(let raw):
                                try readerMinutely.prefetchData(variable: .raw(.init(raw, 0)), time: minutelyTime)
                            case .derived(let derived):
                                try readerMinutely.prefetchData(variable: .derived(.init(derived, 0)), time: minutelyTime)
                            }
                        }
                    }
                    if let hourlyVariables = paramsHourly {
                        for variable in hourlyVariables {
                            switch variable {
                            case .raw(let raw):
                                try reader.prefetchData(variable: .raw(.init(raw, 0)), time: hourlyTime)
                            case .derived(let derived):
                                try reader.prefetchData(variable: .derived(.init(derived, 0)), time: hourlyTime)
                            }
                        }
                    }
                    if let dailyVariables = paramsDaily {
                        try reader.prefetchData(variables: dailyVariables, member: 0, time: dailyTime)
                    }
                },
                current_weather: params.current_weather == true ? {
                    let starttime = currentTime.floor(toNearest: 3600/4)
                    let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600/4)
                    return {
                        let temperature = try readerMinutely.get(raw: .temperature_2m, member: 0, time: time).convertAndRound(params: params)
                        let winddirection = try readerMinutely.get(derived: .winddirection_10m, member: 0, time: time).convertAndRound(params: params)
                        let windspeed = try readerMinutely.get(derived: .windspeed_10m, member: 0, time: time).convertAndRound(params: params)
                        let weathercode = try readerMinutely.get(raw: .weathercode, member: 0, time: time).convertAndRound(params: params)
                        return ForecastapiResult.CurrentWeather(
                            temperature: temperature.data[0],
                            windspeed: windspeed.data[0],
                            winddirection: winddirection.data[0],
                            weathercode: weathercode.data[0],
                            is_day: try readerMinutely.get(derived: .is_day, member: 0, time: time).convertAndRound(params: params).data[0],
                            temperature_unit: temperature.unit,
                            windspeed_unit: windspeed.unit,
                            winddirection_unit: winddirection.unit,
                            weathercode_unit: weathercode.unit,
                            time: starttime
                        )
                    }
                }() : nil,
                current: nil,
                hourly: paramsHourly.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count)
                        for variable in variables {
                            let d = try reader.get(variable: variable, member: 0, time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name)
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
                            let d = try reader.getDaily(variable: variable, member: 0, params: params, time: dailyTime).toApi(name: variable.rawValue)
                            assert(dailyTime.count == d.data.count)
                            res.append(d)
                        }
                        return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: res)
                    }
                },
                sixHourly: nil,
                minutely15: paramsMinutely.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count)
                        for variable in variables {
                            let d = try readerMinutely.get(variable: variable, member: 0, time: minutelyTime).convertAndRound(params: params).toApi(name: variable.name)
                            assert(minutelyTime.count == d.data.count)
                            res.append(d)
                        }
                        return ApiSection(name: "minutely_15", time: minutelyTime.add(utcOffsetShift), columns: res)
                    }
                }
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}


enum DailyWeatherVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case snowfall_sum
    case rain_sum
    case showers_sum
    case weathercode
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
    case updraft_max
}

/// one value 6-18h and then 18-6h
enum DayNightWeatherVariable: String {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case weathercode
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
}

/// overnight 0-6, morning 6-12, afternoon 12-18, evening 18-24
enum OvernightMorningAfternoonEveningWeatherVariable: String {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case weathercode
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
    case cloudcover_total_average
    case relative_humidity_max
}

typealias IconApiVariable = VariableOrDerived<IconVariable, IconVariableDerived>

/**
 Types of pressure level variables
 */
enum IconPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct IconPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: IconPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias IconVariableDerived = SurfaceAndPressureVariable<IconSurfaceVariableDerived, IconPressureVariableDerived>

enum IconSurfaceVariableDerived: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    case windspeed_180m
    case winddirection_180m
    case direct_normal_irradiance
    case evapotranspiration
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case shortwave_radiation
    case snow_height
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case is_day
    
    var requiresOffsetCorrectionForMixing: Bool {
        return self == .snow_height
    }
}

