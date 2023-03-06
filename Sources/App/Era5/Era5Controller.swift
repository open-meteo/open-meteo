import Foundation
import SwiftPFor2D
import Vapor


/**
 TODO time arrays in large history responses are very inefficient
 */
struct Era5Controller {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("archive-api")
        let generationTimeStart = Date()
        let params = try req.query.decode(Era5Query.self)
        try params.validate()
        let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
        
        let allowedRange = Timestamp(1959, 1, 1) ..< Timestamp.now()
        let timezone = try params.resolveTimezone()
        let time = try params.getTimerange(timezone: timezone, allowedRange: allowedRange)
        let hourlyTime = time.range.range(dtSeconds: 3600)
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        
        let domains = params.models ?? [.best_match]
        
        let readers = try domains.compactMap {
            try GenericReaderMulti<CdsVariable>(domain: $0, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land)
        }
        
        guard !readers.isEmpty else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }

        // Start data prefetch to boooooooost API speed :D
        if let hourlyVariables = params.hourly {
            for reader in readers {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
        }
        if let dailyVariables = params.daily {
            for reader in readers {
                try reader.prefetchData(variables: dailyVariables, time: dailyTime)
            }
        }
        
        
        let hourly: ApiSection? = try params.hourly.map { variables in
            var res = [ApiColumn]()
            res.reserveCapacity(variables.count * readers.count)
            for reader in readers {
                for variable in variables {
                    let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                    guard let d = try reader.get(variable: variable, time: hourlyTime)?.convertAndRound(params: params).toApi(name: name) else {
                        continue
                    }
                    assert(hourlyTime.count == d.data.count)
                    res.append(d)
                }
            }
            return ApiSection(name: "hourly", time: hourlyTime, columns: res)
        }
        let daily: ApiSection? = try params.daily.map { dailyVariables in
            var res = [ApiColumn]()
            res.reserveCapacity(dailyVariables.count * readers.count)
            var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
            
            for reader in readers {
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
                    let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                    guard let d = try reader.getDaily(variable: variable, params: params, time: dailyTime)?.toApi(name: name) else {
                        continue
                    }
                    assert(dailyTime.count == d.data.count)
                    res.append(d)
                }
            }
            
            return ApiSection(name: "daily", time: dailyTime, columns: res)
        }
        
        let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
        let out = ForecastapiResult(
            latitude: readers[0].modelLat,
            longitude: readers[0].modelLon,
            elevation: readers[0].targetElevation,
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
    }
}

