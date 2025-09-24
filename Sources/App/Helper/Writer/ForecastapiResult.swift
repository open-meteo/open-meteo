import Foundation
import Vapor
import FlatBuffers
import OpenMeteoSdk

protocol FlatBuffersVariable: RawRepresentableString {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta
}

protocol ModelFlatbufferSerialisable: RawRepresentableString, Sendable {
    associatedtype HourlyVariable: FlatBuffersVariable
    associatedtype HourlyPressureType: FlatBuffersVariable, RawRepresentable, Equatable
    associatedtype HourlyHeightType: FlatBuffersVariable, RawRepresentable, Equatable
    associatedtype DailyVariable: FlatBuffersVariable

    /// 0=all members start at control, 1=Members start at `member01` (Used in CFSv2)
    static var memberOffset: Int { get }

    var flatBufferModel: openmeteo_sdk_Model { get }
}

extension ModelFlatbufferSerialisable {
    static var memberOffset: Int {
        return 0
    }
}

protocol ForecastapiResponder {
    func calculateQueryWeight(nVariablesModels: Int?) -> Float
    func response(format: ForecastResultFormat?, timestamp: Timestamp, fixedGenerationTime: Double?, concurrencySlot: Int?) async throws -> Response

    var numberOfLocations: Int { get }
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
    func toApiSectionString<Model: RawRepresentableString>(memberOffset: Int, model: Model?) -> ApiSectionString {
        return ApiSectionString(name: name, time: time, columns: columns.flatMap { c in
            return c.variables.enumerated().map { member, data in
                let member = member + memberOffset
                let variableAndMember = member > 0 ? "\(c.variable.rawValue)_member\(member.zeroPadded(len: 2))" : c.variable.rawValue
                let variable = model.map { "\(variableAndMember)_\($0.rawValue)" } ?? variableAndMember
                return ApiColumnString(variable: variable, unit: c.unit, data: data)
            }
        })
    }
    
    func toApiSectionString<Model: ModelFlatbufferSerialisable4>(memberOffset: Int, model: Model?) -> ApiSectionString {
        return ApiSectionString(name: name, time: time, columns: columns.flatMap { c in
            return c.variables.enumerated().map { member, data in
                let member = member + memberOffset
                let variableAndMember = member > 0 ? "\(c.variable.rawValue)_member\(member.zeroPadded(len: 2))" : c.variable.rawValue
                let variable = model.map { "\(variableAndMember)_\($0.modelName)" } ?? variableAndMember
                return ApiColumnString(variable: variable, unit: c.unit, data: data)
            }
        })
    }
    
    /*func toApiSectionString(memberOffset: Int, model: GenericDomainFB?) -> ApiSectionString {
        return ApiSectionString(name: name, time: time, columns: columns.flatMap { c in
            return c.variables.enumerated().map { member, data in
                let member = member + memberOffset
                let variableAndMember = member > 0 ? "\(c.variable.rawValue)_member\(member.zeroPadded(len: 2))" : c.variable.rawValue
                let variable = model.map { "\(variableAndMember)_\($0.rawValue)" } ?? variableAndMember
                return ApiColumnString(variable: variable, unit: c.unit, data: data)
            }
        })
    }*/
}

/*extension ApiSection where Variable: FlatBuffersVariable2 {
    func toApiSectionString<Model: RawRepresentableString>(memberOffset: Int, model: Model?) -> ApiSectionString {
        return ApiSectionString(name: name, time: time, columns: columns.flatMap { c in
            return c.variables.enumerated().map { member, data in
                let member = member + memberOffset
                let variableAndMember = member > 0 ? "\(c.variable.originalString)_member\(member.zeroPadded(len: 2))" : String(c.variable.originalString)
                let variable = model.map { "\(variableAndMember)_\($0.rawValue)" } ?? variableAndMember
                return ApiColumnString(variable: variable, unit: c.unit, data: data)
            }
        })
    }
}*/


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
    func itterateIso8601(utc_offset_seconds: Int, quotedString: Bool, onlyDate: Bool) -> AnySequence<String> {
        return AnySequence<String> { () -> AnyIterator<String> in
            var itterator = self.makeIterator()
            var t = tm()
            var dateCalculated = Int.min

            if onlyDate {
                return AnyIterator<String> {
                    guard let element = itterator.next()?.add(utc_offset_seconds) else {
                        return nil
                    }
                    if quotedString {
                        return "\"\(element.iso8601_YYYY_MM_dd)\""
                    }
                    return element.iso8601_YYYY_MM_dd
                }
            }

            return AnyIterator<String> {
                guard let element = itterator.next()?.add(utc_offset_seconds) else {
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

    /// Optimised time itteration function
    func itterate(format: Timeformat, utc_offset_seconds: Int, quotedString: Bool, onlyDate: Bool) -> AnySequence<String> {
        switch format {
        case .iso8601:
            return itterateIso8601(utc_offset_seconds: utc_offset_seconds, quotedString: quotedString, onlyDate: onlyDate)
        case .unixtime:
            return AnySequence<String> { () -> AnyIterator<String> in
                var itterator = self.makeIterator()
                return AnyIterator<String> {
                    guard let element = itterator.next() else {
                        return nil
                    }
                    return "\(element.timeIntervalSince1970)"
                }
            }
        }
    }
}
