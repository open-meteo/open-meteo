import Foundation
import OpenMeteoSdk
import Vapor

public struct ForecastapiController: RouteCollection {
    public func boot(routes: RoutesBuilder) throws {
        let categoriesRoute = routes.grouped("v1")
        let era5 = WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .archive_best_match,
            subdomain: "archive-api",
            alias: ["satellite-api"]
        )
        categoriesRoute.getAndPost("era5", use: era5.query)
        categoriesRoute.getAndPost("archive", use: era5.query)

        categoriesRoute.getAndPost("forecast", use: WeatherApiController(
            defaultModel: .best_match,
            alias: ["historical-forecast-api", "previous-runs-api", "single-runs-api", "seasonal-api", "res1-api"]).query
        )
        categoriesRoute.getAndPost("dwd-icon", use: WeatherApiController(
            defaultModel: .icon_seamless).query
        )
        categoriesRoute.getAndPost("gfs", use: WeatherApiController(
            has15minutely: true,
            defaultModel: .gfs_seamless).query
        )
        categoriesRoute.getAndPost("meteofrance", use: WeatherApiController(
            has15minutely: true,
            defaultModel: .meteofrance_seamless).query
        )
        categoriesRoute.getAndPost("jma", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .jma_seamless).query
        )
        categoriesRoute.getAndPost("metno", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .metno_nordic).query
        )
        categoriesRoute.getAndPost("gem", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .gem_seamless).query
        )
        categoriesRoute.getAndPost("ecmwf", use: WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .ecmwf_ifs025).query
        )
        categoriesRoute.getAndPost("cma", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .cma_grapes_global).query
        )
        categoriesRoute.getAndPost("bom", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .bom_access_global).query
        )
        categoriesRoute.getAndPost("arpae", use: WeatherApiController(
            has15minutely: false,
            defaultModel: .arpae_cosmo_seamless).query
        )

        categoriesRoute.getAndPost("elevation", use: DemController().query)
        categoriesRoute.getAndPost("air-quality", use: WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: true,
            defaultModel: .air_quality_best_match,
            subdomain: "air-quality-api",
            alias: ["res1-api"],
            type: .airQuality
        ).query)
        categoriesRoute.getAndPost("seasonal", use: WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .ecmwf_seasonal_seamless,
            subdomain: "seasonal-api",
            type: .seasonal
        ).query)
        categoriesRoute.getAndPost("flood", use: WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .flood_best_match,
            subdomain: "flood-api",
            type: .flood
        ).query)
        categoriesRoute.getAndPost("climate", use: WeatherApiController(
            has15minutely: false,
            hasCurrentWeather: false,
            defaultModel: .MRI_AGCM3_2_S,
            subdomain: "climate-api",
            type: .climate
        ).query)
        categoriesRoute.getAndPost("marine", use: WeatherApiController(
            has15minutely: true,
            hasCurrentWeather: true,
            defaultModel: .marine_best_match,
            subdomain: "marine-api",
            type: .marine
        ).query)
        categoriesRoute.getAndPost("ensemble", use: WeatherApiController(
            defaultModel: .best_match,
            subdomain: "ensemble-api",
            type: .ensemble).query
        )
    }
}

struct WeatherApiController {
    let has15minutely: Bool
    let hasCurrentWeather: Bool
    let defaultModel: MultiDomains
    let subdomain: String
    let alias: [String]
    let type: ApiType?

    init(has15minutely: Bool = true, hasCurrentWeather: Bool = true, defaultModel: MultiDomains, subdomain: String = "api", alias: [String] = [], type: ApiType? = nil) {
        self.has15minutely = has15minutely
        self.hasCurrentWeather = hasCurrentWeather
        self.defaultModel = defaultModel
        self.subdomain = subdomain
        self.alias = alias
        self.type = type
    }
    
    enum ApiType {
        /// Self-host or localhost
        case none
        case forecast
        case archive
        case historicalForecast
        case previousRuns
        case satellite
        case singleRunsApi
        case seasonal
        case ensemble
        case marine
        case airQuality
        case climate
        case flood
        
        static func detect(host: String?) -> Self {
            guard let host else {
                return .none
            }
            switch host {
            case "historical-forecast-api.open-meteo.com", "customer-historical-forecast-api.open-meteo.com":
                return .historicalForecast
            case "previous-runs-api.open-meteo.com", "customer-previous-runs-api.open-meteo.com":
                return .previousRuns
            case "single-runs-api.open-meteo.com", "customer-single-runs-api.open-meteo.com":
                return .singleRunsApi
            case "archive-api.open-meteo.com", "customer-archive-api.open-meteo.com":
                return .archive
            case "satellite-api.open-meteo.com", "customer-satellite-api.open-meteo.com":
                return .satellite
            case "seasonal-api.open-meteo.com", "customer-seasonal-api.open-meteo.com":
                return .seasonal
            case "api.open-meteo.com", "customer-api.open-meteo.com", "customer-res1-api.open-meteo.com":
                return .forecast
            case "marine-api.open-meteo.com", "customer-marine-api.open-meteo.com":
                return .marine
            case "air-quality-api.open-meteo.com", "customer-air-quality-api.open-meteo.com":
                return .airQuality
            case "climate-api.open-meteo.com", "customer-climate-api.open-meteo.com":
                return .climate
            case "flood-api.open-meteo.com", "customer-flood-api.open-meteo.com":
                return .flood
            default:
                return .none
            }
        }
    }
    
