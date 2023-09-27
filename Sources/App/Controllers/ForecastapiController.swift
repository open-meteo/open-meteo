import Foundation
import Vapor


public struct ForecastapiController: RouteCollection {
    /// Dedicated thread pool for API calls reading data from disk. Prevents blocking of the main thread pools.
    static var runLoop = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    public func boot(routes: RoutesBuilder) throws {
        let cors = CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, /*.POST, .PUT,*/ .OPTIONS, /*.DELETE, .PATCH*/],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        ))
        let corsGroup = routes.grouped(cors, ErrorMiddleware.default(environment: try .detect()))
        let categoriesRoute = corsGroup.grouped("v1")
        let era5 = WeatherApiController(
            forecastDay: 1,
            forecastDaysMax: 1,
            historyStartDate: Timestamp(1940, 1, 1),
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .era5_seamless,
            subdomain: "archive-api")
        categoriesRoute.get("era5", use: era5.query)
        categoriesRoute.get("archive", use: era5.query)
        
        categoriesRoute.get("forecast", use: WeatherApiController(
            defaultModel: .best_match).query
        )
        categoriesRoute.get("dwd-icon", use: WeatherApiController(
            defaultModel: .icon_seamless).query
        )
        categoriesRoute.get("gfs", use: WeatherApiController(
            has15minutely: true,
            defaultModel: .gfs_seamless).query
        )
        categoriesRoute.get("meteofrance", use: WeatherApiController(
            forecastDay: 4,
            has15minutely: false,
            defaultModel: .meteofrance_seamless).query
        )
        categoriesRoute.get("jma", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .jma_seamless).query
        )
        categoriesRoute.get("metno", use: WeatherApiController(
            forecastDay: 3,
            has15minutely: false,
            defaultModel: .metno_nordic).query
        )
        categoriesRoute.get("gem", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .gem_seamless).query
        )
        categoriesRoute.get("ecmwf", use: WeatherApiController(
            forecastDay: 10,
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .ecmwf_ifs04,
            put3HourlyDataIntoHourly: true).query
        )
        
        categoriesRoute.get("elevation", use: DemController().query)
        categoriesRoute.get("air-quality", use: CamsController().query)
        categoriesRoute.get("seasonal", use: SeasonalForecastController().query)
        categoriesRoute.get("flood", use: GloFasController().query)
        categoriesRoute.get("climate", use: CmipController().query)
        categoriesRoute.get("marine", use: IconWaveController().query)
        categoriesRoute.get("ensemble", use: EnsembleApiController().query)
    }
}

struct WeatherApiController {
    let forecastDay: Int
    let forecastDaysMax: Int
    let historyStartDate: Timestamp
    let has15minutely: Bool
    let hasCurrentWeather: Bool
    let defaultModel: MultiDomains
    let subdomain: String
    /// ecmwf v1 uses 3 hourly data in hourly field..
    let put3HourlyDataIntoHourly: Bool
    
    init(forecastDay: Int = 7, forecastDaysMax: Int = 16, historyStartDate: Timestamp = Timestamp(2022, 6, 8), has15minutely: Bool = true, hasCurrentWeather: Bool = true, defaultModel: MultiDomains, subdomain: String = "api", put3HourlyDataIntoHourly: Bool = false) {
        self.forecastDay = forecastDay
        self.forecastDaysMax = forecastDaysMax
        self.historyStartDate = historyStartDate
        self.has15minutely = has15minutely
        self.hasCurrentWeather = hasCurrentWeather
        self.defaultModel = defaultModel
        self.subdomain = subdomain
        self.put3HourlyDataIntoHourly = put3HourlyDataIntoHourly
    }
    
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain(subdomain)
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = historyStartDate ..< currentTime.add(days: forecastDaysMax)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try MultiDomains.load(commaSeparatedOptional: params.models) ?? [defaultModel]
        let paramsMinutely = has15minutely ? try ForecastVariable.load(commaSeparatedOptional: params.minutely_15) : nil
        let paramsCurrent = hasCurrentWeather ? try ForecastVariable.load(commaSeparatedOptional: params.current) : nil
        let paramsHourly = try ForecastVariable.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try ForecastVariableDaily.load(commaSeparatedOptional: params.daily)
        let nParamsHourly = paramsHourly?.count ?? 0
        let nParamsMinutely = paramsMinutely?.count ?? 0
        let nParamsCurrent = paramsCurrent?.count ?? 0
        let nParamsDaily = paramsDaily?.count ?? 0
        let nVariables = nParamsHourly + nParamsMinutely + nParamsCurrent + nParamsDaily
        
