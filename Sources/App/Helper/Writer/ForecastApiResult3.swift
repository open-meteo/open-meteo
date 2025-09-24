//
//  ForecastApiResult3.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 23.09.2025.
//
/*
import Vapor
import OpenMeteoSdk

protocol FlatBuffersVariable2 {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta
    var previousDay: Int {get}
    var originalString: Substring {get}
}

protocol FlatBuffersVariable3: RawRepresentableString {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta
}

protocol ModelFlatbufferSerialisable3: RawRepresentableString, Sendable {
    associatedtype HourlyVariable: FlatBuffersVariable2
    associatedtype DailyVariable: FlatBuffersVariable2

    /// 0=all members start at control, 1=Members start at `member01` (Used in CFSv2)
    static var memberOffset: Int { get }
    
    var dtSeconds: Int { get }
    var countEnsembleMember: Int { get }
    var flatBufferModel: openmeteo_sdk_Model { get }
    
    func get(variable: HourlyVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit?
    func getDaily(variable: DailyVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit?
}


/// Stores the API output for multiple locations
struct ForecastapiResult3<Model: ModelFlatbufferSerialisable3>: ForecastapiResponder, @unchecked Sendable {
    let timeformat: Timeformat
    /// per location, per model
    let results: [PerLocation]

    var numberOfLocations: Int {
        results.count
    }
    
    let hourly: [Model.HourlyVariable]
    let minutely15: [Model.HourlyVariable]
    let daily: [Model.DailyVariable]
    let current: [Model.HourlyVariable]
    let sixHourly: [Model.HourlyVariable]

    /// Number of variables times number of somains. Used to rate limiting
    let nVariablesTimesDomains: Int

    init(timeformat: Timeformat, results: [PerLocation], nVariablesTimesDomains: Int = 1) {
        self.timeformat = timeformat
        self.results = results
        self.nVariablesTimesDomains = nVariablesTimesDomains
        fatalError()
    }

    struct PerLocation {
        let timezone: TimezoneWithOffset
        let time: TimerangeLocal
        let locationId: Int
        let results: [PerModel]

        var utc_offset_seconds: Int {
            timezone.utcOffsetSeconds
        }

        func runAllSections() async throws -> [ApiSectionString] {
            return [try await minutely15(), try await hourly(), try await sixHourly(), try await daily()].compactMap({ $0 })
        }

        func current() async throws -> ApiSectionSingle<String>? {
            let sections = try await results.asyncCompactMap({ perModel -> ApiSectionSingle<String>? in
                guard let h = try await perModel.current?() else {
                    return nil
                }
                return ApiSectionSingle<String>(name: h.name, time: h.time, dtSeconds: h.dtSeconds, columns: h.columns.map { c in
                    let variable = results.count > 1 ? "\(c.variable.originalString)_\(perModel.model.rawValue)" : String(c.variable.originalString)
                    return ApiColumnSingle<String>(variable: variable, unit: c.unit, value: c.value)
                })
            })
            guard let first = sections.first else {
                return nil
            }
            return ApiSectionSingle<String>(name: first.name, time: first.time, dtSeconds: first.dtSeconds, columns: sections.flatMap { $0.columns })
        }

        /// Merge all hourly sections and prefix with the domain name if required
        func hourly() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.hourly?() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel.model : nil)
            })
            return try run.merge()
        }

        func daily() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.daily?() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel.model : nil)
            })
            return try run.merge()
        }
        func sixHourly () async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.sixHourly?() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel.model : nil)
            })
            return try run.merge()
        }
        func minutely15() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.minutely15?() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel.model : nil)
            })
            return try run.merge()
        }
    }

    struct PerModel {
        let model: Model
        let latitude: Float
        let longitude: Float

        /// Desired elevation from a DEM. Used in statistical downscaling
        let elevation: Float?

        let prefetch: (() async throws -> Void)
        let current: (() async throws -> ApiSectionSingle<Model.HourlyVariable>)?
        let hourly: (() async throws -> ApiSection<Model.HourlyVariable>)?
        let daily: (() async throws -> ApiSection<Model.DailyVariable>)?
        let sixHourly: (() async throws -> ApiSection<Model.HourlyVariable>)?
        let minutely15: (() async throws -> ApiSection<Model.HourlyVariable>)?
        
        /// Merge all hourly sections and prefix with the domain name if required
        func hourly(variables: [Model.HourlyVariable], run: IsoDateTime, params: ApiQueryParameter, time: ForecastApiTimeRange) async throws -> ApiSection<Model.HourlyVariable>? {
            let hourlyDt = (params.temporal_resolution ?? .hourly).dtSeconds ?? model.dtSeconds
            let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
            let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
            let members = 0..<model.countEnsembleMember
            
            return ApiSection(name: "hourly", time: timeHourlyDisplay, columns: try await variables.asyncMap { variable in
                //let (v, previousDay) = variable.variableAndPreviousDay
                let previousDay = Int(variable.previousDay)
                var unit: SiUnit?
                let allMembers: [ApiArray] = try await members.asyncCompactMap { member -> ApiArray? in
                    let timeReadOpt = timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run)
                    guard let d = try await model.get(variable: variable, time: timeReadOpt)?.convertAndRound(params: params) else {
                        return nil
                    }
                    unit = d.unit
                    assert(timeHourlyRead.count == d.data.count)
                    return ApiArray.float(d.data)
                }
                guard allMembers.count > 0 else {
                    return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: timeHourlyRead.count)), count: model.countEnsembleMember))
                }
                return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
            })
        }
        
        func daily(dailyVariables: [Model.DailyVariable], run: IsoDateTime, params: ApiQueryParameter, time: ForecastApiTimeRange, timezone: TimezoneWithOffset) async throws -> ApiSection<Model.DailyVariable>? {
            
            
            var riseSet: (rise: [Timestamp], set: [Timestamp])?
            return ApiSection(name: "daily", time: time.dailyDisplay, columns: try await dailyVariables.asyncMap { variable -> ApiColumn<FlatBufferVariableWithOriginal> in
                if variable.v.variableSdk == .sunrise || variable.v.variableSdk == .sunset {
                    // only calculate sunrise/set once. Need to use `dailyDisplay` to make sure half-hour time zone offsets are applied correctly
                    let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.dailyDisplay.range, lat: latitude, lon: longitude, utcOffsetSeconds: timezone.utcOffsetSeconds)
                    riseSet = times
                    if variable.v.variableSdk == .sunset {
                        return ApiColumn(variable: variable, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.set)])
                    } else {
                        return ApiColumn(variable: variable, unit: params.timeformatOrDefault.unit, variables: [.timestamp(times.rise)])
                    }
                }
                if variable.v.variableSdk == .daylightDuration {
                    let duration = Zensun.calculateDaylightDuration(localMidnight: time.dailyDisplay.range, lat: latitude)
                    return ApiColumn(variable: variable, unit: .seconds, variables: [.float(duration)])
                }
                
                // Check if there is a reader with 24h data directly
                let reader24h = GenericReaderMulti<ForecastVariable, MultiDomains>(domain: domain, reader: reader.reader.filter({$0.modelDtSeconds == 24*3600}))
                
                var unit: SiUnit?
                let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                    let timeRead = time.dailyRead.toSettings(ensembleMemberLevel: member, run: run)
                    if let d = try await reader24h.get(variable: variable, time: timeRead) {
                        unit = d.unit
                        assert(time.dailyRead.count == d.data.count)
                        return ApiArray.float(d.data)
                    }
                    guard let d = try await reader.getDaily(variable: variable, params: params, time: timeRead)?.convertAndRound(params: params) else {
                        return nil
                    }
                    unit = d.unit
                    assert(time.dailyRead.count == d.data.count)
                    return ApiArray.float(d.data)
                }
                guard allMembers.count > 0 else {
                    return ApiColumn(variable: variable, unit: .undefined, variables: .init(repeating: ApiArray.float([Float](repeating: .nan, count: time.dailyRead.count)), count: reader.domain.countEnsembleMember))
                }
                return .init(variable: variable, unit: unit ?? .undefined, variables: allMembers)
            })

        }
       

        /// e.g. `52.52N13.42E38m`
        var formatedCoordinatesFilename: String {
            let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
            let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
            return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
        }
    }

    /// Output the given result set with a specified format
    /// timestamp and fixedGenerationTime are used to overwrite dynamic fields in unit tests
    func response(format: ForecastResultFormat?, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil, concurrencySlot: Int? = nil) async throws -> Response {
        fatalError()
        //let loop = ForecastapiController.runLoop
        //return try await loop.next() {
            /*if format == .xlsx && results.count > 100 {
                throw ForecastApiError.generic(message: "XLSX supports only up to 100 locations")
            }
            for location in results {
                for model in location.results {
                    try await model.prefetch()
                }
            }
            switch format ?? .json {
            case .json:
                return try toJsonResponse(fixedGenerationTime: fixedGenerationTime, concurrencySlot: concurrencySlot)
            case .xlsx:
                return try await toXlsxResponse(timestamp: timestamp)
            case .csv:
                return try toCsvResponse(concurrencySlot: concurrencySlot)
            case .flatbuffers:
                return try toFlatbuffersResponse(fixedGenerationTime: fixedGenerationTime, concurrencySlot: concurrencySlot)
            }*/
        //}.get()
    }

    /// Calculate excess weight of an API query. The following factors are considered:
    /// - 14 days of data are considered a weight of 1
    /// - 10 weather variables are a weight of 1
    /// - The number of dails and weather variables is scaled linearly afterwards. E.g. 15 weather variales, account for 1.5 weight.
    /// - Number of locations
    ///
    /// `weight = max(variables / 10, variables / 10 * days / 14) * locations`
    ///
    /// See: https://github.com/open-meteo/open-meteo/issues/438#issuecomment-1722945326
    func calculateQueryWeight(nVariablesModels: Int? = nil) -> Float {
        let referenceDays = 14
        let referenceVariables = 10
        // Sum up weights for each location. Technically each location can have a different time interval
        return results.reduce(0, {
            let nDays = $1.time.range.durationSeconds / 86400
            let timeFraction = Float(nDays) / Float(referenceDays)
            let variablesFraction = Float(nVariablesModels ?? nVariablesTimesDomains) / Float(referenceVariables)
            let weight = max(variablesFraction, timeFraction * variablesFraction)
            return $0 + max(1, weight)
        })
    }
}
*/
