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
            alias: ["historical-forecast-api", "previous-runs-api", "single-runs-api", "seasonal-api"]).query
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
            defaultModel: .ncep_gefs_seamless,
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
            case "api.open-meteo.com", "customer-api.open-meteo.com":
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
        try await req.withApiParameter(subdomain, alias: alias) { host, params -> ForecastapiResult<MultiDomainsReader> in
            let type = type ?? ApiType.detect(host: host)
            let currentTime = Timestamp.now()
            let currentTimeHour0 = currentTime.with(hour: 0)
            
            let forecastDaysMax: Int
            let forecastDayDefault: Int
            let historyStartDate: Timestamp
            let historyEndDate: Timestamp? = type == .climate ? Timestamp(2051, 1, 1) : nil
            let temporalResolutionDefault: ApiTemporalResolution
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
            case .none, .seasonal:
                break
            case .singleRunsApi:
                guard run != nil else {
                    throw ForecastApiError.parameterIsRequired(name: "run")
                }
            case .forecast, .archive, .historicalForecast, .previousRuns, .satellite, .ensemble, .marine, .airQuality, .climate, .flood:
                guard run == nil else {
                    throw ForecastApiError.parameterMostNotBeSet(name: "run")
                }
            }
            let cellSelection = params.cell_selection ?? (type == .marine ? .sea : .land)
            let biasCorrection = !(params.disable_bias_correction ?? false)
            
            let pastDaysMax = (currentTimeHour0.timeIntervalSince1970 - historyStartDate.timeIntervalSince1970) / 86400
            let allowedRange = historyStartDate ..< (historyEndDate ?? currentTimeHour0.add(days: forecastDaysMax))

            let domainsParam = try MultiDomains.load(commaSeparatedOptional: params.models)?.map({ $0 == .best_match ? defaultModel : $0 }) ?? [defaultModel]
            let domains: [MultiDomains]
            switch type {
            case .ensemble:
                // Translate domain names from Ensemble API for compatibility
                domains = domainsParam.map{$0.remappedToEnsembleApi}
            case .airQuality:
                // Air quality API used domains=auto, global or europe
                let camsDomains = try (params.domains.map({ [$0] }) ?? CamsQuery.Domain.load(commaSeparatedOptional: params.models) ?? [.auto])
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
            let options = try params.readerOptions(for: req)
            let temporalResolution = params.temporal_resolution ?? temporalResolutionDefault
            
            let prepared = try await params.prepareCoordinates(allowTimezones: true, logger: options.logger, httpClient: options.httpClient)

            let locations: [ForecastapiResult<MultiDomainsReader>.PerLocation]
            switch prepared {
            case .coordinates(let coordinates):
                locations = try await coordinates.asyncMap { prepared in
                    let coordinates = prepared.coordinate
                    let timezone = prepared.timezone
                    let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                    let readers: [MultiDomainsReader] = try await domains.asyncCompactMap { domain in
                        guard let r = try await domain.getReaders(lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: cellSelection, options: options, biasCorrection: biasCorrection) else {
                            return nil
                        }
                        return MultiDomainsReader(domain: domain, readerHourly: r.hourly.map(VariableHourlyDeriverHighLevel.init), readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, run: run, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
                    }
                    guard !readers.isEmpty else {
                        throw ForecastApiError.noDataAvailableForThisLocation
                    }
                    let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                    return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
                }
            case .boundingBox(let bbox, dates: let dates, timezone: let timezone):
                locations = try await domains.asyncFlatMap({ domain in
                    guard let grid = domain.genericDomain?.grid else {
                        throw ForecastApiError.generic(message: "Bounding box calls not supported for domain \(domain)")
                    }
                    guard let gridpoionts = grid.findBox(boundingBox: bbox) else {
                        throw ForecastApiError.generic(message: "Bounding box calls not supported for grid of domain \(domain)")
                    }

                    if dates.count == 0 {
                        let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: nil, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                        let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                        var locationId = -1
                        return try await gridpoionts.asyncMap( { gridpoint in
                            locationId += 1
                            let r = try await domain.getReaders(gridpoint: gridpoint, options: options)
                            let readers = MultiDomainsReader(domain: domain, readerHourly: r.hourly.map(VariableHourlyDeriverHighLevel.init), readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, run: run, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
                            return .init(timezone: timezone, time: timeLocal, locationId: locationId, results: [readers])
                        })
                    }
                    
                    return try await dates.asyncFlatMap({ date -> [ForecastapiResult<MultiDomainsReader>.PerLocation] in
                        let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: date, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                        let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
                        var locationId = -1
                        return try await gridpoionts.asyncMap( { gridpoint in
                            locationId += 1
                            let r = try await domain.getReaders(gridpoint: gridpoint, options: options)
                            let readers = MultiDomainsReader(domain: domain, readerHourly: r.hourly.map(VariableHourlyDeriverHighLevel.init), readerDaily: r.daily, readerWeekly: r.weekly, readerMonthly: r.monthly, params: params, run: run, has15minutely: has15minutely, time: time, timezone: timezone, currentTime: currentTime, temporalResolution: temporalResolution)
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
    
    let readerHourly: VariableHourlyDeriverHighLevel?
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
    let run: IsoDateTime?
    
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
                let _ = try await readerHourly.prefetchData(variable: v, time: currentTimeRange.toSettings(previousDay: previousDay, run: run))
            }
        }
        if let minutely15Variables, let readerHourly {
            for variable in minutely15Variables {
                let members = variable.onlySingleMember ? 0..<1 : 0..<domain.countEnsembleMember
                let (v, previousDay) = variable.variableAndPreviousDay
                for member in members {
                    let _ = try await readerHourly.prefetchData(variable: v, time: time.minutely15.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run))
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
                    let _ = try await readerHourly.prefetchData(variable: v, time: timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run))
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
                        ensembleMemberLevel: allMembersForRiverDischarge ? nil : member,
                        run: run))
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
            let timeRead = currentTimeRange.toSettings(previousDay: previousDay, run: run)
            
            if case .surface(let v) = v {
                if v.variable == .is_day {
                    let isDay = Zensun.calculateIsDay(timeRange: currentTimeRange, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionless, value: isDay.first ?? .nan)
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
                if v.variable == .is_day {
                    let isDay = Zensun.calculateIsDay(timeRange: timeHourlyRead, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionless, variables: [ApiArray.float(isDay)])
                }
            }
            
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run)
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
            if variable == .daylight_duration {
                let duration = Zensun.calculateDaylightDuration(localMidnight: time.dailyDisplay.range, lat: readerDaily.modelLat)
                return ApiColumn(variable: .daylight_duration, unit: .seconds, variables: [.float(duration)])
            }
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = time.dailyRead.toSettings(
                    ensembleMember: allMembersForRiverDischarge ? member : nil,
                    ensembleMemberLevel: allMembersForRiverDischarge ? nil : member,
                    run: run
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
                if v.variable == .is_day {
                    let isDay = Zensun.calculateIsDay(timeRange: time.minutely15, lat: readerHourly.modelLat, lon: readerHourly.modelLon)
                    return .init(variable: variable, unit: .dimensionless, variables: [ApiArray.float(isDay)])
                }
            }
            
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let timeRead = time.minutely15.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run)
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
    case jms_gsm
    case jma_gsm

    case gem_seamless
    case gem_global
    case gem_regional
    case gem_hrdps_continental
    case gem_hrdps_west
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
    case dwd_sis_europe_africa_v4

    case ecmwf_ifs04
    case ecmwf_ifs025
    case ecmwf_aifs025
    case ecmwf_aifs025_single
    
    case ecmwf_seasonal_seamless
    case ecmwf_seas5
    case ecmwf_ec46
    
    case ecmwf_seasonal_ensemble_mean_seamless
    case ecmwf_seas5_ensemble_mean
    case ecmwf_ec46_ensemble_mean

    case metno_nordic

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

    case ecmwf_ifs025_ensemble
    case ecmwf_aifs025_ensemble

    case gem_global_ensemble

    case bom_access_global_ensemble

    case ncep_gefs_seamless
    case ncep_gefs025
    case ncep_gefs05

    case ukmo_global_ensemble_20km
    case ukmo_uk_ensemble_2km
    
    case meteoswiss_icon_ch1_ensemble
    case meteoswiss_icon_ch2_ensemble
    
    case ewam
    case gwam
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
    
//    enum DomainReaderMapping {
//        case single(domain: GenericDomain, variableType: any GenericVariable.Type)
//        case singleWithPrecipitationProbability(GenericDomain, GenericDomain, any GenericVariable.Type)
//    }
    
    /// Generic domains with hourly data that can use the generic defiver controller
    func getDomainAndVariable() -> (GenericDomain, any GenericVariable.Type)? {
        switch self {
        case .ncep_aigfs025:
            // TODO AIGFS could use precipitation probability from AIGEFS
            return (GfsGraphCastDomain.aigfs025, GfsGraphCastVariable.self)
        case .ncep_hgefs025_ensemble_mean:
            return (GfsGraphCastDomain.hgefs025_ensemble_mean, VariableOrSpread<GfsGraphCastVariable>.self)
        case .gfs_graphcast025, .ncep_gfs_graphcast025:
            return (GfsGraphCastDomain.graphcast025, GfsGraphCastVariable.self)
        case .ncep_aigefs025:
            return (GfsGraphCastDomain.aigefs025, GfsGraphCastVariable.self)
        case .ncep_aigefs025_ensemble_mean:
            return (GfsGraphCastDomain.aigefs025_ensemble_mean, VariableOrSpread<GfsGraphCastVariable>.self)
        case .dwd_sis_europe_africa_v4:
            return (DwdSisDomain.europe_africa_v4, DwdSisVariable.self)
        case .eumetsat_sarah3:
            return (EumetsatSarahDomain.sarah3_30min, EumetsatSarahVariable.self)
        case .jma_jaxa_mtg_fci:
            return (JaxaHimawariDomain.mtg_fci_10min, JaxaHimawariVariable.self)
        case .eumetsat_lsa_saf_msg:
            return (EumetsatLsaSafDomain.msg, EumetsatLsaSafVariable.self)
        case .eumetsat_lsa_saf_iodc:
            return (EumetsatLsaSafDomain.iodc, EumetsatLsaSafVariable.self)
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
    
    func getReaders(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions, biasCorrection: Bool) async throws -> (hourly: (any GenericReaderOptionalProtocol<ForecastVariable>)?, daily: (any GenericReaderOptionalProtocol<ForecastVariableDaily>)?, weekly: (any GenericReaderOptionalProtocol<ForecastVariableWeekly>)?, monthly: (any GenericReaderOptionalProtocol<ForecastVariableMonthly>)?)? {
        
        if let d = getDomainAndVariable() {
            return try await d.0.makeGenericHourlyDaily(variableType: d.1, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        }
        
        switch self {
        case .ecmwf_seasonal_seamless, .ecmwf_seasonal_ensemble_mean_seamless:
            let isEnsembleMean = self == .ecmwf_seasonal_ensemble_mean_seamless
            let ec46Domain: EcmwfSeasDomain = isEnsembleMean ? .ec46_ensemble_mean : .ec46
            let seas5Domain: EcmwfSeasDomain = isEnsembleMean ? .seas5_ensemble_mean : .seas5
            let seas5DailyDomain: EcmwfSeasDomain = isEnsembleMean ? .seas5_daily_ensemble_mean : .seas5_daily
            
            let seas5daily = try await VariableDailyDeriver<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(domain: seas5DailyDomain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            let seas6hourly = try await seas5Domain.makeHourlyDeriverCached(variableType: VariableOrSpread<EcmwfSeasVariableSingleLevel>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let seas6hourlyToDaily = DailyReaderConverter<VariableHourlyDeriver<GenericReaderCached<EcmwfSeasDomain, VariableOrSpread<EcmwfSeasVariableSingleLevel>>>, ForecastVariableDaily>(reader: seas6hourly, allowMinMaxTwoAggregations: true)
            let seas6monthly = try await EcmwfSeasDomain.seas5_monthly.makeMonthlyDeriverCached(variableType: EcmwfSeasVariableMonthly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let ec46hourly = try await ec46Domain.makeHourlyDeriverCached(variableType: EcmwfEC46Variable6Hourly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let ec46hourlyToDaily = ec46hourly.makeDailyAggregator(allowMinMaxTwoAggregations: true)
            
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
            let seas6hourlyToDaily = seas6hourly.makeDailyAggregator(allowMinMaxTwoAggregations: true)
            
            let seas6monthly = try await EcmwfSeasDomain.seas5_monthly.makeMonthlyDeriverCached(variableType: EcmwfSeasVariableMonthly.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            
            let daily = GenericReaderMultiSameType<ForecastVariableDaily>(reader: [seas6hourlyToDaily, seas5daily])
            return (seas6hourly, daily, nil, seas6monthly)
        case .ecmwf_ec46, .ecmwf_ec46_ensemble_mean:
            let isEnsembleMean = self == .ecmwf_ec46_ensemble_mean
            let ec46Domain: EcmwfSeasDomain = isEnsembleMean ? .ec46_ensemble_mean : .ec46
            
            let ec46hourly = try await ec46Domain.makeHourlyDeriverCached(variableType: VariableOrSpread<EcmwfEC46Variable6Hourly>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!
            let ec46hourlyToDaily = ec46hourly.makeDailyAggregator(allowMinMaxTwoAggregations: true)
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
                return (hourly, hourly.makeDailyAggregator(allowMinMaxTwoAggregations: false), nil, nil)
            }
            return (nil, nil, nil, nil)
        case .jma_jaxa_himawari:
            let reader = try await JaxaHimawariDomain.himawari_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
              let redaer70e = try await JaxaHimawariDomain.himawari_70e_10min.makeHourlyDeriverCached(variableType: JaxaHimawariVariable.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: [reader, redaer70e].compactMap({$0}))
            return (hourly, hourly.makeDailyAggregator(allowMinMaxTwoAggregations: false), nil, nil)
            
//        case .ncep_hgefs025_ensemble_mean:
//            return try await GfsGraphCastDomain.hgefs025_ensemble_mean.makeGenericHourlyDaily(variableType: VariableOrSpread<GfsGraphCastVariable>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//        case .gfs_graphcast025, .ncep_gfs_graphcast025:
//            return try await GfsGraphCastDomain.graphcast025.makeGenericHourlyDaily(variableType: VariableOrSpread<GfsGraphCastVariable>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//        case .ncep_aigefs025:
//            return try await GfsGraphCastDomain.aigefs025.makeGenericHourlyDaily(variableType: VariableOrSpread<GfsGraphCastVariable>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//        case .ncep_aigefs025_ensemble_mean:
//            return try await GfsGraphCastDomain.aigefs025_ensemble_mean.makeGenericHourlyDaily(variableType: VariableOrSpread<GfsGraphCastVariable>.self, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//        case .ncep_aigfs025:
//            // Use precipitation_probability from AIGEFS
//            guard
//                let aigfs = try await GenericReader<GfsGraphCastDomain, VariableOrSpread<GfsGraphCastVariable>>(domain: .aigfs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
//                let prob: any GenericReaderProtocol = try await ProbabilityReader.makeAigefsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
//                return nil
//            }
//            let hourly = GenericReaderMulti<ForecastVariable>(reader: [GenericReaderCached(reader: aigfs), prob])
//            let daily = DailyReaderConverter<GenericReaderMulti<ForecastVariable>, ForecastVariableDaily>(reader: hourly, allowMinMaxTwoAggregations: true)
//            return (hourly, daily, nil, nil)
        default:
            let readers: [any GenericReaderProtocol] = try await getReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            guard readers.count > 0 else {
                return nil
            }
            let hourlyReader = GenericReaderMulti<ForecastVariable>(reader: readers)
            let daily = DailyReaderConverter<GenericReaderMulti<ForecastVariable>, ForecastVariableDaily>(reader: hourlyReader, allowMinMaxTwoAggregations: false)
            return (hourlyReader, daily, nil, nil)
        }
        
    }
    
    func getReaders(gridpoint: Int, options: GenericReaderOptions) async throws -> (hourly: (any GenericReaderOptionalProtocol<ForecastVariable>)?, daily: (any GenericReaderOptionalProtocol<ForecastVariableDaily>)?, weekly: (any GenericReaderOptionalProtocol<ForecastVariableWeekly>)?, monthly: (any GenericReaderOptionalProtocol<ForecastVariableMonthly>)?) {
        
        if let d = getDomainAndVariable() {
            return try await d.0.makeGenericHourlyDaily(variableType: d.1, position: gridpoint, options: options)
        }
        
        switch self {
        case .meteofrance_currents:
            // same grid, but different time resolution and variables
            let mfsst: any GenericReaderProtocol = try await GenericReader<MfWaveDomain, MfSSTVariable>(domain: .mfsst, position: gridpoint, options: options)
            let mfcurrents: any GenericReaderProtocol = MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: try await GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, position: gridpoint, options: options)))
            let hourlyReader = GenericReaderMulti<ForecastVariable>(reader: [mfsst, mfcurrents])
            let daily = DailyReaderConverter<GenericReaderMulti<ForecastVariable>, ForecastVariableDaily>(reader: hourlyReader, allowMinMaxTwoAggregations: false)
            return (hourlyReader, daily, nil, nil)
            
        default:
            guard let readers: any GenericReaderProtocol = try await getReader(gridpoint: gridpoint, options: options) else {
                return (nil, nil, nil, nil)
            }
            let hourlyReader = GenericReaderMulti<ForecastVariable>(reader: [readers])
            let daily = DailyReaderConverter<GenericReaderMulti<ForecastVariable>, ForecastVariableDaily>(reader: hourlyReader, allowMinMaxTwoAggregations: false)
            return (hourlyReader, daily, nil, nil)
        }
    }
    
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> [any GenericReaderProtocol] {
        switch self {
        case .best_match:
            guard let icon: any GenericReaderProtocol = try await IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            let gfsProbabilites = try await ProbabilityReader.makeGfsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let iconProbabilities = try await ProbabilityReader.makeIconReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)

            guard let gfs: any GenericReaderProtocol = try await GfsReader(domains: [.gfs025, .gfs013], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            // For Netherlands and Belgium use KNMI
            if (49.35..<53.79).contains(lat), (2.19..<7.66).contains(lon), let knmiNetherlands = try await KnmiReader(domain: KnmiDomain.harmonie_arome_netherlands, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let iconEu = try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let iconD2 = try await IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return Array([gfsProbabilites, probabilities, gfs, icon, iconEu, iconD2, ecmwf, ifsHres, knmiNetherlands].compacted())
            }
            // Scandinavian region, combine with ICON
            if lat >= 54.9, let metno = try await MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let iconEu = try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let iconD2 = try await IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return Array([gfsProbabilites, probabilities, gfs, icon, iconEu, iconD2, ecmwf, ifsHres, metno].compacted())
            }
            // If Icon-d2 is available, use icon domains
            if let iconD2 = try await IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
               let iconD2_15min = try await IconReader(domain: .iconD2_15min, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                // TODO: check how out of projection areas are handled
                guard let iconEu = try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                    throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
                }
                return [gfsProbabilites, iconProbabilities, gfs, icon, iconEu, iconD2, iconD2_15min]
            }
            // For western europe, use arome models
            if (42.10..<51.32).contains(lat), (-6.18..<8.35).contains(lon), let arome_france_hd = try await MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let arome_france_hd_15min = try await MeteoFranceReader(domain: .arome_france_hd_15min, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let arome_france = try await MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let arome_france_15min = try await MeteoFranceReader(domain: .arome_france_15min, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let arpege_europe = try await MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return Array([gfsProbabilites, iconProbabilities, gfs, icon, arpege_europe, arome_france, arome_france_hd, arome_france_15min, arome_france_hd_15min].compacted())
            }
            // For Northern Europe and Iceland use DMI Harmonie
            if (44..<66).contains(lat), let dmiEurope = try await DmiReader(domain: DmiDomain.harmonie_arome_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let iconEu = try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return Array([gfsProbabilites, probabilities, gfs, icon, iconEu, ecmwf, ifsHres, dmiEurope].compacted())
            }
            // For North America, use HRRR
            if let hrrr = try await GfsReader(domains: [.hrrr_conus, .hrrr_conus_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                let nbmProbabilities = try await ProbabilityReader.makeNbmReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return Array([gfsProbabilites, nbmProbabilities, icon, gfs, hrrr].compacted())
            }
            // For Japan use JMA MSM with ICON. Does not use global JMA model because of poor resolution
            if (22.4 + 5..<47.65 - 5).contains(lat), (120 + 5..<150 - 5).contains(lon), let jma_msm = try await JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options), let jma_msm_upper = try await JmaReader(domain: .msm_upper_level, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                return [gfsProbabilites, iconProbabilities, gfs, icon, jma_msm_upper, jma_msm]
            }

            // Remaining eastern europe
            if let iconEu = try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                return [gfsProbabilites, iconProbabilities, gfs, icon, iconEu]
            }

            // Northern africa
            if let arpege_europe = try await MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) {
                return [gfsProbabilites, iconProbabilities, gfs, icon, arpege_europe].compactMap({ $0 })
            }

            // Remaining parts of the world
            return [gfsProbabilites, iconProbabilities, gfs, icon]
        case .gfs_mix, .gfs_seamless, .ncep_seamless:
            return [
                try await ProbabilityReader.makeGfsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) as any GenericReaderProtocol,
                try await ProbabilityReader.makeNbmReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) as (any GenericReaderProtocol)?,
                try await GfsReader(domains: [.gfs025, .gfs013, .hrrr_conus, .hrrr_conus_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            ].compactMap({ $0 })
        case .gfs_global, .ncep_gfs_global:
            let gfsProbabilites = try await ProbabilityReader.makeGfsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [gfsProbabilites] + (try await GfsReader(domains: [.gfs025, .gfs013], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .gfs025, .ncep_gfs025:
            return try await GfsReader(domains: [.gfs025], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gfs013, .ncep_gfs013:
            return try await GfsReader(domains: [.gfs013], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gfs_hrrr, .ncep_hrrr_conus:
            return [
                try await ProbabilityReader.makeNbmReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) as (any GenericReaderProtocol)?,
                try await GfsReader(domains: [.hrrr_conus, .hrrr_conus_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            ].compactMap({ $0 })
        case .ncep_hrrr_conus_15min:
            return try await GfsReader(domains: [.hrrr_conus_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_nam_conus:
            return try await GfsReader(domains: [.nam_conus], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gfs_graphcast025, .ncep_gfs_graphcast025:
//            return try await GfsGraphCastReader(domain: .graphcast025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
            return []
        case .ncep_aigfs025, .ncep_aigefs025_ensemble_mean:
            /// Use precipitation_probability from AIGEFS
//            return [
//                try await ProbabilityReader.makeAigefsReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) as (any GenericReaderProtocol)?,
//                try await GfsGraphCastReader(domain: .aigfs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//            ].compactMap({ $0 })
            return []
        case .ncep_aigefs025:
            return []
//            return try await GfsGraphCastReader(domain: .aigefs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_hgefs025_ensemble_mean:
            return []
//            return try await GfsGraphCastReader(domain: .hgefs025_ensemble_mean, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteofrance_mix, .meteofrance_seamless:
            return (try await MeteoFranceMixer(domains: [.arpege_world, .arpege_europe, .arome_france, .arome_france_hd, .arome_france_15min, .arome_france_hd_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []).compactMap({ $0 })
        case .meteofrance_arpege_seamless, .arpege_seamless:
            return (try await MeteoFranceMixer(domains: [.arpege_world, .arpege_europe], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []).compactMap({ $0 })
        case .meteofrance_arome_seamless, .arome_seamless:
            return try await MeteoFranceMixer(domains: [.arome_france, .arome_france_hd, .arome_france_15min, .arome_france_hd_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .meteofrance_arpege_world, .arpege_world, .meteofrance_arpege_world025:
            return try await MeteoFranceReader(domain: .arpege_world, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteofrance_arpege_europe, .arpege_europe:
            return (try await MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []).compactMap({ $0 })
        case .meteofrance_arome_france, .arome_france, .meteofrance_arome_france0025:
            // Note: AROME PI 15min is not used for consistency here
            return try await MeteoFranceMixer(domains: [.arome_france], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .meteofrance_arome_france_hd, .arome_france_hd:
            // Note: AROME PI 15min is not used for consistency here
            return try await MeteoFranceMixer(domains: [.arome_france_hd], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .meteofrance_arome_france_15min:
            return try await MeteoFranceMixer(domains: [.arome_france_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .meteofrance_arome_france_hd_15min:
            return try await MeteoFranceMixer(domains: [.arome_france_hd_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .jma_mix, .jma_seamless:
            return try await JmaMixer(domains: [.gsm, .msm_upper_level, .msm], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .jma_msm:
            return [
                try await JmaReader(domain: .msm_upper_level, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options),
                try await JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            ].compactMap({ $0 })
        case .jms_gsm, .jma_gsm:
            return try await JmaReader(domain: .gsm, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .icon_seamless, .icon_mix, .dwd_icon_seamless:
            let iconProbabilities = try await ProbabilityReader.makeIconReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [iconProbabilities] + (try await IconMixer(domains: [.icon, .iconEu, .iconD2, .iconD2_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? [])
        case .icon_global, .dwd_icon_global, .dwd_icon:
            let iconProbabilities = try await ProbabilityReader.makeIconGlobalReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [iconProbabilities] + (try await IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .icon_eu, .dwd_icon_eu:
            let iconProbabilities = try await ProbabilityReader.makeIconEuReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (iconProbabilities.flatMap({ [$0] }) ?? []) + (try await IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .icon_d2, .dwd_icon_d2:
            let iconProbabilities = try await ProbabilityReader.makeIconD2Reader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return (iconProbabilities.flatMap({ [$0] }) ?? []) + (try await IconMixer(domains: [.iconD2, .iconD2_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? [])
        case .dwd_icon_d2_15min:
            return (try await IconMixer(domains: [.iconD2_15min], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? [])
        case .ecmwf_ifs04:
            return try await EcmwfReader(domain: .ifs04, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_ifs025:
            let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities] + (try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .ecmwf_aifs025:
            return try await EcmwfReader(domain: .aifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_aifs025_single:
            return try await EcmwfReader(domain: .aifs025_single, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .metno_nordic:
            return try await MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gem_seamless:
            let probabilities = try await ProbabilityReader.makeGemReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities] + (try await GemMixer(domains: [.gem_global, .gem_regional, .gem_hrdps_continental], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? [])
        case .gem_global, .cmc_gem_gdps:
            let probabilities = try await ProbabilityReader.makeGemReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities] + (try await GemReader(domain: .gem_global, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .gem_regional, .cmc_gem_rdps:
            return try await GemReader(domain: .gem_regional, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gem_hrdps_continental, .cmc_gem_hrdps:
            return try await GemReader(domain: .gem_hrdps_continental, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gem_hrdps_west, .cmc_gem_hrdps_west:
            return try await GemReader(domain: .gem_hrdps_west, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .archive_best_match:
            return [try await Era5Factory.makeArchiveBestMatch(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .era5_seamless, .copernicus_era5_seamless:
            return [try await Era5Factory.makeEra5CombinedLand(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .era5, .copernicus_era5:
            // If explicitly selected ERA5, combine with ensemble to read spread variables
            return [try await Era5Factory.makeEra5WithEnsemble(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .era5_land, .copernicus_era5_land:
            return [try await Era5Factory.makeReader(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .cerra, .copernicus_cerra:
            return try await CerraReader(domain: .cerra, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_ifs:
            let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            //return [try await Era5Factory.makeReader(domain: .ecmwf_ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
            let ifsHres: (any GenericReaderProtocol)? = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, ifsHres].compactMap({ $0 })
        case .ecmwf_wam:
            let wam: (any GenericReaderProtocol)? = try await GenericReader<EcmwfEcpdsDomain, EcmwfEcdpsWamVariable>(domain: .wam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [wam].compactMap({ $0 })
        case .cma_grapes_global:
            return try await CmaReader(domain: .grapes_global, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .bom_access_global:
            let probabilities = try await ProbabilityReader.makeBomReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities] + (try await BomReader(domain: .access_global, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? [])
        case .arpae_cosmo_seamless, .arpae_cosmo_2i, .arpae_cosmo_2i_ruc, .arpae_cosmo_5m:
            throw ForecastApiError.generic(message: "ARPAE COSMO models are not available anymore")
        case .knmi_harmonie_arome_europe:
            return try await KnmiReader(domain: KnmiDomain.harmonie_arome_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .knmi_harmonie_arome_netherlands:
            return try await KnmiReader(domain: KnmiDomain.harmonie_arome_netherlands, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .dmi_harmonie_arome_europe:
            return try await DmiReader(domain: DmiDomain.harmonie_arome_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .knmi_seamless:
            let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let knmiNetherlands: (any GenericReaderProtocol)? = try await KnmiReader(domain: KnmiDomain.harmonie_arome_netherlands, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let knmiEurope = try await KnmiReader(domain: KnmiDomain.harmonie_arome_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, ecmwf, ifsHres, knmiEurope, knmiNetherlands].compactMap({ $0 })
        case .dmi_seamless:
            let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let dmiEurope: (any GenericReaderProtocol)? = try await DmiReader(domain: DmiDomain.harmonie_arome_europe, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, ecmwf, ifsHres, dmiEurope].compactMap({ $0 })
        case .metno_seamless:
            let probabilities = try await ProbabilityReader.makeEcmwfReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let metno: (any GenericReaderProtocol)? = try await MetNoReader(domain: .nordic_pp, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ecmwf = try await EcmwfReader(domain: .ifs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ifsHres = try await EcmwfEcpdsReader(domain: .ifs, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, ecmwf, ifsHres, metno].compactMap({ $0 })
        case .ecmwf_ifs_analysis_long_window:
            return [try await Era5Factory.makeReader(domain: .ecmwf_ifs_analysis_long_window, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .ecmwf_ifs_analysis:
            return [try await Era5Factory.makeReader(domain: .ecmwf_ifs_analysis, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .ecmwf_ifs_long_window:
            return [try await Era5Factory.makeReader(domain: .ecmwf_ifs_long_window, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .era5_ensemble, .copernicus_era5_ensemble:
            return [try await Era5Factory.makeReader(domain: .era5_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
        case .ukmo_seamless:
            let ukmoGlobal: (any GenericReaderProtocol)? = try await UkmoReader(domain: UkmoDomain.global_deterministic_10km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ukmoUk = try await UkmoReader(domain: UkmoDomain.uk_deterministic_2km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [ukmoGlobal, ukmoUk].compactMap({ $0 })
        case .ukmo_global_deterministic_10km:
            let ukmoGlobal: (any GenericReaderProtocol)? = try await UkmoReader(domain: UkmoDomain.global_deterministic_10km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [ukmoGlobal].compactMap({ $0 })
        case .ukmo_uk_deterministic_2km:
            let ukmoUk = try await UkmoReader(domain: UkmoDomain.uk_deterministic_2km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [ukmoUk].compactMap({ $0 })
        case .ncep_nbm_conus:
            return try await NbmReader(domains: [.nbm_conus], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .eumetsat_sarah3:
            return [] // migrated to upper level
        case .jma_jaxa_himawari:
            return [] // migrated to upper level
        case .jma_jaxa_mtg_fci:
            return [] // migrated to upper level
        case .eumetsat_lsa_saf_msg:
            return [] // migrated to upper level
        case .eumetsat_lsa_saf_iodc:
            return [] // migrated to upper level
        case .satellite_radiation_seamless:
            return [] // migrated to upper level
        case .kma_seamless:
            let ldps = try await KmaReader(domain: .ldps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let gdps = try await KmaReader(domain: .gdps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [gdps, ldps].compactMap({ $0 })
        case .kma_gdps:
            let reader = try await KmaReader(domain: .gdps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [reader].compactMap({ $0 })
        case .kma_ldps:
            let reader = try await KmaReader(domain: .ldps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [reader].compactMap({ $0 })
        case .italia_meteo_arpae_icon_2i:
            let reader = try await ItaliaMeteoArpaeReader(domain: .icon_2i, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [reader].compactMap({ $0 })
        case .meteoswiss_icon_ch1:
            let probabilities: (any GenericReaderProtocol)? = try await ProbabilityReader.makeMeteoSwissReader(domain: .icon_ch1_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let reader: (any GenericReaderProtocol)? = try await MeteoSwissReader(domain: .icon_ch1, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, reader].compactMap({ $0 })
        case .meteoswiss_icon_ch2:
            let probabilities: (any GenericReaderProtocol)? = try await ProbabilityReader.makeMeteoSwissReader(domain: .icon_ch2_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let reader: (any GenericReaderProtocol)? = try await MeteoSwissReader(domain: .icon_ch2, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilities, reader].compactMap({ $0 })
        case .meteoswiss_icon_seamless:
            let probabilitiesCh1: (any GenericReaderProtocol)? = try await ProbabilityReader.makeMeteoSwissReader(domain: .icon_ch1_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let probabilitiesCh2: (any GenericReaderProtocol)? = try await ProbabilityReader.makeMeteoSwissReader(domain: .icon_ch2_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ch1: (any GenericReaderProtocol)? = try await MeteoSwissReader(domain: .icon_ch1, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ch2: (any GenericReaderProtocol)? = try await MeteoSwissReader(domain: .icon_ch2, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            return [probabilitiesCh2, probabilitiesCh1, ch2, ch1].compactMap({ $0 })
        case .icon_seamless_eps:
            /// Note: ICON D2 EPS has been excluded, because it only provides 20 members and noticable different results compared to ICON EU EPS
            /// See: https://github.com/open-meteo/open-meteo/issues/876
            return try await IconMixer(domains: [.iconEps, .iconEuEps], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)?.reader ?? []
        case .icon_global_eps:
            return try await IconReader(domain: .iconEps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .icon_eu_eps:
            return try await IconReader(domain: .iconEuEps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .icon_d2_eps:
            return try await IconReader(domain: .iconD2Eps, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_ifs025_ensemble:
            return try await EcmwfReader(domain: .ifs025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_aifs025_ensemble:
            return try await EcmwfReader(domain: .aifs025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gefs025:
            return try await GfsReader(domains: [.gfs025_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gfs05, .ncep_gefs05:
            return try await GfsReader(domains: [.gfs05_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gefs_seamless:
            return try await GfsReader(domains: [.gfs05_ens, .gfs025_ens], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gem_global_ensemble:
            return try await GemReader(domain: .gem_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .bom_access_global_ensemble:
            return try await BomReader(domain: .access_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ukmo_global_ensemble_20km:
            return try await UkmoReader(domain: .global_ensemble_20km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ukmo_uk_ensemble_2km:
            return try await UkmoReader(domain: .uk_ensemble_2km, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteoswiss_icon_ch1_ensemble:
            return try await MeteoSwissReader(domain: .icon_ch1_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteoswiss_icon_ch2_ensemble:
            return try await MeteoSwissReader(domain: .icon_ch2_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_seasonal_seamless:
            return []
        case .ecmwf_seas5:
            return []
        case .ecmwf_ec46:
            return []
        case .ecmwf_seasonal_ensemble_mean_seamless:
            return []
        case .ecmwf_seas5_ensemble_mean:
            return []
        case .ecmwf_ec46_ensemble_mean:
            return []
        case .marine_best_match:
            // let gwam = try IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let ewam = try await IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfcurrents = try await GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }
            let mfsst = try await GenericReader<MfWaveDomain, MfSSTVariable>(domain: .mfsst, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfwave = try await GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfWaveReader(reader: reader)
            }
            let waveModel: [(any GenericReaderProtocol)?]
            if let update = try await MfWaveDomain.mfwave.getMetaJson(client: options.httpClient, logger: options.logger)?.lastRunAvailabilityTime, update <= Timestamp.now().subtract(hours: 26) {
                // mf model outdated, use ECMWF
                waveModel = [mfwave, try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)]
            } else {
                // use mf wave
                waveModel = [mfwave]
            }
            let readers: [(any GenericReaderProtocol)?] = [mfcurrents, mfsst, ewam] + waveModel
            return readers.compactMap({ $0 })
            /*
            let ecmwfWam025 = try GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let readers: [(any GenericReaderProtocol)?] = [ewam, ecmwfWam025, gwam]
            return readers.compactMap({$0})*/
        case .ewam:
            return try await IconWaveReader(domain: .ewam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .gwam:
            return try await IconWaveReader(domain: .gwam, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .era5_ocean:
            return try await GenericReader<CdsDomain, Era5Variable>(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_wam025:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ecmwf_wam025_ensemble:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: EcmwfDomain.wam025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .meteofrance_wave:
            return try await GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [MfWaveReader(reader: $0)] }) ?? []
        case .meteofrance_currents:
            let mfsst = try await GenericReader<MfWaveDomain, MfSSTVariable>(domain: .mfsst, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            let mfcurrents = try await GenericReader<MfWaveDomain, MfCurrentReader.Variable>(domain: .mfcurrents, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).map { reader -> any GenericReaderProtocol in
                MfCurrentReader(reader: GenericReaderCached<MfWaveDomain, MfCurrentReader.Variable>(reader: reader))
            }
            return [mfsst, mfcurrents].compactMap({ $0 })
        case .ncep_gfswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gefswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025_ens, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .ncep_gfswave016:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave016, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options).flatMap({ [$0] }) ?? []
        case .air_quality_best_match:
            guard let reader = try await CamsMixer(domains: [.cams_global, .cams_global_greenhouse_gases, .cams_europe, .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated, .cams_europe_reanalysis_validated_pre2020, .cams_europe_reanalysis_validated_pre2018], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return []
            }
            return [reader]
        case .cams_global:
            guard let reader = try await CamsMixer(domains: [.cams_global, .cams_global_greenhouse_gases], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return []
            }
            return [reader]
        case .cams_europe:
            guard let reader = try await CamsMixer(domains: [.cams_europe, .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated, .cams_europe_reanalysis_validated_pre2020, .cams_europe_reanalysis_validated_pre2018], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return []
            }
            return [reader]
        case .CMCC_CM2_VHR4, .FGOALS_f3_H, .HiRAM_SIT_HR, .MRI_AGCM3_2_S, .EC_Earth3P_HR, .MPI_ESM1_2_XR, .NICAM16_8S:
            return []
        case .flood_best_match, .seamless_v3, .forecast_v3, .consolidated_v3, .seamless_v4, .forecast_v4, .consolidated_v4:
            return []
        case .dwd_sis_europe_africa_v4:
            return []
        }
    }

    var genericDomain: (any GenericDomain)? {
        if let d = getDomainAndVariable() {
            return d.0
        }
        
        switch self {
        case .gfs025, .ncep_gfs025:
            return GfsDomain.gfs025
        case .gfs013, .ncep_gfs013:
            return GfsDomain.gfs013
        case .gfs_hrrr, .ncep_hrrr_conus:
            return GfsDomain.hrrr_conus
        case .ncep_hrrr_conus_15min:
            return GfsDomain.hrrr_conus_15min
        case .ncep_nam_conus:
            return GfsDomain.nam_conus
        case .gfs_graphcast025, .ncep_gfs_graphcast025:
            return GfsGraphCastDomain.graphcast025
        case .ncep_aigfs025:
            return GfsGraphCastDomain.aigfs025
        case .ncep_aigefs025_ensemble_mean:
            return GfsGraphCastDomain.aigefs025_ensemble_mean
        case .ncep_aigefs025:
            return GfsGraphCastDomain.aigefs025
        case .ncep_hgefs025_ensemble_mean:
            return GfsGraphCastDomain.hgefs025_ensemble_mean
        case .meteofrance_arpege_world, .arpege_world, .meteofrance_arpege_world025:
            return MeteoFranceDomain.arpege_world
        case .meteofrance_arpege_europe, .arpege_europe:
            return MeteoFranceDomain.arpege_europe
        case .meteofrance_arome_france, .arome_france, .meteofrance_arome_france0025:
            return MeteoFranceDomain.arome_france
        case .meteofrance_arome_france_hd, .arome_france_hd:
            return MeteoFranceDomain.arome_france_hd
        case .icon_global, .dwd_icon_global, .dwd_icon:
            return IconDomains.icon
        case .icon_eu, .dwd_icon_eu:
            return IconDomains.iconEu
        case .icon_d2, .dwd_icon_d2:
            return IconDomains.iconD2
        case .dwd_icon_d2_15min:
            return IconDomains.iconD2_15min
        case .ecmwf_ifs04:
            return EcmwfDomain.ifs04
        case .ecmwf_ifs025:
            return EcmwfDomain.ifs025
        case .ecmwf_aifs025:
            return EcmwfDomain.aifs025
        case .metno_nordic:
            return MetNoDomain.nordic_pp
        case .gem_global, .cmc_gem_gdps:
            return GemDomain.gem_global
        case .gem_regional, .cmc_gem_rdps:
            return GemDomain.gem_regional
        case .gem_hrdps_continental, .cmc_gem_hrdps:
            return GemDomain.gem_hrdps_continental
        case .gem_hrdps_west, .cmc_gem_hrdps_west:
            return GemDomain.gem_hrdps_west
        case .era5, .copernicus_era5:
            return CdsDomain.era5
        case .era5_land, .copernicus_era5_land:
            return CdsDomain.era5_land
        case .cerra, .copernicus_cerra:
            return CdsDomain.cerra
        case .ecmwf_ifs:
            return EcmwfEcpdsDomain.ifs
        case .ecmwf_wam:
            return EcmwfEcpdsDomain.wam
        case .cma_grapes_global:
            return CmaDomain.grapes_global
        case .bom_access_global:
            return BomDomain.access_global
        case .best_match:
            return nil
        case .gfs_seamless, .gfs_mix, .ncep_seamless:
            return nil
        case .gfs_global, .ncep_gfs_global:
            return nil
        case .ncep_nbm_conus:
            return NbmDomain.nbm_conus
        case .meteofrance_seamless:
            return nil
        case .meteofrance_mix:
            return nil
        case .meteofrance_arpege_seamless:
            return nil
        case .meteofrance_arome_seamless:
            return nil
        case .meteofrance_arome_france_hd_15min:
            return MeteoFranceDomain.arome_france_hd_15min
        case .meteofrance_arome_france_15min:
            return MeteoFranceDomain.arome_france_15min
        case .arpege_seamless:
            return nil
        case .arome_seamless:
            return nil
        case .jma_seamless:
            return nil
        case .jma_mix:
            return nil
        case .jma_msm:
            return JmaDomain.msm
        case .jms_gsm, .jma_gsm:
            return JmaDomain.gsm
        case .gem_seamless:
            return nil
        case .icon_seamless, .icon_mix, .dwd_icon_seamless:
            return nil
        case .ecmwf_aifs025_single:
            return EcmwfDomain.aifs025_single
        case .archive_best_match:
            return nil
        case .era5_seamless, .copernicus_era5_seamless:
            return CdsDomain.era5_land
        case .era5_ensemble, .copernicus_era5_ensemble:
            return CdsDomain.era5_ensemble
        case .ecmwf_ifs_analysis:
            return CdsDomain.ecmwf_ifs_analysis
        case .ecmwf_ifs_analysis_long_window:
            return CdsDomain.ecmwf_ifs_analysis_long_window
        case .ecmwf_ifs_long_window:
            return CdsDomain.ecmwf_ifs_long_window
        case .arpae_cosmo_seamless:
            return nil
        case .arpae_cosmo_2i:
            return nil
        case .arpae_cosmo_2i_ruc:
            return nil
        case .arpae_cosmo_5m:
            return nil
        case .knmi_harmonie_arome_europe:
            return KnmiDomain.harmonie_arome_europe
        case .knmi_harmonie_arome_netherlands:
            return KnmiDomain.harmonie_arome_netherlands
        case .dmi_harmonie_arome_europe:
            return DmiDomain.harmonie_arome_europe
        case .knmi_seamless:
            return nil
        case .dmi_seamless:
            return nil
        case .metno_seamless:
            return nil
        case .ukmo_seamless:
            return nil
        case .ukmo_global_deterministic_10km:
            return UkmoDomain.global_deterministic_10km
        case .ukmo_uk_deterministic_2km:
            return UkmoDomain.uk_deterministic_2km
        case .satellite_radiation_seamless:
            return nil
        case .eumetsat_sarah3:
            return nil
        case .eumetsat_lsa_saf_msg:
            return nil
        case .eumetsat_lsa_saf_iodc:
            return nil
        case .jma_jaxa_himawari:
            return nil
        case .jma_jaxa_mtg_fci:
            return nil
        case .kma_seamless:
            return nil
        case .kma_gdps:
            return KmaDomain.gdps
        case .kma_ldps:
            return KmaDomain.ldps
        case .italia_meteo_arpae_icon_2i:
            return ItaliaMeteoArpaeDomain.icon_2i
        case .meteoswiss_icon_ch1:
            return MeteoSwissDomain.icon_ch1
        case .meteoswiss_icon_ch2:
            return MeteoSwissDomain.icon_ch2
        case .meteoswiss_icon_seamless:
            return nil
        case .gfs05:
            return nil
        case .icon_seamless_eps:
            return nil
        case .icon_global_eps:
            return nil
        case .icon_eu_eps:
            return nil
        case .icon_d2_eps:
            return nil
        case .ecmwf_ifs025_ensemble:
            return nil
        case .ecmwf_aifs025_ensemble:
            return nil
        case .gem_global_ensemble:
            return nil
        case .bom_access_global_ensemble:
            return nil
        case .ncep_gefs_seamless:
            return nil
        case .ncep_gefs025:
            return nil
        case .ncep_gefs05:
            return nil
        case .ukmo_global_ensemble_20km:
            return nil
        case .ukmo_uk_ensemble_2km:
            return nil
        case .meteoswiss_icon_ch1_ensemble:
            return nil
        case .meteoswiss_icon_ch2_ensemble:
            return nil
        case .ecmwf_seasonal_seamless:
            return nil
        case .ecmwf_seas5:
            return nil
        case .ecmwf_ec46:
            return nil
        case .ecmwf_seasonal_ensemble_mean_seamless:
            return nil
        case .ecmwf_seas5_ensemble_mean:
            return nil
        case .ecmwf_ec46_ensemble_mean:
            return nil
        case .marine_best_match:
            return nil
        case .ewam:
            return IconWaveDomain.ewam
        case .gwam:
            return IconWaveDomain.gwam
        case .era5_ocean:
            return CdsDomain.era5_ocean
        case .ecmwf_wam025:
            return EcmwfDomain.wam025
        case .ecmwf_wam025_ensemble:
            return EcmwfDomain.wam025_ensemble
        case .ncep_gfswave025:
            return GfsDomain.gfswave025
        case .ncep_gfswave016:
            return GfsDomain.gfswave016
        case .ncep_gefswave025:
            return GfsDomain.gfswave025_ens
        case .meteofrance_wave:
            return MfWaveDomain.mfwave
        case .meteofrance_currents:
            return MfWaveDomain.mfcurrents
        case .air_quality_best_match:
            return nil
        case .cams_global:
            return CamsDomain.cams_global
        case .cams_europe:
            return CamsDomain.cams_europe
        case .CMCC_CM2_VHR4, .FGOALS_f3_H, .HiRAM_SIT_HR, .MRI_AGCM3_2_S, .EC_Earth3P_HR, .MPI_ESM1_2_XR, .NICAM16_8S:
            return nil
        case .flood_best_match, .seamless_v3, .forecast_v3, .consolidated_v3, .seamless_v4, .forecast_v4, .consolidated_v4:
            return nil
        case .dwd_sis_europe_africa_v4:
            return nil
        }
    }

    func getReader(gridpoint: Int, options: GenericReaderOptions) async throws -> (any GenericReaderProtocol)? {
        switch self {
        case .gfs025, .ncep_gfs025:
            return try await GfsReader(domain: .gfs025, gridpoint: gridpoint, options: options)
        case .gfs013, .ncep_gfs013:
            return try await GfsReader(domain: .gfs013, gridpoint: gridpoint, options: options)
        case .gfs_hrrr, .ncep_hrrr_conus:
            return try await GfsReader(domain: .hrrr_conus, gridpoint: gridpoint, options: options)
        case .ncep_hrrr_conus_15min:
            return try await GfsReader(domain: .hrrr_conus_15min, gridpoint: gridpoint, options: options)
        case .ncep_nam_conus:
            return try await GfsReader(domain: .nam_conus, gridpoint: gridpoint, options: options)
        case .gfs_graphcast025, .ncep_gfs_graphcast025:
            return nil // defined in the upper function
        case .ncep_aigfs025:
            return nil // defined in the upper function
        case .ncep_aigefs025:
            return nil // defined in the upper function
        case .ncep_aigefs025_ensemble_mean:
            return nil // defined in the upper function
        case .ncep_hgefs025_ensemble_mean:
            return nil // defined in the upper function
        case .meteofrance_arpege_world, .arpege_world, .meteofrance_arpege_world025:
            return try await MeteoFranceReader(domain: .arpege_world, gridpoint: gridpoint, options: options)
        case .meteofrance_arpege_europe, .arpege_europe, .meteofrance_arome_france0025:
            return try await MeteoFranceReader(domain: .arpege_europe, gridpoint: gridpoint, options: options)
        case .meteofrance_arome_france, .arome_france:
            return try await MeteoFranceReader(domain: .arome_france, gridpoint: gridpoint, options: options)
        case .meteofrance_arome_france_hd, .arome_france_hd:
            return try await MeteoFranceReader(domain: .arome_france_hd, gridpoint: gridpoint, options: options)
        case .meteofrance_seamless:
            return nil
        case .meteofrance_mix:
            return nil
        case .meteofrance_arpege_seamless:
            return nil
        case .meteofrance_arome_seamless:
            return nil
        case .meteofrance_arome_france_hd_15min:
            return try await MeteoFranceReader(domain: .arome_france_hd_15min, gridpoint: gridpoint, options: options)
        case .meteofrance_arome_france_15min:
            return try await MeteoFranceReader(domain: .arome_france_15min, gridpoint: gridpoint, options: options)
        case .arpege_seamless:
            return nil
        case .arome_seamless:
            return nil
        case .icon_global, .dwd_icon_global, .dwd_icon:
            return try await IconReader(domain: .icon, gridpoint: gridpoint, options: options)
        case .icon_eu, .dwd_icon_eu:
            return try await IconReader(domain: .iconEu, gridpoint: gridpoint, options: options)
        case .icon_d2, .dwd_icon_d2:
            return try await IconReader(domain: .iconD2, gridpoint: gridpoint, options: options)
        case .dwd_icon_d2_15min:
            return try await IconReader(domain: .iconD2_15min, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs04:
            return try await EcmwfReader(domain: .ifs04, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs025:
            return try await EcmwfReader(domain: .ifs025, gridpoint: gridpoint, options: options)
        case .ecmwf_aifs025:
            return try await EcmwfReader(domain: .aifs025, gridpoint: gridpoint, options: options)
        case .metno_nordic:
            return try await MetNoReader(domain: .nordic_pp, gridpoint: gridpoint, options: options)
        case .gem_global, .cmc_gem_gdps:
            return try await GemReader(domain: .gem_global, gridpoint: gridpoint, options: options)
        case .gem_regional, .cmc_gem_rdps:
            return try await GemReader(domain: .gem_regional, gridpoint: gridpoint, options: options)
        case .gem_hrdps_continental, .cmc_gem_hrdps:
            return try await GemReader(domain: .gem_hrdps_continental, gridpoint: gridpoint, options: options)
        case .gem_hrdps_west, .cmc_gem_hrdps_west:
            return try await GemReader(domain: .gem_hrdps_west, gridpoint: gridpoint, options: options)
        case .era5, .copernicus_era5:
            return try await Era5Factory.makeReader(domain: .era5, gridpoint: gridpoint, options: options)
        case .era5_land, .copernicus_era5_land:
            return try await Era5Factory.makeReader(domain: .era5_land, gridpoint: gridpoint, options: options)
        case .cerra, .copernicus_cerra:
            return try await CerraReader(domain: .cerra, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs:
            return try await Era5Factory.makeReader(domain: .ecmwf_ifs, gridpoint: gridpoint, options: options)
        case .ecmwf_wam:
            return try await GenericReader<EcmwfEcpdsDomain, EcmwfEcdpsWamVariable>(domain: .wam, position: gridpoint, options: options)
        case .cma_grapes_global:
            return try await CmaReader(domain: .grapes_global, gridpoint: gridpoint, options: options)
        case .bom_access_global:
            return try await BomReader(domain: .access_global, gridpoint: gridpoint, options: options)
        case .arpae_cosmo_2i, .arpae_cosmo_2i_ruc, .arpae_cosmo_5m, .arpae_cosmo_seamless:
            throw ForecastApiError.generic(message: "ARPAE COSMO models are not available anymore")
        case .best_match:
            return nil
        case .gfs_seamless, .ncep_seamless, .gfs_mix:
            return nil
        case .gfs_global, .ncep_gfs_global:
            return nil
        case .ncep_nbm_conus:
            return try await NbmReader(domain: .nbm_conus, gridpoint: gridpoint, options: options)
        case .jma_seamless, .jma_mix:
            return nil
        case .jma_msm:
            return try await JmaReader(domain: .msm, gridpoint: gridpoint, options: options)
        case .jms_gsm, .jma_gsm:
            return try await JmaReader(domain: .gsm, gridpoint: gridpoint, options: options)
        case .gem_seamless:
            return nil
        case .icon_seamless, .icon_mix, .dwd_icon_seamless:
            return nil
        case .ecmwf_aifs025_single:
            return try await EcmwfReader(domain: .aifs025_single, gridpoint: gridpoint, options: options)
        case .archive_best_match:
            return nil
        case .era5_seamless, .copernicus_era5_seamless:
            let era5land = try await GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, position: gridpoint, options: options)
            guard
                let era5 = try await GenericReader<CdsDomain, Era5Variable>(domain: .era5, lat: era5land.modelLat, lon: era5land.modelLon, elevation: era5land.targetElevation, mode: .nearest, options: options)
            else {
                // Not possible
                throw ForecastApiError.noDataAvailableForThisLocation
            }
            return Era5Reader<GenericReaderMixerSameDomain<GenericReaderCached<CdsDomain, Era5Variable>>>(reader: GenericReaderMixerSameDomain(reader: [GenericReaderCached(reader: era5), GenericReaderCached(reader: era5land)]), options: options)
        case .era5_ensemble, .copernicus_era5_ensemble:
            return try await Era5Factory.makeReader(domain: .era5_ensemble, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs_analysis:
            return try await Era5Factory.makeReader(domain: .ecmwf_ifs_analysis, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs_analysis_long_window:
            return try await Era5Factory.makeReader(domain: .ecmwf_ifs_analysis_long_window, gridpoint: gridpoint, options: options)
        case .ecmwf_ifs_long_window:
            return try await Era5Factory.makeReader(domain: .ecmwf_ifs_long_window, gridpoint: gridpoint, options: options)
        case .knmi_harmonie_arome_europe:
            return try await KnmiReader(domain: .harmonie_arome_europe, gridpoint: gridpoint, options: options)
        case .knmi_harmonie_arome_netherlands:
            return try await KnmiReader(domain: .harmonie_arome_netherlands, gridpoint: gridpoint, options: options)
        case .dmi_harmonie_arome_europe:
            return try await DmiReader(domain: .harmonie_arome_europe, gridpoint: gridpoint, options: options)
        case .knmi_seamless:
            return nil
        case .dmi_seamless:
            return nil
        case .metno_seamless:
            return nil
        case .ukmo_seamless:
            return nil
        case .ukmo_global_deterministic_10km:
            return try await UkmoReader(domain: .global_deterministic_10km, gridpoint: gridpoint, options: options)
        case .ukmo_uk_deterministic_2km:
            return try await UkmoReader(domain: .uk_deterministic_2km, gridpoint: gridpoint, options: options)
        case .satellite_radiation_seamless:
            return nil
        case .eumetsat_sarah3:
            return nil
        case .eumetsat_lsa_saf_msg:
            return nil
        case .eumetsat_lsa_saf_iodc:
            return nil
        case .jma_jaxa_himawari:
            return nil
        case .jma_jaxa_mtg_fci:
            return nil
        case .kma_seamless:
            return nil
        case .kma_gdps:
            return try await KmaReader(domain: .gdps, gridpoint: gridpoint, options: options)
        case .kma_ldps:
            return try await KmaReader(domain: .ldps, gridpoint: gridpoint, options: options)
        case .italia_meteo_arpae_icon_2i:
            return try await ItaliaMeteoArpaeReader(domain: .icon_2i, gridpoint: gridpoint, options: options)
        case .meteoswiss_icon_ch1:
            return try await MeteoSwissReader(domain: .icon_ch1, gridpoint: gridpoint, options: options)
        case .meteoswiss_icon_ch2:
            return try await MeteoSwissReader(domain: .icon_ch2, gridpoint: gridpoint, options: options)
        case .meteoswiss_icon_seamless:
            return nil
        case .gfs05:
            return nil
        case .icon_seamless_eps:
            return nil
        case .icon_global_eps:
            return nil
        case .icon_eu_eps:
            return nil
        case .icon_d2_eps:
            return nil
        case .ecmwf_ifs025_ensemble:
            return nil
        case .ecmwf_aifs025_ensemble:
            return nil
        case .gem_global_ensemble:
            return nil
        case .bom_access_global_ensemble:
            return nil
        case .ncep_gefs_seamless:
            return nil
        case .ncep_gefs025:
            return nil
        case .ncep_gefs05:
            return nil
        case .ukmo_global_ensemble_20km:
            return nil
        case .ukmo_uk_ensemble_2km:
            return nil
        case .meteoswiss_icon_ch1_ensemble:
            return nil
        case .meteoswiss_icon_ch2_ensemble:
            return nil
        case .ecmwf_seasonal_seamless:
            return nil
        case .ecmwf_seas5:
            return nil
        case .ecmwf_ec46:
            return nil
        case .ecmwf_seasonal_ensemble_mean_seamless:
            return nil
        case .ecmwf_seas5_ensemble_mean:
            return nil
        case .ecmwf_ec46_ensemble_mean:
            return nil
        case .marine_best_match:
            return nil
        case .ewam:
            return try await GenericReader<IconWaveDomain, IconWaveVariable>(domain: .ewam, position: gridpoint, options: options)
        case .gwam:
            return try await GenericReader<IconWaveDomain, IconWaveVariable>(domain: .gwam, position: gridpoint, options: options)
        case .era5_ocean:
            return try await GenericReader<CdsDomain, Era5Variable>(domain: .era5_ocean, position: gridpoint, options: options)
        case .ecmwf_wam025:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: .wam025, position: gridpoint, options: options)
        case .ecmwf_wam025_ensemble:
            return try await GenericReader<EcmwfDomain, EcmwfWaveVariable>(domain: .wam025_ensemble, position: gridpoint, options: options)
        case .ncep_gfswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025, position: gridpoint, options: options)
        case .ncep_gfswave016:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave016, position: gridpoint, options: options)
        case .ncep_gefswave025:
            return try await GenericReader<GfsDomain, GfsWaveVariable>(domain: .gfswave025_ens, position: gridpoint, options: options)
        case .meteofrance_wave:
            return try await GenericReader<MfWaveDomain, MfWaveVariable>(domain: .mfwave, position: gridpoint, options: options)
        case .meteofrance_currents:
            return nil // defined in the upper function
        case .air_quality_best_match:
            return nil
        case .cams_global:
            let reader = try await GenericReader<CamsDomain, CamsVariable>(domain: .cams_global, position: gridpoint, options: options)
            return CamsReader(reader: GenericReaderCached(reader: reader))
        case .cams_europe:
            let reader = try await GenericReader<CamsDomain, CamsVariable>(domain: .cams_europe, position: gridpoint, options: options)
            return CamsReader(reader: GenericReaderCached(reader: reader))
        case .CMCC_CM2_VHR4, .FGOALS_f3_H, .HiRAM_SIT_HR, .MRI_AGCM3_2_S, .EC_Earth3P_HR, .MPI_ESM1_2_XR, .NICAM16_8S:
            return nil
        case .flood_best_match, .seamless_v3, .forecast_v3, .consolidated_v3, .seamless_v4, .forecast_v4, .consolidated_v4:
            return nil
        case .dwd_sis_europe_africa_v4:
            return nil
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .icon_seamless_eps:
            return IconDomains.iconEps.countEnsembleMember
        case .icon_global_eps:
            return IconDomains.iconEps.countEnsembleMember
        case .icon_eu_eps:
            return IconDomains.iconEuEps.countEnsembleMember
        case .icon_d2_eps:
            return IconDomains.iconD2Eps.countEnsembleMember
        case .ecmwf_ifs025_ensemble:
            return EcmwfDomain.ifs025_ensemble.countEnsembleMember
        case .ecmwf_aifs025_ensemble:
            return EcmwfDomain.aifs025_ensemble.countEnsembleMember
        case .ncep_gefs025:
            return GfsDomain.gfs025_ens.countEnsembleMember
        case .ncep_gefs05:
            return GfsDomain.gfs05_ens.countEnsembleMember
        case .ncep_gefs_seamless:
            return GfsDomain.gfs05_ens.countEnsembleMember
        case .gem_global_ensemble:
            return GemDomain.gem_global_ensemble.countEnsembleMember
        case .bom_access_global_ensemble:
            return BomDomain.access_global_ensemble.countEnsembleMember
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



