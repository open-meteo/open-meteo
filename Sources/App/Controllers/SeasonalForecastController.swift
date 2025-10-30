import Vapor
import OpenMeteoSdk

enum SeasonalForecastControllerDomains: String, Codable, CaseIterable, MultiDomainMixerDomainSameType, GenericDomainProvider {
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> (hourly: [any GenericReaderOptionalProtocol<SeasonalVariableHourly>], daily: [any GenericReaderOptionalProtocol<SeasonalVariableDaily>], weekly: [any GenericReaderOptionalProtocol<SeasonalVariableWeekly>], monthly: [any GenericReaderOptionalProtocol<SeasonalVariableMonthly>]) {
        switch self {
        case .ecmwf_seasonal_seamless:
            let seas5daily = try await SeasonalForecastDeriverDaily<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(domain: .seas5_daily, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let seas6hourly = try await SeasonalForecastDeriverHourly(reader: GenericReaderCached(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableSingleLevel>(domain: .seas5, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let seas6hourlyToDaily = DailyReaderConverter<SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableSingleLevel>>, SeasonalVariableDaily>(reader: seas6hourly)
            let seas6monthly = try await SeasonalForecastDeriverMonthly(reader: GenericReaderCached(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableMonthly>(domain: .seas5_monthly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            let ec46hourly = try await SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>(reader: GenericReader<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>(domain: .ec46, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let ec46hourlyToDaily = DailyReaderConverter<SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>>, SeasonalVariableDaily>(reader: ec46hourly)
            
            let ec46weekly = try await SeasonalForecastDeriverWeekly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46VariableWeekly>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfEC46VariableWeekly>(reader: GenericReader<EcmwfSeasDomain, EcmwfEC46VariableWeekly>(domain: .ec46_weekly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            return ([seas6hourly, ec46hourly], [seas6hourlyToDaily, seas5daily, ec46hourlyToDaily], [ec46weekly], [seas6monthly])
        case .ecmwf_seas5:
            let seas5daily = try await SeasonalForecastDeriverDaily<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableDailySingleLevel>(domain: .seas5_daily, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let seas6hourly = try await SeasonalForecastDeriverHourly(reader: GenericReaderCached(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableSingleLevel>(domain: .seas5, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            let seas6hourlyToDaily = DailyReaderConverter<SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableSingleLevel>>, SeasonalVariableDaily>(reader: seas6hourly)
            let seas6monthly = try await SeasonalForecastDeriverMonthly(reader: GenericReaderCached(reader: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableMonthly>(domain: .seas5_monthly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            return ([seas6hourly], [seas6hourlyToDaily, seas5daily], [], [seas6monthly])
        case .ecmwf_ec46:
            let ec46hourly = try await SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>(reader: GenericReader<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>(domain: .ec46, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            let ec46hourlyToDaily = DailyReaderConverter<SeasonalForecastDeriverHourly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46Variable6Hourly>>, SeasonalVariableDaily>(reader: ec46hourly)
            
            let ec46weekly = try await SeasonalForecastDeriverWeekly<GenericReaderCached<EcmwfSeasDomain, EcmwfEC46VariableWeekly>>(reader: GenericReaderCached<EcmwfSeasDomain, EcmwfEC46VariableWeekly>(reader: GenericReader<EcmwfSeasDomain, EcmwfEC46VariableWeekly>(domain: .ec46_weekly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)!), options: options)
            
            return ([ec46hourly], [ec46hourlyToDaily], [ec46weekly], [])
        }
    }
    
    func getReader(gridpoint: Int, options: GenericReaderOptions) async throws -> (hourly: [any GenericReaderOptionalProtocol<SeasonalVariableHourly>], daily: [any GenericReaderOptionalProtocol<SeasonalVariableDaily>], weekly: [any GenericReaderOptionalProtocol<SeasonalVariableWeekly>], monthly: [any GenericReaderOptionalProtocol<SeasonalVariableMonthly>])? {
        fatalError()
    }
    
    typealias VariableHourly = SeasonalVariableHourly
    
    typealias VariableDaily = SeasonalVariableDaily
    
    typealias VariableWeekly = SeasonalVariableWeekly
    
    typealias VariableMonthly = SeasonalVariableMonthly
    
    var countEnsembleMember: Int {
        return 51
    }
    
    var genericDomain: (any GenericDomain)? {
        return nil
    }
    
    var flatBufferModel: openmeteo_sdk_Model {
        return .ecmwfSeas5
    }
    
    case ecmwf_seasonal_seamless
    case ecmwf_seas5
    case ecmwf_ec46
}

struct SeasonalForecastController {
    func query(_ req: Request) async throws -> Response {
        try await req.withApiParameter("seasonal-api") { _, params in
            let currentTime = Timestamp.now()
            let allowedRange = Timestamp(2024, 1, 1) ..< currentTime.add(86400 * 400)
            let logger = req.logger
            let httpClient = req.application.http.client.shared

            let prepared = try await params.prepareCoordinates(allowTimezones: false, logger: logger, httpClient: httpClient)
            guard case .coordinates(let prepared) = prepared else {
                throw ForecastApiError.generic(message: "Bounding box not supported")
            }
            let domains = try SeasonalForecastControllerDomains.load(commaSeparatedOptional: params.models) ?? [.ecmwf_seasonal_seamless]
            let paramsSixHourly = try Seas5Reader.HourlyVariable.load(commaSeparatedOptional: params.six_hourly)
            let paramsHourly = try SeasonalVariableHourly.load(commaSeparatedOptional: params.hourly)
            let paramsDaily = try Seas5Reader.DailyVariable.load(commaSeparatedOptional: params.daily)
            let paramsWeekly = try Seas5Reader.WeeklyVariable.load(commaSeparatedOptional: params.weekly)
            let paramsMonthly = try Seas5Reader.MonthlyVariable.load(commaSeparatedOptional: params.monthly)
            let nMember = 51
            let nVariables6Hourly = ((paramsHourly?.count ?? 0) + (paramsSixHourly?.count ?? 0)) * nMember / 6
            let nVariablesDaily = (paramsDaily?.count ?? 0) * nMember / 24
            /// adjusted to 6hourly and 24h aggregations
            let nVariables = nVariables6Hourly + nVariablesDaily + (paramsMonthly?.count ?? 0)
            let options = try params.readerOptions(logger: logger, httpClient: httpClient)
            
            /*let runCurrent = (IsoDateTime(timeIntervalSince1970: try await EcmwfSeasDomain.seas5.getLatestFullRun(client: options.httpClient, logger: options.logger)?.timeIntervalSince1970 ?? Timestamp.now().subtract(days: 5).with(day: 1).timeIntervalSince1970))
            let run = IsoDateTime(year: 2025, month: 8, day: 1, hour:0, minute:0, second: 0) // params.run ?? runCurrent
            print(run.format_directoriesYYYYMMddhhmm)*/

            let locations: [ForecastapiResult<Seas5Reader>.PerLocation] = try await prepared.asyncMap { prepared in
                let coordinates = prepared.coordinate
                let timezone = prepared.timezone
                let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 183, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
                let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)

                let readers: [Seas5Reader] = try await domains.asyncCompactMap { domain -> Seas5Reader? in
                    let r = try await domain.getReader(lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options)
                    return Seas5Reader(domain: domain, readerHourly: GenericReaderMultiSameType(reader: r.hourly), readerDaily: GenericReaderMultiSameType(reader: r.daily), readerWeekly: GenericReaderMultiSameType(reader: r.weekly), readerMonthly: GenericReaderMultiSameType(reader: r.monthly), params: params, time: time, timezone: timezone, run: params.run)
                }
                guard !readers.isEmpty else {
                    throw ForecastApiError.noDataAvailableForThisLocation
                }
                return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
            }
            return ForecastapiResult<Seas5Reader>(timeformat: params.timeformatOrDefault, results: locations, currentVariables: nil, minutely15Variables: nil, hourlyVariables: paramsHourly, sixHourlyVariables: paramsSixHourly, dailyVariables: paramsDaily, weeklyVariables: paramsWeekly, monthlyVariables: paramsMonthly, nVariablesTimesDomains: nVariables)
        }
    }
}


struct Seas5Reader: ModelFlatbufferSerialisable {
    typealias MonthlyVariable = SeasonalVariableMonthly
    typealias WeeklyVariable = SeasonalVariableWeekly
    
    typealias HourlyVariable = SeasonalVariableHourly
    
    typealias DailyVariable = SeasonalVariableDaily
    
    var flatBufferModel: OpenMeteoSdk.openmeteo_sdk_Model {
        domain.flatBufferModel
    }
    
    var modelName: String {
        return domain.rawValue
    }
    
    let domain: SeasonalForecastControllerDomains
    let readerHourly: GenericReaderMultiSameType<SeasonalVariableHourly>
    let readerDaily: GenericReaderMultiSameType<SeasonalVariableDaily>
    let readerWeekly: GenericReaderMultiSameType<SeasonalVariableWeekly>
    let readerMonthly: GenericReaderMultiSameType<SeasonalVariableMonthly>
    
    var latitude: Float {
        readerHourly.modelLat
    }
    
    var longitude: Float {
        readerHourly.modelLon
    }
    
    var elevation: Float? {
        readerHourly.targetElevation
    }
    
    let params: ApiQueryParameter
    let time: ForecastApiTimeRange
    let timezone: TimezoneWithOffset
    let run: IsoDateTime?
    
    func prefetch(currentVariables: [HourlyVariable]?, minutely15Variables: [HourlyVariable]?, hourlyVariables: [HourlyVariable]?, sixHourlyVariables: [HourlyVariable]?, dailyVariables: [DailyVariable]?, weeklyVariables: [WeeklyVariable]?, monthlyVariables: [MonthlyVariable]?) async throws {
        let members = 0..<domain.countEnsembleMember
        if let sixHourlyVariables {
            let timeSixHourlyRead = time.dailyRead.with(dtSeconds: 3600 * 6)
            for variable in sixHourlyVariables {
                for member in members {
                    let _ = try await readerHourly.prefetchData(variable: variable, time: timeSixHourlyRead.toSettings(ensembleMemberLevel: member, run: run))
                }
            }
        }
        if let hourlyVariables {
            let hourlyDt = (params.temporal_resolution ?? .hourly_6).dtSeconds ?? readerHourly.modelDtSeconds
            let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
            for variable in hourlyVariables {
                for member in members {
                    let _ = try await readerHourly.prefetchData(variable: variable, time: timeHourlyRead.toSettings(ensembleMemberLevel: member, run: run))
                }
            }
        }
        if let dailyVariables {
            for variable in dailyVariables {
                for member in members {
                    let _ = try await readerDaily.prefetchData(variable: variable, time: time.dailyRead.toSettings(ensembleMemberLevel: member, run: run))
                }
            }
        }
        if let weeklyVariables {
            let timeWeekly = TimerangeDt(
                start: time.dailyRead.range.lowerBound.add(-4*24*3600).floor(toNearest: 7*24*3600).add(4*24*3600),
                to: time.dailyRead.range.upperBound.add(-4*24*3600).ceil(toNearest: 7*24*3600).add(4*24*3600),
                dtSeconds: 7*24*3600
            )
            for variable in weeklyVariables {
                let _ = try await readerWeekly.prefetchData(variable: variable, time: timeWeekly.toSettings())
            }
        }
        if let monthlyVariables {
            let yearMonths = time.dailyRead.toYearMonth()
            let timeMonthlyDisplay = TimerangeDt(start: yearMonths.lowerBound.timestamp, to: yearMonths.upperBound.timestamp, dtSeconds: .dtSecondsMonthly)
            let timeMonthlyRead = timeMonthlyDisplay
            for variable in monthlyVariables {
                let _ = try await readerMonthly.prefetchData(variable: variable, time: timeMonthlyRead.toSettings())
            }
        }
    }

    func current(variables: [HourlyVariable]?) async throws -> ApiSectionSingle<HourlyVariable>? {
        return nil
    }
    
    func hourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        guard let variables else {
            return nil
        }
        let hourlyDt = (params.temporal_resolution ?? .hourly_6).dtSeconds ?? readerHourly.modelDtSeconds
        let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
        let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
        let members = 0..<domain.countEnsembleMember
        return .init(name: "hourly", time: timeHourlyDisplay, columns: try await variables.asyncCompactMap { variable in
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                guard let d = try await readerHourly.get(variable: variable, time: timeHourlyRead.toSettings(ensembleMemberLevel: member, run: run))?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(timeHourlyRead.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return nil
            }
            return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func daily(variables: [DailyVariable]?) async throws -> ApiSection<DailyVariable>? {
        guard let variables else {
            return nil
        }
        let members = 0..<domain.countEnsembleMember
        var riseSet: (rise: [Timestamp], set: [Timestamp])?
        return ApiSection<DailyVariable>(name: "daily", time: time.dailyDisplay, columns: try await variables.asyncCompactMap { variable in
            
            if variable == .sunrise || variable == .sunset {
                // only calculate sunrise/set once. Need to use `dailyDisplay` to make sure half-hour time zone offsets are applied correctly
                let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.dailyDisplay.range, lat: readerHourly.modelLat, lon: readerHourly.modelLon, utcOffsetSeconds: timezone.utcOffsetSeconds)
                riseSet = times
                if variable == .sunset {
                    return ApiColumn(variable: .sunset, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.set)])
                } else {
                    return ApiColumn(variable: .sunrise, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.rise)])
                }
            }
            if variable == .daylight_duration {
                let duration = Zensun.calculateDaylightDuration(localMidnight: time.dailyDisplay.range, lat: readerHourly.modelLat)
                return ApiColumn(variable: .daylight_duration, unit: .seconds, variables: [.float(duration)])
            }
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                guard let d = try await readerDaily.get(variable: variable, time: time.dailyRead.toSettings(ensembleMemberLevel: member, run: run))?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(time.dailyRead.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return nil
            }
            return ApiColumn<DailyVariable>(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func sixHourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        guard let variables else {
            return nil
        }
         let members = 0..<domain.countEnsembleMember
        let timeSixHourlyRead = time.dailyRead.with(dtSeconds: 3600 * 6)
        let timeSixHourlyDisplay = time.dailyDisplay.with(dtSeconds: 3600 * 6)
        return .init(name: "six_hourly", time: timeSixHourlyDisplay, columns: try await variables.asyncCompactMap { variable in
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                guard let d = try await readerHourly.get(variable: variable, time: timeSixHourlyRead.toSettings(ensembleMemberLevel: member, run: run))?.convertAndRound(params: params) else {
                    return nil
                }
                unit = d.unit
                assert(timeSixHourlyRead.count == d.data.count)
                return ApiArray.float(d.data)
            }
            guard allMembers.count > 0 else {
                return nil
            }
            return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
        })
    }
    
    func minutely15(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        return nil
    }
    
    func weekly(variables: [WeeklyVariable]?) async throws -> ApiSection<WeeklyVariable>? {
        guard let variables else {
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
        guard let variables else {
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
