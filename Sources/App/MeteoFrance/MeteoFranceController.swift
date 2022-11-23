import Foundation
import Vapor

/**
 TODO:
 - weather code
 - No 120/180m wind
 */
public struct MeteoFranceController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(MeteoFranceQuery.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 6)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 4, allowedRange: allowedRange)
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = [MeteoFranceDomain.arpege_world, .arpege_europe, .arome_france, .arome_france_hd] //[MeteoFranceDomain.arome_france]
            
            guard let reader = try MeteoFranceMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
            if let dailyVariables = params.daily {
                try reader.prefetchData(variables: dailyVariables, time: dailyTime)
            }
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count)
                for variable in variables {
                    let d = try reader.get(variable: variable, time: hourlyTime).conertAndRound(params: params).toApi(name: variable.name)
                    assert(hourlyTime.count == d.data.count)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            
            let currentWeather: ForecastapiResult.CurrentWeather?
            if params.current_weather == true {
                let starttime = currentTime.floor(toNearest: 3600)
                let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
                guard let reader = try MeteoFranceMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                let temperature = try reader.get(raw: .temperature_2m, time: time).conertAndRound(params: params)
                let winddirection = try reader.get(derived: .winddirection_10m, time: time).conertAndRound(params: params)
                let windspeed = try reader.get(derived: .windspeed_10m, time: time).conertAndRound(params: params)
                //let weathercode = try reader.get(variable: .weathercode).conertAndRound(params: params)
                currentWeather = ForecastapiResult.CurrentWeather(
                    temperature: temperature.data[0],
                    windspeed: windspeed.data[0],
                    winddirection: winddirection.data[0],
                    weathercode: .nan, //weathercode.data[0],
                    temperature_unit: temperature.unit,
                    windspeed_unit: windspeed.unit,
                    winddirection_unit: winddirection.unit,
                    weathercode_unit: .dimensionless, //weathercode.unit,
                    time: starttime
                )
            } else {
                currentWeather = nil
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
                    let d = try reader.getDaily(variable: variable, params: params, time: dailyTime).toApi(name: variable.rawValue)
                    assert(dailyTime.count == d.data.count)
                    res.append(d)
                }
                return ApiSection(name: "daily", time: dailyTime, columns: res)
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: reader.targetElevation,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: currentWeather,
                sections: [hourly, daily].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}


struct MeteoFranceQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let hourly: [MeteoFranceVariableCombined]?
    let daily: [MeteoFranceDailyWeatherVariable]?
    let current_weather: Bool?
    let elevation: Float?
    let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let forecast_days: Int?
    let format: ForecastResultFormat?
    
    /// iso starting date `2022-02-01`
    let start_date: IsoDate?
    /// included end date `2022-06-01`
    let end_date: IsoDate?
    
    func validate() throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        if let forecast_days = forecast_days, forecast_days <= 0 || forecast_days > 16 {
            throw ForecastapiError.forecastDaysInvalid(given: forecast_days, allowed: 0...16)
        }
        if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}


enum MeteoFranceDailyWeatherVariable: String, Codable {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case snowfall_sum
    //case rain_sum
    //case showers_sum
    //case weathercode
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

enum MeteoFranceVariableDerivedSurface: String, Codable, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumitidy_2m
    case dewpoint_2m
    case windspeed_10m
    case winddirection_10m
    //case windspeed_80m
    //case winddirection_80m
    /*case windspeed_120m
    case winddirection_120m
    case windspeed_180m
    case winddirection_180m*/
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    //case evapotranspiration
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum MeteoFrancePressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct MeteoFrancePressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: MeteoFrancePressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias MeteoFranceVariableDerived = SurfaceAndPressureVariable<MeteoFranceVariableDerivedSurface, MeteoFrancePressureVariableDerived>

typealias MeteoFranceVariableCombined = VariableOrDerived<MeteoFranceVariable, MeteoFranceVariableDerived>

struct MeteoFranceReader: GenericReaderDerived, GenericReaderMixable {
    typealias Domain = MeteoFranceDomain
    
    typealias Variable = MeteoFranceVariable
    
    typealias Derived = MeteoFranceVariableDerived
    
    typealias MixingVar = MeteoFranceVariableCombined
    
    var reader: GenericReaderCached<MeteoFranceDomain, MeteoFranceVariable>
    
