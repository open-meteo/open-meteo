import Foundation
import Vapor

public struct GemController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let generationTimeStart = Date()
        let params = try req.query.decode(GemQuery.self)
        try params.validate()
        let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
        let currentTime = Timestamp.now()
        
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 11)
        let timezone = try params.resolveTimezone()
        let (utcOffsetSecondsActual, time) = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, allowedRange: allowedRange)
        /// For fractional timezones, shift data to show only for full timestamps
        let utcOffsetShift = time.utcOffsetSeconds - utcOffsetSecondsActual
        
        let hourlyTime = time.range.range(dtSeconds: 3600)
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        
        let domains = [GemDomain.gem_global, .gem_regional, .gem_hrdps_continental]
        
        guard let reader = try GemMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        
        
        // Start data prefetch to boooooooost API speed :D
        let paramsHourly = try GemVariableCombined.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try GemDailyWeatherVariable.load(commaSeparatedOptional: params.daily)
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
            return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
        }
        
        let currentWeather: ForecastapiResult.CurrentWeather?
        if params.current_weather == true {
            let starttime = currentTime.floor(toNearest: 3600)
            let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
            let temperature = try reader.get(variable: .temperature_2m, time: time).convertAndRound(params: params)
            let winddirection = try reader.get(variable: .winddirection_10m, time: time).convertAndRound(params: params)
            let windspeed = try reader.get(variable: .windspeed_10m, time: time).convertAndRound(params: params)
            let weathercode = try reader.get(variable: .weathercode, time: time).convertAndRound(params: params)
            currentWeather = ForecastapiResult.CurrentWeather(
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
            return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: res)
        }
        
        let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
        let out = ForecastapiResult(
            latitude: reader.modelLat,
            longitude: reader.modelLon,
            elevation: reader.targetElevation,
            generationtime_ms: generationTimeMs,
            utc_offset_seconds: utcOffsetSecondsActual,
            timezone: timezone,
            current_weather: currentWeather,
            sections: [hourly, daily].compactMap({$0}),
            timeformat: params.timeformatOrDefault
        )
        return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
    }
}


struct GemQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
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
    let length_unit: LengthUnit?
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
        if let forecast_days = forecast_days, forecast_days < 0 || forecast_days > 16 {
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


enum GemDailyWeatherVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
    case snowfall_sum
    case rain_sum
    case showers_sum
    case shortwave_radiation_sum
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
    case weathercode
}