enum CdsDomainApi: String, Codable, CaseIterable, MultiDomainMixerDomain {
    case best_match
    case era5
    case cerra
    case era5_land
    case ecmwf_ifs
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable] {
        switch self {
        case .best_match:
            return try Era5Mixer(domains: [.era5, .era5_land], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .era5:
            return try Era5Reader(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .era5_land:
            return try Era5Reader(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .cerra:
            return try CerraReader(domain: .cerra, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs:
            return try Era5Reader(domain: .ecmwf_ifs, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        }
    }
}

enum CdsVariable: String, Codable, GenericVariableMixable {
    case temperature_2m
    case windgusts_10m
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case soil_moisture_0_to_100cm
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    case weathercode
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
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_7cm:
            fallthrough
        case .soil_moisture_7_to_28cm:
            fallthrough
        case .soil_moisture_28_to_100cm:
            fallthrough
        case .soil_moisture_100_to_255cm:
            return true
        default:
            return false
        }
    }
}

typealias Era5HourlyVariable = VariableOrDerived<Era5Variable, Era5VariableDerived>

enum Era5VariableDerived: String, Codable, RawRepresentableString, GenericVariableMixable {
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
    case weathercode
    case soil_moisture_0_to_100cm
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

enum Era5DailyWeatherVariable: String, Codable, DailyVariableCalculatable {
    case weathercode
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    case apparent_temperature_max
    case apparent_temperature_min
    case apparent_temperature_mean
    case relative_humidity_2m_min
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case precipitation_sum
    case snowfall_sum
    case snowfall_water_equivalent_sum
    case rain_sum
    case shortwave_radiation_sum
    case windspeed_10m_max
    case windspeed_10m_min
    case windspeed_10m_mean
    case windgusts_10m_max
    case windgusts_10m_min
    case windgusts_10m_mean
    case winddirection_10m_dominant
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
    case pressure_msl_max
    case pressure_msl_min
    case pressure_msl_mean
    case surface_pressure_max
    case surface_pressure_min
    case surface_pressure_mean
    case cloudcover_max
    case cloudcover_min
    case cloudcover_mean
    /// only for CMIP6 reference
    case soil_moisture_0_to_10cm_mean
    
    /// Get the file path to a linear bias seasonal file for a given variable
    func getBiasCorrectionFile(for domain: GenericDomain) -> OmFilePathWithSuffix {
        return OmFilePathWithSuffix(domain: domain.rawValue, directory: "master", variable: rawValue, suffix: "linear_bias_seasonal")
    }
    
    func openBiasCorrectionFile(for domain: GenericDomain) throws -> OmFileReader<MmapFile>? {
        return try OmFileManager.get(getBiasCorrectionFile(for: domain))
    }
    
    var aggregation: DailyAggregation<CdsVariable> {
        switch self {
        case .weathercode:
            return .max(.weathercode)
        case .temperature_2m_max:
            return .max(.temperature_2m)
        case .temperature_2m_min:
            return .min(.temperature_2m)
        case .temperature_2m_mean:
            return .mean(.temperature_2m)
        case .apparent_temperature_mean:
            return .mean(.apparent_temperature)
        case .apparent_temperature_max:
            return .max(.apparent_temperature)
        case .apparent_temperature_min:
            return .min(.apparent_temperature)
        case .precipitation_sum:
            return .sum(.precipitation)
        case .snowfall_sum:
            return .sum(.snowfall)
        case .rain_sum:
            return .sum(.rain)
        case .shortwave_radiation_sum:
            return .radiationSum(.shortwave_radiation)
        case .windspeed_10m_max:
            return .max(.windspeed_10m)
        case .windspeed_10m_min:
            return .min(.windspeed_10m)
        case .windspeed_10m_mean:
            return .mean(.windspeed_10m)
        case .windgusts_10m_max:
            return .max(.windgusts_10m)
        case .windgusts_10m_min:
            return .min(.windgusts_10m)
        case .windgusts_10m_mean:
            return .mean(.windgusts_10m)
        case .winddirection_10m_dominant:
            return .dominantDirection(velocity: .windspeed_10m, direction: .winddirection_10m)
        case .precipitation_hours:
            return .precipitationHours(.precipitation)
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .et0_fao_evapotranspiration:
            return .sum(.et0_fao_evapotranspiration)
        case .pressure_msl_max:
            return .max(.pressure_msl)
        case .pressure_msl_min:
            return .min(.pressure_msl)
        case .pressure_msl_mean:
            return .mean(.pressure_msl)
        case .surface_pressure_max:
            return .max(.surface_pressure)
        case .surface_pressure_min:
            return .min(.surface_pressure)
        case .surface_pressure_mean:
            return .mean(.surface_pressure)
        case .cloudcover_max:
            return .max(.cloudcover)
        case .cloudcover_min:
            return .min(.cloudcover)
        case .cloudcover_mean:
            return .mean(.cloudcover)
        case .relative_humidity_2m_min:
            return .min(.relativehumidity_2m)
        case .relative_humidity_2m_max:
            return .max(.relativehumidity_2m)
        case .relative_humidity_2m_mean:
            return .mean(.relativehumidity_2m)
        case .snowfall_water_equivalent_sum:
            return .sum(.snowfall_water_equivalent)
        case .soil_moisture_0_to_10cm_mean:
            return .mean(.soil_moisture_0_to_7cm)
        }
    }
}

struct Era5Query: Content, QueryWithTimezone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let hourly: [CdsVariable]?
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
    let models: [CdsDomainApi]?
    let cell_selection: GridSelectionMode?
    
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
