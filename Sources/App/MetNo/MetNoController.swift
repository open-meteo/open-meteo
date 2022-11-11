import Foundation
import Vapor


struct MetNoController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(MetNoQuery.self)
            try params.validate()
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 11)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 10, allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: 3600)
            
            guard let reader = try MetNoReader(domain: MetNoDomain.nordic_pp, lat: params.latitude, lon: params.longitude, elevation: .nan, mode: .nearest) else {
                fatalError("Not possible, ECMWF is global")
            }
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count)
                for variable in variables {
                    let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit).toApi(name: variable.name)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.reader.modelLat,
                longitude: reader.reader.modelLon,
                elevation: nil,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

typealias MetNoHourlyVariable = VariableOrDerived<MetNoVariable, MetNoVariableDerived>

struct MetNoQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let hourly: [MetNoHourlyVariable]?
    //let current_weather: Bool?
    let elevation: Float?
    //let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    
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
        if let timezone = timezone, !timezone.isEmpty {
            throw ForecastapiError.timezoneNotSupported
        }
        /*if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }*/
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}

struct MetNoReader: GenericReaderDerivedSimple, GenericReaderMixable {
    var reader: GenericReaderCached<MetNoDomain, MetNoVariable>
    
    typealias Domain = MetNoDomain
    
    typealias Variable = MetNoVariable
    
    typealias Derived = MetNoVariableDerived
    
    func prefetchData(derived: MetNoVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
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
        case .cloudcover_low:
            fallthrough
        case .cloudcover_mid:
            fallthrough
        case .cloudcover_high:
            try prefetchData(raw: .cloudcover, time: time)
        case .wind_u_component_10m:
            fallthrough
        case .wind_v_component_10m:
            try prefetchData(raw: .windspeed_10m, time: time)
            try prefetchData(raw: .winddirection_10m, time: time)
        }
    }
    
    func get(derived: MetNoVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .apparent_temperature:
            let windspeed = try get(raw: .windspeed_10m, time: time).data
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
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let rh = try get(raw: .relativehumidity_2m, time: time).data
            let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
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
            let dhi = try get(derived: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .direct_normal_irradiance_instant:
            let direct = try get(derived: .direct_radiation_instant, time: time)
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
            let direct = try get(derived: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .cloudcover_low:
            return try get(raw: .cloudcover, time: time)
        case .cloudcover_mid:
            return try get(raw: .cloudcover, time: time)
        case .cloudcover_high:
            return try get(raw: .cloudcover, time: time)
        case .wind_u_component_10m:
            let speed = try get(raw: .windspeed_10m, time: time)
            let direction = try get(raw: .winddirection_10m, time: time)
            return DataAndUnit(zip(speed.data, direction.data).map(Meteorology.uWind), speed.unit)
        case .wind_v_component_10m:
            let speed = try get(raw: .windspeed_10m, time: time)
            let direction = try get(raw: .winddirection_10m, time: time)
            return DataAndUnit(zip(speed.data, direction.data).map(Meteorology.vWind), speed.unit)
        }
    }
}

/// cloudcover low/mid/high and wind u/v components are requried to be used in the general forecast api
enum MetNoVariableDerived: String, Codable, GenericVariableMixable {
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case wind_u_component_10m
    case wind_v_component_10m
    
    case apparent_temperature
    case dewpoint_2m
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
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
