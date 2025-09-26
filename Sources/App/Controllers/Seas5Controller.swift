import Vapor
import OpenMeteoSdk


struct Seas5Controller {
    func query(_ req: Request) async throws -> Response {
        try await req.withApiParameter("seasonal-api") { _, params in
            let currentTime = Timestamp.now()
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 400)
            let logger = req.logger
            let httpClient = req.application.http.client.shared

            let prepared = try await params.prepareCoordinates(allowTimezones: false, logger: logger, httpClient: httpClient)
            guard case .coordinates(let prepared) = prepared else {
                throw ForecastApiError.generic(message: "Bounding box not supported")
            }
            /// Will be configurable by API later
            let domains = [SeasonalForecastDomainApi.cfsv2]

            let paramsSixHourly = try Seas5Reader.HourlyVariable.load(commaSeparatedOptional: params.six_hourly)
            let paramsDaily = try Seas5Reader.DailyVariable.load(commaSeparatedOptional: params.daily)
            let paramsMonthly = try Seas5Reader.MonthlyVariable.load(commaSeparatedOptional: params.monthly)
            let nVariables = ((paramsSixHourly?.count ?? 0) + (paramsDaily?.count ?? 0) + (paramsMonthly?.count ?? 0)) * domains.reduce(0, { $0 + $1.forecastDomain.nMembers })
            let options = try params.readerOptions(logger: logger, httpClient: httpClient)
            
            let runCurrent = (IsoDateTime(timeIntervalSince1970: try await EcmwfSeasDomain.seas5_6hourly.getLatestFullRun(client: options.httpClient, logger: options.logger)?.timeIntervalSince1970 ?? Timestamp.now().subtract(days: 5).with(day: 1).timeIntervalSince1970))
            let run = params.run ?? runCurrent

            let locations: [ForecastapiResult<Seas5Reader>.PerLocation] = try await prepared.asyncMap { prepared in
                let coordinates = prepared.coordinate
                let timezone = prepared.timezone
                let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 92, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
                let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)

                let readers: [Seas5Reader] = try await domains.asyncCompactMap { domain -> Seas5Reader? in
                    guard let readerHourly = try await EcmwfSeas5Controller6Hourly(lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options) else {
                        return nil
                    }
                    guard let readerDaily = try await EcmwfSeas5Controller24Hourly(lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options) else {
                        return nil
                    }
                    guard let readerMonthly = try await GenericReader<EcmwfSeasDomain, EcmwfSeasVariableMonthly>(domain: .seas5_monthly, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options) else {
                        return nil
                    }
                    return Seas5Reader(readerHourly: readerHourly, readerDaily: readerDaily, readerMonthly: readerMonthly, params: params, time: time, run: run)
                }
                guard !readers.isEmpty else {
                    throw ForecastApiError.noDataAvailableForThisLocation
                }
                return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
            }
            return ForecastapiResult<Seas5Reader>(timeformat: params.timeformatOrDefault, results: locations, currentVariables: nil, minutely15Variables: nil, hourlyVariables: nil, sixHourlyVariables: paramsSixHourly, dailyVariables: paramsDaily, monthlyVariables: paramsMonthly, nVariablesTimesDomains: nVariables)
        }
    }
}


struct Seas5Reader: ModelFlatbufferSerialisable {
    typealias MonthlyVariable = EcmwfSeasVariableMonthly
    
    typealias HourlyVariable = VariableOrDerived<EcmwfSeasVariableSingleLevel, EcmwfSeasVariableSingleLevelDerived>
    
    typealias DailyVariable = VariableOrDerived<EcmwfSeasVariable24HourlySingleLevel, EcmwfSeasVariable24HourlySingleLevelDerived>
    
    var flatBufferModel: OpenMeteoSdk.openmeteo_sdk_Model {
        // TODO seas5 domain
        .ecmwfIfs
    }
    
    var modelName: String {
        "seas5"
    }
        
    let readerHourly: EcmwfSeas5Controller6Hourly
    let readerDaily: EcmwfSeas5Controller24Hourly
    let readerMonthly: GenericReader<EcmwfSeasDomain, EcmwfSeasVariableMonthly>
    
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
    let run: IsoDateTime
    
