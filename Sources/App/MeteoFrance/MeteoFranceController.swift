import Foundation
import Vapor


public struct MeteoFranceController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 6)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try MeteoFranceApiDomains.load(commaSeparatedOptional: params.models) ?? [.best_match]
        let paramsHourly = try MeteoFranceVariableCombined.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try MeteoFranceDailyWeatherVariable.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.count
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 4, forecastDaysMax: 16, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            let readers = try domains.map {
                guard let reader = try MeteoFranceMixer(domains: $0.domains, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return reader
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: readers[0].modelLat,
                longitude: readers[0].modelLon,
                elevation: readers[0].targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        for reader in readers {
                            try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                        }
                    }
                    if let dailyVariables = paramsDaily {
                        for reader in readers {
                            try reader.prefetchData(variables: dailyVariables, time: dailyTime)
                        }
                    }
                },
                current_weather: params.current_weather == true ? try {
                    let starttime = currentTime.floor(toNearest: 3600)
                    let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
                    guard let reader = try MeteoFranceMixer(domains: MeteoFranceApiDomains.best_match.domains, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                        throw ForecastapiError.noDataAvilableForThisLocation
                    }
                    return {
                        let temperature = try reader.get(variable: .raw(.surface(.temperature_2m)), time: time).convertAndRound(params: params)
                        let winddirection = try reader.get(variable: .derived(.surface(.winddirection_10m)), time: time).convertAndRound(params: params)
                        let windspeed = try reader.get(variable: .derived(.surface(.windspeed_10m)), time: time).convertAndRound(params: params)
                        let weathercode = try reader.get(variable: .derived(.surface(.weathercode)), time: time).convertAndRound(params: params)
                        return ForecastapiResult.CurrentWeather(
                            temperature: temperature.data[0],
                            windspeed: windspeed.data[0],
                            winddirection: winddirection.data[0],
                            weathercode: weathercode.data[0],
                            is_day: try reader.get(variable: .derived(.surface(.is_day)), time: time).convertAndRound(params: params).data[0],
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
                        res.reserveCapacity(variables.count * readers.count)
                        for (reader, domain) in zip(readers, domains) {
                            for variable in variables {
                                let name = readers.count > 1 ? "\(variable.rawValue)_\(domain.rawValue)" : variable.rawValue
                                let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: name)
                                assert(hourlyTime.count == d.data.count)
                                res.append(d)
                            }
                        }
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: paramsDaily.map { dailyVariables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(dailyVariables.count * readers.count)
                        var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                        
                        for (reader, domain) in zip(readers, domains) {
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
                                let name = readers.count > 1 ? "\(variable.rawValue)_\(domain.rawValue)" : variable.rawValue
                                let d = try reader.getDaily(variable: variable, params: params, time: dailyTime).toApi(name: name)
                                assert(dailyTime.count == d.data.count)
                                res.append(d)
                            }
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

enum MeteoFranceApiDomains: String, Codable, RawRepresentableString, CaseIterable {
    case best_match
    case arpege_seamless
    case arpege_world
    case arpege_europe
    case arome_seamless
    case arome_france
    case arome_france_hd
    
    var domains: [MeteoFranceDomain] {
        switch self {
        case .best_match:
            return [.arpege_world, .arpege_europe, .arome_france, .arome_france_hd]
        case .arpege_world:
            return [.arpege_world]
        case .arpege_europe:
            return [.arpege_europe]
        case .arome_france:
            return [.arome_france]
        case .arome_france_hd:
            return [.arome_france_hd]
        case .arpege_seamless:
            return [.arome_france, .arome_france_hd]
        case .arome_seamless:
            return [.arpege_world, .arpege_europe]
        }
    }
}

enum MeteoFranceDailyWeatherVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case apparent_temperature_max
    case apparent_temperature_min
    case precipitation_sum
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

enum MeteoFranceVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumitidy_2m
    case dewpoint_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_20m
    case winddirection_20m
    case windspeed_50m
    case winddirection_50m
    case windspeed_100m
    case winddirection_100m
    case windspeed_150m
    case winddirection_150m
    case windspeed_200m
    case winddirection_200m
    /// Is using 100m wind
    case windspeed_80m
    case winddirection_80m
    /// Is using 150m wind
    case windspeed_120m
    case winddirection_120m
    /// Is using 200m wind
    case windspeed_180m
    case winddirection_180m
    case temperature_80m
    case temperature_120m
    case temperature_180m
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
    case weathercode
    case is_day
    
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

struct MeteoFranceReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = MeteoFranceDomain
    
    typealias Variable = MeteoFranceVariable
    
    typealias Derived = MeteoFranceVariableDerived
    
    typealias MixingVar = MeteoFranceVariableCombined
    
    var reader: GenericReaderCached<MeteoFranceDomain, MeteoFranceVariable>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func get(raw: MeteoFranceVariable, time: TimerangeDt) throws -> DataAndUnit {
        // arpege_europe and arpege_world have no level 125
        if reader.domain == .arpege_europe || reader.domain == .arpege_world, case let .pressure(pressure) = raw, pressure.level == 125  {
            return try self.interpolatePressureLevel(variable: pressure.variable, level: 125, lowerLevel: 100, upperLevel: 150, time: time)
        }
        
        /// AROME France domain has no cloud cover for pressure levels, calculate from RH
        if reader.domain == .arome_france, case let .pressure(pressure) = raw, pressure.variable == .cloudcover {
            let rh = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .relativehumidity, level: pressure.level)), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(pressure.level))}), .percent)
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
            case .weathercode:
                try prefetchData(variable: .cloudcover, time: time)
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(derived: .surface(.snowfall), time: time)
                try prefetchData(variable: .cape, time: time)
                try prefetchData(variable: .windgusts_10m, time: time)
            case .is_day:
                break
            case .windspeed_20m:
                fallthrough
            case .winddirection_20m:
                try prefetchData(variable: .wind_u_component_20m, time: time)
                try prefetchData(variable: .wind_v_component_20m, time: time)
            case .windspeed_50m:
                fallthrough
            case .winddirection_50m:
                try prefetchData(variable: .wind_u_component_50m, time: time)
                try prefetchData(variable: .wind_v_component_50m, time: time)
            case .windspeed_80m:
                fallthrough
            case .winddirection_80m:
                fallthrough
            case .windspeed_100m:
                fallthrough
            case .winddirection_100m:
                try prefetchData(variable: .wind_u_component_100m, time: time)
                try prefetchData(variable: .wind_v_component_100m, time: time)
            case .windspeed_120m:
                fallthrough
            case .winddirection_120m:
                fallthrough
            case .windspeed_150m:
                fallthrough
            case .winddirection_150m:
                try prefetchData(variable: .wind_u_component_150m, time: time)
                try prefetchData(variable: .wind_v_component_150m, time: time)
            case .windspeed_180m:
                fallthrough
            case .winddirection_180m:
                fallthrough
            case .windspeed_200m:
                fallthrough
            case .winddirection_200m:
                try prefetchData(variable: .wind_u_component_200m, time: time)
                try prefetchData(variable: .wind_v_component_200m, time: time)
            case .temperature_80m:
                try prefetchData(variable: .temperature_100m, time: time)
            case .temperature_120m:
                try prefetchData(variable: .temperature_150m, time: time)
            case .temperature_180m:
                try prefetchData(variable: .temperature_200m, time: time)
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
            case .weathercode:
                let cloudcover = try get(raw: .cloudcover, time: time).data
                let precipitation = try get(raw: .precipitation, time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
                let cape = try get(raw: .cape, time: time).data
                let gusts = try get(raw: .windgusts_10m, time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: nil,
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
            case .windspeed_20m:
                let u = try get(raw: .wind_u_component_20m, time: time).data
                let v = try get(raw: .wind_v_component_20m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_20m:
                let u = try get(raw: .wind_u_component_20m, time: time).data
                let v = try get(raw: .wind_v_component_20m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_50m:
                let u = try get(raw: .wind_u_component_50m, time: time).data
                let v = try get(raw: .wind_v_component_50m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_50m:
                let u = try get(raw: .wind_u_component_50m, time: time).data
                let v = try get(raw: .wind_v_component_50m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m:
                fallthrough
            case .windspeed_100m:
                let u = try get(raw: .wind_u_component_100m, time: time).data
                let v = try get(raw: .wind_v_component_100m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_80m:
                fallthrough
            case .winddirection_100m:
                let u = try get(raw: .wind_u_component_100m, time: time).data
                let v = try get(raw: .wind_v_component_100m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_120m:
                fallthrough
            case .windspeed_150m:
                let u = try get(raw: .wind_u_component_150m, time: time).data
                let v = try get(raw: .wind_v_component_150m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_120m:
                fallthrough
            case .winddirection_150m:
                let u = try get(raw: .wind_u_component_150m, time: time).data
                let v = try get(raw: .wind_v_component_150m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_180m:
                fallthrough
            case .windspeed_200m:
                let u = try get(raw: .wind_u_component_200m, time: time).data
                let v = try get(raw: .wind_v_component_200m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_180m:
                fallthrough
            case .winddirection_200m:
                let u = try get(raw: .wind_u_component_200m, time: time).data
                let v = try get(raw: .wind_v_component_200m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .temperature_80m:
                return try get(raw: .temperature_100m, time: time)
            case .temperature_120m:
                return try get(raw: .temperature_150m, time: time)
            case .temperature_180m:
                return try get(raw: .temperature_200m, time: time)
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
    
    static func makeReader(domain: MeteoFranceReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> MeteoFranceReader? {
        return try MeteoFranceReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}

extension MeteoFranceMixer {
    func getDaily(variable: MeteoFranceDailyWeatherVariable, params: ApiQueryParameter, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: 3600)
        switch variable {
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

