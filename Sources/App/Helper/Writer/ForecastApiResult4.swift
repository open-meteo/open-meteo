//
//  ForecastApiResult4.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 23.09.2025.
//

import OpenMeteoSdk
import Vapor


protocol ModelFlatbufferSerialisable4 {
    associatedtype HourlyVariable: FlatBuffersVariable
    associatedtype HourlyPressureType: FlatBuffersVariable, RawRepresentable, Equatable
    associatedtype HourlyHeightType: FlatBuffersVariable, RawRepresentable, Equatable
    associatedtype DailyVariable: FlatBuffersVariable

    /// 0=all members start at control, 1=Members start at `member01` (Used in CFSv2)
    static var memberOffset: Int { get }

    var flatBufferModel: openmeteo_sdk_Model { get }
    var modelName: String {get}
    
    
    var latitude: Float { get }
    var longitude: Float { get }

    /// Desired elevation from a DEM. Used in statistical downscaling
    var elevation: Float? { get }

    func prefetch() async throws -> Void
    func current() async throws -> ApiSectionSingle<ForecastapiResult4<Self>.SurfacePressureAndHeightVariable>?
    func hourly() async throws -> ApiSection<ForecastapiResult4<Self>.SurfacePressureAndHeightVariable>?
    func daily() async throws -> ApiSection<DailyVariable>?
    func sixHourly() async throws -> ApiSection<ForecastapiResult4<Self>.SurfacePressureAndHeightVariable>?
    func minutely15() async throws -> ApiSection<ForecastapiResult4<Self>.SurfacePressureAndHeightVariable>?
}


extension ModelFlatbufferSerialisable4 {
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
struct ForecastapiResult4<Model: ModelFlatbufferSerialisable4>: ForecastapiResponder, @unchecked Sendable {
    let timeformat: Timeformat
    /// per location, per model
    let results: [PerLocation]

    var numberOfLocations: Int {
        results.count
    }

    /// Number of variables times number of somains. Used to rate limiting
    let nVariablesTimesDomains: Int

    init(timeformat: Timeformat, results: [PerLocation], nVariablesTimesDomains: Int = 1) {
        self.timeformat = timeformat
        self.results = results
        self.nVariablesTimesDomains = nVariablesTimesDomains
    }

    struct PerLocation {
        let timezone: TimezoneWithOffset
        let time: TimerangeLocal
        let locationId: Int
        let results: [Model]

        var utc_offset_seconds: Int {
            timezone.utcOffsetSeconds
        }

        func runAllSections() async throws -> [ApiSectionString] {
            return [try await minutely15(), try await hourly(), try await sixHourly(), try await daily()].compactMap({ $0 })
        }

        func current() async throws -> ApiSectionSingle<String>? {
            let sections = try await results.asyncCompactMap({ perModel -> ApiSectionSingle<String>? in
                guard let h = try await perModel.current() else {
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
        func hourly() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.hourly() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }

        func daily() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.daily() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
        func sixHourly () async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.sixHourly() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
        func minutely15() async throws -> ApiSectionString? {
            let run: [ApiSectionString] = try await results.asyncCompactMap({ perModel -> ApiSectionString? in
                guard let h = try await perModel.minutely15() else {
                    return nil
                }
                return h.toApiSectionString(memberOffset: Model.memberOffset, model: results.count > 1 ? perModel : nil)
            })
            return try run.merge()
        }
    }

    /*struct PerModel {
        let model: Model
        let latitude: Float
        let longitude: Float

        /// Desired elevation from a DEM. Used in statistical downscaling
        let elevation: Float?

        let prefetch: (() async throws -> Void)
        let current: (() async throws -> ApiSectionSingle<SurfacePressureAndHeightVariable>)?
        let hourly: (() async throws -> ApiSection<SurfacePressureAndHeightVariable>)?
        let daily: (() async throws -> ApiSection<Model.DailyVariable>)?
        let sixHourly: (() async throws -> ApiSection<SurfacePressureAndHeightVariable>)?
        let minutely15: (() async throws -> ApiSection<SurfacePressureAndHeightVariable>)?

        /// e.g. `52.52N13.42E38m`
        var formatedCoordinatesFilename: String {
            let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
            let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
            return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
        }
    }*/

    struct PressureVariableAndLevel {
        let variable: Model.HourlyPressureType
        let level: Int

        init(_ variable: Model.HourlyPressureType, _ level: Int) {
            self.variable = variable
            self.level = level
        }
    }

    struct HeightVariableAndLevel {
        let variable: Model.HourlyHeightType
        let level: Int

        init(_ variable: Model.HourlyHeightType, _ level: Int) {
            self.variable = variable
            self.level = level
        }
    }

    /// Enum with surface and pressure variable
    enum SurfacePressureAndHeightVariable: RawRepresentableString, FlatBuffersVariable {
        init?(rawValue: String) {
            fatalError()
        }

        var rawValue: String {
            switch self {
            case .surface(let v):
                return v.rawValue
            case .pressure(let v):
                return "\(v.variable.rawValue)_\(v.level)hPa"
            case .height(let v):
                return "\(v.variable.rawValue)_\(v.level)m"
            }
        }

        case surface(Model.HourlyVariable)
        case pressure(PressureVariableAndLevel)
        case height(HeightVariableAndLevel)

        func getFlatBuffersMeta() -> FlatBufferVariableMeta {
            switch self {
            case .surface(let hourlyVariable):
                return hourlyVariable.getFlatBuffersMeta()
            case .pressure(let pressureVariableAndLevel):
                let meta = pressureVariableAndLevel.variable.getFlatBuffersMeta()
                return FlatBufferVariableMeta(
                    variable: meta.variable,
                    aggregation: meta.aggregation,
                    altitude: meta.altitude,
                    pressureLevel: Int16(pressureVariableAndLevel.level),
                    depth: meta.depth,
                    depthTo: meta.depthTo
                )
            case .height(let heightVariableAndLevel):
                let meta = heightVariableAndLevel.variable.getFlatBuffersMeta()
                return FlatBufferVariableMeta(
                    variable: meta.variable,
                    aggregation: meta.aggregation,
                    altitude: Int16(heightVariableAndLevel.level),
                    depth: meta.depth,
                    depthTo: meta.depthTo
                )
            }
        }
    }

    /// Output the given result set with a specified format
    /// timestamp and fixedGenerationTime are used to overwrite dynamic fields in unit tests
    func response(format: ForecastResultFormat?, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil, concurrencySlot: Int? = nil) async throws -> Response {
        //let loop = ForecastapiController.runLoop
        //return try await loop.next() {
            if format == .xlsx && results.count > 100 {
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
            }
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