    func query(_ req: Request) async throws -> Response {
        OmMetrics.requestsForecastApiTotal.add(1, ordering: .relaxed)
        guard OmMetrics.requestsRunning.load(ordering: .relaxed) <= RateLimiter.concurrencyLimitTotal else {
            OmMetrics.requestsServiceOverloadedTotal.add(1, ordering: .relaxed)
            throw RateLimitError.serviceOverloaded
        }
        return try await req.withApiParameter(subdomain, alias: alias) { info, params -> ForecastapiResult<MultiDomainsReader> in
            let type = type ?? ApiType.detect(host: info.host)
            let currentTime = Timestamp.now()
            let currentTimeHour0 = currentTime.with(hour: 0)
            
            let forecastDaysMax: Int
            let forecastDayDefault: Int
            let historyStartDate: Timestamp
            let historyEndDate: Timestamp? = type == .climate ? Timestamp(2051, 1, 1) : nil
            let temporalResolutionDefault: ApiTemporalResolution
            let allowRemoteArchive = !(OpenMeteo.remoteDataDirectoryMinimumAge ?? 0 >= 24*3600 && type == .forecast)
            switch type {
            case .none:
                forecastDaysMax = 217
                forecastDayDefault = 7
                historyStartDate = Timestamp(1940, 1, 1)
                temporalResolutionDefault = .hourly
            case .forecast:
                forecastDaysMax = 16
                forecastDayDefault = 7
                historyStartDate = currentTimeHour0.subtract(days: 93)
                temporalResolutionDefault = .hourly
            case .archive:
                forecastDaysMax = 1
                forecastDayDefault = 1
                historyStartDate = Timestamp(1940, 1, 1)
                temporalResolutionDefault = .hourly
            case .historicalForecast:
                forecastDaysMax = 16
                forecastDayDefault = 1
                historyStartDate = Timestamp(2016, 1, 1)
                temporalResolutionDefault = .hourly
            case .previousRuns:
                forecastDaysMax = 16
                forecastDayDefault = 7
                historyStartDate = Timestamp(2016, 1, 1)
                temporalResolutionDefault = .hourly
            case .satellite:
                forecastDaysMax = 1
                forecastDayDefault = 1
                historyStartDate = Timestamp(1983, 1, 1)
                temporalResolutionDefault = .hourly
            case .singleRunsApi:
                forecastDaysMax = 16
                forecastDayDefault = 7
                historyStartDate = Timestamp(2023, 1, 1)
                temporalResolutionDefault = .hourly
            case .seasonal:
                forecastDaysMax = 217
                forecastDayDefault = 183
                historyStartDate = Timestamp(2025, 9, 1)
                temporalResolutionDefault = .hourly_6
            case .ensemble:
                forecastDaysMax = 36
                forecastDayDefault = 7
                historyStartDate = currentTimeHour0.subtract(days: 93)
                temporalResolutionDefault = .hourly
            case .marine:
                forecastDaysMax = 16
                forecastDayDefault = 7
                historyStartDate = Timestamp(1940, 1, 1)
                temporalResolutionDefault = .hourly
            case .airQuality:
                forecastDaysMax = 7
                forecastDayDefault = 5
                historyStartDate = Timestamp(2013, 1, 1)
                temporalResolutionDefault = .hourly
            case .climate:
                forecastDaysMax = 14
                forecastDayDefault = 7
                historyStartDate = Timestamp(1950, 1, 1)
                temporalResolutionDefault = .hourly
            case .flood:
                forecastDaysMax = 366
                forecastDayDefault = 92
                historyStartDate = Timestamp(1984, 1, 1)
                temporalResolutionDefault = .hourly
            }
            let run = params.run
            switch type {
            case .none, .seasonal, .ensemble:
                break
            case .singleRunsApi:
                guard run != nil else {
                    throw ForecastApiError.parameterIsRequired(name: "run")
                }
            case .forecast, .archive, .historicalForecast, .previousRuns, .satellite, .marine, .airQuality, .climate, .flood:
                guard run == nil else {
                    throw ForecastApiError.parameterMustNotBeSet(name: "run")
                }
            }
            let cellSelection = params.cell_selection ?? (type == .marine ? .sea : .land)
            let biasCorrection = !(params.disable_bias_correction ?? false)
            
            let pastDaysMax = (currentTimeHour0.timeIntervalSince1970 - historyStartDate.timeIntervalSince1970) / 86400
            let allowedRange = historyStartDate ..< (historyEndDate ?? currentTimeHour0.add(days: forecastDaysMax))

            let domainsParam = try MultiDomains.load(commaSeparatedOptional: params.models)?.map({ $0 == .best_match ? defaultModel : $0 }) ?? [defaultModel]
            if type == .ensemble, domainsParam.contains(.best_match) == true {
                throw ForecastApiError.generic(message: "Model 'best_match' is not supported by the Ensemble API. Please select a specific ensemble model.")
            }
            let domains: [MultiDomains]
            switch type {
            case .ensemble:
                // Translate domain names from Ensemble API for compatibility
                domains = domainsParam.map{$0.remappedToEnsembleApi}
            case .airQuality:
                // Air quality API used domains=auto, global or europe
                let camsDomains = try (params.domains.map({ [$0] }) ?? CamsApiDomain.load(commaSeparatedOptional: params.models) ?? [.auto])
                domains = camsDomains.map(\.multiDomain)
            default:
                domains = domainsParam
            }
            
            let paramsMinutely = has15minutely ? try ForecastVariable.load(commaSeparatedOptional: params.minutely_15) : nil
            let defaultCurrentWeather = [ForecastVariable.surface(.init(.temperature, 0)), .surface(.init(.windspeed, 0)), .surface(.init(.winddirection, 0)), .surface(.init(.is_day, 0)), .surface(.init(.weathercode, 0))]
            let paramsCurrent: [ForecastVariable]? = !hasCurrentWeather ? nil : params.current_weather == true ? defaultCurrentWeather : try ForecastVariable.load(commaSeparatedOptional: params.current)
            let paramsHourly = try ForecastVariable.load(commaSeparatedOptional: params.hourly)
            let paramsDaily = try ForecastVariableDaily.load(commaSeparatedOptional: params.daily)
            let paramsWeekly = try ForecastVariableWeekly.load(commaSeparatedOptional: params.weekly)
            let paramsMonthly = try ForecastVariableMonthly.load(commaSeparatedOptional: params.monthly)
            
            let nParamsHourly = paramsHourly?.count ?? 0
            let nParamsMinutely = paramsMinutely?.count ?? 0
            let nParamsCurrent = paramsCurrent?.count ?? 0
            let nParamsDaily = paramsDaily?.count ?? 0
            let nParamsWeekly = paramsWeekly?.count ?? 0
            let nParamsMonthly = paramsMonthly?.count ?? 0
            let nVariableNonEnsemble = (nParamsWeekly + nParamsMonthly) * domains.count
            let nVariables = (nParamsHourly + nParamsMinutely + nParamsCurrent + nParamsDaily) * domains.reduce(0, { $0 + $1.countEnsembleMember }) + nVariableNonEnsemble
            // Currently the old calculation basically blocks climate data access very early. Adjust weigthing a bit
            let nVariablesAdjusted = type == .seasonal ? nVariables / 24 / 5 : nVariables
            let options = try params.readerOptions(for: req, allowRemoteArchive: allowRemoteArchive)
            let temporalResolution = params.temporal_resolution ?? temporalResolutionDefault
            
            /// Only read 15 minutely data if actually necessary
            let include15Min = params.current?.isEmpty == false || params.minutely_15?.isEmpty == false || params.current_weather == true || (params.temporal_resolution?.dtSeconds ?? 3600) <= 30*60
            
            let prepared = try await params.prepareCoordinates(allowTimezones: true, logger: options.logger, httpClient: options.httpClient)

            let locations: [ForecastapiResult<MultiDomainsReader>.PerLocation]
            switch prepared {
            case .coordinates(let coordinates):
                if let numberOfLocationsMaximum = info.numberOfLocationsMaximum, coordinates.count > numberOfLocationsMaximum {
                    OmMetrics.requestsTooManyLocationsTotal.add(1, ordering: .relaxed)
                    throw ForecastApiError.generic(message: "Only up to \(numberOfLocationsMaximum) locations can be requested at once")
                }
                OmMetrics.recordModelRequest(models: domains, locationCount: coordinates.count)
                let isSingleLocation = coordinates.count == 1
                locations = try await coordinates.asyncMap { prepared in
                    let coordinates = prepared.coordinate
                    let timezone = prepared.timezone
                    if params.run != nil {
                        try params.validateSingleRunAggregationsAlignWithLocalPeriodStart(timezone: timezone)
                    }
                    let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                    let readers: [MultiDomainsReader] = try await domains.asyncCompactMap { domain in
                        let run = (domain.useLatestRun && run == nil) ? try await domain.getDomainAndVariable()?.singleDomain?.getLatestFullRun(client: options.httpClient, logger: options.logger)?.toIsoDateTime() : run
                        var options = options
                        options.run = run
                        guard let r = try await domain.getReaders(lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: cellSelection, options: options, biasCorrection: biasCorrection, include15Min: include15Min) else {
                            return nil
                        }
                        if isSingleLocation && domains.count == 1 && r.hourly == nil && r.daily == nil && r.weekly == nil && r.monthly == nil {
                            throw ForecastApiError.noDataAvailableForThisLocation
                        }
                        return MultiDomainsReader(domain: domain, readerHourly: r.hourly, readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
                    }
                    guard !readers.isEmpty else {
                        throw ForecastApiError.noDataAvailableForThisLocation
                    }
                    let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                    return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
                }
            case .boundingBox(let bbox, dates: let dates, timezone: let timezone):
                var countedModels = Set<MultiDomains>()
                locations = try await domains.asyncFlatMap({ domain in
                    let mapping = try await domain.getDomainAndVariable()
                    guard let grid = mapping?.gridForBoundingBoxRequests?.grid else {
                        throw ForecastApiError.generic(message: "Bounding box calls not supported for domain \(domain)")
                    }
                    guard let numberOfGridCells = grid.estimatedNumberOfGridCells(boundingBox: bbox) else {
                        throw ForecastApiError.generic(message: "Bounding box calls not supported for grid of domain \(domain)")
                    }
                    if let numberOfLocationsMaximum = info.numberOfLocationsMaximum, numberOfGridCells > numberOfLocationsMaximum {
                        OmMetrics.requestsTooManyLocationsTotal.add(1, ordering: .relaxed)
                        throw ForecastApiError.generic(message: "Only up to \(numberOfLocationsMaximum) locations can be requested at once")
                    }
                    guard let gridpoionts = grid.findBox(boundingBox: bbox) else {
                        throw ForecastApiError.generic(message: "Bounding box calls not supported for grid of domain \(domain)")
                    }
                    if countedModels.insert(domain).inserted {
                        let locationCount = gridpoionts.reduce(0) { count, _ in count + 1 } * max(dates.count, 1)
                        OmMetrics.recordModelRequest(models: [domain], locationCount: locationCount)
                    }
                    /// Some domains like `ecmwf_ifs_europe_ensemble` only write data to `data_run`. Resolve the latest run
                    let run = (domain.useLatestRun && run == nil) ? try await mapping?.singleDomain?.getLatestFullRun(client: options.httpClient, logger: options.logger)?.toIsoDateTime() : run
                    var options = options
                    options.run = run

                    if dates.count == 0 {
                        if params.run != nil {
                            try params.validateSingleRunAggregationsAlignWithLocalPeriodStart(timezone: timezone)
                        }
                        let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: nil, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                        let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                        var locationId = -1
                        return try await gridpoionts.asyncMap( { gridpoint in
                            locationId += 1
                            let r = try await domain.getReaders(gridpoint: gridpoint, mapping: mapping, options: options)
                            let readers = MultiDomainsReader(domain: domain, readerHourly: r.hourly, readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
                            return .init(timezone: timezone, time: timeLocal, locationId: locationId, results: [readers])
                        })
                    }
                    
                    return try await dates.asyncFlatMap({ date -> [ForecastapiResult<MultiDomainsReader>.PerLocation] in
                        if params.run != nil {
                            try params.validateSingleRunAggregationsAlignWithLocalPeriodStart(timezone: timezone)
                        }
                        let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: date, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                        let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                        var locationId = -1
                        return try await gridpoionts.asyncMap( { gridpoint in
                            locationId += 1
                            let r = try await domain.getReaders(gridpoint: gridpoint, mapping: mapping, options: options)
                            let readers = MultiDomainsReader(domain: domain, readerHourly: r.hourly, readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
                            return .init(timezone: timezone, time: timeLocal, locationId: locationId, results: [readers])
                        })
                    })
                })
            }
            
            return ForecastapiResult(timeformat: params.timeformatOrDefault, results: locations, currentVariables: paramsCurrent, minutely15Variables: paramsMinutely, hourlyVariables: paramsHourly, dailyVariables: paramsDaily, weeklyVariables: paramsWeekly, monthlyVariables: paramsMonthly, nVariablesTimesDomains: nVariablesAdjusted)
        }
    }
}

struct MultiDomainsReader: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastVariable
    
    typealias DailyVariable = ForecastVariableDaily
    
    typealias MonthlyVariable = ForecastVariableMonthly
    typealias WeeklyVariable = ForecastVariableWeekly
    
    var flatBufferModel: OpenMeteoSdk.openmeteo_sdk_Model {
        domain.flatBufferModel
    }
    
    var modelName: String {
        domain.rawValue
    }
    
    //let reader: GenericReaderMulti<ForecastVariable, MultiDomains>
    let domain: MultiDomains
    
    let readerHourly: (any GenericReaderOptionalProtocol<ForecastVariable>)?
    let readerDaily: (any GenericReaderOptionalProtocol<ForecastVariableDaily>)?
    let readerWeekly: (any GenericReaderOptionalProtocol<ForecastVariableWeekly>)?
    let readerMonthly: (any GenericReaderOptionalProtocol<ForecastVariableMonthly>)?
    
    var latitude: Float {
        readerHourly?.modelLat ?? readerDaily?.modelLat ?? .nan
    }
    
    var longitude: Float {
        readerHourly?.modelLon ?? readerDaily?.modelLon ?? .nan
    }
    
    var elevation: Float? {
        readerHourly?.targetElevation ?? readerDaily?.targetElevation
    }
    
    let params: ApiQueryParameter
    
    let has15minutely: Bool
    let time: ForecastApiTimeRange
    let timezone: TimezoneWithOffset
    let currentTime: Timestamp
    let temporalResolution: ApiTemporalResolution
    
    func prefetch(currentVariables: [HourlyVariable]?, minutely15Variables: [HourlyVariable]?, hourlyVariables: [HourlyVariable]?, dailyVariables: [DailyVariable]?, weeklyVariables: [WeeklyVariable]?, monthlyVariables: [MonthlyVariable]?) async throws {
        if let currentVariables, let readerHourly {
            let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: has15minutely ? 900 : 3600), nTime: 1, dtSeconds: has15minutely ? 900 : 3600)
            for variable in currentVariables {
                let (v, previousDay) = variable.variableAndPreviousDay
                let _ = try await readerHourly.prefetchData(variable: v, time: currentTimeRange.toSettings(previousDay: previousDay))
            }
        }
        if let minutely15Variables, let readerHourly {
            for variable in minutely15Variables {
                let members = variable.onlySingleMember ? 0..<1 : 0..<domain.countEnsembleMember
                let (v, previousDay) = variable.variableAndPreviousDay
                for member in members {
                    let _ = try await readerHourly.prefetchData(variable: v, time: time.minutely15.toSettings(previousDay: previousDay, ensembleMemberLevel: member))
                }
            }
        }
        if let hourlyVariables, let readerHourly {
            let hourlyDt = (params.temporal_resolution ?? temporalResolution).dtSeconds ?? readerHourly.modelDtSeconds
            let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
            for variable in hourlyVariables {
                let members = variable.onlySingleMember ? 0..<1 : 0..<domain.countEnsembleMember
                let (v, previousDay) = variable.variableAndPreviousDay
                for member in members {
                    let _ = try await readerHourly.prefetchData(variable: v, time: timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member))
                }
            }
        }
        if let dailyVariables, let readerDaily {
            for variable in dailyVariables {
                /// Flood API uses a boolean flag to enable ensemble members for river_discharge
                /// Also, flood API uses `ensembleMember` instead of `ensembleMemberLevel`, because members are stored in different files
                let allMembersForRiverDischarge = variable == .river_discharge && params.ensemble
                let members = allMembersForRiverDischarge ? 0..<51 : 0..<domain.countEnsembleMember
                for member in members {
                    let _ = try await readerDaily.prefetchData(variable: variable, time: time.dailyRead.toSettings(
                        ensembleMember: allMembersForRiverDischarge ? member : nil,
                        ensembleMemberLevel: allMembersForRiverDischarge ? nil : member))
                }
            }
        }
        if let weeklyVariables, let readerWeekly {
            let timeWeekly = TimerangeDt(
                start: time.dailyRead.range.lowerBound.add(-4*24*3600).floor(toNearest: 7*24*3600).add(4*24*3600),
                to: time.dailyRead.range.upperBound.add(-4*24*3600).ceil(toNearest: 7*24*3600).add(4*24*3600),
                dtSeconds: 7*24*3600
            )
            for variable in weeklyVariables {
                let _ = try await readerWeekly.prefetchData(variable: variable, time: timeWeekly.toSettings())
            }
        }
        if let monthlyVariables, let readerMonthly {
            let yearMonths = time.dailyRead.toYearMonth()
            let timeMonthlyDisplay = TimerangeDt(start: yearMonths.lowerBound.timestamp, to: yearMonths.upperBound.timestamp, dtSeconds: .dtSecondsMonthly)
            let timeMonthlyRead = timeMonthlyDisplay
            for variable in monthlyVariables {
                let _ = try await readerMonthly.prefetchData(variable: variable, time: timeMonthlyRead.toSettings())
            }
        }
    }

    func current(variables: [HourlyVariable]?) async throws -> ApiSectionSingle<HourlyVariable>? {
        guard let variables, let readerHourly else {
            return nil
        }
        let currentTimeRange = TimerangeDt(start: currentTime.floor(toNearest: has15minutely ? 900 : 3600), nTime: 1, dtSeconds: has15minutely ? 900 : 3600)
        return .init(name: params.current_weather == true ? "current_weather" : "current", time: currentTimeRange.range.lowerBound, dtSeconds: currentTimeRange.dtSeconds, columns: try await variables.asyncMap { variable in
            let (v, previousDay) = variable.variableAndPreviousDay
            let timeRead = currentTimeRange.toSettings(previousDay: previousDay)
            
            if case .surface(let v) = v {
                switch v.variable {
                case .is_day:
                    let isDay = Zensun.calculateIsDay(timeRange: currentTimeRange, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionlessInteger, value: isDay.first ?? .nan)
                case .terrestrial_radiation:
                    let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: currentTimeRange)
                    return .init(variable: variable, unit: .wattPerSquareMetre, value: solar.first ?? .nan)
                case .terrestrial_radiation_instant:
                    let solar = Zensun.extraTerrestrialRadiationInstant(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: currentTimeRange)
                    return .init(variable: variable, unit: .wattPerSquareMetre, value: solar.first ?? .nan)
                default:
                    break
                }
            }
            
            guard let d = try await readerHourly.get(variable: v, time: timeRead)?.convertAndRound(params: params) else {
                return .init(variable: variable, unit: .undefined, value: .nan)
            }
            return .init(variable: variable, unit: d.unit, value: d.data.first ?? .nan)
        })
    }
    
    func hourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        guard let variables, let readerHourly else {
            return nil
        }
        let hourlyDt = (params.temporal_resolution ?? temporalResolution).dtSeconds ?? readerHourly.modelDtSeconds
        let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
        let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
        return .init(name: "hourly", time: timeHourlyDisplay, columns: try await variables.asyncMap { variable in
            let (v, previousDay) = variable.variableAndPreviousDay
            let members = variable.onlySingleMember ? 0..<1 : 0..<domain.countEnsembleMember
            
            if case .surface(let v) = v {
                switch v.variable {
                case .is_day:
                    let isDay = Zensun.calculateIsDay(timeRange: timeHourlyRead, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionlessInteger, variables: [ApiArray.float(isDay)])
                case .terrestrial_radiation:
                    let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: timeHourlyRead)
                    return .init(variable: variable, unit: .wattPerSquareMetre, variables: [ApiArray.float(solar)])
                case .terrestrial_radiation_instant:
                    let solar = Zensun.extraTerrestrialRadiationInstant(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: timeHourlyRead)
                    return .init(variable: variable, unit: .wattPerSquareMetre, variables: [ApiArray.float(solar)])
                default:
                    break
                }
            }
            
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member)
                guard let d = try await readerHourly.get(variable: v, time: timeRead)?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(timeHourlyRead.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: timeHourlyRead.count)), count: domain.countEnsembleMember))
            }
            return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func daily(variables: [DailyVariable]?) async throws -> ApiSection<DailyVariable>? {
        guard let variables, let readerDaily else {
            return nil
        }
        let members = 0..<domain.countEnsembleMember
        
        var riseSet: (rise: [Timestamp], set: [Timestamp])?
        var moonRiseSet: (rise: [Timestamp], set: [Timestamp])?
        return ApiSection(name: "daily", time: time.dailyDisplay, columns: try await variables.asyncMap { variable -> ApiColumn<ForecastVariableDaily> in
            /// Flood API uses a boolean flag to enable ensemble members for river_discharge
            /// /// Also, flood API uses `ensembleMember` instead of `ensembleMemberLevel`, because members are stored in different files
            let allMembersForRiverDischarge = variable == .river_discharge && params.ensemble
            let members = allMembersForRiverDischarge ? 0..<51 : members
            if variable == .sunrise || variable == .sunset {
                // only calculate sunrise/set once. Need to use `dailyDisplay` to make sure half-hour time zone offsets are applied correctly
                let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.dailyDisplay.range, lat: readerDaily.modelLat, lon: readerDaily.modelLon, utcOffsetSeconds: timezone.utcOffsetSeconds)
                riseSet = times
                if variable == .sunset {
                    return ApiColumn(variable: .sunset, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.set)])
                } else {
                    return ApiColumn(variable: .sunrise, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.rise)])
                }
            }
            if variable == .moonrise || variable == .moonset {
                // only calculate moonrise/set once. Uses `dailyDisplay` (local midnight in UTC) like sunrise/set
                let times = moonRiseSet ?? Moon.calculateMoonRiseSet(timeRange: time.dailyDisplay.range, lat: readerDaily.modelLat, lon: readerDaily.modelLon)
                moonRiseSet = times
                if variable == .moonset {
                    return ApiColumn(variable: .moonset, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.set)])
                } else {
                    return ApiColumn(variable: .moonrise, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.rise)])
                }
            }
            if variable == .moon_phase {
                let phase = Moon.calculateMoonPhase(timeRange: time.dailyDisplay.range)
                return ApiColumn(variable: .moon_phase, unit: .fraction, variables: [.float(phase)])
            }
            if variable == .daylight_duration {
                let duration = Zensun.calculateDaylightDuration(localMidnight: time.dailyDisplay.range, lat: readerDaily.modelLat)
                return ApiColumn(variable: .daylight_duration, unit: .seconds, variables: [.float(duration)])
            }
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = time.dailyRead.toSettings(
                    ensembleMember: allMembersForRiverDischarge ? member : nil,
                    ensembleMemberLevel: allMembersForRiverDischarge ? nil : member
                )
                guard let d = try await readerDaily.get(variable: variable, time: timeRead)?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(time.dailyRead.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.dailyRead.count)), count: domain.countEnsembleMember))
            }
            return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func minutely15(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        guard let variables, let readerHourly else {
            return nil
        }
        
        return .init(name: "minutely_15", time: time.minutely15, columns: try await variables.asyncMap { variable in
            let (v, previousDay) = variable.variableAndPreviousDay
            let members = variable.onlySingleMember ? 0..<1 : 0..<domain.countEnsembleMember
            
            if case .surface(let v) = v {
                switch v.variable {
                case .is_day:
                    let isDay = Zensun.calculateIsDay(timeRange: time.minutely15, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionlessInteger, variables: [ApiArray.float(isDay)])
                case .terrestrial_radiation:
                    let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: time.minutely15)
                    return .init(variable: variable, unit: .wattPerSquareMetre, variables: [ApiArray.float(solar)])
                case .terrestrial_radiation_instant:
                    let solar = Zensun.extraTerrestrialRadiationInstant(latitude: readerHourly.modelLat, longitude: readerHourly.modelLon, timerange: time.minutely15)
                    return .init(variable: variable, unit: .wattPerSquareMetre, variables: [ApiArray.float(solar)])
                default:
                    break
                }
            }
            
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = time.minutely15.toSettings(previousDay: previousDay, ensembleMemberLevel: member)
                guard let d = try await readerHourly.get(variable: v, time: timeRead)?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(time.minutely15.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.minutely15.count)), count: domain.countEnsembleMember))
            }
            return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func weekly(variables: [WeeklyVariable]?) async throws -> ApiSection<WeeklyVariable>? {
        guard let variables, let readerWeekly else {
            return nil
        }
        // Align data start to Monday of each week
        let timeWeekly = TimerangeDt(
            start: time.dailyRead.range.lowerBound.add(-4*24*3600).floor(toNearest: 7*24*3600).add(4*24*3600),
            to: time.dailyRead.range.upperBound.add(-4*24*3600).ceil(toNearest: 7*24*3600).add(4*24*3600),
            dtSeconds: 7*24*3600
        )
        return ApiSection<WeeklyVariable>(name: "weekly", time: timeWeekly, columns: try await variables.asyncCompactMap { variable in
            guard let d = try await readerWeekly.get(variable: variable, time: timeWeekly.toSettings())?.convertAndRound(params: params) else {
                return nil
            }
            assert(timeWeekly.count == d.data.count)
            return ApiColumn<WeeklyVariable>(variable: variable, unit: d.unit, variables: [ApiArray.float(d.data)])
        })
    }
    
    func monthly(variables: [MonthlyVariable]?) async throws -> ApiSection<MonthlyVariable>? {
        guard let variables, let readerMonthly else {
            return nil
        }
        let yearMonths = time.dailyRead.toYearMonth()
        let timeMonthlyDisplay = TimerangeDt(start: yearMonths.lowerBound.timestamp, to: yearMonths.upperBound.timestamp, dtSeconds: .dtSecondsMonthly)
        let timeMonthlyRead = timeMonthlyDisplay
        return ApiSection<MonthlyVariable>(name: "monthly", time: timeMonthlyDisplay, columns: try await variables.asyncCompactMap { variable in
            guard let d = try await readerMonthly.get(variable: variable, time: timeMonthlyRead.toSettings())?.convertAndRound(params: params) else {
                return nil
            }
            assert(timeMonthlyDisplay.count == d.data.count)
            return ApiColumn<MonthlyVariable>(variable: variable, unit: d.unit, variables: [ApiArray.float(d.data)])
        })
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
enum MultiDomains: String, RawRepresentableString, CaseIterable, Sendable {
    case best_match

    case gfs_seamless
    case gfs_mix
    case gfs_global
    case gfs05
    case gfs025
    case gfs013
    case gfs_hrrr
    case gfs_graphcast025
    
    case ncep_seamless
    case ncep_gfs_seamless
    case ncep_rrfs_seamless
    case ncep_rrfs_conus
    case ncep_rrfs_north_america
    case ncep_rrfs_conus_15min
    case ncep_rrfs_conus_ensemble
    case ncep_gfs_global
    case ncep_nbm_conus
    case ncep_gfs025
    case ncep_gfs013
    case ncep_hrrr_conus
    case ncep_hrrr_conus_15min
    case ncep_gfs_graphcast025
    case ncep_nam_conus
    case ncep_aigfs025
    case ncep_aigefs025
    case ncep_hgefs025_ensemble_mean
    case ncep_aigefs025_ensemble_mean
    
    case meteofrance_seamless
    case meteofrance_mix
    case meteofrance_arpege_seamless
    case meteofrance_arpege_world
    case meteofrance_arpege_europe
    case meteofrance_arome_seamless
    case meteofrance_arome_france
    case meteofrance_arome_france0025
    case meteofrance_arpege_world025
    case meteofrance_arome_france_hd
    case meteofrance_arome_france_hd_15min
    case meteofrance_arome_france_15min
    case arpege_seamless
    case arpege_world
    case arpege_europe
    case arome_seamless
    case arome_france
    case arome_france_hd

    case jma_seamless
    case jma_mix
    case jma_msm
    case jma_msm_upper_level
    case jms_gsm
    case jma_gsm

    case gem_seamless
    case gem_global
    case gem_regional
    case gem_hrdps_continental
    case gem_hrdps_west
    case cmc_gem_seamless
    case cmc_gem_gdps
    case cmc_gem_hrdps
    case cmc_gem_hrdps_west
    case cmc_gem_rdps

    case icon_seamless
    case icon_mix
    case icon_global
    case icon_eu
    case icon_d2
    case dwd_icon_seamless
    case dwd_icon_global
    case dwd_icon
    case dwd_icon_eu
    case dwd_icon_d2
    case dwd_icon_d2_15min
    case dwd_aicon_global_native
    case dwd_icon_global_native
    case dwd_icon_global_native_model_level
    case dwd_icon_eu_native
    case dwd_icon_eu_native_model_level
    case dwd_icon_d2_ruc_native
    case dwd_icon_d2_ruc_native_15min
    case dwd_icon_d2_ruc_native_model_level
    case dwd_icon_d2_native
    case dwd_icon_d2_native_model_level
    case dwd_icon_d2_native_15min
    case dwd_icon_global_eps_native
    case dwd_icon_eu_eps_native
    case dwd_icon_d2_eps_native
    case dwd_sis_europe_africa_v4

    case ecmwf_ifs04
    case ecmwf_ifs01
    case ecmwf_ifs01_ensemble
    case ecmwf_ifs01_ensemble_mean
    case ecmwf_ifs025
    case ecmwf_aifs025
    case ecmwf_aifs025_single
    case ecmwf_ifs_europe_ensemble
    case ecmwf_ifs_europe_ensemble_mean
    case ecmwf_aifs_europe_ensemble
    case ecmwf_aifs_europe_ensemble_mean
    
    case ecmwf_seasonal_seamless
    case ecmwf_seas5
    case ecmwf_ec46
    
    case ecmwf_seasonal_ensemble_mean_seamless
    case ecmwf_seas5_ensemble_mean
    case ecmwf_ec46_ensemble_mean

    case metno_nordic

    case geosphere_arome_austria
    case geosphere_seamless

    case chmi_aladin_cz_1km
    case chmi_aladin_central_europe_2km
    case chmi_aladin_seamless

    case cma_grapes_global

    case bom_access_global

    case archive_best_match
    case marine_best_match
    case era5_seamless
    case era5
    case cerra
    case era5_land
    case era5_ensemble
    case copernicus_era5_seamless
    case copernicus_era5
    case copernicus_cerra
    case copernicus_era5_land
    case copernicus_era5_ensemble
    case ecmwf_wam
    case ecmwf_ifs
    case ecmwf_ifs_analysis
    case ecmwf_ifs_analysis_long_window
    case ecmwf_ifs_long_window

    case arpae_cosmo_seamless
    case arpae_cosmo_2i
    case arpae_cosmo_2i_ruc
    case arpae_cosmo_5m

    case knmi_harmonie_arome_europe
    case knmi_harmonie_arome_netherlands
    case dmi_harmonie_arome_europe
    case knmi_seamless
    case dmi_seamless
    case metno_seamless

    case ukmo_seamless
    case ukmo_global_deterministic_10km
    case ukmo_uk_deterministic_2km

    case satellite_radiation_seamless
    case eumetsat_sarah3
    case eumetsat_lsa_saf_msg
    case eumetsat_lsa_saf_iodc
    case jma_jaxa_himawari
    case jma_jaxa_mtg_fci

    case kma_seamless
    case kma_gdps
    case kma_ldps

    case italia_meteo_arpae_icon_2i

    case meteoswiss_icon_ch1
    case meteoswiss_icon_ch2
    case meteoswiss_icon_seamless
    
    case icon_seamless_eps
    case icon_global_eps
    case icon_eu_eps
    case icon_d2_eps
    case dwd_icon_seamless_eps
    case dwd_icon_global_eps
    case dwd_icon_eu_eps
    case dwd_icon_d2_eps

    case ecmwf_ifs025_ensemble
    case ecmwf_aifs025_ensemble

    case gem_global_ensemble
    case cmc_gem_geps

    case bom_access_global_ensemble
    case google_weathernext2_ensemble

    case ncep_gefs_seamless
    case ncep_gefs025
    case ncep_gefs05

    case ukmo_global_ensemble_20km
    case ukmo_uk_ensemble_2km
    
    case meteoswiss_icon_ch1_ensemble
    case meteoswiss_icon_ch2_ensemble
    
    case ewam
    case gwam
    case dwd_ewam
    case dwd_gwam
    case era5_ocean
    case ecmwf_wam025
    case ecmwf_wam025_ensemble
    case ncep_gfswave025
    case ncep_gfswave016
    case ncep_gefswave025
    case meteofrance_wave
    case meteofrance_currents
    
    case air_quality_best_match
    case cams_global
    case cams_europe
    
    case CMCC_CM2_VHR4
    case FGOALS_f3_H
    case HiRAM_SIT_HR
    case MRI_AGCM3_2_S
    case EC_Earth3P_HR
    case MPI_ESM1_2_XR
    case NICAM16_8S
    
    // GloFas domains should be prefixed with glofas in the future
    case flood_best_match
    case seamless_v3
    case forecast_v3
    case consolidated_v3
    case seamless_v4
    case forecast_v4
    case consolidated_v4
    
    case dwd_icon_eps_ensemble_mean_seamless
    case dwd_icon_eps_ensemble_mean
    case dwd_icon_eu_eps_ensemble_mean
    case dwd_icon_d2_eps_ensemble_mean
    case ecmwf_ifs025_ensemble_mean
    case ecmwf_aifs025_ensemble_mean
    case ncep_gefs025_ensemble_mean
    case ncep_gefs05_ensemble_mean
    case ncep_gefs_ensemble_mean_seamless
    case cmc_gem_geps_ensemble_mean
    case bom_access_global_ensemble_mean
    case google_weathernext2_ensemble_mean
    case ukmo_global_ensemble_mean_20km
    case ukmo_uk_ensemble_mean_2km
    case meteoswiss_icon_ch1_ensemble_mean
    case meteoswiss_icon_ch2_ensemble_mean
    case ecmwf_wam025_ensemble_mean
    case ncep_gefswave025_ensemble_mean

    typealias ForecastReaderResult = (
        hourly: (any GenericReaderOptionalProtocol<ForecastVariable>)?,
        daily: (any GenericReaderOptionalProtocol<ForecastVariableDaily>)?,
        weekly: (any GenericReaderOptionalProtocol<ForecastVariableWeekly>)?,
        monthly: (any GenericReaderOptionalProtocol<ForecastVariableMonthly>)?
    )

    struct RawReaderDerivationGroup {
        typealias ReaderResult = (reader: any GenericReaderOptionalProtocol<ForecastVariable>, elevation: Float)

        private let makeReaderClosure: (Float, Float, Float, GridSelectionMode, GenericReaderOptions) async throws -> ReaderResult?

        init<Domain, Variable>(
            domains: [Domain],
            variableType: Variable.Type,
            derivationDomain: Domain
        ) where
            Domain: GenericDomain,
            Variable: GenericVariable & Hashable
        {
            self.makeReaderClosure = { lat, lon, elevation, mode, options in
                var resolvedElevation = elevation
                var unavailableRun: ForecastApiError?
                var derivationDomainInitialized = false
                var hasAvailableRun = false
                let initialized: [GenericReaderCached<Domain, Variable>] = try await domains.reversed().asyncCompactMap { domain in
                    do {
                        let rawReader = try await GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: resolvedElevation, mode: mode, options: options)
                        hasAvailableRun = true
                        guard let rawReader else { return nil }
                        let reader = GenericReaderCached(reader: rawReader)
                        if resolvedElevation.isNaN {
                            resolvedElevation = reader.resolvedTargetElevation
                        }
                        if domain.domainRegistry == derivationDomain.domainRegistry {
                            derivationDomainInitialized = true
                        }
                        return reader
                    } catch let error as ForecastApiError {
                        guard case .modelRunUnavailable = error else { throw error }
                        unavailableRun = unavailableRun ?? error
                        return nil
                    }
                }.reversed()
                guard !initialized.isEmpty else {
                    if !hasAvailableRun, let error = unavailableRun { throw error }
                    return nil
                }
                // Preserve ordinary spatial coverage; an explicit run may use another generation.
                guard derivationDomainInitialized || options.run != nil else { return nil }
                let mixer = GenericReaderMixerSameVariableType(reader: initialized)
                let reader = VariableHourlyDeriver(
                    reader: mixer,
                    options: options,
                    domainRegistry: derivationDomain.domainRegistry
                )
                return (reader, resolvedElevation)
            }
        }

        init<PrimaryDomain, PrimaryVariable, SupplementalDomain, SupplementalVariable>(
            primary: (PrimaryDomain, PrimaryVariable.Type),
            supplemental: (SupplementalDomain, SupplementalVariable.Type)
        ) where
            PrimaryDomain: GenericDomain,
            PrimaryVariable: GenericVariable,
            SupplementalDomain: GenericDomain,
            SupplementalVariable: GenericVariable
        {
            self.makeReaderClosure = { lat, lon, elevation, mode, options in
                guard let primaryRawReader = try await GenericReader<PrimaryDomain, PrimaryVariable>(
                    domain: primary.0,
                    lat: lat,
                    lon: lon,
                    elevation: elevation,
                    mode: mode,
                    options: options
                ) else {
                    return nil
                }
                let primaryReader = GenericReaderCached(reader: primaryRawReader)
                let resolvedElevation = elevation.isFinite ? elevation : primaryReader.resolvedTargetElevation
                let supplementalReader: GenericReaderCached<SupplementalDomain, SupplementalVariable>?
                do {
                    supplementalReader = try await GenericReader<SupplementalDomain, SupplementalVariable>(
                        domain: supplemental.0, lat: lat, lon: lon, elevation: resolvedElevation, mode: mode, options: options
                    ).map { GenericReaderCached(reader: $0) }
                } catch ForecastApiError.modelRunUnavailable {
                    supplementalReader = nil
                }
                let rawReaders: [any GenericReaderProtocol] = [supplementalReader].compactMap { $0 } + [primaryReader]
                let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<PrimaryVariable, SupplementalVariable>>(
                    reader: rawReaders
                )
                let reader = VariableHourlyDeriver(
                    reader: mixer,
                    options: options,
                    domainRegistry: primary.0.domainRegistry
                )
                return (reader, resolvedElevation)
            }
        }

        func makeReader(
            lat: Float,
            lon: Float,
            elevation: Float,
            mode: GridSelectionMode,
            options: GenericReaderOptions
        ) async throws -> ReaderResult? {
            try await makeReaderClosure(lat, lon, elevation, mode, options)
        }
    }

    /// Each source derives its variables independently (optionally mixing raw inputs first),
    /// then the resulting readers are combined by priority.
    /// Missing runs are skipped during construction; if every primary run is missing,
    /// throw `modelRunUnavailable`. Other construction errors propagate.
    struct DomainReaderMapping {
        enum Source {
            /// Derive variables from one domain before mixing with other sources.
            case domain(any GenericDomain, any GenericVariable.Type)
            /// Mix raw variables within the group before deriving forecast variables.
            case mixedBeforeDerivation(RawReaderDerivationGroup)

            func makeReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> RawReaderDerivationGroup.ReaderResult? {
                switch self {
                case .domain(let domain, let variable):
                    guard let reader = try await domain.makeDerivedHourly(variableType: variable, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else { return nil }
                    return (reader, reader.resolvedTargetElevation)
                case .mixedBeforeDerivation(let group):
                    return try await group.makeReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                }
            }
        }

        /// Forecast sources, ordered from lowest to highest priority. At least one
        /// must have the requested run, independently of whether it covers the location.
        let primary: [Source]
        /// Optional providers (e.g. precipitation probability), ordered from lowest to
        /// highest priority, below all primary sources. They cannot satisfy run availability
        /// or required primary coverage, and are omitted from bounding-box requests.
        let secondary: [Source]
        /// Defines the output grid for bounding-box requests; nil disables these requests.
        /// All primary sources are remapped onto this grid. The domain also supplies
        /// metadata for automatic latest-run selection where enabled.
        let gridForBoundingBoxRequests: (any GenericDomain)?
        /// Prefetch every reader; otherwise stop at the first reader accepting the variable.
        let prefetchAllReaders: Bool
        /// Smooth transitions when combining model data. False only fills missing values
        /// from lower-priority readers, preserving existing higher-priority values.
        let smoothTransitions: Bool
        /// At least one coordinate must be covered by a primary domain
        let requirePrimaryCoverage: Bool

        init(
            primary: [Source],
            secondary: [Source] = [],
            gridForBoundingBoxRequests: (any GenericDomain)? = nil,
            prefetchAllReaders: Bool = false,
            smoothTransitions: Bool = true,
            requirePrimaryCoverage: Bool = false
        ) {
            self.primary = primary
            self.secondary = secondary
            self.gridForBoundingBoxRequests = gridForBoundingBoxRequests
            self.prefetchAllReaders = prefetchAllReaders
            self.smoothTransitions = smoothTransitions
            self.requirePrimaryCoverage = requirePrimaryCoverage
        }

        static func single(_ domain: any GenericDomain, _ variable: any GenericVariable.Type) -> Self {
            .init(primary: [.domain(domain, variable)], gridForBoundingBoxRequests: domain)
        }

        static func multiple(_ primary: [Source], secondary: [Source] = []) -> Self {
            .init(primary: primary, secondary: secondary)
        }

        static func singleWithPrecipitationProbability(_ domain: any GenericDomain, _ variable: any GenericVariable.Type, precipitationProb: any GenericDomain) -> Self {
            .init(primary: [.domain(domain, variable)], secondary: [.domain(precipitationProb, ProbabilityVariable.self)], gridForBoundingBoxRequests: domain, requirePrimaryCoverage: true)
        }

        static func multipleWithPrecipitationProbability(_ primary: [Source], precipitationProb: any GenericDomain) -> Self {
            .init(primary: primary, secondary: [.domain(precipitationProb, ProbabilityVariable.self)])
        }

        static func makeDomainReaders(
            sources: [Source], lat: Float, lon: Float, elevation: Float,
            mode: GridSelectionMode, options: GenericReaderOptions
        ) async throws -> (readers: [any GenericReaderOptionalProtocol<ForecastVariable>], elevation: Float, unavailableRun: ForecastApiError?, hasAvailableRun: Bool) {
            var elevation = elevation
            var unavailableRun: ForecastApiError?
            var hasAvailableRun = false
            let readers: [any GenericReaderOptionalProtocol<ForecastVariable>] = try await sources.reversed().asyncCompactMap { source in
                do {
                    let result = try await source.makeReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                    // Successful construction can return nil outside the grid, but the run exists.
                    hasAvailableRun = true
                    guard let result else { return nil }
                    if elevation.isNaN {
                        elevation = result.elevation
                    }
                    return result.reader
                } catch let error as ForecastApiError {
                    guard case .modelRunUnavailable = error else { throw error }
                    unavailableRun = unavailableRun ?? error
                    return nil
                }
            }.reversed()
            return (readers, elevation, unavailableRun, hasAvailableRun)
        }

        var singleDomain: (any GenericDomain)? {
            gridForBoundingBoxRequests
        }

        func getReaders(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> ForecastReaderResult? {
            let forecast = try await Self.makeDomainReaders(sources: primary, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            if !forecast.hasAvailableRun, let error = forecast.unavailableRun { throw error }
            if requirePrimaryCoverage && forecast.readers.isEmpty { return nil }
            let supplemental = try await Self.makeDomainReaders(sources: secondary, lat: lat, lon: lon, elevation: forecast.elevation, mode: mode, options: options)
            return MultiDomains.hourlyToMultiSameType(supplemental.readers + forecast.readers, prefetchAllReaders: prefetchAllReaders, smoothTransitions: smoothTransitions)
        }
    }

    /// If true, use domain from `getDomainAndVariable().singleDomain` to resolve the latest run.
    /// This only works with one domain. Needs larger rewrite if this should work with seamless domains like ec46+seas5.
    var useLatestRun: Bool {
        switch self {
        case .ecmwf_ifs_europe_ensemble, .ecmwf_aifs_europe_ensemble:
            return true
        default:
            return false
        }
    }

    private static var gfsGlobalDerivationGroup: RawReaderDerivationGroup {
        RawReaderDerivationGroup(
            primary: (GfsDomain.gfs013, Gfs013Variable.self),
            supplemental: (GfsDomain.gfs025, Gfs025Variable.self)
        )
    }

    private static func hrrrDerivationGroup(include15Min: Bool) -> RawReaderDerivationGroup {
        RawReaderDerivationGroup(
            domains: include15Min ? [GfsDomain.hrrr_conus, .hrrr_conus_15min] : [.hrrr_conus],
            variableType: HrrrVariable.self,
            derivationDomain: .hrrr_conus
        )
    }

    /// Generic domains with hourly data that can use the generic deriver controller.
    /// IFS daily temperature extrema use hourly temperatures: stored interval extrema can cross local midnight.
    func getDomainAndVariable(include15Min: Bool = false) async throws -> DomainReaderMapping? {
        switch self {
        case .ncep_rrfs_north_america:
            return .single(NcepRrfsDomain.ncep_rrfs_north_america, NcepRrfsVariable.self)
        case .ncep_rrfs_conus:
            return .singleWithPrecipitationProbability(NcepRrfsDomain.ncep_rrfs_conus, NcepRrfsVariable.self, precipitationProb: NcepRrfsDomain.ncep_rrfs_conus_ensemble)
        case .ncep_rrfs_conus_15min:
            return .singleWithPrecipitationProbability(NcepRrfsDomain.ncep_rrfs_conus_15min, NcepRrfs15MinVariable.self, precipitationProb: NcepRrfsDomain.ncep_rrfs_conus_ensemble)
        case .ncep_rrfs_conus_ensemble:
            return .singleWithPrecipitationProbability(NcepRrfsDomain.ncep_rrfs_conus_ensemble, NcepRrfsEnsembleVariable.self, precipitationProb: NcepRrfsDomain.ncep_rrfs_conus_ensemble)
        case .ncep_rrfs_seamless:
            // Readers are ordered from lowest to highest priority.
            // 15 minutely data is always added because it has 1-hourly update intervals
            let domains: [DomainReaderMapping.Source] = [
                .domain(GfsDomain.gfs05_ens, Gefs05Variable.self),
                .domain(GfsDomain.gfs025, Gfs025Variable.self),
                .domain(NcepRrfsDomain.ncep_rrfs_conus, NcepRrfsVariable.self),
                .domain(NcepRrfsDomain.ncep_rrfs_conus_15min, NcepRrfs15MinVariable.self)
            ]
            return .multipleWithPrecipitationProbability(domains, precipitationProb: NcepRrfsDomain.ncep_rrfs_conus_ensemble)
        case .ecmwf_ifs04:
            return .single(EcmwfDomain.ifs04, EcmwfVariable.self)
        case .ecmwf_ifs01:
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    primary: (EcmwfDomain.ifs01, EcmwfIfsVariable.self),
                    supplemental: (EcmwfDomain.ifs01_pressure_levels, EcmwfIfsVariable.self)
                ))],
                secondary: [.domain(EcmwfDomain.ifs01_ensemble, ProbabilityVariable.self)],
                gridForBoundingBoxRequests: EcmwfDomain.ifs01,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .ecmwf_ifs01_ensemble:
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    primary: (EcmwfDomain.ifs01_ensemble, EcmwfIfsVariable.self),
                    supplemental: (EcmwfDomain.ifs01_ensemble_pressure_levels, EcmwfIfsVariable.self)
                ))],
                gridForBoundingBoxRequests: EcmwfDomain.ifs01_ensemble,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .ecmwf_ifs01_ensemble_mean:
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    primary: (EcmwfDomain.ifs01_ensemble_mean, VariableOrSpread<EcmwfIfsVariable>.self),
                    supplemental: (EcmwfDomain.ifs01_ensemble_pressure_levels_mean, VariableOrSpread<EcmwfIfsVariable>.self)
                ))],
                gridForBoundingBoxRequests: EcmwfDomain.ifs01_ensemble_mean,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .ecmwf_ifs025:
            return .singleWithPrecipitationProbability(EcmwfDomain.ifs025, EcmwfIfsVariable.self, precipitationProb: EcmwfDomain.ifs025_ensemble)
        case .ecmwf_aifs025:
            return .single(EcmwfDomain.aifs025, EcmwfVariable.self)
        case .ecmwf_aifs025_single:
            return .single(EcmwfDomain.aifs025_single, EcmwfAifsVariable.self)
        case .ecmwf_ifs025_ensemble:
            return .single(EcmwfDomain.ifs025_ensemble, EcmwfIfsVariable.self)
        case .ecmwf_aifs025_ensemble:
            return .single(EcmwfDomain.aifs025_ensemble, EcmwfAifsVariable.self)
        case .ecmwf_ifs:
            return .singleWithPrecipitationProbability(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self, precipitationProb: EcmwfDomain.ifs025_ensemble)
        case .era5, .copernicus_era5:
            // Mix deterministic components with ensemble uncertainties before deriving wind spreads.
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    domains: [CdsDomain.era5_ensemble, .era5], variableType: Era5Variable.self,
                    derivationDomain: .era5
                ))],
                gridForBoundingBoxRequests: CdsDomain.era5,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .era5_seamless, .copernicus_era5_seamless:
            // ET0 uses ERA5-Land temperature with ERA5 radiation, including on the land grid.
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    domains: [CdsDomain.era5, .era5_land], variableType: Era5Variable.self,
                    derivationDomain: .era5_land
                ))],
                gridForBoundingBoxRequests: CdsDomain.era5_land,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .archive_best_match:
            // This is the CDS IFS archive, not the ECPDS domain used by the forecast model.
            return .init(
                primary: [.mixedBeforeDerivation(.init(
                    domains: [CdsDomain.era5, .era5_land, .ecmwf_ifs], variableType: Era5Variable.self,
                    derivationDomain: .ecmwf_ifs
                ))],
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .era5_land, .copernicus_era5_land:
            return .single(CdsDomain.era5_land, Era5Variable.self)
        case .era5_ensemble, .copernicus_era5_ensemble:
            return .single(CdsDomain.era5_ensemble, Era5Variable.self)
        case .cerra, .copernicus_cerra:
            return .single(CdsDomain.cerra, CerraVariable.self)
        case .ecmwf_ifs_analysis:
            return .single(CdsDomain.ecmwf_ifs_analysis, Era5Variable.self)
        case .ecmwf_ifs_analysis_long_window:
            return .single(CdsDomain.ecmwf_ifs_analysis_long_window, Era5Variable.self)
        case .ecmwf_ifs_long_window:
            return .single(CdsDomain.ecmwf_ifs_long_window, Era5Variable.self)

        case .kma_gdps:
            return .single(KmaDomain.gdps, KmaVariable.self)
        case .kma_ldps:
            return .single(KmaDomain.ldps, KmaVariable.self)
        case .kma_seamless:
            return .multiple([
                .domain(KmaDomain.gdps, KmaVariable.self),
                .domain(KmaDomain.ldps, KmaVariable.self)
            ])
        case .gfs025, .ncep_gfs025:
            return .single(GfsDomain.gfs025, Gfs025Variable.self)
        case .gfs013, .ncep_gfs013:
            return .single(GfsDomain.gfs013, Gfs013Variable.self)
        case .ncep_nam_conus:
            return .single(GfsDomain.nam_conus, NamVariable.self)
        case .ncep_hrrr_conus_15min:
            return .single(GfsDomain.hrrr_conus_15min, Hrrr15MinVariable.self)
        case .gfs_hrrr, .ncep_hrrr_conus:
            return .init(
                primary: [
                    .mixedBeforeDerivation(Self.hrrrDerivationGroup(include15Min: include15Min))
                ],
                secondary: [.domain(NbmDomain.nbm_conus, ProbabilityVariable.self)],
                gridForBoundingBoxRequests: GfsDomain.hrrr_conus,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .gfs_global, .ncep_gfs_global:
            return .init(
                primary: [
                    .mixedBeforeDerivation(Self.gfsGlobalDerivationGroup)
                ],
                secondary: [
                    .domain(GfsDomain.gfs05_ens, ProbabilityVariable.self),
                    .domain(GfsDomain.gfs025_ens, ProbabilityVariable.self)
                ],
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .gfs_mix, .gfs_seamless, .ncep_seamless, .ncep_gfs_seamless:
            return .init(
                primary: [
                    .mixedBeforeDerivation(Self.gfsGlobalDerivationGroup),
                    .mixedBeforeDerivation(Self.hrrrDerivationGroup(include15Min: include15Min))
                ],
                secondary: [
                    .domain(GfsDomain.gfs05_ens, ProbabilityVariable.self),
                    .domain(GfsDomain.gfs025_ens, ProbabilityVariable.self),
                    .domain(NbmDomain.nbm_conus, ProbabilityVariable.self)
                ],
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .ncep_gefs025:
            return .single(GfsDomain.gfs025_ens, Gefs025Variable.self)
        case .gfs05, .ncep_gefs05:
            return .single(GfsDomain.gfs05_ens, Gefs05Variable.self)
        case .ncep_gefs_seamless:
            return .multiple([
                .domain(GfsDomain.gfs05_ens, Gefs05Variable.self),
                .domain(GfsDomain.gfs025_ens, Gefs025Variable.self)
            ])
        case .ncep_nbm_conus:
            return .single(NbmDomain.nbm_conus, NbmSurfaceVariable.self)
        case .dwd_aicon_global_native:
            return .single(try await IconNativeDomains.aiconNative.load(), AiconSurfaceVariable.self)
        case .dwd_icon_global_native:
            let domain = try await IconNativeDomains.iconNative.load()
            return .init(primary: [
                .domain(domain, IconVariable.self),
                .domain(try await IconNativeDomains.iconNativeModelLevel.load(), IconModelLevelVariable.self)
            ], secondary: [.domain(try await IconNativeDomains.iconEpsNative.load(), ProbabilityVariable.self)], gridForBoundingBoxRequests: domain)
        case .dwd_icon_d2_ruc_native:
            let domain = try await IconNativeDomains.iconD2RucNative.load()
            return .init(
                primary: [.mixedBeforeDerivation(.init(domains: [
                    domain,
                    try await IconNativeDomains.iconD2RucNativeModelLevel.load(),
                    try await IconNativeDomains.iconD2RucNative15min.load()
                ], variableType: IconVariable.self, derivationDomain: domain))],
                gridForBoundingBoxRequests: domain
            )
        case .dwd_icon_d2_ruc_native_15min:
            return .single(try await IconNativeDomains.iconD2RucNative15min.load(), IconVariable.self)
        case .dwd_icon_d2_ruc_native_model_level:
            return .single(try await IconNativeDomains.iconD2RucNativeModelLevel.load(), IconModelLevelVariable.self)
        case .dwd_icon_d2_native:
            let domain = try await IconNativeDomains.iconD2Native.load()
            return .init(primary: [
                .domain(domain, IconVariable.self),
                .domain(try await IconNativeDomains.iconD2NativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(try await IconNativeDomains.iconD2Native15min.load(), IconVariable.self)
            ], secondary: [.domain(try await IconNativeDomains.iconD2EpsNative.load(), ProbabilityVariable.self)], gridForBoundingBoxRequests: domain)
        case .dwd_icon_d2_native_15min:
            return .single(try await IconNativeDomains.iconD2Native15min.load(), IconVariable.self)
        case .dwd_icon_eu_native:
            let domain = try await IconNativeDomains.iconEuNative.load()
            return .init(primary: [
                .domain(domain, IconVariable.self),
                .domain(try await IconNativeDomains.iconEuNativeModelLevel.load(), IconModelLevelVariable.self)
            ], secondary: [.domain(try await IconNativeDomains.iconEuEpsNative.load(), ProbabilityVariable.self)], gridForBoundingBoxRequests: domain)
        case .dwd_icon_global_native_model_level:
            return .single(try await IconNativeDomains.iconNativeModelLevel.load(), IconModelLevelVariable.self)
        case .dwd_icon_eu_native_model_level:
            return .single(try await IconNativeDomains.iconEuNativeModelLevel.load(), IconModelLevelVariable.self)
        case .dwd_icon_d2_native_model_level:
            return .single(try await IconNativeDomains.iconD2NativeModelLevel.load(), IconModelLevelVariable.self)
        case .dwd_icon_global_eps_native:
            return .single(try await IconNativeDomains.iconEpsNative.load(), DwdIconEpsGlobalVariable.self)
        case .dwd_icon_eu_eps_native:
            return .single(try await IconNativeDomains.iconEuEpsNative.load(), DwdIconEuEpsGlobalVariable.self)
        case .dwd_icon_d2_eps_native:
            return .single(try await IconNativeDomains.iconD2EpsNative.load(), DwdIconD2EpsGlobalVariable.self)
        case .ncep_aigfs025:
            return .singleWithPrecipitationProbability(GfsGraphCastDomain.aigfs025, GfsGraphCastVariable.self, precipitationProb: GfsGraphCastDomain.aigefs025)
        case .ncep_hgefs025_ensemble_mean:
            return .single(GfsGraphCastDomain.hgefs025_ensemble_mean, VariableOrSpread<GfsGraphCastVariable>.self)
        case .gfs_graphcast025, .ncep_gfs_graphcast025:
            return .single(GfsGraphCastDomain.graphcast025, GfsGraphCastVariable.self)
        case .ncep_aigefs025:
            return .single(GfsGraphCastDomain.aigefs025, GfsGraphCastVariable.self)
        case .ncep_aigefs025_ensemble_mean:
            return .single(GfsGraphCastDomain.aigefs025_ensemble_mean, VariableOrSpread<GfsGraphCastVariable>.self)
        case .dwd_sis_europe_africa_v4:
            return .single(DwdSisDomain.europe_africa_v4, DwdSisVariable.self)
        case .eumetsat_sarah3:
            return .single(EumetsatSarahDomain.sarah3_30min, EumetsatSarahVariable.self)
        case .jma_jaxa_mtg_fci:
            return .single(JaxaHimawariDomain.mtg_fci_10min, JaxaHimawariVariable.self)
        case .eumetsat_lsa_saf_msg:
            return .single(EumetsatLsaSafDomain.msg, EumetsatLsaSafVariable.self)
        case .eumetsat_lsa_saf_iodc:
            return .single(EumetsatLsaSafDomain.iodc, EumetsatLsaSafVariable.self)
        case .bom_access_global_ensemble:
            return .single(BomDomain.access_global_ensemble, BomVariable.self)
        case .google_weathernext2_ensemble:
            return .single(WeatherNextDomain.weathernext_global, WeatherNextVariable.self)
        case .bom_access_global:
            return .singleWithPrecipitationProbability(BomDomain.access_global, BomVariable.self, precipitationProb: BomDomain.access_global_ensemble)
        case .cma_grapes_global:
            return .single(CmaDomain.grapes_global, CmaVariable.self)
        case .dmi_harmonie_arome_europe:
            return .single(DmiDomain.harmonie_arome_europe, DmiVariable.self)
        case .knmi_harmonie_arome_europe:
            return .single(KnmiDomain.harmonie_arome_europe, KnmiVariable.self)
        case .knmi_harmonie_arome_netherlands:
            return .single(KnmiDomain.harmonie_arome_netherlands, KnmiVariable.self)
        case .italia_meteo_arpae_icon_2i:
            return .single(ItaliaMeteoArpaeDomain.icon_2i, ItaliaMeteoArpaeVariable.self)
        case .dmi_seamless:
            return .multipleWithPrecipitationProbability([
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self),
                .domain(DmiDomain.harmonie_arome_europe, DmiVariable.self)
            ], precipitationProb: EcmwfDomain.ifs025_ensemble)
        case .metno_nordic:
            return .single(MetNoDomain.nordic_pp, MetNoVariable.self)
        case .metno_seamless:
            return .multipleWithPrecipitationProbability([
                .domain(GfsDomain.gfs013, GfsUvIndexVariable.self),
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self),
                .domain(MetNoDomain.nordic_pp, MetNoVariable.self)
            ], precipitationProb: EcmwfDomain.ifs025_ensemble)
        case .knmi_seamless:
            return .multipleWithPrecipitationProbability([
                .domain(GfsDomain.gfs013, GfsUvIndexVariable.self),
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self),
                .domain(KnmiDomain.harmonie_arome_europe, KnmiVariable.self),
                .domain(KnmiDomain.harmonie_arome_netherlands, KnmiVariable.self)
            ], precipitationProb: EcmwfDomain.ifs025_ensemble)
        case .meteofrance_seamless, .meteofrance_mix:
            return .multiple([
                .domain(MeteoFranceDomain.arpege_world, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arpege_europe, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_hd, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_15min, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_hd_15min, MeteoFranceVariable.self)
            ])
        case .meteofrance_arpege_seamless, .arpege_seamless:
            return .multiple([
                .domain(MeteoFranceDomain.arpege_world, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arpege_europe, MeteoFranceVariable.self)
            ])
        case .meteofrance_arome_seamless, .arome_seamless:
            return .multiple([
                .domain(MeteoFranceDomain.arome_france, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_hd, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_15min, MeteoFranceVariable.self),
                .domain(MeteoFranceDomain.arome_france_hd_15min, MeteoFranceVariable.self)
            ])
        case .meteofrance_arpege_world, .arpege_world, .meteofrance_arpege_world025:
            return .single(MeteoFranceDomain.arpege_world, MeteoFranceVariable.self)
        case .meteofrance_arpege_europe, .arpege_europe:
            return .single(MeteoFranceDomain.arpege_europe, MeteoFranceVariable.self)
        case .meteofrance_arome_france, .arome_france, .meteofrance_arome_france0025:
            return .single(MeteoFranceDomain.arome_france, MeteoFranceVariable.self)
        case .meteofrance_arome_france_hd, .arome_france_hd:
            return .single(MeteoFranceDomain.arome_france_hd, MeteoFranceVariable.self)
        case .meteofrance_arome_france_15min:
            return .single(MeteoFranceDomain.arome_france_15min, MeteoFranceVariable.self)
        case .meteofrance_arome_france_hd_15min:
            return .single(MeteoFranceDomain.arome_france_hd_15min, MeteoFranceVariable.self)
        case .jma_seamless, .jma_mix:
            return .multiple([
                .domain(JmaDomain.gsm, JmaVariable.self),
                .domain(JmaDomain.msm_upper_level, JmaPressureVariable.self),
                .domain(JmaDomain.msm, JmaSurfaceVariable.self)
            ])
        case .jma_msm:
            return .init(primary: [
                .domain(JmaDomain.msm_upper_level, JmaPressureVariable.self),
                .domain(JmaDomain.msm, JmaSurfaceVariable.self)
            ], gridForBoundingBoxRequests: JmaDomain.msm)
        case .jma_msm_upper_level:
            return .single(JmaDomain.msm_upper_level, JmaPressureVariable.self)
        case .jms_gsm, .jma_gsm:
            return .single(JmaDomain.gsm, JmaVariable.self)
        case .icon_seamless, .icon_mix, .dwd_icon_seamless:
            // Prefer native EPS probabilities; deterministic storage keeps its regular-first priority until cutover.
            return .multiple([
                .domain(try await IconNativeDomains.iconNative.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconNativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.icon, IconVariable.self),
                .domain(try await IconNativeDomains.iconEuNative.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconEuNativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.iconEu, IconVariable.self),
                .domain(try await IconNativeDomains.iconD2Native.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconD2NativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.iconD2, IconVariable.self),
                .domain(try await IconNativeDomains.iconD2Native15min.load(), IconVariable.self),
                .domain(IconDomains.iconD2_15min, IconVariable.self)
            ] + (try await Self.dwd_icon_d2_ruc_native.getDomainAndVariable()?.primary ?? []), secondary: [
                .domain(IconDomains.iconEps, ProbabilityVariable.self),
                .domain(try await IconNativeDomains.iconEpsNative.load(), ProbabilityVariable.self),
                .domain(IconDomains.iconEuEps, ProbabilityVariable.self),
                .domain(try await IconNativeDomains.iconEuEpsNative.load(), ProbabilityVariable.self)
            ])
        case .icon_global, .dwd_icon_global, .dwd_icon:
            // Keep regular deterministic storage preferred, including its model-level fields, until cutover.
            return .init(primary: [
                .domain(try await IconNativeDomains.iconNative.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconNativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.icon, IconVariable.self)
            ], secondary: [
                .domain(IconDomains.iconEps, ProbabilityVariable.self),
                .domain(try await IconNativeDomains.iconEpsNative.load(), ProbabilityVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.icon,
                prefetchAllReaders: true, smoothTransitions: false)
        case .icon_eu, .dwd_icon_eu:
            return .init(primary: [
                .domain(try await IconNativeDomains.iconEuNative.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconEuNativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.iconEu, IconVariable.self)
            ], secondary: [
                .domain(IconDomains.iconEuEps, ProbabilityVariable.self),
                .domain(try await IconNativeDomains.iconEuEpsNative.load(), ProbabilityVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconEu,
                prefetchAllReaders: true, smoothTransitions: false)
        case .icon_d2, .dwd_icon_d2:
            return .init(primary: [
                .domain(try await IconNativeDomains.iconD2Native.load(), IconVariable.self),
                .domain(try await IconNativeDomains.iconD2NativeModelLevel.load(), IconModelLevelVariable.self),
                .domain(IconDomains.iconD2, IconVariable.self),
                .domain(try await IconNativeDomains.iconD2Native15min.load(), IconVariable.self),
                .domain(IconDomains.iconD2_15min, IconVariable.self)
            ] + (try await Self.dwd_icon_d2_ruc_native.getDomainAndVariable()?.primary ?? []), secondary: [
                .domain(IconDomains.iconD2Eps, ProbabilityVariable.self),
                .domain(try await IconNativeDomains.iconD2EpsNative.load(), ProbabilityVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconD2,
                prefetchAllReaders: true, smoothTransitions: false)
        case .dwd_icon_d2_15min:
            return .init(primary: [
                .domain(try await IconNativeDomains.iconD2Native15min.load(), IconVariable.self),
                .domain(IconDomains.iconD2_15min, IconVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconD2_15min,
                prefetchAllReaders: true, smoothTransitions: false)
        case .icon_seamless_eps, .dwd_icon_seamless_eps:
            return .multiple([
                .domain(IconDomains.iconEps, DwdIconEpsGlobalVariable.self),
                .domain(try await IconNativeDomains.iconEpsNative.load(), DwdIconEpsGlobalVariable.self),
                .domain(IconDomains.iconEuEps, DwdIconEuEpsGlobalVariable.self),
                .domain(try await IconNativeDomains.iconEuEpsNative.load(), DwdIconEuEpsGlobalVariable.self)
            ])
        case .dwd_icon_eps_ensemble_mean_seamless:
            return .multiple([
                .domain(IconDomains.iconEpsEnsembleMean, VariableOrSpread<DwdIconEpsGlobalVariable>.self),
                .domain(try await IconNativeDomains.iconEpsNativeEnsembleMean.load(), VariableOrSpread<DwdIconEpsGlobalVariable>.self),
                .domain(IconDomains.iconEuEpsEnsembleMean, VariableOrSpread<DwdIconEuEpsGlobalVariable>.self),
                .domain(try await IconNativeDomains.iconEuEpsNativeEnsembleMean.load(), VariableOrSpread<DwdIconEuEpsGlobalVariable>.self)
            ])
        case .icon_global_eps, .dwd_icon_global_eps:
            // Regular EPS ingestion has stopped; prefer native storage and retain regular archives.
            return .init(primary: [
                .domain(IconDomains.iconEps, DwdIconEpsGlobalVariable.self),
                .domain(try await IconNativeDomains.iconEpsNative.load(), DwdIconEpsGlobalVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconEps,
                prefetchAllReaders: true, smoothTransitions: false)
        case .icon_eu_eps, .dwd_icon_eu_eps:
            return .init(primary: [
                .domain(IconDomains.iconEuEps, DwdIconEuEpsGlobalVariable.self),
                .domain(try await IconNativeDomains.iconEuEpsNative.load(), DwdIconEuEpsGlobalVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconEuEps,
                prefetchAllReaders: true, smoothTransitions: false)
        case .icon_d2_eps, .dwd_icon_d2_eps:
            return .init(primary: [
                .domain(IconDomains.iconD2Eps, DwdIconD2EpsGlobalVariable.self),
                .domain(try await IconNativeDomains.iconD2EpsNative.load(), DwdIconD2EpsGlobalVariable.self)
            ], gridForBoundingBoxRequests: IconDomains.iconD2Eps,
                prefetchAllReaders: true, smoothTransitions: false)
        case .dwd_icon_eps_ensemble_mean:
            return .init(primary: [
                .domain(IconDomains.iconEpsEnsembleMean, VariableOrSpread<DwdIconEpsGlobalVariable>.self),
                .domain(try await IconNativeDomains.iconEpsNativeEnsembleMean.load(), VariableOrSpread<DwdIconEpsGlobalVariable>.self)
            ], gridForBoundingBoxRequests: IconDomains.iconEpsEnsembleMean,
                prefetchAllReaders: true, smoothTransitions: false)
        case .dwd_icon_eu_eps_ensemble_mean:
            return .init(primary: [
                .domain(IconDomains.iconEuEpsEnsembleMean, VariableOrSpread<DwdIconEuEpsGlobalVariable>.self),
                .domain(try await IconNativeDomains.iconEuEpsNativeEnsembleMean.load(), VariableOrSpread<DwdIconEuEpsGlobalVariable>.self)
            ], gridForBoundingBoxRequests: IconDomains.iconEuEpsEnsembleMean,
                prefetchAllReaders: true, smoothTransitions: false)
        case .dwd_icon_d2_eps_ensemble_mean:
            return .init(primary: [
                .domain(IconDomains.iconD2EpsEnsembleMean, VariableOrSpread<DwdIconD2EpsGlobalVariable>.self),
                .domain(try await IconNativeDomains.iconD2EpsNativeEnsembleMean.load(), VariableOrSpread<DwdIconD2EpsGlobalVariable>.self)
            ], gridForBoundingBoxRequests: IconDomains.iconD2EpsEnsembleMean,
                prefetchAllReaders: true, smoothTransitions: false)
        case .ecmwf_ifs025_ensemble_mean:
            return .single(EcmwfDomain.ifs025_ensemble_mean, VariableOrSpread<EcmwfIfsVariable>.self)
        case .ecmwf_aifs025_ensemble_mean:
            return .single(EcmwfDomain.aifs025_ensemble_mean, VariableOrSpread<EcmwfAifsVariable>.self)
        case .ncep_gefs025_ensemble_mean:
            return .single(GfsDomain.gefs025_ensemble_mean, VariableOrSpread<Gefs025Variable>.self)
        case .ncep_gefs05_ensemble_mean:
            return .single(GfsDomain.gefs05_ensemble_mean, VariableOrSpread<Gefs05Variable>.self)
        case .ecmwf_ifs_europe_ensemble:
            return .single(EcmwfEcpdsDomain.ifs_europe_ensemble, EcmwfEcdpsIfsEuropeEnsembleVariable.self)
        case .ecmwf_ifs_europe_ensemble_mean:
            return .single(EcmwfEcpdsDomain.ifs_europe_ensemble_mean, VariableOrSpread<EcmwfEcdpsIfsEuropeEnsembleVariable>.self)
        case .ecmwf_aifs_europe_ensemble:
            return .single(EcmwfEcpdsDomain.aifs_europe_ensemble, EcmwfEcdpsAifsEuropeEnsembleVariable.self)
        case .ecmwf_aifs_europe_ensemble_mean:
            return .single(EcmwfEcpdsDomain.aifs_europe_ensemble_mean, VariableOrSpread<EcmwfEcdpsAifsEuropeEnsembleVariable>.self)
        case .ncep_gefs_ensemble_mean_seamless:
            return .multiple([
                .domain(GfsDomain.gefs05_ensemble_mean, VariableOrSpread<Gefs05Variable>.self),
                .domain(GfsDomain.gefs025_ensemble_mean, VariableOrSpread<Gefs025Variable>.self)
            ])
        case .gem_seamless, .cmc_gem_seamless:
            // Keep both generations of GDPS/RDPS for archive and forecast fallback.
            // Derive each product independently before mixing; HRDPS West is not part of seamless.
            return .multipleWithPrecipitationProbability([
                .domain(GemDomain.gem_gdps_15km_upper_level, GemVariable.self),
                .domain(GemDomain.gem_global, GemVariable.self),
                .domain(GemDomain.gem_gdps_15km, GemVariable.self),
                .domain(GemDomain.gem_regional, GemVariable.self),
                .domain(GemDomain.gem_rdps_10km, GemVariable.self),
                .domain(GemDomain.gem_hrdps_continental, GemVariable.self)
            ], precipitationProb: GemDomain.gem_global_ensemble)
        case .gem_global, .cmc_gem_gdps:
            // Use all generations, remapping gridpoint requests onto the legacy output grid.
            return .init(primary: [
                .domain(GemDomain.gem_gdps_15km_upper_level, GemVariable.self),
                .domain(GemDomain.gem_global, GemVariable.self),
                .domain(GemDomain.gem_gdps_15km, GemVariable.self)
            ], secondary: [.domain(GemDomain.gem_global_ensemble, ProbabilityVariable.self)], gridForBoundingBoxRequests: GemDomain.gem_global)
        case .gem_regional, .cmc_gem_rdps:
            // The old and new RDPS grids have different indexing.
            return .init(primary: [
                .domain(GemDomain.gem_regional, GemVariable.self),
                .domain(GemDomain.gem_rdps_10km, GemVariable.self)
            ], gridForBoundingBoxRequests: GemDomain.gem_regional)
        case .gem_hrdps_continental, .cmc_gem_hrdps:
            return .single(GemDomain.gem_hrdps_continental, GemVariable.self)
        case .gem_hrdps_west, .cmc_gem_hrdps_west:
            return .single(GemDomain.gem_hrdps_west, GemVariable.self)
        case .gem_global_ensemble, .cmc_gem_geps:
            // Preserve the coordinate-only GEPS API contract.
            return .multiple([.domain(GemDomain.gem_global_ensemble, GemVariable.self)])
        case .cmc_gem_geps_ensemble_mean:
            return .single(GemDomain.gem_global_ensemble_mean, VariableOrSpread<GemVariable>.self)
        case .bom_access_global_ensemble_mean:
            return .single(BomDomain.access_global_ensemble, VariableOrSpread<BomVariable>.self)
        case .google_weathernext2_ensemble_mean:
            return .single(WeatherNextDomain.weathernext_global_ensemble_mean, VariableOrSpread<WeatherNextVariable>.self)
        case .ukmo_global_ensemble_20km:
            return .single(UkmoDomain.global_ensemble_20km, UkmoGlobalEnsembleVariable.self)
        case .ukmo_uk_ensemble_2km:
            return .single(UkmoDomain.uk_ensemble_2km, UkmoUkvEnsembleVariable.self)
        case .ukmo_global_ensemble_mean_20km:
            return .single(UkmoDomain.global_ensemble_mean_20km, VariableOrSpread<UkmoGlobalEnsembleVariable>.self)
        case .ukmo_uk_ensemble_mean_2km:
            return .single(UkmoDomain.uk_ensemble_mean_2km, VariableOrSpread<UkmoUkvEnsembleVariable>.self)
        case .ukmo_seamless:
            return .multiple([
                .domain(UkmoDomain.global_deterministic_10km, SurfaceAndPressureVariable<UkmoGlobalDeterministicSurfaceVariable, UkmoPressureVariable>.self),
                .domain(UkmoDomain.uk_deterministic_2km, UkmoVariable.self)
            ], secondary: [
                .domain(UkmoDomain.global_ensemble_20km, ProbabilityVariable.self),
                .domain(UkmoDomain.uk_ensemble_2km, ProbabilityVariable.self)
            ])
        case .ukmo_uk_deterministic_2km:
            return .singleWithPrecipitationProbability(
                UkmoDomain.uk_deterministic_2km,
                UkmoVariable.self,
                precipitationProb: UkmoDomain.uk_ensemble_2km
            )
        case .ukmo_global_deterministic_10km:
            return .singleWithPrecipitationProbability(
                UkmoDomain.global_deterministic_10km,
                SurfaceAndPressureVariable<UkmoGlobalDeterministicSurfaceVariable, UkmoPressureVariable>.self,
                precipitationProb: UkmoDomain.global_ensemble_20km
            )
        case .meteoswiss_icon_ch1:
            return .singleWithPrecipitationProbability(MeteoSwissDomain.icon_ch1, MeteoSwissVariable.self, precipitationProb: MeteoSwissDomain.icon_ch1_ensemble)
        case .meteoswiss_icon_ch2:
            return .singleWithPrecipitationProbability(MeteoSwissDomain.icon_ch2, MeteoSwissVariable.self, precipitationProb: MeteoSwissDomain.icon_ch2_ensemble)
        case .meteoswiss_icon_seamless:
            return .multiple([
                .domain(MeteoSwissDomain.icon_ch2, MeteoSwissVariable.self),
                .domain(MeteoSwissDomain.icon_ch1, MeteoSwissVariable.self)
            ], secondary: [
                .domain(MeteoSwissDomain.icon_ch2_ensemble, ProbabilityVariable.self),
                .domain(MeteoSwissDomain.icon_ch1_ensemble, ProbabilityVariable.self)
            ])
        case .meteoswiss_icon_ch1_ensemble:
            return .single(MeteoSwissDomain.icon_ch1_ensemble, MeteoSwissVariable.self)
        case .meteoswiss_icon_ch2_ensemble:
            return .single(MeteoSwissDomain.icon_ch2_ensemble, MeteoSwissVariable.self)
        case .meteoswiss_icon_ch1_ensemble_mean:
            return .single(MeteoSwissDomain.icon_ch1_ensemble_mean, VariableOrSpread<MeteoSwissVariable>.self)
        case .meteoswiss_icon_ch2_ensemble_mean:
            return .single(MeteoSwissDomain.icon_ch2_ensemble_mean, VariableOrSpread<MeteoSwissVariable>.self)
        case .ecmwf_wam:
            return .single(EcmwfEcpdsDomain.wam, EcmwfEcdpsWamVariable.self)
        case .ewam, .dwd_ewam:
            return .single(IconWaveDomain.ewam, IconWaveVariable.self)
        case .gwam, .dwd_gwam:
            return .single(IconWaveDomain.gwam, IconWaveVariable.self)
        case .era5_ocean:
            return .single(CdsDomain.era5_ocean, Era5Variable.self)
        case .ecmwf_wam025:
            return .single(EcmwfDomain.wam025, EcmwfWaveVariable.self)
        case .ecmwf_wam025_ensemble:
            return .single(EcmwfDomain.wam025_ensemble, EcmwfWaveVariable.self)
        case .meteofrance_wave:
            return .single(MfWaveDomain.mfwave, MfWaveVariable.self)
        case .meteofrance_currents:
            return .init(primary: [
                .domain(MfWaveDomain.mfsst, MfSSTVariable.self),
                .domain(MfWaveDomain.mfcurrents, MfCurrentVariable.self)
            ], gridForBoundingBoxRequests: MfWaveDomain.mfcurrents)
        case .ncep_gfswave025:
            return .single(GfsDomain.gfswave025, GfsWaveVariable.self)
        case .ncep_gfswave016:
            return .single(GfsDomain.gfswave016, GfsWaveVariable.self)
        case .ncep_gefswave025:
            return .single(GfsDomain.gfswave025_ens, GfsWaveVariable.self)
        case .ecmwf_wam025_ensemble_mean:
            return .single(EcmwfDomain.wam025_ensemble_mean, VariableOrSpread<EcmwfWaveVariable>.self)
        case .ncep_gefswave025_ensemble_mean:
            return .single(GfsDomain.gefswave025_ensemble_mean, VariableOrSpread<GfsWaveVariable>.self)
        case .geosphere_arome_austria:
            return .single(GeoSphereDomain.arome_austria, GeoSphereVariable.self)
        case .chmi_aladin_cz_1km:
            return .single(ChmiDomain.aladin_cz_1km, ChmiSurfaceVariable.self)
        case .chmi_aladin_central_europe_2km:
            return .single(ChmiDomain.aladin_central_europe_2km, ChmiVariable.self)
        case .chmi_aladin_seamless:
            return .init(primary: [
                .domain(ChmiDomain.aladin_central_europe_2km, ChmiVariable.self),
                .domain(ChmiDomain.aladin_cz_1km, ChmiSurfaceVariable.self)
            ], secondary: [
                .domain(EcmwfDomain.ifs025_ensemble, ProbabilityVariable.self),
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self)
            ], requirePrimaryCoverage: true)
        case .air_quality_best_match:
            return .init(
                primary: [
                    .mixedBeforeDerivation(.init(
                        domains: [
                            CamsDomain.cams_global,
                            .cams_global_greenhouse_gases,
                            .cams_europe,
                            .cams_europe_reanalysis_interim,
                            .cams_europe_reanalysis_validated,
                            .cams_europe_reanalysis_validated_pre2020,
                            .cams_europe_reanalysis_validated_pre2018
                        ],
                        variableType: CamsVariable.self,
                        derivationDomain: CamsDomain.cams_global
                    ))
                ],
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .cams_global:
            return .init(
                primary: [
                    .mixedBeforeDerivation(.init(
                        domains: [CamsDomain.cams_global, .cams_global_greenhouse_gases],
                        variableType: CamsVariable.self,
                        derivationDomain: CamsDomain.cams_global
                    ))
                ],
                gridForBoundingBoxRequests: CamsDomain.cams_global,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .cams_europe:
            return .init(
                primary: [
                    .mixedBeforeDerivation(.init(
                        domains: [
                            CamsDomain.cams_europe,
                            .cams_europe_reanalysis_interim,
                            .cams_europe_reanalysis_validated,
                            .cams_europe_reanalysis_validated_pre2020,
                            .cams_europe_reanalysis_validated_pre2018
                        ],
                        variableType: CamsVariable.self,
                        derivationDomain: CamsDomain.cams_europe
                    ))
                ],
                gridForBoundingBoxRequests: CamsDomain.cams_europe,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            )
        case .geosphere_seamless:
            return .multipleWithPrecipitationProbability([
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self),
                .domain(GeoSphereDomain.arome_austria, GeoSphereVariable.self)
            ], precipitationProb: EcmwfDomain.ifs025_ensemble)
        default:
            return nil
        }
    }

    /// The ensemble API endpoint uses domain names without "_ensemble". Remap to maintain backwards compatibility
    var remappedToEnsembleApi: Self {
        switch self {
        case .icon_seamless:
            return .icon_seamless_eps
        case .icon_global:
            return .icon_global_eps
        case .icon_eu:
            return .icon_eu_eps
        case .icon_d2:
            return .icon_d2_eps
        case .ecmwf_ifs01:
            return .ecmwf_ifs01_ensemble
        case .ecmwf_ifs025:
            return .ecmwf_ifs025_ensemble
        case .ecmwf_aifs025:
            return .ecmwf_aifs025_ensemble
        case .gem_global:
            return .gem_global_ensemble
        case .gfs_seamless:
            return .ncep_gefs_seamless
        case .gfs025:
            return .ncep_gefs025
        case .gfs05:
            return .ncep_gefs05
        case .meteoswiss_icon_ch1:
            return .meteoswiss_icon_ch1_ensemble
        case .meteoswiss_icon_ch2:
            return .meteoswiss_icon_ch2_ensemble
        default:
            return self
        }
    }
    
    static func hourlyToMultiSameType(
        _ readers: [any GenericReaderOptionalProtocol<ForecastVariable>],
        prefetchAllReaders: Bool = false,
        smoothTransitions: Bool = true
    ) -> ForecastReaderResult? {
        guard readers.count > 0 else {
            return nil
        }
        let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: readers, prefetchAllReaders: prefetchAllReaders, smoothTransitions: smoothTransitions)
        return (hourly, hourly.makeDailyAggregator(), nil, nil)
    }

    static func hourlyToMultiSameType(
        _ readers: [(any GenericReaderOptionalProtocol<ForecastVariable>)?],
        prefetchAllReaders: Bool = false
    ) -> ForecastReaderResult? {
        return hourlyToMultiSameType(readers.compactMap { $0 }, prefetchAllReaders: prefetchAllReaders)
    }

    // best_match may change its model selection over time, so native ICON intentionally takes priority here.
    // Keep these storage pairs separate from the probability and quarter-hourly companions in best_match.
    private static func makeBestMatchIconReader(
        domain: IconDomains, native: IconNativeDomains,
        lat: Float, lon: Float, elevation: Float,
        mode: GridSelectionMode, options: GenericReaderOptions
    ) async throws -> (any GenericReaderOptionalProtocol<ForecastVariable>)? {
        let primary: [DomainReaderMapping.Source]
        if let nativeGrid = try? await native.load() {
            primary = [.domain(domain, IconVariable.self), .domain(nativeGrid, IconVariable.self)]
        } else {
            primary = [.domain(domain, IconVariable.self)]
        }
        let forecast = try await DomainReaderMapping.makeDomainReaders(sources: primary, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        guard !forecast.readers.isEmpty else {
            if let error = forecast.unavailableRun { throw error }
            return nil
        }
        var secondary: [DomainReaderMapping.Source] = []
        if let modelLevel = native.modelLevelDomain {
            if let modelLevelGrid = try? await modelLevel.load() {
                secondary.append(.domain(modelLevelGrid, IconModelLevelVariable.self))
            }
        }
        let supplemental = try await DomainReaderMapping.makeDomainReaders(sources: secondary, lat: lat, lon: lon, elevation: forecast.elevation, mode: mode, options: options)
        let readers = forecast.readers + supplemental.readers
        return GenericReaderMultiSameType<ForecastVariable>(reader: readers, prefetchAllReaders: true, smoothTransitions: false)
    }

    func getReaders(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions, biasCorrection: Bool, include15Min: Bool) async throws -> ForecastReaderResult? {
        if let d = try await getDomainAndVariable(include15Min: include15Min) {
            return try await d.getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        }
        
        switch self {
        case .marine_best_match:
            let lastRunAvailabilityTime = try await MfWaveDomain.mfwave
                .getMetaJson(client: options.httpClient, logger: options.logger)?
                .lastRunAvailabilityTime
            var sources: [DomainReaderMapping.Source] = [
                .domain(MfWaveDomain.mfcurrents, MfCurrentVariable.self),
                .domain(MfWaveDomain.mfsst, MfSSTVariable.self),
                .domain(IconWaveDomain.ewam, IconWaveVariable.self),
                .domain(MfWaveDomain.mfwave, MfWaveVariable.self),
            ]
            if let lastRunAvailabilityTime, lastRunAvailabilityTime <= Timestamp.now().subtract(hours: 26) {
                sources.append(.domain(EcmwfDomain.wam025, EcmwfWaveVariable.self))
            }
            return try await DomainReaderMapping.multiple(sources).getReaders(
                lat: lat,
                lon: lon,
                elevation: elevation,
                mode: mode,
                options: options
            )
        case .best_match:
            let gfsProbabilites = try await ProbabilityReader.makeGfsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let iconProbabilities = try await ProbabilityReader.makeIconReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ifsProbabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let gfsForecast = try await DomainReaderMapping(
                    primary: [
                        .mixedBeforeDerivation(Self.gfsGlobalDerivationGroup)
                    ],
                    prefetchAllReaders: true, requirePrimaryCoverage: true
                ).getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)

            // do not fail a request because people did not synchronize icon-native grid.bin file in the best_match branch
            let icon = try await Self.makeBestMatchIconReader(domain: .icon, native: .iconNative, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)

            guard
                let gfs = gfsForecast?.hourly,
                let gfsUvIndex = try await GfsDomain.gfs013.makeDerivedHourly(variableType: GfsUvIndexVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
                let ifs025 = try await EcmwfDomain.ifs025.makeDerivedHourly(variableType: EcmwfIfsVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
                let ifsHres = try await EcmwfEcpdsDomain.ifs.makeDerivedHourly(variableType: EcmwfEcdpsIfsVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            // For Netherlands and Belgium use KNMI, IFS and ICON
            if (49.35..<53.79).contains(lat), (2.19..<7.66).contains(lon), let knmiNetherlands = try await KnmiDomain.harmonie_arome_netherlands.makeDerivedHourly(variableType: KnmiVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let iconEu = try await Self.makeBestMatchIconReader(domain: .iconEu, native: .iconEuNative, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let iconD2 = try await Self.makeBestMatchIconReader(domain: .iconD2, native: .iconD2Native, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ruc: ForecastReaderResult?
                do {
                    ruc = try await Self.dwd_icon_d2_ruc_native.getDomainAndVariable()?
                        .getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                } catch IconNativeDomainError.missingGridArtifact, ForecastApiError.modelRunUnavailable {
                    ruc = nil
                }
                return MultiDomains.hourlyToMultiSameType([
                    iconProbabilities.asOptionalReader,
                    ifsProbabilities?.asOptionalReader,
                    gfsUvIndex,
                    icon,
                    iconEu,
                    iconD2,
                    ruc?.hourly,
                    ifs025,
                    ifsHres,
                    knmiNetherlands
                ])
            }
            // Scandinavian region, combine MetNo Nordic with IFS HRES
            if lat >= 54.9, let _ = try await MetNoDomain.nordic_pp.makeHourlyReader(variableType: MetNoVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                guard let mapping = try await Self.metno_seamless.getDomainAndVariable() else {
                    throw ModelError.domainInitFailed(domain: Self.metno_seamless.rawValue)
                }
                return try await mapping.getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            }
            // For UK, use MetOffice UK, but cut out the English channel triangle for Northern France
            if RegionGeometry.isInUKVArea(lat: lat, lon: lon) {
                let mapping = DomainReaderMapping.multipleWithPrecipitationProbability([
                    .domain(GfsDomain.gfs013, GfsUvIndexVariable.self),
                    .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                    .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self),
                    .domain(UkmoDomain.global_deterministic_10km, SurfaceAndPressureVariable<UkmoGlobalDeterministicSurfaceVariable, UkmoPressureVariable>.self),
                    .domain(UkmoDomain.uk_deterministic_2km, UkmoVariable.self)
                ], precipitationProb: EcmwfDomain.ifs025_ensemble)
                return try await mapping.getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            }
            // If Icon-d2 is available, use icon domains
            if let iconD2 = try await Self.makeBestMatchIconReader(domain: .iconD2, native: .iconD2Native, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
               let iconD2_15min = try await Self.makeBestMatchIconReader(domain: .iconD2_15min, native: .iconD2Native15min, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let iconEu = try await Self.makeBestMatchIconReader(domain: .iconEu, native: .iconEuNative, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ruc: ForecastReaderResult?
                do {
                    ruc = try await Self.dwd_icon_d2_ruc_native.getDomainAndVariable()?
                        .getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                } catch IconNativeDomainError.missingGridArtifact, ForecastApiError.modelRunUnavailable {
                    ruc = nil
                }
                return MultiDomains.hourlyToMultiSameType([
                    ifsProbabilities?.asOptionalReader,
                    iconProbabilities.asOptionalReader,
                    gfs,
                    ifsHres,
                    icon,
                    iconEu,
                    iconD2,
                    include15Min ? iconD2_15min : nil,
                    ruc?.hourly
                ])
            }
            // For western europe, use arome models
            if (42.10..<51.32).contains(lat), (-6.18..<8.35).contains(lon) {
                var meteofranceElevation = elevation
                let aromeFranceHd15Min = try await MeteoFranceDomain.arome_france_hd_15min.makeDerivedHourly(variableType: MeteoFranceVariable.self, lat: lat, lon: lon, elevation: meteofranceElevation, mode: mode, options: options)
                if meteofranceElevation.isNaN, let aromeFranceHd15Min {
                    meteofranceElevation = aromeFranceHd15Min.resolvedTargetElevation
                }
                let aromeFrance15Min = try await MeteoFranceDomain.arome_france_15min.makeDerivedHourly(variableType: MeteoFranceVariable.self, lat: lat, lon: lon, elevation: meteofranceElevation, mode: mode, options: options)
                if meteofranceElevation.isNaN, let aromeFrance15Min {
                    meteofranceElevation = aromeFrance15Min.resolvedTargetElevation
                }
                if let aromeFranceHd = try await MeteoFranceDomain.arome_france_hd.makeDerivedHourly(variableType: MeteoFranceVariable.self, lat: lat, lon: lon, elevation: meteofranceElevation, mode: mode, options: options) {
                    if meteofranceElevation.isNaN {
                        meteofranceElevation = aromeFranceHd.resolvedTargetElevation
                    }
                    let aromeFrance = try await MeteoFranceDomain.arome_france.makeDerivedHourly(variableType: MeteoFranceVariable.self, lat: lat, lon: lon, elevation: meteofranceElevation, mode: mode, options: options)
                    let arpegeEurope = try await MeteoFranceDomain.arpege_europe.makeDerivedHourly(variableType: MeteoFranceVariable.self, lat: lat, lon: lon, elevation: meteofranceElevation, mode: mode, options: options)
                    return MultiDomains.hourlyToMultiSameType([
                        gfsProbabilites?.asOptionalReader,
                        iconProbabilities.asOptionalReader,
                        gfs,
                        icon,
                        ifsHres,
                        arpegeEurope,
                        aromeFrance,
                        aromeFranceHd,
                        aromeFrance15Min,
                        aromeFranceHd15Min
                    ])
                }
            }
            // For Northern Europe and Iceland use DMI Harmonie
            if (44..<66).contains(lat), let dmiEurope = try await DmiDomain.harmonie_arome_europe.makeDerivedHourly(variableType: DmiVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let iconEu = try await Self.makeBestMatchIconReader(domain: .iconEu, native: .iconEuNative, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return MultiDomains.hourlyToMultiSameType([
                    iconProbabilities.asOptionalReader,
                    gfsProbabilites?.asOptionalReader,
                    ifsProbabilities?.asOptionalReader,
                    gfs,
                    icon,
                    iconEu,
                    ifs025,
                    ifsHres,
                    dmiEurope
                ])
            }
            // For North America, use HRRR
            if let hrrr = try await DomainReaderMapping(
                primary: [
                    .mixedBeforeDerivation(Self.hrrrDerivationGroup(include15Min: include15Min))
                ],
                gridForBoundingBoxRequests: GfsDomain.hrrr_conus,
                prefetchAllReaders: true, requirePrimaryCoverage: true
            ).getReaders(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.hourly {
                let nbmProbabilities = try await ProbabilityReader.makeNbmReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return MultiDomains.hourlyToMultiSameType([
                    iconProbabilities.asOptionalReader,
                    gfsProbabilites?.asOptionalReader,
                    nbmProbabilities?.asOptionalReader,
                    icon,
                    gfs,
                    hrrr
                ])
            }
            // For Japan use JMA MSM with ICON. Does not use global JMA model because of poor resolution
            if (22.4 + 5..<47.65 - 5).contains(lat),
               (120 + 5..<150 - 5).contains(lon),
               let jmaMsm = try await JmaDomain.msm.makeDerivedHourly(variableType: JmaSurfaceVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
               let jmaMsmUpper = try await JmaDomain.msm_upper_level.makeDerivedHourly(variableType: JmaPressureVariable.self, lat: lat, lon: lon, elevation: jmaMsm.resolvedTargetElevation, mode: mode, options: options) {
                return MultiDomains.hourlyToMultiSameType([
                    iconProbabilities.asOptionalReader,
                    gfsProbabilites?.asOptionalReader,
                    ifsProbabilities?.asOptionalReader,
                    gfs,
                    icon,
                    ifsHres,
                    jmaMsmUpper,
                    jmaMsm
                ])
            }

            // Remaining eastern europe
            if let iconEu = try await Self.makeBestMatchIconReader(domain: .iconEu, native: .iconEuNative, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                return MultiDomains.hourlyToMultiSameType([
                    gfsProbabilites?.asOptionalReader,
                    ifsProbabilities?.asOptionalReader,
                    iconProbabilities.asOptionalReader,
                    gfs,
                    ifsHres,
                    icon,
                    iconEu
                ])
            }

            // Remaining parts of the world
            return MultiDomains.hourlyToMultiSameType([
                iconProbabilities.asOptionalReader,
                gfsProbabilites?.asOptionalReader,
                ifsProbabilities?.asOptionalReader,
                gfs,
                icon,
                ifsHres
            ])
            
        case .ecmwf_seasonal_seamless, .ecmwf_seasonal_ensemble_mean_seamless:
            let isEnsembleMean = self == .ecmwf_seasonal_ensemble_mean_seamless
            let ec46Domain: EcmwfSeasDomain = isEnsembleMean ? .ec46_ensemble_mean : .ec46
            let seas5Domain: EcmwfSeasDomain = isEnsembleMean ? .seas5_ensemble_mean : .seas5
            let seas5DailyDomain: EcmwfSeasDomain = isEnsembleMean ? .seas5_daily_ensemble_mean : .seas5_daily
            
            let seas5daily = try await VariableDailyDeriver<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(domain: seas5DailyDomain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            let seas6hourly = try await seas5Domain.makeHourlyDeriverCached(variableType: VariableOrSpread<EcmwfSeasVariableSingleLevel>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let seas6hourlyToDaily = seas6hourly.makeDailyAggregator()
            let seas6monthly = try await EcmwfSeasDomain.seas5_monthly.makeMonthlyDeriverCached(variableType: EcmwfSeasVariableMonthly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let ec46hourly = try await ec46Domain.makeHourlyDeriverCached(variableType: EcmwfEC46Variable6Hourly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let ec46hourlyToDaily = ec46hourly.makeDailyAggregator()
            
            let ec46weekly = try await EcmwfSeasDomain.ec46_weekly.makeWeeklyDeriverCached(variableType: EcmwfEC46VariableWeekly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
                        
            let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: [seas6hourly, ec46hourly])
            let daily = GenericReaderMultiSameType<ForecastVariableDaily>(reader: [seas6hourlyToDaily, seas5daily, ec46hourlyToDaily])
            return (hourly, daily, ec46weekly, seas6monthly)
        case .ecmwf_seas5, .ecmwf_seas5_ensemble_mean:
            let isEnsembleMean = self == .ecmwf_seas5_ensemble_mean
            let seas5Domain: EcmwfSeasDomain = isEnsembleMean ? .seas5_ensemble_mean : .seas5
            let seas5DailyDomain: EcmwfSeasDomain = isEnsembleMean ? .seas5_daily_ensemble_mean : .seas5_daily
            
            let seas5daily = try await VariableDailyDeriver<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(domain: seas5DailyDomain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let seas6hourly = try await seas5Domain.makeHourlyDeriverCached(variableType: VariableOrSpread<EcmwfSeasVariableSingleLevel>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            let seas6hourlyToDaily = seas6hourly.makeDailyAggregator()
            
            let seas6monthly = try await EcmwfSeasDomain.seas5_monthly.makeMonthlyDeriverCached(variableType: EcmwfSeasVariableMonthly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let daily = GenericReaderMultiSameType<ForecastVariableDaily>(reader: [seas6hourlyToDaily, seas5daily])
            return (seas6hourly, daily, nil, seas6monthly)
        case .ecmwf_ec46, .ecmwf_ec46_ensemble_mean:
            let isEnsembleMean = self == .ecmwf_ec46_ensemble_mean
            let ec46Domain: EcmwfSeasDomain = isEnsembleMean ? .ec46_ensemble_mean : .ec46
            
            let ec46hourly = try await ec46Domain.makeHourlyDeriverCached(variableType: VariableOrSpread<EcmwfEC46Variable6Hourly>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            let ec46hourlyToDaily = ec46hourly.makeDailyAggregator()
            let ec46weekly = try await EcmwfSeasDomain.ec46_weekly.makeWeeklyDeriverCached(variableType: EcmwfEC46VariableWeekly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            return (ec46hourly, ec46hourlyToDaily, ec46weekly, nil)
            
        case .CMCC_CM2_VHR4:
            let reader = try await Cmip6Domain.CMCC_CM2_VHR4.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .FGOALS_f3_H:
            let reader = try await Cmip6Domain.FGOALS_f3_H.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .HiRAM_SIT_HR:
            let reader = try await Cmip6Domain.HiRAM_SIT_HR.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .MRI_AGCM3_2_S:
            let reader = try await Cmip6Domain.MRI_AGCM3_2_S.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .EC_Earth3P_HR:
            let reader = try await Cmip6Domain.EC_Earth3P_HR.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .MPI_ESM1_2_XR:
            let reader = try await Cmip6Domain.MPI_ESM1_2_XR.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .NICAM16_8S:
            let reader = try await Cmip6Domain.NICAM16_8S.makeReader(biasCorrection: biasCorrection, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
            
        case .flood_best_match:
            guard let reader = try await GloFasMixer(domains: [.seasonal, .consolidated, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .seamless_v3:
            guard let reader = try await GloFasMixer(domains: [.seasonalv3, .consolidatedv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .forecast_v3:
            guard let reader = try await GloFasMixer(domains: [.seasonalv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .consolidated_v3:
            guard let reader = try await GloFasMixer(domains: [.consolidatedv3], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .seamless_v4:
            guard let reader = try await GloFasMixer(domains: [.seasonal, .consolidated, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .forecast_v4:
            guard let reader = try await GloFasMixer(domains: [.seasonal, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
        case .consolidated_v4:
            guard let reader = try await GloFasMixer(domains: [.consolidated], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return (nil, nil, nil, nil)
            }
            return (nil, GenericReaderMulti<ForecastVariableDaily>(reader: [reader]), nil, nil)
            
        case .satellite_radiation_seamless:
            if (-20..<60).contains(lon) { // DWD MTG on 0°
                return try await DwdSisDomain.europe_africa_v4.makeGenericHourlyDaily(variableType: DwdSisVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            }
            if (-60..<50).contains(lon) { // MSG on 0°
                return try await EumetsatLsaSafDomain.msg.makeGenericHourlyDaily(variableType: EumetsatLsaSafVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            }
            if (50..<90).contains(lon) { // IODC on 41.5°
                return try await EumetsatLsaSafDomain.iodc.makeGenericHourlyDaily(variableType: EumetsatLsaSafVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            }
            if (90...).contains(lon) { // Himawari on 140°
                let reader = try await JaxaHimawariDomain.himawari_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let reader70e = try await JaxaHimawariDomain.himawari_70e_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: [reader, reader70e].compactMap({$0}))
                return (hourly, hourly.makeDailyAggregator(), nil, nil)
            }
            return (nil, nil, nil, nil)
        case .jma_jaxa_himawari:
            let reader = try await JaxaHimawariDomain.himawari_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
              let redaer70e = try await JaxaHimawariDomain.himawari_70e_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: [reader, redaer70e].compactMap({$0}))
            return (hourly, hourly.makeDailyAggregator(), nil, nil)
        case .arpae_cosmo_seamless, .arpae_cosmo_2i, .arpae_cosmo_2i_ruc, .arpae_cosmo_5m:
            throw ForecastApiError.generic(message: "ARPAE COSMO models are not available anymore")
        default:
            return nil
        }
    }
    
    func getReaders(gridpoint: Int, options: GenericReaderOptions) async throws -> ForecastReaderResult {
        let mapping = try await getDomainAndVariable()
        return try await getReaders(gridpoint: gridpoint, mapping: mapping, options: options)
    }

    /// Reuse the resolved mapping for every cell of a bounding-box request.
    func getReaders(gridpoint: Int, mapping: DomainReaderMapping?, options: GenericReaderOptions) async throws -> ForecastReaderResult {
        guard let mapping,
              let gridForBoundingBoxRequests = mapping.gridForBoundingBoxRequests else {
            return (nil, nil, nil, nil)
        }
        let coordinate = gridForBoundingBoxRequests.grid.getCoordinates(gridpoint: gridpoint)
        var unavailableRun: ForecastApiError?
        let readers: [any GenericReaderOptionalProtocol<ForecastVariable>] = try await mapping.primary.asyncCompactMap { source in
            do {
                switch source {
                case .domain(let domain, let variable):
                    let position = domain.domainRegistry == gridForBoundingBoxRequests.domainRegistry ? gridpoint : domain.grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude)
                    guard let position else { return nil }
                    return try await domain.makeGenericHourlyDaily(variableType: variable, position: position, modelCoordinates: coordinate, options: options).hourly
                case .mixedBeforeDerivation(let group):
                    return try await group.makeReader(lat: coordinate.latitude, lon: coordinate.longitude, elevation: .nan, mode: .nearest, options: options)?.reader
                }
            } catch let error as ForecastApiError {
                guard case .modelRunUnavailable = error else { throw error }
                unavailableRun = unavailableRun ?? error
                return nil
            }
        }
        if readers.isEmpty, let error = unavailableRun { throw error }
        // Keep an empty reader so an unmapped output cell still produces null forecast columns.
        let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: readers, prefetchAllReaders: mapping.prefetchAllReaders, smoothTransitions: mapping.smoothTransitions)
        return (hourly, hourly.makeDailyAggregator(), nil, nil)
    }

    func genericDomain() async throws -> (any GenericDomain)? {
        try await getDomainAndVariable()?.gridForBoundingBoxRequests
    }

    var countEnsembleMember: Int {
        switch self {
        case .ncep_rrfs_conus_ensemble:
            return NcepRrfsDomain.ncep_rrfs_conus_ensemble.countEnsembleMember
        case .icon_seamless_eps, .dwd_icon_seamless_eps:
            return IconDomains.iconEps.countEnsembleMember
        case .icon_global_eps, .dwd_icon_global_eps, .dwd_icon_global_eps_native:
            return IconDomains.iconEps.countEnsembleMember
        case .icon_eu_eps, .dwd_icon_eu_eps, .dwd_icon_eu_eps_native:
            return IconDomains.iconEuEps.countEnsembleMember
        case .icon_d2_eps, .dwd_icon_d2_eps, .dwd_icon_d2_eps_native:
            return IconDomains.iconD2Eps.countEnsembleMember
        case .ecmwf_ifs01_ensemble:
            return EcmwfDomain.ifs01_ensemble.countEnsembleMember
        case .ecmwf_ifs025_ensemble:
            return EcmwfDomain.ifs025_ensemble.countEnsembleMember
        case .ecmwf_aifs025_ensemble:
            return EcmwfDomain.aifs025_ensemble.countEnsembleMember
        case .ecmwf_ifs_europe_ensemble:
            return EcmwfEcpdsDomain.ifs_europe_ensemble.countEnsembleMember
        case .ecmwf_aifs_europe_ensemble:
            return EcmwfEcpdsDomain.aifs_europe_ensemble.countEnsembleMember
        case .ncep_gefs025:
            return GfsDomain.gfs025_ens.countEnsembleMember
        case .ncep_gefs05:
            return GfsDomain.gfs05_ens.countEnsembleMember
        case .ncep_gefs_seamless:
            return GfsDomain.gfs05_ens.countEnsembleMember
        case .gem_global_ensemble, .cmc_gem_geps:
            return GemDomain.gem_global_ensemble.countEnsembleMember
        case .bom_access_global_ensemble:
            return BomDomain.access_global_ensemble.countEnsembleMember
        case .google_weathernext2_ensemble:
            return WeatherNextDomain.weathernext_global.countEnsembleMember
        case .ukmo_global_ensemble_20km:
            return UkmoDomain.global_ensemble_20km.countEnsembleMember
        case .ukmo_uk_ensemble_2km:
            return UkmoDomain.uk_ensemble_2km.countEnsembleMember
        case .meteoswiss_icon_ch1_ensemble:
            return MeteoSwissDomain.icon_ch1_ensemble.countEnsembleMember
        case .meteoswiss_icon_ch2_ensemble:
            return MeteoSwissDomain.icon_ch2_ensemble.countEnsembleMember
        case .ecmwf_seasonal_seamless, .ecmwf_seas5, .ecmwf_ec46:
            return EcmwfSeasDomain.seas5.countEnsembleMember
        case .ecmwf_wam025_ensemble:
            return EcmwfDomain.wam025_ensemble.countEnsembleMember
        case .ncep_gefswave025:
            return GfsDomain.gfswave025_ens.countEnsembleMember
        case .ncep_aigefs025:
            return GfsGraphCastDomain.aigefs025.countEnsembleMember
        default:
            return 1
        }
    }
}

enum ModelError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        return .badRequest
    }

    case domainInitFailed(domain: String)
}
