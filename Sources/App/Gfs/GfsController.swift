import Foundation
import Vapor

/**
 TODO:
 - No convective precip in NAM/HRRR
 - No 120/180m wind
 - Soil temp/moisture on different levels
 - DONE No cloudcover in NAM/HRRR on pressure levels -> RH to clouds implemented
 - DONE No diffuse/direct radiation in GFS -> separation model implemented
 */
public struct GfsController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let generationTimeStart = Date()
        let params = try req.query.decode(GfsQuery.self)
        try params.validate()
        let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
        let currentTime = Timestamp.now()
        
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 17)
        let timezone = try params.resolveTimezone()
        let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, allowedRange: allowedRange)
        
        let hourlyTime = time.range.range(dtSeconds: 3600)
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        
        // gfs025 is automatically used inside `GfsMixer`
        let domains = [GfsDomain.gfs013, /*.nam_conus,*/ .hrrr_conus]
        
        guard let reader = try GfsMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        
        
        // Start data prefetch to boooooooost API speed :D
        let paramsHourly = try GfsVariableCombined.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try GfsDailyWeatherVariable.load(commaSeparatedOptional: params.daily)
        if let hourlyVariables = paramsHourly {
            try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
        }
        if let dailyVariables = paramsDaily {
            try reader.prefetchData(variables: dailyVariables, time: dailyTime)
        }
        
        let hourly: ApiSection? = try paramsHourly.map { variables in
            var res = [ApiColumn]()
            res.reserveCapacity(variables.count)
            for variable in variables {
                let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name)
                assert(hourlyTime.count == d.data.count)
                res.append(d)
            }
            return ApiSection(name: "hourly", time: hourlyTime, columns: res)
        }
        
        let currentWeather: ForecastapiResult.CurrentWeather?
        if params.current_weather == true {
            let starttime = currentTime.floor(toNearest: 3600)
            let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
            let temperature = try reader.get(raw: .temperature_2m, time: time).convertAndRound(params: params)
            let winddirection = try reader.get(derived: .winddirection_10m, time: time).convertAndRound(params: params)
            let windspeed = try reader.get(derived: .windspeed_10m, time: time).convertAndRound(params: params)
            let weathercode = try reader.get(derived: .weathercode, time: time).convertAndRound(params: params)
            currentWeather = ForecastapiResult.CurrentWeather(
                temperature: temperature.data[0],
                windspeed: windspeed.data[0],
                winddirection: winddirection.data[0],
                weathercode: weathercode.data[0],
                temperature_unit: temperature.unit,
                windspeed_unit: windspeed.unit,
                winddirection_unit: winddirection.unit,
                weathercode_unit: weathercode.unit,
                time: starttime
            )
        } else {
            currentWeather = nil
        }
        
        let daily: ApiSection? = try paramsDaily.map { dailyVariables in
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
    }
}


struct GfsQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let hourly: [String]?
    let daily: [String]?
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
    let cell_selection: GridSelectionMode?
    
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


enum GfsDailyWeatherVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case precipitation_probability_max
    case precipitation_probability_min
    case precipitation_probability_mean
    case snowfall_sum
    //case rain_sum
    //case showers_sum
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
}

enum GfsVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumitidy_2m
    case dewpoint_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    /*case windspeed_120m
    case winddirection_120m
    case windspeed_180m
    case winddirection_180m*/
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case shortwave_radiation_instant
    case evapotranspiration
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case snowfall
    case rain
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: GfsPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias GfsVariableDerived = SurfaceAndPressureVariable<GfsVariableDerivedSurface, GfsPressureVariableDerived>

typealias GfsVariableCombined = VariableOrDerived<GfsVariable, GfsVariableDerived>