        let locations: [ForecastapiResultMulti<MultiDomains, ForecastVariable, ForecastVariableDaily>] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? forecastDay, forecastDaysMax: forecastDaysMax, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: 3600/4), nTime: 1, dtSeconds: 3600/4)
            let hourlyTime = time.range.range(dtSeconds: put3HourlyDataIntoHourly ? 3*3600 : 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            // limited to 3 forecast days
            let minutelyTime = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 3, forecastDaysMax: forecastDaysMax, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92).range.range(dtSeconds: 3600/4)
            
            let readers: [ForecastapiResult<MultiDomains, ForecastVariable, ForecastVariableDaily>] = try domains.compactMap { domain in
                guard let reader = try GenericReaderMulti<ForecastVariable>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                    return nil
                }
                
                return ForecastapiResult<MultiDomains, ForecastVariable, ForecastVariableDaily>(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let paramsCurrent {
                            try reader.prefetchData(variables: paramsCurrent, time: minutelyTime)
                        }
                        if let paramsMinutely {
                            try reader.prefetchData(variables: paramsMinutely, time: minutelyTime)
                        }
                        if let paramsHourly {
                            try reader.prefetchData(variables: paramsHourly, time: hourlyTime)
                        }
                        if let paramsDaily {
                            try reader.prefetchData(variables: paramsDaily, time: dailyTime)
                        }
                    },
                    current_weather: (hasCurrentWeather && params.current_weather == true ? {
                        let temperature = try reader.get(variable: ForecastVariable.surface(.temperature_2m), time: currentTimeRange)!.convertAndRound(params: params)
                        let winddirection = try reader.get(variable: ForecastVariable.surface(.winddirection_10m), time: currentTimeRange)!.convertAndRound(params: params)
                        let windspeed = try reader.get(variable: ForecastVariable.surface(.windspeed_10m), time: currentTimeRange)!.convertAndRound(params: params)
                        let weathercode = try reader.get(variable: ForecastVariable.surface(.weathercode), time: currentTimeRange)!.convertAndRound(params: params)
                        return CurrentWeather(
                            temperature: temperature.data[0],
                            windspeed: windspeed.data[0],
                            winddirection: winddirection.data[0],
                            weathercode: weathercode.data[0],
                            is_day: try reader.get(variable: .surface(.is_day), time: currentTimeRange)!.convertAndRound(params: params).data[0],
                            temperature_unit: temperature.unit,
                            windspeed_unit: windspeed.unit,
                            winddirection_unit: winddirection.unit,
                            weathercode_unit: weathercode.unit,
                            time: currentTimeRange.range.lowerBound
                        )
                    } : nil),
                    current: paramsCurrent.map { variables in
                        return {
                            var res = [ApiColumnSingle]()
                            res.reserveCapacity(variables.count)
                                for variable in variables {
                                    // TODO
                                    let name = variable.rawValue
                                    guard let d = try reader.get(variable: variable, time: currentTimeRange)?.convertAndRound(params: params).toApiSingle(name: name) else {
                                        continue
                                    }
                                    res.append(d)
                                }
                            return ApiSectionSingle(name: "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: res)
                        }
                    },
                    hourly: paramsHourly.map { variables in
                        return {
                            return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: try variables.compactMap { variable -> ApiColumn<ForecastVariable>? in
                                guard let d = try reader.get(variable: variable, time: hourlyTime)?.convertAndRound(params: params) else {
                                    return nil
                                }
                                assert(hourlyTime.count == d.data.count)
                                return ApiColumn<ForecastVariable>(variable: variable, unit: d.unit, data: .float(d.data))
                            })
                        }
                    },
                    daily: paramsDaily.map { dailyVariables in
                        return {
                            var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                            return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try dailyVariables.compactMap { variable -> ApiColumn<ForecastVariableDaily>? in
                                if variable == .sunrise || variable == .sunset {
                                    // only calculate sunrise/set once
                                    let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.range, lat: coordinates.latitude, lon: coordinates.longitude, utcOffsetSeconds: time.utcOffsetSeconds)
                                    riseSet = times
                                    if variable == .sunset {
                                        return ApiColumn(variable: .sunset, unit: params.timeformatOrDefault.unit, data: .timestamp(times.set))
                                    } else {
                                        return ApiColumn(variable: .sunrise, unit: params.timeformatOrDefault.unit, data: .timestamp(times.rise))
                                    }
                                }
                                guard let d = try reader.getDaily(variable: variable, params: params, time: dailyTime) else {
                                    return nil
                                }
                                assert(dailyTime.count == d.data.count)
                                return ApiColumn<ForecastVariableDaily>(variable: variable, unit: d.unit, data: .float(d.data))
                            })
                        }
                    },
                    sixHourly: nil,
                    minutely15: paramsMinutely.map { variables in
                        return {
                            return ApiSection(name: "minutely_15", time: minutelyTime.add(utcOffsetShift), columns: try variables.compactMap { variable -> ApiColumn<ForecastVariable>? in
                                guard let d = try reader.get(variable: variable, time: minutelyTime)?.convertAndRound(params: params) else {
                                    return nil
                                }
                                assert(minutelyTime.count == d.data.count)
                                return ApiColumn<ForecastVariable>(variable: variable, unit: d.unit, data: .float(d.data))
                            })
                        }
                    }
                )
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return ForecastapiResultMulti<MultiDomains, ForecastVariable, ForecastVariableDaily>(timezone: timezone, time: time, results: readers)
        }
        let result = ForecastapiResultSet<MultiDomains, ForecastVariable, ForecastVariableDaily>(timeformat: params.timeformatOrDefault, results: locations)
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
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
enum MultiDomains: String, RawRepresentableString, CaseIterable, MultiDomainMixerDomain {
    case best_match

