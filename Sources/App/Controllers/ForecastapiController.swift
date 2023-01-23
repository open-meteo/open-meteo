import Foundation
import Vapor


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
        categoriesRoute.get("archive", use: Era5Controller().query)
        categoriesRoute.get("elevation", use: DemController().query)
        categoriesRoute.get("air-quality", use: CamsController().query)
        categoriesRoute.get("seasonal", use: SeasonalForecastController().query)
        categoriesRoute.get("gfs", use: GfsController().query)
        categoriesRoute.get("meteofrance", use: MeteoFranceController().query)
        categoriesRoute.get("jma", use: JmaController().query)
        categoriesRoute.get("metno", use: MetNoController().query)
        categoriesRoute.get("gem", use: GemController().query)
        categoriesRoute.get("flood", use: GloFasController().query)
        categoriesRoute.get("climate", use: CmipController().query)
    }
    
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(ForecastApiQuery.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 16)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 7, allowedRange: allowedRange)
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = params.models ?? [.best_match]
            
            let readers = try domains.compactMap {
                try GenericReaderMulti<ForecastVariable>(domain: $0, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised)
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
            
            let currentWeather: ForecastapiResult.CurrentWeather?
            if params.current_weather == true {
                let starttime = currentTime.floor(toNearest: 3600)
                let time = TimerangeDt(start: starttime, nTime: 1, dtSeconds: 3600)
                guard let reader = try GenericReaderMulti<ForecastVariable>(domain: MultiDomains.best_match, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                let temperature = try reader.get(variable: .surface(.temperature_2m), time: time)!.convertAndRound(params: params)
                let winddirection = try reader.get(variable: .surface(.winddirection_10m), time: time)!.convertAndRound(params: params)
                let windspeed = try reader.get(variable: .surface(.windspeed_10m), time: time)!.convertAndRound(params: params)
                let weathercode = try reader.get(variable: .surface(.weathercode), time: time)!.convertAndRound(params: params)
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


struct ForecastApiQuery: Content, QueryWithStartEndDateTimeZone, ApiUnitsSelectable {
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
    let models: [MultiDomains]?
    
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

/**
 Automatic domain selection rules:
 - If HRRR domain matches, use HRRR+GFS+ICON
 - If Western Europe, use Arome + ICON_EU+ ICON + GFS
 - If Central Europe, use ICON_D2, ICON_EU, ICON + GFS
 - If Japan, use JMA_MSM + ICON + GFS
 - default ICON + GFS
 
 Note Nov 2022: Use the term `seamless` instead of `mix`
 */
enum MultiDomains: String, Codable, CaseIterable, MultiDomainMixerDomain {
    case best_match

    case gfs_seamless
    case gfs_mix
    case gfs_global
    case gfs_hrrr
    
    case meteofrance_seamless
    case meteofrance_mix
    case meteofrance_arpege_world
    case meteofrance_arpege_europe
    case meteofrance_arome_france
    case meteofrance_arome_france_hd
    
    case jma_seamless
    case jma_mix
    case jma_msm
    case jms_gsm
    case jma_gsm
    
    case gem_seamless
    case gem_global
    case gem_regional
    case gem_hrdps_continental
    
    case icon_seamless
    case icon_mix
    case icon_global
    case icon_eu
    case icon_d2
    
    case ecmwf_ifs04
    
    case metno_nordic
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable] {
        switch self {
        case .best_match:
            guard let icon: any GenericReaderMixable = try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            guard let gfs025: any GenericReaderMixable = try GfsReader(domain: .gfs025, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            // Scandinavian region, combine with ICON
            if lat >= 54.9, let metno = try MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode)
                return Array([gfs025, icon, iconEu, metno].compacted())
            }
            // If Icon-d2 is available, use icon domains
            if let iconD2 = try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                // TODO: check how out of projection areas are handled
                guard let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
                }
                return [gfs025, icon, iconEu, iconD2]
            }
            // For western europe, use arome models
            if let arome_france_hd = try MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                let arome_france = try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode)
                let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode)
                return Array([gfs025, icon, arpege_europe, arome_france, arome_france_hd].compacted())
            }
            // For North America, use HRRR
            if let hrrr = try GfsReader(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [icon, gfs025, hrrr]
            }
            // For Japan use JMA MSM with ICON. Does not use global JMA model because of poor resolution
            if let jma_msm = try JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, jma_msm]
            }
            
            // Remaining eastern europe
            if let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, iconEu]
            }
            
            // Northern africa
            if let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, arpege_europe]
            }
            
            // Remaining parts of the world
            return [gfs025, icon]
        case .gfs_seamless:
            fallthrough
        case .gfs_mix:
            return try GfsMixer(domains: [.gfs025, .hrrr_conus], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gfs_global:
            return try GfsReader(domain: .gfs025, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gfs_hrrr:
            return try GfsReader(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_seamless:
            fallthrough
        case .meteofrance_mix:
            return try MeteoFranceMixer(domains: [.arpege_world, .arpege_europe, .arome_france, .arome_france_hd], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .meteofrance_arpege_world:
            return try MeteoFranceReader(domain: .arpege_world, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arpege_europe:
            return try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arome_france:
            return try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arome_france_hd:
            return try MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .jma_seamless:
            fallthrough
        case .jma_mix:
            return try JmaMixer(domains: [.gsm, .msm], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .jma_msm:
            return try JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .jms_gsm:
            fallthrough
        case .jma_gsm:
            return try JmaReader(domain: .gsm, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_seamless:
            fallthrough
        case .icon_mix:
            return try IconMixer(domains: [.icon, .iconEu, .iconD2], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .icon_global:
            return try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_eu:
            return try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_d2:
            return try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs04:
            return try EcmwfReader(domain: .ifs04, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .metno_nordic:
            return try MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gem_seamless:
            return try GemMixer(domains: [.gem_global, .gem_regional, .gem_hrdps_continental], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gem_global:
            return try GemReader(domain: .gem_global, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gem_regional:
            return try GemReader(domain: .gem_regional, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gem_hrdps_continental:
            return try GemReader(domain: .gem_hrdps_continental, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        }
    }
}

enum ModelError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        return .badRequest
    }
    
    case domainInitFailed(domain: String)
}


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
    case snow_height
    case sensible_heatflux
    case latent_heatflux
    case showers
    case rain
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
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case visibility
    case cape
    
    /// Currently only from icon-d2
    case lightning_potential
    
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
enum ForecastPressureVariableType: String, Codable, GenericVariableMixable {
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

struct ForecastPressureVariable: PressureVariableRespresentable, GenericVariableMixable {
    let variable: ForecastPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias ForecastVariable = SurfaceAndPressureVariable<ForecastSurfaceVariable, ForecastPressureVariable>

/// Available daily aggregations
enum ForecastVariableDaily: String, Codable {
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    case apparent_temperature_max
    case apparent_temperature_min
    case apparent_temperature_mean
    case precipitation_sum
    case snowfall_sum
    case rain_sum
    case showers_sum
    case weathercode
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
    case visibility_max
    case visibility_min
    case visibility_mean
    case pressure_msl_max
    case pressure_msl_min
    case pressure_msl_mean
    case surface_pressure_max
    case surface_pressure_min
    case surface_pressure_mean
    case cape_max
    case cape_min
    case cape_mean
    
    var aggregation: DailyAggregation<ForecastSurfaceVariable> {
        switch self {
        case .temperature_2m_max:
            return .max(.temperature_2m)
        case .temperature_2m_min:
            return .min(.temperature_2m)
        case .temperature_2m_mean:
            return .mean(.temperature_2m)
        case .apparent_temperature_max:
            return .max(.apparent_temperature)
        case .apparent_temperature_mean:
            return .mean(.apparent_temperature)
        case .apparent_temperature_min:
            return .min(.apparent_temperature)
        case .precipitation_sum:
            return .sum(.precipitation)
        case .snowfall_sum:
            return .sum(.snowfall)
        case .rain_sum:
            return .sum(.rain)
        case .showers_sum:
            return .sum(.showers)
        case .weathercode:
            return .max(.weathercode)
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
            return .sum(.evapotranspiration)
        case .visibility_max:
            return .max(.visibility)
        case .visibility_min:
            return .min(.visibility)
        case .visibility_mean:
            return .mean(.visibility)
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
        case .cape_max:
            return .max(.cape)
        case .cape_min:
            return .min(.cape)
        case .cape_mean:
            return .mean(.cape)
        }
    }
}

enum DailyAggregation<WeatherVariable> {
    case none
    case max(WeatherVariable)
    case min(WeatherVariable)
    case mean(WeatherVariable)
    case sum(WeatherVariable)
    case radiationSum(WeatherVariable)
    case precipitationHours(WeatherVariable)
    case dominantDirection(velocity: WeatherVariable, direction: WeatherVariable)
    
    /// Return 0, 1 or 2 weahter variables which should be prefetched
    var variables: (WeatherVariable?, WeatherVariable?) {
        switch self {
        case .none:
            return (nil, nil)
        case .max(let weatherVariable):
            return (weatherVariable, nil)
        case .min(let weatherVariable):
            return (weatherVariable, nil)
        case .mean(let weatherVariable):
            return (weatherVariable, nil)
        case .sum(let weatherVariable):
            return (weatherVariable, nil)
        case .radiationSum(let weatherVariable):
            return (weatherVariable, nil)
        case .precipitationHours(let weatherVariable):
            return (weatherVariable, nil)
        case .dominantDirection(let velocity, let direction):
            return (velocity, direction)
        }
    }
}


extension GenericReaderMulti where Variable == ForecastVariable {
    func get(variable: ForecastSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit? {
        return try get(variable: .surface(variable), time: time)
    }
    
    func getDaily(variable: ForecastVariableDaily, params: ForecastApiQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit? {
        let time = timeDaily.with(dtSeconds: 3600)
        
        switch variable.aggregation {
        case .none:
            return nil
        case .max(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .min(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .mean(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .sum(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.sum(by: 24), data.unit)
        case .radiationSum(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .precipitationHours(let variable):
            guard let data = try get(variable: variable, time: time)?.convertAndRound(params: params) else {
                return nil
            }
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .dominantDirection(velocity: let velocity, direction: let direction):
            guard let speed = try get(variable: velocity, time: time)?.data,
                let direction = try get(variable: direction, time: time)?.data else {
                return nil
            }
            // vector addition
            let u = zip(speed, direction).map(Meteorology.uWind).sum(by: 24)
            let v = zip(speed, direction).map(Meteorology.vWind).sum(by: 24)
            return DataAndUnit(Meteorology.windirectionFast(u: u, v: v), .degreeDirection)
        }
    }
    

    func prefetchData(variables: [ForecastVariableDaily], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            let v = variable.aggregation
            if let v0 = variable.aggregation.variables.0 {
                try prefetchData(variable: .surface(v0), time: time)
            }
            if let v1 = variable.aggregation.variables.1 {
                try prefetchData(variable: .surface(v1), time: time)
            }
        }
    }
}
