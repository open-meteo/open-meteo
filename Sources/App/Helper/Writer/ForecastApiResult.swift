import Foundation
import Vapor
import FlatBuffers
import OpenMeteoSdk

protocol FlatBuffersVariable: RawRepresentableString {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta
}

protocol ForecastapiResponder {
    func calculateQueryWeight(nVariablesModels: Int?) -> Float
    func response(format: ForecastResultFormatWithOptions?, timestamp: Timestamp, fixedGenerationTime: Double?, concurrencySlot: Int?) async throws -> Response

    var numberOfLocations: Int { get }
}

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
    func response(format: ForecastResultFormatWithOptions?, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil, concurrencySlot: Int? = nil) async throws -> Response {
        if case .xlsx(_) = format, results.count > 100 {
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
        case .xlsx(let options):
            switch options {
            case .omit:
                return try await toXlsxResponse(timestamp: timestamp, withLocationHeader: false)
            case .section:
                return try await toXlsxResponse(timestamp: timestamp, withLocationHeader: true)
            }
        case .csv(let options):
            switch options {
                case .omit:
                    return try toCsvResponse(concurrencySlot: concurrencySlot, withLocationHeader: false)
                case .section:
                    return try toCsvResponse(concurrencySlot: concurrencySlot, withLocationHeader: true)
            }
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



enum ApiArray {
    case float([Float])
    case timestamp([Timestamp])

    var count: Int {
        switch self {
        case .float(let a):
            return a.count
        case .timestamp(let a):
            return a.count
        }
    }
}

struct ApiColumn<Variable> {
    let variable: Variable
    let unit: SiUnit
    // one entry per ensemble member
    let variables: [ApiArray]
}

/// Similar to ApiColumn, but no separation for multipl ensemble members anymore
struct ApiColumnString {
    let variable: String
    let unit: SiUnit
    let data: ApiArray
}

/// Contain a single value
struct ApiColumnSingle<Variable> {
    let variable: Variable
    let unit: SiUnit
    let value: Float
}

struct ApiColumnSingleString {
    let variable: String
    let unit: SiUnit
    let value: Float
}

struct ApiSection<Variable> {
    // e.g. hourly or daily
    let name: String
    let time: TimerangeDt
    let columns: [ApiColumn<Variable>]
}

struct ApiSectionString {
    // e.g. hourly or daily
    let name: String
    let time: TimerangeDt
    let columns: [ApiColumnString]
}

/// Sfore current weather information giving only a single value per variable
struct ApiSectionSingle<Variable> {
    let name: String
    let time: Timestamp
    let dtSeconds: Int
    let columns: [ApiColumnSingle<Variable>]
}

extension ApiSection where Variable: RawRepresentableString {
    func toApiSectionString<Model: ModelFlatbufferSerialisable>(memberOffset: Int, model: Model?) -> ApiSectionString {
        return ApiSectionString(name: name, time: time, columns: columns.flatMap { c in
            return c.variables.enumerated().map { member, data in
                let member = member + memberOffset
                let variableAndMember = member > 0 ? "\(c.variable.rawValue)_member\(member.zeroPadded(len: 2))" : c.variable.rawValue
                let variable = model.map { "\(variableAndMember)_\($0.modelName)" } ?? variableAndMember
                return ApiColumnString(variable: variable, unit: c.unit, data: data)
            }
        })
    }

}

extension Array where Element == ApiSectionString {
    func merge() throws -> ApiSectionString? {
        guard let first = self.first else {
            return nil
        }
        guard !self.contains(where: { $0.time.dtSeconds != first.time.dtSeconds }) else {
            throw ForecastApiError.cannotReturnModelsWithDifferentTimeIntervals
        }
        return ApiSectionString(name: first.name, time: first.time, columns: self.flatMap { $0.columns })
    }
}

enum ForecastResultFormat: String, Codable {
    case json
    case xlsx
    case csv
    case flatbuffers

}

enum ForecastResultFormatWithOptions {
    case json
    case xlsx(_ options: OutputLocationInformation)
    case csv(_ options: OutputLocationInformation)
    case flatbuffers
}

/// Simplify flush commands
struct BufferAndAsyncWriter{
    let writer: any AsyncBodyStreamWriter
    var buffer: ByteBuffer

    @inlinable init(writer: any AsyncBodyStreamWriter) {
        self.writer = writer
        self.buffer = ByteBufferAllocator().buffer(capacity: 4 * 1024)
    }

    /// Check if enough data has been written to the buffer and flush if required
    @inlinable mutating func flushIfRequired() async throws {
        if buffer.writerIndex > 3 * 1024 {
            try await flush()
        }
    }

    @inlinable mutating func flush() async throws {
        guard buffer.writerIndex > 0 else {
            return
        }
        let bufferCopy = buffer
        try await writer.writeBuffer(bufferCopy)
        buffer.moveWriterIndex(to: 0)
    }

    @inlinable mutating func end() async throws {
        try await writer.write(.end)
    }
}

extension Timestamp {
    func formated(format: Timeformat, utc_offset_seconds: Int, quotedString: Bool) -> String {
        switch format {
        case .iso8601:
            let iso = add(utc_offset_seconds).iso8601_YYYY_MM_dd_HH_mm
            if quotedString {
                return "\"\(iso)\""
            }
            return iso
        case .unixtime:
            return "\(timeIntervalSince1970)"
        }
    }
}

extension Sequence where Element == Timestamp {
    /// includes quotes characters if `quotedString` is true
    func iterateIso8601(utc_offset_seconds: Int, quotedString: Bool, onlyDate: Bool) -> AnySequence<String> {
        return AnySequence<String> { () -> AnyIterator<String> in
            var iterator = self.makeIterator()
            var t = tm()
            var dateCalculated = Int.min

            if onlyDate {
                return AnyIterator<String> {
                    guard let element = iterator.next()?.add(utc_offset_seconds) else {
                        return nil
                    }
                    if quotedString {
                        return "\"\(element.iso8601_YYYY_MM_dd)\""
                    }
                    return element.iso8601_YYYY_MM_dd
                }
            }

            return AnyIterator<String> {
                guard let element = iterator.next()?.add(utc_offset_seconds) else {
                    return nil
                }
                var time = element.timeIntervalSince1970
                if dateCalculated != time - time.moduloPositive(86400) {
                    dateCalculated = time - time.moduloPositive(86400)
                    gmtime_r(&time, &t)
                }
                let year = Int(t.tm_year + 1900)
                let month = Int(t.tm_mon + 1)
                let day = Int(t.tm_mday)

                let hour = time.moduloPositive(86400) / 3600
                let minute = time.moduloPositive(3600) / 60
                if quotedString {
                    return "\"\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2))\""
                } else {
                    return "\(year)-\(month.zeroPadded(len: 2))-\(day.zeroPadded(len: 2))T\(hour.zeroPadded(len: 2)):\(minute.zeroPadded(len: 2))"
                }
            }
        }
    }

    /// Optimised time iteration function
    func iterate(format: Timeformat, utc_offset_seconds: Int, quotedString: Bool, onlyDate: Bool) -> AnySequence<String> {
        switch format {
        case .iso8601:
            return iterateIso8601(utc_offset_seconds: utc_offset_seconds, quotedString: quotedString, onlyDate: onlyDate)
        case .unixtime:
            return AnySequence<String> { () -> AnyIterator<String> in
                var iterator = self.makeIterator()
                return AnyIterator<String> {
                    guard let element = iterator.next() else {
                        return nil
                    }
                    return "\(element.timeIntervalSince1970)"
                }
            }
        }
    }
}