    func prefetch(currentVariables: [HourlyVariable]?, minutely15Variables: [HourlyVariable]?, hourlyVariables: [HourlyVariable]?, sixHourlyVariables: [HourlyVariable]?, dailyVariables: [DailyVariable]?, monthlyVariables: [MonthlyVariable]?) async throws {
        let members = 0..<readerHourly.reader.domain.countEnsembleMember
        let timeSixHourlyRead = time.dailyRead.with(dtSeconds: 3600 * 6)
        if let sixHourlyVariables {
            for variable in sixHourlyVariables {
                for member in members {
                    try await readerHourly.prefetchData(variable: variable, time: timeSixHourlyRead.toSettings(ensembleMember: member, run: run))
                }
            }
        }
        if let dailyVariables {
            for variable in dailyVariables {
                for member in members {
                    try await readerDaily.prefetchData(variable: variable, time: time.dailyRead.toSettings(ensembleMember: member, run: run))
                }
            }
        }
        if let monthlyVariables {
            // TODO align monthly time to actual month
            let timeMonthly = time.dailyRead.with(dtSeconds: .dtSecondsMonthly)
            
            time.dailyRead.range.lowerBound.with(hour: 0).with(day: 1)
            
            for variable in monthlyVariables {
                for member in members {
                    try await readerMonthly.prefetchData(variable: variable, time: timeMonthly.toSettings(ensembleMember: member))
                }
            }
        }
    }

    func current(variables: [HourlyVariable]?) async throws -> ApiSectionSingle<HourlyVariable>? {
        return nil
    }
    
    func hourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>? {
        return try await sixHourly(variables: variables)
    }
    
    func daily(variables: [DailyVariable]?) async throws -> ApiSection<DailyVariable>? {
        guard let variables else {
            return nil
        }
        let members = 0..<readerDaily.reader.domain.countEnsembleMember
        return ApiSection<DailyVariable>(name: "daily", time: time.dailyDisplay, columns: try await variables.asyncCompactMap { variable in
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let d = try await readerDaily.get(variable: variable, time: time.dailyRead.toSettings(ensembleMember: member, run: run)).convertAndRound(params: params)
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
        let members = 0..<readerHourly.reader.domain.countEnsembleMember
        
        let timeSixHourlyRead = time.dailyRead.with(dtSeconds: 3600 * 6)
        let timeSixHourlyDisplay = time.dailyDisplay.with(dtSeconds: 3600 * 6)
        
        return .init(name: "six_hourly", time: timeSixHourlyDisplay, columns: try await variables.asyncCompactMap { variable in
            var unit: SiUnit?
            let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                let d = try await readerHourly.get(variable: variable, time: timeSixHourlyRead.toSettings(ensembleMember: member, run: run)).convertAndRound(params: params)
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
    
    func monthly(variables: [MonthlyVariable]?) async throws -> ApiSection<MonthlyVariable>? {
        guard let variables else {
            return nil
        }
        let timeRead = time.dailyRead.with(dtSeconds: .dtSecondsMonthly)
        let timeDisplay = time.dailyDisplay.with(dtSeconds: .dtSecondsMonthly)
        return ApiSection<MonthlyVariable>(name: "daily", time: timeDisplay, columns: try await variables.asyncCompactMap { variable in
            let d = try await readerMonthly.get(variable: variable, time: timeRead.toSettings()).convertAndRound(params: params)
            assert(timeRead.count == d.data.count)
            return ApiColumn<MonthlyVariable>(variable: variable, unit: d.unit, variables: [ApiArray.float(d.data)])
        })
    }
}


extension EcmwfSeasVariableMonthly: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        fatalError()
    }
}

extension EcmwfSeasVariableSingleLevel: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        fatalError()
    }
}

extension EcmwfSeasVariableSingleLevelDerived: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        fatalError()
    }
}

extension EcmwfSeasVariable24HourlySingleLevel: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        fatalError()
    }
}

extension EcmwfSeasVariable24HourlySingleLevelDerived: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        fatalError()
    }
}
