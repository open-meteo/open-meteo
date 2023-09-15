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
        categoriesRoute.get("ensemble", use: EnsembleApiController().query)
    }
    
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 16)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try MultiDomains.load(commaSeparatedOptional: params.models) ?? [.best_match]
        let paramsMinutely = try IconApiVariable.load(commaSeparatedOptional: params.minutely_15)
        let paramsHourly = try ForecastVariable.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try ForecastVariableDaily.load(commaSeparatedOptional: params.daily)
        let nVariables = ((paramsHourly?.count ?? 0) + (paramsMinutely?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.count
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 16, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            // limited to 3 forecast days
            let minutelyTime = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 3, forecastDaysMax: 16, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92).range.range(dtSeconds: 3600/4)
            
            let readers = try domains.compactMap {
                try GenericReaderMulti<ForecastVariable>(domain: $0, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land)
            }
            // TODO: Preliminary 15 minutes data implemetation only. Final version should support model selection with HRRR 15 minutes data.
            guard let readerMinutely = try IconMixer(domains: [.icon, .iconEu, .iconD2, .iconD2_15min], lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                throw ForecastapiError.noDataAvilableForThisLocation
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
                    guard let reader = try GenericReaderMulti<ForecastVariable>(domain: MultiDomains.best_match, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                        throw ForecastapiError.noDataAvilableForThisLocation
                    }
                    return {
                        let temperature = try reader.get(variable: .surface(.temperature_2m), time: time)!.convertAndRound(params: params)
                        let winddirection = try reader.get(variable: .surface(.winddirection_10m), time: time)!.convertAndRound(params: params)
                        let windspeed = try reader.get(variable: .surface(.windspeed_10m), time: time)!.convertAndRound(params: params)
                        let weathercode = try reader.get(variable: .surface(.weathercode), time: time)!.convertAndRound(params: params)
                        return ForecastapiResult.CurrentWeather(
                            temperature: temperature.data[0],
                            windspeed: windspeed.data[0],
                            winddirection: winddirection.data[0],
                            weathercode: weathercode.data[0],
                            is_day: try reader.get(variable: .surface(.is_day), time: time)!.convertAndRound(params: params).data[0],
                            temperature_unit: temperature.unit,
                            windspeed_unit: windspeed.unit,
                            winddirection_unit: winddirection.unit,
                            weathercode_unit: weathercode.unit,
                            time: starttime
                        )
                    }
                }() : nil,
                hourly: paramsHourly.map { variables in
                    return {
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
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: paramsDaily.map { dailyVariables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(dailyVariables.count * readers.count)
                        var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                        for reader in readers {
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
                                let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                                guard let d = try reader.getDaily(variable: variable, params: params, time: dailyTime)?.toApi(name: name) else {
                                    continue
                                }
                                assert(dailyTime.count == d.data.count)
                                res.append(d)
                            }
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
            if let iconD2 = try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                // TODO: check how out of projection areas are handled
                guard let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
                }
                return [gfs013, icon, iconEu, iconD2]
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
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    case precipitation
    case precipitation_probability
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
    case uv_index
    case uv_index_clear_sky
    case is_day
    
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
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    case apparent_temperature_max
    case apparent_temperature_min
    case apparent_temperature_mean
    case precipitation_sum
    case precipitation_probability_max
    case precipitation_probability_min
    case precipitation_probability_mean
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
    case cloudcover_max
    case cloudcover_min
    case cloudcover_mean
    case uv_index_max
    case uv_index_clear_sky_max
    
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
        }
    }
}
