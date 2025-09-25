//
//  ForecastapiResult.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 23.09.2025.
//

import OpenMeteoSdk
import Vapor

protocol ModelFlatbufferSerialisable {
    associatedtype HourlyVariable: FlatBuffersVariable
    associatedtype DailyVariable: FlatBuffersVariable
    associatedtype MonthlyVariable: FlatBuffersVariable

    /// 0=all members start at control, 1=Members start at `member01` (Used in CFSv2)
    static var memberOffset: Int { get }

    var flatBufferModel: openmeteo_sdk_Model { get }
    var modelName: String {get}
    
    
    var latitude: Float { get }
    var longitude: Float { get }

    /// Desired elevation from a DEM. Used in statistical downscaling
    var elevation: Float? { get }

    func prefetch(currentVariables: [HourlyVariable]?, minutely15Variables: [HourlyVariable]?, hourlyVariables: [HourlyVariable]?, sixHourlyVariables: [HourlyVariable]?, dailyVariables: [DailyVariable]?, monthlyVariables: [MonthlyVariable]?) async throws -> Void
    
    func current(variables: [HourlyVariable]?) async throws -> ApiSectionSingle<HourlyVariable>?
    func hourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>?
    func sixHourly(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>?
    func minutely15(variables: [HourlyVariable]?) async throws -> ApiSection<HourlyVariable>?
    func daily(variables: [DailyVariable]?) async throws -> ApiSection<DailyVariable>?
    func monthly(variables: [MonthlyVariable]?) async throws -> ApiSection<MonthlyVariable>?
}

struct FlatBuffersVariableNone: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        return FlatBufferVariableMeta(variable: .undefined)
    }
    
    init?(rawValue: String) {
        return nil
    }
    
    var rawValue: String {
        return "undefined"
    }
}


extension ModelFlatbufferSerialisable {
    static var memberOffset: Int {
        return 0
    }
    
    /// e.g. `52.52N13.42E38m`
    var formatedCoordinatesFilename: String {
        let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
        let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
        return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
    }
}

/// Stores the API output for multiple locations
struct ForecastapiResult<Model: ModelFlatbufferSerialisable>: ForecastapiResponder, @unchecked Sendable {
    let timeformat: Timeformat
    /// per location, per model
    let results: [PerLocation]

    var numberOfLocations: Int {
        results.count
    }

    /// Number of variables times number of somains. Used to rate limiting
    let nVariablesTimesDomains: Int
    
    struct RequestVariables {
        let currentVariables: [Model.HourlyVariable]?
        let minutely15Variables: [Model.HourlyVariable]?
        let hourlyVariables: [Model.HourlyVariable]?
        let sixHourlyVariables: [Model.HourlyVariable]?
        let dailyVariables: [Model.DailyVariable]?
        let monthlyVariables: [Model.MonthlyVariable]?
    }
    let variables: RequestVariables


    init(timeformat: Timeformat, results: [PerLocation], currentVariables: [Model.HourlyVariable]?, minutely15Variables: [Model.HourlyVariable]?, hourlyVariables: [Model.HourlyVariable]?, sixHourlyVariables: [Model.HourlyVariable]?, dailyVariables: [Model.DailyVariable]?, monthlyVariables: [Model.MonthlyVariable]?, nVariablesTimesDomains: Int = 1) {
        self.timeformat = timeformat
        self.results = results
        self.nVariablesTimesDomains = nVariablesTimesDomains
        self.variables = RequestVariables(currentVariables: currentVariables, minutely15Variables: minutely15Variables, hourlyVariables: hourlyVariables, sixHourlyVariables: sixHourlyVariables, dailyVariables: dailyVariables, monthlyVariables: monthlyVariables)
    }

    struct PerLocation {
        let timezone: TimezoneWithOffset
        let time: TimerangeLocal
        let locationId: Int
        let results: [Model]

        var utc_offset_seconds: Int {
            timezone.utcOffsetSeconds
        }

        func runAllSections(variables: RequestVariables) async throws -> [ApiSectionString] {
            return [
                try await minutely15(variables: variables.minutely15Variables),
                try await hourly(variables: variables.hourlyVariables),
                try await sixHourly(variables: variables.sixHourlyVariables),
                try await daily(variables: variables.dailyVariables),
                try await monthly(variables: variables.monthlyVariables),
            ].compactMap({ $0 })
        }

        func current(variables: [Model.HourlyVariable]?) async throws -> ApiSectionSingle<String>? {
            guard let variables else {
                return nil
            }
            let sections = try await results.asyncCompactMap({ perModel -> ApiSectionSingle<String>? in
                guard let h = try await perModel.current(variables: variables) else {
                    return nil
                }
                return ApiSectionSingle<String>(name: h.name, time: h.time, dtSeconds: h.dtSeconds, columns: h.columns.map { c in
                    let variable = results.count > 1 ? "\(c.variable.rawValue)_\(perModel.modelName)" : c.variable.rawValue
                    return ApiColumnSingle<String>(variable: variable, unit: c.unit, value: c.value)
                })
            })
            guard let first = sections.first else {
                return nil
            }
            return ApiSectionSingle<String>(name: first.name, time: first.time, dtSeconds: first.dtSeconds, columns: sections.flatMap { $0.columns })
        }

        /// Merge all hourly sections and prefix with the domain name if required
        func hourly(variables: [Model.HourlyVariable]?) async throws -> ApiSectionString? {
            guard let variables else {
                return nil
            }
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.hourly(variables: variables) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }

        func daily(variables: [Model.DailyVariable]?) async throws -> ApiSectionString? {
            guard let variables else {
                return nil
            }
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.daily(variables: variables) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
        func sixHourly(variables: [Model.HourlyVariable]?) async throws -> ApiSectionString? {
            guard let variables else {
                return nil
            }
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.sixHourly(variables: variables) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
        func minutely15(variables: [Model.HourlyVariable]?) async throws -> ApiSectionString? {
            guard let variables else {
                return nil
            }
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.minutely15(variables: variables) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
        
        func monthly(variables: [Model.MonthlyVariable]?) async throws -> ApiSectionString? {
            guard let variables else {
                return nil
            }
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.monthly(variables: variables) else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
    }

    /// Output the given result set with a specified format
    /// timestamp and fixedGenerationTime are used to overwrite dynamic fields in unit tests
    func response(format: ForecastResultFormat?, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil, concurrencySlot: Int? = nil) async throws -> Response {
        if format == .xlsx && results.count > 100 {
            throw ForecastApiError.generic(message: "XLSX supports only up to 100 locations")
        }
        for location in results {
            for model in location.results {
                try await model.prefetch(currentVariables: variables.currentVariables, minutely15Variables: variables.minutely15Variables, hourlyVariables: variables.hourlyVariables, sixHourlyVariables: variables.sixHourlyVariables, dailyVariables: variables.dailyVariables, monthlyVariables: variables.monthlyVariables)
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
            let nDays = $1.time.range.durationSeconds / 86400
            let timeFraction = Float(nDays) / Float(referenceDays)
            let variablesFraction = Float(nVariablesModels ?? nVariablesTimesDomains) / Float(referenceVariables)
            let weight = max(variablesFraction, timeFraction * variablesFraction)
            return $0 + max(1, weight)
        })
    }
}
