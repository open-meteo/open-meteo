import Foundation
import Vapor

/// Define all available surface weather variables
enum ForecastSurfaceVariable: String, Codable, GenericVariableMixable {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    case precipitation
    case weathercode
    case temperature_80m
    case temperature_120m
    case temperature_180m
    case soil_temperature_0cm
    case soil_temperature_6cm
    case soil_temperature_18cm
    case soil_temperature_54cm
    case soil_moisture_0_1cm
    case soil_moisture_1_3cm
    case soil_moisture_3_9cm
    case soil_moisture_9_27cm
    case soil_moisture_27_81cm
    case snow_depth
    case sensible_heatflux
    case latent_heatflux
    case showers
    case rain
    case snowfall_convective_water_equivalent
    case snowfall_water_equivalent
    case windgusts_10m
    case freezinglevel_height
    case dewpoint_2m
    case diffuse_radiation
    case direct_radiation
    case apparent_temperature
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
    case visibility
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_1cm: return true
        case .soil_moisture_1_3cm: return true
        case .soil_moisture_3_9cm: return true
        case .soil_moisture_9_27cm: return true
        case .soil_moisture_27_81cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
}

/// Available pressure level variables
enum ForecastPressureVariable: String, Codable, GenericVariableMixable {
    case temperature
    case geopotential_height
    case relativehumidity
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias ForecastVariable = SurfaceAndPressureVariable<ForecastSurfaceVariable, ForecastPressureVariable>

/// Available daily aggregations
enum ForecastVariableDaily: String, Codable {
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
    case windspeed_10m_max
    case windgusts_10m_max
    case winddirection_10m_dominant
    case precipitation_hours
    case sunrise
    case sunset
    case et0_fao_evapotranspiration
}


enum MultiDomains: String, Codable, CaseIterable {
    case auto

    case gfs_combined
    case gfs
    case gfs_hrrr
    
    case meteofrance
    case meteofrance_arpege_world
    case meteofrance_arpege_europe
    case meteofrance_arome_france
    case meteofrance_arome_france_hd
    
    case jma
    case jma_msm
    case jms_gsm
    
    case icon
    case icon_global
    case icon_eu
    case icon_d2
    
    case ifs04
    
    public func getReader() {
        
    }
}

struct MultiDomainReader: GenericReaderMixable {
    typealias MixingVar = ForecastVariable
    
    typealias Domain = MultiDomains
    
    var modelLat: Float
    
    var modelLon: Float
    
    var targetElevation: Float
    
    var modelDtSeconds: Int
    
    let domain: MultiDomains
    
    func get(variable: ForecastVariable, time: TimerangeDt) throws -> DataAndUnit {
        <#code#>
    }
    
    func prefetchData(variable: ForecastVariable, time: TimerangeDt) throws {
        <#code#>
    }
    
    init?(domain: MultiDomains, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        <#code#>
    }
}

extension GfsVariableCombined {
    static func fromForecastVariable(variable: ForecastVariable) -> Self? {
        return Self.init(rawValue: variable.rawValue)
    }
}

fileprivate extension GenericReaderMixer where Reader.MixingVar: RawRepresentable, Reader.MixingVar.RawValue == String {
    func get(mixed: ForecastVariable, time: TimerangeDt) throws -> DataAndUnit? {
        guard let v = Reader.MixingVar(rawValue: mixed.rawValue) else {
            return nil
        }
        return try self.get(variable: v, time: time)
    }
    
    func prefetchData(mixed: ForecastVariable, time: TimerangeDt) throws {
        guard let v = Reader.MixingVar(rawValue: mixed.rawValue) else {
            return
        }
        try self.prefetchData(variable: v, time: time)
    }
}


struct MultiDomainMixer {
    let reader: [any GenericReaderMixer]
}



public struct ForecastapiController: RouteCollection {
    public func boot(routes: RoutesBuilder) throws {
        let cors = CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, /*.POST, .PUT,*/ .OPTIONS, /*.DELETE, .PATCH*/],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        ))
        let corsGroup = routes.grouped(cors, ErrorMiddleware.default(environment: try .detect()))
        let categoriesRoute = corsGroup.grouped("v1")
        categoriesRoute.get("forecast", use: self.query)
        categoriesRoute.get("dwd-icon", use: IconController().query)
        categoriesRoute.get("ecmwf", use: EcmwfController().query)
        categoriesRoute.get("marine", use: IconWaveController().query)
        categoriesRoute.get("era5", use: Era5Controller().query)
        categoriesRoute.get("elevation", use: DemController().query)
        categoriesRoute.get("air-quality", use: CamsController().query)
        categoriesRoute.get("seasonal", use: SeasonalForecastController().query)
        categoriesRoute.get("gfs", use: GfsController().query)
        categoriesRoute.get("meteofrance", use: MeteoFranceController().query)
        categoriesRoute.get("jma", use: JmaController().query)
    }
    
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(ForecastapiQuery.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 8)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 7, allowedRange: allowedRange)
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            guard let reader = try MultiDomainMixer(domains: MultiDomains.allCases, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
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
                    let d = try reader.get(variable: variable, time: hourlyTime).conertAndRound(params: params).toApi(name: variable.rawValue)
                    assert(hourlyTime.count == d.data.count)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            
            let currentWeather: ForecastapiResult.CurrentWeather?
            if params.current_weather == true {
                let starttime = currentTime.floor(toNearest: 3600)
                let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
                guard let reader = try MultiDomainMixer(domains: MultiDomains.allCases, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                let temperature = try reader.get(variable: .surface(.temperature_2m), time: time).conertAndRound(params: params)
                let winddirection = try reader.get(variable: .surface(.winddirection_10m), time: time).conertAndRound(params: params)
                let windspeed = try reader.get(variable: .surface(.windspeed_10m), time: time).conertAndRound(params: params)
                let weathercode = try reader.get(variable: .surface(.weathercode), time: time).conertAndRound(params: params)
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


struct ForecastapiQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let hourly: [ForecastVariable]?
    let daily: [ForecastVariableDaily]?
    let current_weather: Bool?
    let elevation: Float?
    let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
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
        if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}