    func get(raw: MeteoFranceVariable, time: TimerangeDt) throws -> DataAndUnit {
        // arpege_europe and arpege_world have no level 125
        if reader.domain == .arpege_europe || reader.domain == .arpege_world, case let .pressure(pressure) = raw, pressure.level == 125  {
            return try self.interpolatePressureLevel(variable: pressure.variable, level: 125, lowerLevel: 100, upperLevel: 150, time: time)
        }
        
        /// AROME France domain has no cloud cover for pressure levels, calculate from RH
        if reader.domain == .arome_france, case let .pressure(pressure) = raw, pressure.variable == .cloudcover {
            let rh = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .relativehumidity, level: pressure.level)), time: time)
            let clc = rh.data.map(Meteorology.relativeHumidityToCloudCover)
            return DataAndUnit(clc, .percent)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: MeteoFranceVariable, time: TimerangeDt) throws {
        // arpege_europe and arpege_world have no level 125
        if reader.domain == .arpege_europe || reader.domain == .arpege_world, case let .pressure(pressure) = raw, pressure.level == 125  {
            try self.prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: pressure.variable, level: 100)), time: time)
            try self.prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: pressure.variable, level: 150)), time: time)
            return
        }
        
        /// AROME France domain has no cloud cover for pressure levels, calculate from RH
        if reader.domain == .arome_france, case let .pressure(pressure) = raw, pressure.variable == .cloudcover {
            try self.prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .relativehumidity, level: pressure.level)), time: time)
            return
        }
        
        try reader.prefetchData(variable: raw, time: time)
    }
    
    
    /// TODO partly duplicate code with ICON
    private func interpolatePressureLevel(variable: MeteoFrancePressureVariableType, level: Int, lowerLevel: Int, upperLevel: Int, time: TimerangeDt) throws -> DataAndUnit {
        let lower = try get(raw: .pressure(MeteoFrancePressureVariable(variable: variable, level: lowerLevel)), time: time)
        let upper = try get(raw: .pressure(MeteoFrancePressureVariable(variable: variable, level: upperLevel)), time: time)
        
        switch variable {
        case .temperature:
            // temperature/pressure is linear, therefore
            // perform linear interpolation between 2 points
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .geopotential_height:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                let lP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: l)
                let hP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: h)
                let adjPressure = lP + Float(level - lowerLevel) * (hP - lP) / Float(upperLevel - lowerLevel)
                return Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: adjPressure)
            }, lower.unit)
        case .relativehumidity:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return (l + h) / 2
            }, lower.unit)
        case .cloudcover:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        }
    }
    
    func prefetchData(variable: MeteoFranceSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }
    
    func get(raw: MeteoFranceSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(derived: MeteoFranceVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .relativehumitidy_2m:
                try prefetchData(variable: .relativehumidity_2m, time: time)
            case .windspeed_10m:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .winddirection_10m:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .vapor_pressure_deficit:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .shortwave_radiation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .snowfall:
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            case .surface_pressure:
                try prefetchData(variable: .pressure_msl, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dewpoint_2m:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
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
                try prefetchData(variable: .shortwave_radiation, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint:
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .relativehumidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: MeteoFranceVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
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
            case .snowfall:
                let snowfall_water_equivalent = try get(raw: .snowfall_water_equivalent, time: time).data
                let snowfall = snowfall_water_equivalent.map({$0 * 0.7})
                return DataAndUnit(snowfall, SiUnit.centimeter)
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

            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                let u = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint:
                let temperature = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .relativehumidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            }
        }
    }
}

struct MeteoFranceMixer: GenericReaderMixer {
    let reader: [MeteoFranceReader]
}

extension MeteoFranceMixer {
    func getDaily(variable: MeteoFranceDailyWeatherVariable, params: MeteoFranceQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: 3600)
        switch variable {
        case .temperature_2m_max:
            let data = try get(raw: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(raw: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(derived: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(derived: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(raw: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        /*case .weathercode:
            // not 100% corrct
            let data = try get(variable: .weathercode).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)*/
        case .shortwave_radiation_sum:
            let data = try get(raw: .shortwave_radiation, time: time).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(derived: .windspeed_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(raw: .windgusts_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(raw: .wind_u_component_10m, time: time).data.sum(by: 24)
            let v = try get(raw: .wind_v_component_10m, time: time).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        //case .sunshine_hours:
            /// TODO need sunrise and set time for correct numbers
            //fatalError()
        case .precipitation_hours:
            let data = try get(raw: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(derived: .et0_fao_evapotranspiration, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(derived: .snowfall, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        /*case .rain_sum:
            let data = try get(variable: .rain).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(variable: .showers).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)*/
        }
    }
    
    func prefetchData(variables: [MeteoFranceDailyWeatherVariable], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(raw: .temperature_2m, time: time)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .precipitation_sum:
                try prefetchData(raw: .precipitation, time: time)
            //case .weathercode:
            //    try prefetchData(variable: .weathercode)
            case .shortwave_radiation_sum:
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .windspeed_10m_max:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .windgusts_10m_max:
                try prefetchData(raw: .windgusts_10m, time: time)
            case .winddirection_10m_dominant:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .precipitation_hours:
                try prefetchData(raw: .precipitation, time: time)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .shortwave_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .snowfall_sum:
                try prefetchData(raw: .snowfall_water_equivalent, time: time)
            /*case .rain_sum:
                try prefetchData(variable: .rain)
            case .showers_sum:
                try prefetchData(variable: .showers)*/
            }
        }
    }
    
    func prefetchData(raw: MeteoFranceSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(raw)), time: time)
    }
    
    func get(raw: MeteoFranceSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func get(derived: MeteoFranceVariableDerivedSurface, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .derived(.surface(derived)), time: time)
    }
}