enum GemVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case windspeed_10m
    case winddirection_10m
    case windspeed_40m
    case winddirection_40m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
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
    case snowfall
    case rain
    case weathercode
    case is_day
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum GemPressureVariableDerivedType: String, CaseIterable {
    case dewpoint
    case cloudcover
    case windspeed
    case winddirection
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct GemPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: GemPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias GemVariableDerived = SurfaceAndPressureVariable<GemVariableDerivedSurface, GemPressureVariableDerived>

typealias GemVariableCombined = VariableOrDerived<VariableAndMemberAndControl<GemVariable>, VariableAndMemberAndControl<GemVariableDerived>>

struct GemReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = GemVariableCombined
    
    typealias Domain = GemDomain
    
    typealias Variable = VariableAndMemberAndControl<GemVariable>
    
    typealias Derived = VariableAndMemberAndControl<GemVariableDerived>
    
    var reader: GenericReaderCached<GemDomain, Variable>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .dewpoint_2m:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .vapor_pressure_deficit:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .surface_pressure:
                try prefetchData(raw: .init(.surface(.pressure_msl), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
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
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .snowfall:
                try prefetchData(raw: .init(.surface(.snowfall_water_equivalent), member), time: time)
            case .rain:
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                try prefetchData(raw: .init(.surface(.snowfall_water_equivalent), member), time: time)
            case .cloudcover_low:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), member), time: time)
            case .cloudcover_mid:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), member), time: time)
            case .cloudcover_high:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), member), time: time)
            case .weathercode:
                try prefetchData(raw: .init(.surface(.cloudcover), member), time: time)
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                try prefetchData(derived: .init(.surface(.snowfall), member), time: time)
                try prefetchData(raw: .init(.surface(.showers), member), time: time)
                try prefetchData(raw: .init(.surface(.cape), member), time: time)
                try prefetchData(raw: .init(.surface(.windgusts_10m), member), time: time)
            case .is_day:
                break
            case .windspeed_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .windspeed_40m:
                fallthrough
            case .winddirection_40m:
                try prefetchData(raw: .init(.surface(.wind_u_component_40m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_40m), member), time: time)
            case .windspeed_80m:
                fallthrough
            case .winddirection_80m:
                try prefetchData(raw: .init(.surface(.wind_u_component_80m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_80m), member), time: time)
            case .windspeed_120m:
                fallthrough
            case .winddirection_120m:
                try prefetchData(raw: .init(.surface(.wind_u_component_120m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_120m), member), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .dewpoint:
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            case .cloudcover:
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
            }
        }
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .apparent_temperature:
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let relhum = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let radiation = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimeter)
            case .surface_pressure:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let pressure = try get(raw: .init(.surface(.pressure_msl), member), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(derived: .init(.surface(.direct_radiation), member), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, .wattPerSquareMeter)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation_instant), member), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .init(.surface(.diffuse_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .dewpoint_2m:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time)
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .snowfall:
                let snowwater = try get(raw: .init(.surface(.snowfall_water_equivalent), member), time: time).data
                let snowfall = snowwater.map { $0 * 0.7 }
                return DataAndUnit(snowfall, .centimeter)
            case .rain:
                let snowwater = try get(raw: .init(.surface(.snowfall_water_equivalent), member), time: time).data
                let total = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                let rain = zip(zip(total, snowwater), showers).map { (arg0, showers) in
                    let (total, snowwater) = arg0
                    return max(total - snowwater - showers, 0)
                }
                return DataAndUnit(rain, .millimeter)
            case .cloudcover_low:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .cloudcover_mid:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .cloudcover_high:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .weathercode:
                let cloudcover = try get(raw: .init(.surface(.cloudcover), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let snowfall = try get(derived: .init(.surface(.snowfall), member), time: time).data
                let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                let cape = try get(raw: .init(.surface(.cape), member), time: time).data
                let gusts = try get(raw: .init(.surface(.windgusts_10m), member), time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: nil,
                    visibilityMeters: nil,
                    categoricalFreezingRain: nil,
                    modelDtHours: time.dtSeconds / 3600), .wmoCode
                )
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionless_integer)
            case .windspeed_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_40m:
                let u = try get(raw: .init(.surface(.wind_u_component_40m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_40m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_40m:
                let u = try get(raw: .init(.surface(.wind_u_component_40m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_40m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_120m:
                let u = try get(raw: .init(.surface(.wind_u_component_120m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_120m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_120m:
                let u = try get(raw: .init(.surface(.wind_u_component_120m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_120m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            }
        case .pressure(let v):
            switch v.variable {
            case .dewpoint:
                let temperature = try get(raw: .init(.pressure(GemPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                let rh = try get(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                let rh = try get(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percent)
            case .windspeed:
                let u = try get(raw: .init(.pressure(GemPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                let v = try get(raw: .init(.pressure(GemPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: .init(.pressure(GemPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time).data
                let v = try get(raw: .init(.pressure(GemPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            }
        }
    }
}

struct GemMixer: GenericReaderMixer {
    let reader: [GemReader]
    
    static func makeReader(domain: GemReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GemReader? {
        return try GemReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}

extension GemMixer {
    func prefetchData(variable: GemSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.init(.surface(variable), 0)), time: time)
    }
    
    func get(variable: GemSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.init(.surface(variable), 0)), time: time)
    }
    
    func get(variable: GemVariableDerivedSurface, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .derived(.init(.surface(variable), 0)), time: time)
    }
    
    func getDaily(variable: GemDailyWeatherVariable, params: GemQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
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
        case .windgusts_10m_max:
            let data = try get(variable: .windgusts_10m, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(variable: .wind_u_component_10m, time: time).data.sum(by: 24)
            let v = try get(variable: .wind_v_component_10m, time: time).data.sum(by: 24)
            return DataAndUnit(Meteorology.windirectionFast(u: u, v: v), .degreeDirection)
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
        case .snowfall_sum:
            let data = try get(variable: .snowfall, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .rain_sum:
            let data = try get(variable: .rain, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(variable: .showers, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            let data = try get(variable: .weathercode, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        }
    }
    
    func prefetchData(variables: [GemDailyWeatherVariable], time timeDaily: TimerangeDt) throws {
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
            case .windgusts_10m_max:
                try prefetchData(variable: .windgusts_10m, time: time)
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
            case .snowfall_sum:
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            case .rain_sum:
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            case .weathercode:
                try prefetchData(variable: .derived(.init(.surface(.weathercode), 0)), time: time)
            case .showers_sum:
                try prefetchData(variable: .showers, time: time)
            }
        }
    }
}

