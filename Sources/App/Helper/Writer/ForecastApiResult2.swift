//
//  ForecastApiResult2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.09.2025.
//

import Vapor

/*protocol GenericReaderProtocolFB {
    //func cast(variable: FlatBufferVariable) -> Self.MixingVar?
    
    func get(variable: FlatBufferVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit?
    //func getStatic(type: ReaderStaticVariable) async throws -> Float?
    func prefetchData(variable: FlatBufferVariable, time: TimerangeDtAndSettings) async throws
}

protocol GenericDomainFB: RawRepresentableString {
    var dtSeconds: Int { get }
    var countEnsembleMember: Int { get }
    var memberOffset: Int {get}
}

struct FlatBufferVariableWithOriginal: RawRepresentableString {
    let v: FlatBufferVariable
    
    /// The original name from the URL for backwards compatibility. Could be `relativehumidity_2m` instead of `relative_humidity_2m`
    let rawValue: String
    
    init?(rawValue: String) {
        fatalError()
    }
}

/// Stores the API output for multiple locations
struct ForecastapiResult2: ForecastapiResponder, @unchecked Sendable {
    let timeformat: Timeformat
    /// per location, per model
    let results: [PerLocation]
    
    /// old current weather
    let current_weather: Bool
    
    let temporal_resolution: ApiTemporalResolution?
    
    let run: IsoDateTime
    
    let hourly: [FlatBufferVariableWithOriginal]
    let minutely15: [FlatBufferVariableWithOriginal]
    let daily: [FlatBufferVariableWithOriginal]
    let current: [FlatBufferVariableWithOriginal]
    let sixHourly: [FlatBufferVariableWithOriginal]

    var numberOfLocations: Int {
        results.count
    }

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
        let time: ForecastApiTimeRange
        let timeLocal: TimerangeLocal
        let locationId: Int
        let results: [PerModel]

        var utc_offset_seconds: Int {
            timezone.utcOffsetSeconds
        }
        
        func runAllSections() async throws -> [ApiSectionString] {
            fatalError()
            //return [try await minutely15(), try await hourly(), try await sixHourly(), try await daily()].compactMap({ $0 })
        }
        
        /// Merge all hourly sections and prefix with the domain name if required
        func hourly(variables: [FlatBufferVariableWithOriginal], params: ApiQueryParameter, run: IsoDateTime) async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.hourly(variables: variables, run: run, params: params, time: time) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: perModel.model.memberOffset, model: results.count > 1 ? perModel.model : nil)
            })
            return try run.merge()
        }
    }

    struct PerModel {
        /// multi domain like `icon_seamless`
        let model: any GenericDomainFB
        /// initialised reader for a given location
        let reader: any GenericReaderProtocolFB
        /// grid coordinates
        let latitude: Float
        let longitude: Float

        /// Desired elevation from a DEM. Used in statistical downscaling
        let elevation: Float?
        

        func current() async throws -> ApiSectionSingle<FlatBufferVariableWithOriginal>? {
            fatalError()
            
        }

        /// Merge all hourly sections and prefix with the domain name if required
        func hourly(variables: [FlatBufferVariableWithOriginal], run: IsoDateTime, params: ApiQueryParameter, time: ForecastApiTimeRange) async throws -> ApiSection<FlatBufferVariableWithOriginal>? {
            let hourlyDt = (params.temporal_resolution ?? .hourly).dtSeconds ?? model.dtSeconds
            let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
            let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
            let members = 0..<model.countEnsembleMember
            
            return ApiSection(name: "hourly", time: timeHourlyDisplay, columns: try await variables.asyncMap { variable in
                //let (v, previousDay) = variable.variableAndPreviousDay
                let previousDay = Int(variable.v.previousDay)
                var unit: SiUnit?
                let allMembers: [ApiArray] = try await members.asyncCompactMap { member -> ApiArray? in
                    let timeReadOpt = timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run)
                    guard let d = try await reader.get(variable: variable.v, time: timeReadOpt)?.convertAndRound(params: params) else {
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

        func daily(dailyVariables: [FlatBufferVariableWithOriginal], run: IsoDateTime, params: ApiQueryParameter, time: ForecastApiTimeRange, timezone: TimezoneWithOffset) async throws -> ApiSection<FlatBufferVariableWithOriginal>? {
            
            
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
        func sixHourly () async throws -> ApiSectionString? {
            fatalError()

        }
        func minutely15() async throws -> ApiSectionString? {
            fatalError()
            

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
        if format == .xlsx && results.count > 100 {
            throw ForecastApiError.generic(message: "XLSX supports only up to 100 locations")
        }
        for location in results {
            let time = location.time
            for model in location.results {
                let hourlyDt = (temporal_resolution ?? .hourly).dtSeconds ?? model.model.dtSeconds
                let timeHourlyRead = time.hourlyRead.with(dtSeconds: hourlyDt)
                //let timeHourlyDisplay = time.hourlyDisplay.with(dtSeconds: hourlyDt)
                let members = 0..<model.model.countEnsembleMember
                
                for variable in hourly {
                    let previousDay = Int(variable.v.previousDay)
                    for member in members {
                        let timeReadOpt = timeHourlyRead.toSettings(previousDay: previousDay, ensembleMemberLevel: member, run: run)
                        try await model.reader.prefetchData(variable: variable.v, time: timeReadOpt)
                    }
                }
            }
        }
        switch format ?? .json {
        case .json:
            return try toJsonResponse(fixedGenerationTime: fixedGenerationTime, concurrencySlot: concurrencySlot)
        case .xlsx:
            fatalError()
//                return try await toXlsxResponse(timestamp: timestamp)
        case .csv:
            fatalError()
//                return try toCsvResponse(concurrencySlot: concurrencySlot)
        case .flatbuffers:
            fatalError()
//                return try toFlatbuffersResponse(fixedGenerationTime: fixedGenerationTime, concurrencySlot: concurrencySlot)
        }
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
            let nDays = $1.timeLocal.range.durationSeconds / 86400
            let timeFraction = Float(nDays) / Float(referenceDays)
            let variablesFraction = Float(nVariablesModels ?? nVariablesTimesDomains) / Float(referenceVariables)
            let weight = max(variablesFraction, timeFraction * variablesFraction)
            return $0 + max(1, weight)
        })
    }
}
*/