    case gfs_seamless
    case gfs_mix
    case gfs_global
    case gfs_hrrr
    
    case meteofrance_seamless
    case meteofrance_mix
    case meteofrance_arpege_seamless
    case meteofrance_arpege_world
    case meteofrance_arpege_europe
    case meteofrance_arome_seamless
    case meteofrance_arome_france
    case meteofrance_arome_france_hd
    case arpege_seamless
    case arpege_world
    case arpege_europe
    case arome_seamless
    case arome_france
    case arome_france_hd
    
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
    
    case era5_seamless
    case era5
    case cerra
    case era5_land
    case ecmwf_ifs
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            guard let icon: any GenericReaderProtocol = try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            guard let gfs013: any GenericReaderProtocol = try GfsReader(domain: .gfs013, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            // Scandinavian region, combine with ICON
            if lat >= 54.9, let metno = try MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode)
                return Array([gfs013, icon, iconEu, metno].compacted())
            }
            // If Icon-d2 is available, use icon domains
            if let iconD2 = try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode),
               let iconD2_15min = try IconReader(domain: .iconD2_15min, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                // TODO: check how out of projection areas are handled
                guard let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
                }
                return [gfs013, icon, iconEu, iconD2, iconD2_15min]
            }
            // For western europe, use arome models
            if let arome_france_hd = try MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                let arome_france = try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode)
                let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode)
                return Array([gfs013, icon, arpege_europe, arome_france, arome_france_hd].compacted())
            }
            // For North America, use HRRR
            if let hrrr = try GfsReader(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [icon, gfs013, hrrr]
            }
            // For Japan use JMA MSM with ICON. Does not use global JMA model because of poor resolution
            if let jma_msm = try JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs013, icon, jma_msm]
            }
            
            // Remaining eastern europe
            if let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs013, icon, iconEu]
            }
            
            // Northern africa
            if let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs013, icon, arpege_europe]
            }
            
            // Remaining parts of the world
            return [gfs013, icon]
        case .gfs_seamless:
            fallthrough
        case .gfs_mix:
            return try GfsMixer(domains: [.gfs013, .hrrr_conus], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gfs_global:
            return try GfsMixer(domains: [.gfs013], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gfs_hrrr:
            return try GfsMixer(domains: [.hrrr_conus], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .meteofrance_seamless:
            fallthrough
        case .meteofrance_mix:
            return try MeteoFranceMixer(domains: [.arpege_world, .arpege_europe, .arome_france, .arome_france_hd], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .meteofrance_arpege_seamless:
            fallthrough
        case .arpege_seamless:
            return try MeteoFranceMixer(domains: [.arpege_world, .arpege_europe], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .meteofrance_arome_seamless:
            fallthrough
        case .arome_seamless:
            return try MeteoFranceMixer(domains: [.arome_france, .arome_france_hd], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .arpege_world:
            fallthrough
        case .meteofrance_arpege_world:
            return try MeteoFranceReader(domain: .arpege_world, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .arpege_europe:
            fallthrough
        case .meteofrance_arpege_europe:
            return try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .arome_france:
            fallthrough
        case .meteofrance_arome_france:
            return try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .arome_france_hd:
            fallthrough
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
            return try IconMixer(domains: [.icon, .iconEu, .iconD2, .iconD2_15min], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .icon_global:
            return try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_eu:
            return try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_d2:
            return try IconMixer(domains: [.iconD2, .iconD2_15min], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
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
        case .era5_seamless:
            return [try Era5Factory.makeEra5CombinedLand(lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .era5:
            return [try Era5Factory.makeReader(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .era5_land:
            return [try Era5Factory.makeReader(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        case .cerra:
            return try CerraReader(domain: .cerra, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs:
            return [try Era5Factory.makeReader(domain: .ecmwf_ifs, lat: lat, lon: lon, elevation: elevation, mode: mode)]
        }
    }
    
    var countEnsembleMember: Int {
        return 1
    }
}

enum ModelError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        return .badRequest
    }
    
    case domainInitFailed(domain: String)
}


/// Define all available surface weather variables
enum ForecastSurfaceVariable: String, GenericVariableMixable {
    case apparent_temperature
    case cape
    case cloudcover
    case cloudcover_high
    case cloudcover_low
    case cloudcover_mid
    case dewpoint_2m
    case diffuse_radiation
    case diffuse_radiation_instant
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case et0_fao_evapotranspiration
    case evapotranspiration
    case freezinglevel_height
    case growing_degree_days_base_0_limit_50
    case is_day
    case latent_heatflux
    case leaf_wetness_probability
    case lightning_potential
    case precipitation
    case precipitation_probability
    case pressure_msl
    case rain
    case relativehumidity_2m
    case runoff
    case sensible_heatflux
    case shortwave_radiation
    case shortwave_radiation_instant
    case showers
    case skin_temperature
    case snow_depth
    case snow_height
    case snowfall
    case snowfall_water_equivalent
    case soil_moisture_0_1cm
    case soil_moisture_0_to_1cm
    case soil_moisture_0_to_100cm
    case soil_moisture_0_to_10cm
    case soil_moisture_0_to_7cm
    case soil_moisture_100_to_200cm
    case soil_moisture_100_to_255cm
    case soil_moisture_10_to_40cm
    case soil_moisture_1_3cm
    case soil_moisture_1_to_3cm
    case soil_moisture_27_81cm
    case soil_moisture_27_to_81cm
    case soil_moisture_28_to_100cm
    case soil_moisture_3_9cm
    case soil_moisture_3_to_9cm
    case soil_moisture_40_to_100cm
    case soil_moisture_7_to_28cm
    case soil_moisture_9_27cm
    case soil_moisture_9_to_27cm
    case soil_moisture_index_0_to_100cm
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_7_to_28cm
    case soil_temperature_0_to_100cm
    case soil_temperature_0_to_10cm
    case soil_temperature_0_to_7cm
    case soil_temperature_0cm
    case soil_temperature_100_to_200cm
    case soil_temperature_100_to_255cm
    case soil_temperature_10_to_40cm
    case soil_temperature_18cm
    case soil_temperature_28_to_100cm
    case soil_temperature_40_to_100cm
    case soil_temperature_54cm
    case soil_temperature_6cm
    case soil_temperature_7_to_28cm
    case surface_air_pressure
    case surface_pressure
    case surface_temperature
    case temperature_120m
    case temperature_180m
    case temperature_2m
    case temperature_40m
    case temperature_80m
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case total_column_integrated_water_vapour
    case updraft
    case uv_index
    case uv_index_clear_sky
    case vapor_pressure_deficit
    case visibility
    case weathercode
    case winddirection_100m
    case winddirection_10m
    case winddirection_120m
    case winddirection_150m
    case winddirection_180m
    case winddirection_200m
    case winddirection_20m
    case winddirection_40m
    case winddirection_50m
    case winddirection_80m
    case windgusts_10m
    case windspeed_100m
    case windspeed_10m
    case windspeed_120m
    case windspeed_150m
    case windspeed_180m
    case windspeed_200m
    case windspeed_20m
    case windspeed_40m
    case windspeed_50m
    case windspeed_80m

    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_1cm: return true
        case .soil_moisture_0_to_100cm: return true
        case .soil_moisture_0_to_10cm: return true
        case .soil_moisture_0_to_7cm: return true
        case .soil_moisture_100_to_200cm: return true
        case .soil_moisture_100_to_255cm: return true
        case .soil_moisture_10_to_40cm: return true
        case .soil_moisture_1_3cm: return true
        case .soil_moisture_27_81cm: return true
        case .soil_moisture_28_to_100cm: return true
        case .soil_moisture_3_9cm: return true
        case .soil_moisture_40_to_100cm: return true
        case .soil_moisture_7_to_28cm: return true
        case .soil_moisture_9_27cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
}

/// Available pressure level variables
enum ForecastPressureVariableType: String, GenericVariableMixable {
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
enum ForecastVariableDaily: String, DailyVariableCalculatable, RawRepresentableString {
    case apparent_temperature_max
    case apparent_temperature_mean
    case apparent_temperature_min
    case cape_max
    case cape_mean
    case cape_min
    case cloudcover_max
    case cloudcover_mean
    case cloudcover_min
    case dewpoint_2m_max
    case dewpoint_2m_mean
    case dewpoint_2m_min
    case et0_fao_evapotranspiration
    case et0_fao_evapotranspiration_sum
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability_mean
    case precipitation_hours
    case precipitation_probability_max
    case precipitation_probability_mean
    case precipitation_probability_min
    case precipitation_sum
    case pressure_msl_max
    case pressure_msl_mean
    case pressure_msl_min
    case rain_sum
    case relative_humidity_2m_max
    case relative_humidity_2m_mean
    case relative_humidity_2m_min
    case shortwave_radiation_sum
    case showers_sum
    case snowfall_sum
    case snowfall_water_equivalent_sum
    case soil_moisture_0_to_100cm_mean
    case soil_moisture_0_to_10cm_mean
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_28_to_100cm_mean
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_index_0_to_100cm_mean
    case soil_moisture_index_0_to_7cm_mean
    case soil_moisture_index_100_to_255cm_mean
    case soil_moisture_index_28_to_100cm_mean
    case soil_moisture_index_7_to_28cm_mean
    case soil_temperature_0_to_100cm_mean
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_28_to_100cm_mean
    case soil_temperature_7_to_28cm_mean
    case sunrise
    case sunset
    case surface_pressure_max
    case surface_pressure_mean
    case surface_pressure_min
    case temperature_2m_max
    case temperature_2m_mean
    case temperature_2m_min
    case updraft_max
    case uv_index_clear_sky_max
    case uv_index_max
    case vapor_pressure_deficit_max
    case visibility_max
    case visibility_mean
    case visibility_min
    case weathercode
    case winddirection_10m_dominant
    case windgusts_10m_max
    case windgusts_10m_mean
    case windgusts_10m_min
    case windspeed_10m_max
    case windspeed_10m_mean
    case windspeed_10m_min
    
    
    var aggregation: DailyAggregation<ForecastVariable> {
        switch self {
        case .temperature_2m_max:
            return .max(.surface(.temperature_2m))
        case .temperature_2m_min:
            return .min(.surface(.temperature_2m))
        case .temperature_2m_mean:
            return .mean(.surface(.temperature_2m))
        case .apparent_temperature_max:
            return .max(.surface(.apparent_temperature))
        case .apparent_temperature_mean:
            return .mean(.surface(.apparent_temperature))
        case .apparent_temperature_min:
            return .min(.surface(.apparent_temperature))
        case .precipitation_sum:
            return .sum(.surface(.precipitation))
        case .snowfall_sum:
            return .sum(.surface(.snowfall))
        case .rain_sum:
            return .sum(.surface(.rain))
        case .showers_sum:
            return .sum(.surface(.showers))
        case .weathercode:
            return .max(.surface(.weathercode))
        case .shortwave_radiation_sum:
            return .radiationSum(.surface(.shortwave_radiation))
        case .windspeed_10m_max:
            return .max(.surface(.windspeed_10m))
        case .windspeed_10m_min:
            return .min(.surface(.windspeed_10m))
        case .windspeed_10m_mean:
            return .mean(.surface(.windspeed_10m))
        case .windgusts_10m_max:
            return .max(.surface(.windgusts_10m))
        case .windgusts_10m_min:
            return .min(.surface(.windgusts_10m))
        case .windgusts_10m_mean:
            return .mean(.surface(.windgusts_10m))
        case .winddirection_10m_dominant:
            return .dominantDirection(velocity: .surface(.windspeed_10m), direction: .surface(.winddirection_10m))
        case .precipitation_hours:
            return .precipitationHours(.surface(.precipitation))
        case .sunrise:
            return .none
        case .sunset:
            return .none
        case .et0_fao_evapotranspiration:
            return .sum(.surface(.et0_fao_evapotranspiration))
        case .visibility_max:
            return .max(.surface(.visibility))
        case .visibility_min:
            return .min(.surface(.visibility))
        case .visibility_mean:
            return .mean(.surface(.visibility))
        case .pressure_msl_max:
            return .max(.surface(.pressure_msl))
        case .pressure_msl_min:
            return .min(.surface(.pressure_msl))
        case .pressure_msl_mean:
            return .mean(.surface(.pressure_msl))
        case .surface_pressure_max:
            return .max(.surface(.surface_pressure))
        case .surface_pressure_min:
            return .min(.surface(.surface_pressure))
        case .surface_pressure_mean:
            return .mean(.surface(.surface_pressure))
        case .cape_max:
            return .max(.surface(.cape))
        case .cape_min:
            return .min(.surface(.cape))
        case .cape_mean:
            return .mean(.surface(.cape))
        case .cloudcover_max:
            return .max(.surface(.cloudcover))
        case .cloudcover_min:
            return .min(.surface(.cloudcover))
        case .cloudcover_mean:
            return .mean(.surface(.cloudcover))
        case .uv_index_max:
            return .max(.surface(.uv_index))
        case .uv_index_clear_sky_max:
            return .max(.surface(.uv_index_clear_sky))
        case .precipitation_probability_max:
            return .max(.surface(.precipitation_probability))
        case .precipitation_probability_min:
            return .max(.surface(.precipitation_probability))
        case .precipitation_probability_mean:
            return .max(.surface(.precipitation_probability))
        case .dewpoint_2m_max:
            return .max(.surface(.dewpoint_2m))
        case .dewpoint_2m_mean:
            return .mean(.surface(.dewpoint_2m))
        case .dewpoint_2m_min:
            return .min(.surface(.dewpoint_2m))
        case .et0_fao_evapotranspiration_sum:
            return .sum(.surface(.et0_fao_evapotranspiration))
        case .growing_degree_days_base_0_limit_50:
            return .sum(.surface(.growing_degree_days_base_0_limit_50))
        case .leaf_wetness_probability_mean:
            return .mean(.surface(.leaf_wetness_probability))
        case .relative_humidity_2m_max:
            return .max(.surface(.relativehumidity_2m))
        case .relative_humidity_2m_mean:
            return .mean(.surface(.relativehumidity_2m))
        case .relative_humidity_2m_min:
            return .min(.surface(.relativehumidity_2m))
        case .snowfall_water_equivalent_sum:
            return .sum(.surface(.snowfall_water_equivalent))
        case .soil_moisture_0_to_100cm_mean:
            return .mean(.surface(.soil_moisture_0_to_100cm))
        case .soil_moisture_0_to_10cm_mean:
            return .mean(.surface(.soil_moisture_0_to_10cm))
        case .soil_moisture_0_to_7cm_mean:
            return .mean(.surface(.soil_moisture_0_to_7cm))
        case .soil_moisture_28_to_100cm_mean:
            return .mean(.surface(.soil_moisture_28_to_100cm))
        case .soil_moisture_7_to_28cm_mean:
            return .mean(.surface(.soil_moisture_7_to_28cm))
        case .soil_moisture_index_0_to_100cm_mean:
            return .mean(.surface(.soil_moisture_index_0_to_100cm))
        case .soil_moisture_index_0_to_7cm_mean:
            return .mean(.surface(.soil_moisture_index_0_to_7cm))
        case .soil_moisture_index_100_to_255cm_mean:
            return .mean(.surface(.soil_moisture_index_100_to_255cm))
        case .soil_moisture_index_28_to_100cm_mean:
            return .mean(.surface(.soil_moisture_index_28_to_100cm))
        case .soil_moisture_index_7_to_28cm_mean:
            return .mean(.surface(.soil_moisture_index_7_to_28cm))
        case .soil_temperature_0_to_100cm_mean:
            return .mean(.surface(.soil_temperature_0_to_100cm))
        case .soil_temperature_0_to_7cm_mean:
            return .mean(.surface(.soil_temperature_0_to_7cm))
        case .soil_temperature_28_to_100cm_mean:
            return .mean(.surface(.soil_temperature_28_to_100cm))
        case .soil_temperature_7_to_28cm_mean:
            return .mean(.surface(.soil_temperature_7_to_28cm))
        case .updraft_max:
            return .max(.surface(.updraft))
        case .vapor_pressure_deficit_max:
            return .max(.surface(.vapor_pressure_deficit))
        }
    }
}