struct GfsReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = GfsDomain
    
    typealias Variable = GfsVariable
    
    typealias Derived = GfsVariableDerived
    
    typealias MixingVar = GfsVariableCombined
    
    var reader: GenericReaderMixerSameDomain<GenericReaderCached<GfsDomain, GfsVariable>>
    
    var domain: Domain
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        switch domain {
        case .gfs013:
            // Note gfs025_ensemble only offers precipitation probability at 3h
            // A nicer implementation should use a dedicated variables enum
            let readers: [GenericReaderCached<GfsDomain, GfsVariable>] = try [GfsDomain.gfs025_ensemble, .gfs025, .gfs013].compactMap {
                guard let reader = try GenericReader<GfsDomain, GfsVariable>(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    return nil
                }
                return GenericReaderCached(reader: reader)
            }
            guard !readers.isEmpty else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: readers)
        case .gfs025:
            fatalError("gfs025 should not been initilised in GfsMixer025_013")
        case .gfs025_ensemble:
            fatalError("gfs025_ensemble should not been initilised in GfsMixer025_013")
        case .hrrr_conus:
            guard let reader = try GenericReader<GfsDomain, GfsVariable>(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: [GenericReaderCached(reader: reader)])
        }
        self.domain = domain
    }
    
    func get(raw: Variable, time: TimerangeDt) throws -> DataAndUnit {
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw, pressure.variable == .cloudcover {
            let rh = try reader.get(variable: .pressure(GfsPressureVariable(variable: .relativehumidity, level: pressure.level)), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(pressure.level))}), .percent)
        }
        
        /// GFS has no diffuse radiation
        /*if reader.domain == .gfs025, case let .surface(variable) = raw, variable == .diffuse_radiation {
            let ghi = try reader.get(variable: .surface(.shortwave_radiation), time: time)
            let dhi = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: ghi.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(dhi, ghi.unit)
        }*/
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: Variable, time: TimerangeDt) throws {
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw, pressure.variable == .cloudcover {
            return try reader.prefetchData(variable: .pressure(GfsPressureVariable(variable: .relativehumidity, level: pressure.level)), time: time)
        }
        
        /// GFS has no diffuse radiation
        /*if reader.domain == .gfs025, case let .surface(variable) = raw, variable == .diffuse_radiation {
            return try reader.prefetchData(variable: .surface(.shortwave_radiation), time: time)
        }*/
        
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func prefetchData(derived: GfsVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_10m), time: time)
                try prefetchData(raw: .surface(.relativehumidity_2m), time: time)
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .relativehumitidy_2m:
                try prefetchData(raw: .surface(.relativehumidity_2m), time: time)
            case .windspeed_10m:
                try prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .winddirection_10m:
                try prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .windspeed_80m:
                try prefetchData(raw: .surface(.wind_u_component_80m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_80m), time: time)
            case .winddirection_80m:
                try prefetchData(raw: .surface(.wind_u_component_80m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_80m), time: time)
            case .evapotranspiration:
                try prefetchData(raw: .surface(.latent_heatflux), time: time)
            case .vapor_pressure_deficit:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relativehumidity_2m), time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relativehumidity_2m), time: time)
                try prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .rain:
                fallthrough
            case .snowfall:
                try prefetchData(raw: .surface(.frozen_precipitation_percent), time: time)
                try prefetchData(raw: .surface(.precipitation), time: time)
            case .surface_pressure:
                try prefetchData(raw: .surface(.pressure_msl), time: time)
                try prefetchData(raw: .surface(.temperature_2m), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dewpoint_2m:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relativehumidity_2m), time: time)
            case .diffuse_radiation_instant:
                try prefetchData(raw: .surface(.diffuse_radiation), time: time)
            case .direct_normal_irradiance:
                fallthrough
            case .direct_normal_irradiance_instant:
                fallthrough
            case .direct_radiation:
                fallthrough
            case .direct_radiation_instant:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try prefetchData(raw: .surface(.diffuse_radiation), time: time)
            case .shortwave_radiation_instant:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .weathercode:
                try prefetchData(raw: .surface(.cloudcover), time: time)
                try prefetchData(raw: .surface(.precipitation), time: time)
                try prefetchData(derived: .surface(.snowfall), time: time)
                try prefetchData(raw: .surface(.showers), time: time)
                try prefetchData(raw: .surface(.cape), time: time)
                try prefetchData(raw: .surface(.windgusts_10m), time: time)
                try prefetchData(raw: .surface(.visibility), time: time)
                try prefetchData(raw: .surface(.lifted_index), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint:
                try prefetchData(raw: .pressure(GfsPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: GfsVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .surface(let gfsVariableDerivedSurface):
            switch gfsVariableDerivedSurface {
            case .windspeed_10m:
                let u = try get(raw: .surface(.wind_u_component_10m), time: time).data
                let v = try get(raw: .surface(.wind_v_component_10m), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_10m:
                let u = try get(raw: .surface(.wind_u_component_10m), time: time).data
                let v = try get(raw: .surface(.wind_v_component_10m), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m:
                let u = try get(raw: .surface(.wind_u_component_80m), time: time).data
                let v = try get(raw: .surface(.wind_v_component_80m), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_80m:
                let u = try get(raw: .surface(.wind_u_component_80m), time: time).data
                let v = try get(raw: .surface(.wind_v_component_80m), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let relhum = try get(raw: .surface(.relativehumidity_2m), time: time).data
                let radiation = try get(raw: .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .evapotranspiration:
                let latent = try get(raw: .surface(.latent_heatflux), time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimeter)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let rh = try get(raw: .surface(.relativehumidity_2m), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(raw: .surface(.shortwave_radiation), time: time).data
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try get(raw: .surface(.relativehumidity_2m), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimeter)
            case .snowfall:
                let frozen_precipitation_percent = try get(raw: .surface(.frozen_precipitation_percent), time: time).data
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                let snowfall = zip(frozen_precipitation_percent, precipitation).map({
                    max($0/100 * $1 * 0.7, 0)
                })
                return DataAndUnit(snowfall, SiUnit.centimeter)
            case .rain:
                let frozen_precipitation_percent = try get(raw: .surface(.frozen_precipitation_percent), time: time).data
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                let rain = zip(frozen_precipitation_percent, precipitation).map({
                    max((1-$0/100) * $1, 0)
                })
                return DataAndUnit(rain, .millimeter)
            case .relativehumitidy_2m:
                return try get(raw: .surface(.relativehumidity_2m), time: time)
            case .surface_pressure:
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let pressure = try get(raw: .surface(.pressure_msl), time: time)
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
                let temperature = try get(raw: .surface(.temperature_2m), time: time)
                let rh = try get(raw: .surface(.relativehumidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .surface(.shortwave_radiation), time: time)
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
            case .direct_radiation:
                let diffuse = try get(raw: .surface(.diffuse_radiation), time: time)
                let swrad = try get(raw: .surface(.shortwave_radiation), time: time)
                return DataAndUnit(zip(swrad.data, diffuse.data).map(-), diffuse.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(raw: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weathercode:
                let cloudcover = try get(raw: .surface(.cloudcover), time: time).data
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
                let showers = try get(raw: .surface(.showers), time: time).data
                let cape = try get(raw: .surface(.cape), time: time).data
                let gusts = try get(raw: .surface(.windgusts_10m), time: time).data
                let visibility = try get(raw: .surface(.visibility), time: time).data
                let liftedIndex = try get(raw: .surface(.lifted_index), time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: liftedIndex,
                    visibilityMeters: visibility,
                    modelDtHours: time.dtSeconds / 3600), .wmoCode
                )
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                let u = try get(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint:
                let temperature = try get(raw: .pressure(GfsPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            }
        }
    }
}


struct GfsMixer: GenericReaderMixer {
    let reader: [GfsReader]
    
    static func makeReader(domain: GfsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GfsReader? {
        return try GfsReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}

extension GfsMixer {
    func getDaily(variable: GfsDailyWeatherVariable, params: GfsQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: 3600)
        switch variable {
        case .precipitation_probability_max:
            let data = try get(raw: .precipitation_probability, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .precipitation_probability_min:
            let data = try get(raw: .precipitation_probability, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_probability_mean:
            let data = try get(raw: .precipitation_probability, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .temperature_2m_max:
            let data = try get(raw: .temperature_2m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(raw: .temperature_2m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(derived: .apparent_temperature, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(derived: .apparent_temperature, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(raw: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            let data = try get(derived: .weathercode, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(raw: .shortwave_radiation, time: time).convertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(derived: .windspeed_10m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(raw: .windgusts_10m, time: time).convertAndRound(params: params)
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
            let data = try get(raw: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(derived: .et0_fao_evapotranspiration, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(derived: .snowfall, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        /*case .rain_sum:
            let data = try get(variable: .rain).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(variable: .showers).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)*/
        }
    }
    
    func prefetchData(variables: [GfsDailyWeatherVariable], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            switch variable {
            case .precipitation_probability_min:
                fallthrough
            case .precipitation_probability_mean:
                fallthrough
            case .precipitation_probability_max:
                try prefetchData(raw: .precipitation_probability, time: time)
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
            case .weathercode:
                try prefetchData(variable: .derived(.surface(.weathercode)), time: time)
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
                try prefetchData(raw: .precipitation, time: time)
                try prefetchData(raw: .frozen_precipitation_percent, time: time)
            /*case .rain_sum:
                try prefetchData(variable: .rain)
            case .showers_sum:
                try prefetchData(variable: .showers)*/
            }
        }
    }
    
    func get(raw: GfsSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func get(derived: GfsVariableDerivedSurface, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .derived(.surface(derived)), time: time)
    }
    
    func prefetchData(raw: GfsSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(raw)), time: time)
    }
}
