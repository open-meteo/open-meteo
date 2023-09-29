
import Foundation
import Vapor
import FlatBuffers

protocol ModelFlatbufferSerialisable: RawRepresentableString {
    associatedtype HourlyVariable: RawRepresentableString
    associatedtype HourlyPressureType: RawRepresentableString, RawRepresentable, Equatable
    associatedtype DailyVariable: RawRepresentableString
    
    //var rawValue: String { get }
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws
    
    /// 0=all members start at control, 1=Members start at `member01` (Used in CFSv2)
    static var memberOffset: Int { get }
}

extension ModelFlatbufferSerialisable {
    static var memberOffset: Int {
        return 0
    }
}


fileprivate struct ModelAndSection<Model: ModelFlatbufferSerialisable, Variable: RawRepresentableString> {
    let model: Model
    let section: () throws -> ApiSection<Variable>
    
    static func run(sections: [Self]) throws -> ApiSectionString {
        let run = try sections.compactMap({ m in
            let h = try m.section()
            return ApiSectionString(name: h.name, time: h.time, columns: h.columns.flatMap { c in
                return c.variables.enumerated().map { (member, data) in
                    let member = member + Model.memberOffset
                    let variableAndMember = member > 0 ? "\(c.variable.rawValue)_member\(member.zeroPadded(len: 2))" : c.variable.rawValue
                    let variable = sections.count > 1 ? "\(variableAndMember)_\(m.model.rawValue)" : variableAndMember
                    return ApiColumnString(variable: variable, unit: c.unit, data: data)
                }
            })
        })
        guard let first = run.first else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return ApiSectionString(name: first.name, time: first.time, columns: run.flatMap { $0.columns})
    }
}

/// Stores the API output for multiple locations
struct ForecastapiResult<Model: ModelFlatbufferSerialisable> {
    let timeformat: Timeformat
    /// per location, per model
    let results: [PerLocation]
    
    struct PerLocation {
        let timezone: TimezoneWithOffset
        let time: TimerangeLocal
        let results: [PerModel]
        
        var utc_offset_seconds: Int {
            timezone.utcOffsetSeconds
        }
        
        func runAllSections() throws -> [ApiSectionString] {
            return [try minutely15?(), try hourly?(), try sixHourly?(), try daily?()].compactMap({$0})
        }
        
        var current: (() throws -> ApiSectionSingle<String>)? {
            let run = results.compactMap({ m in m.current.map{ (model: m.model, section: $0)} })
            guard run.count > 0 else {
                return nil
            }
            return {
                let run = try run.compactMap({ m in
                    let h = try m.section()
                    return ApiSectionSingle<String>(name: h.name, time: h.time, dtSeconds: h.dtSeconds, columns: h.columns.map { c in
                        let variable = run.count > 1 ? "\(c.variable.rawValue)_\(m.model.rawValue)" : c.variable.rawValue
                        return ApiColumnSingle<String>(variable: variable, unit: c.unit, value: c.value)
                    })
                })
                guard let first = run.first else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return ApiSectionSingle<String>(name: first.name, time: first.time, dtSeconds: first.dtSeconds, columns: run.flatMap { $0.columns})
            }
        }
        
        /// Merge all hourly sections and prefix with the domain name if required
        var hourly: (() throws -> ApiSectionString)? {
            let run = results.compactMap({ m in m.hourly.map{ ModelAndSection(model: m.model, section: $0)} })
            guard run.count > 0 else {
                return nil
            }
            return {
                try ModelAndSection.run(sections: run)
            }
        }
        
        var daily: (() throws -> ApiSectionString)? {
            let run = results.compactMap({ m in m.daily.map{ ModelAndSection(model: m.model, section: $0)} })
            guard run.count > 0 else {
                return nil
            }
            return {
                try ModelAndSection.run(sections: run)
            }
        }
        var sixHourly: (() throws -> ApiSectionString)? {
            let run = results.compactMap({ m in m.sixHourly.map{ ModelAndSection(model: m.model, section: $0)} })
            guard run.count > 0 else {
                return nil
            }
            return {
                try ModelAndSection.run(sections: run)
            }
        }
        var minutely15: (() throws -> ApiSectionString)? {
            let run = results.compactMap({ m in m.minutely15.map{ ModelAndSection(model: m.model, section: $0)} })
            guard run.count > 0 else {
                return nil
            }
            return {
                try ModelAndSection.run(sections: run)
            }
        }
    }
    
    struct PerModel {
        let model: Model
        let latitude: Float
        let longitude: Float
        
        /// Desired elevation from a DEM. Used in statistical downscaling
        let elevation: Float?
        
        let prefetch: (() throws -> ())
        let current: (() throws -> ApiSectionSingle<SurfaceAndPressureVariable>)?
        let hourly: (() throws -> ApiSection<SurfaceAndPressureVariable>)?
        let daily: (() throws -> ApiSection<Model.DailyVariable>)?
        let sixHourly: (() throws -> ApiSection<SurfaceAndPressureVariable>)?
        let minutely15: (() throws -> ApiSection<SurfaceAndPressureVariable>)?
        
        /// e.g. `52.52N13.42E38m`
        var formatedCoordinatesFilename: String {
            let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
            let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
            return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
        }
    }
    
    struct PressureVariableAndLevel {
        let variable: Model.HourlyPressureType
        let level: Int
        
        init(_ variable: Model.HourlyPressureType, _ level: Int) {
            self.variable = variable
            self.level = level
        }
    }

    /// Enum with surface and pressure variable
    enum SurfaceAndPressureVariable: RawRepresentableString {
        init?(rawValue: String) {
            fatalError()
        }
        
        var rawValue: String {
            switch self {
            case .surface(let v):
                return v.rawValue
            case .pressure(let v):
                return "\(v.variable.rawValue)_\(v.level)hPa"
            }
        }
        
        case surface(Model.HourlyVariable)
        case pressure(PressureVariableAndLevel)
    }
    
    /// Output the given result set with a specified format
    /// timestamp and fixedGenerationTime are used to overwrite dynamic fields in unit tests
    func response(format: ForecastResultFormat, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil) -> EventLoopFuture<Response> {
        return ForecastapiController.runLoop.next().submit {
            for location in results {
                for model in location.results {
                    try model.prefetch()
                }
            }
            switch format {
            case .json:
                return try toJsonResponse(fixedGenerationTime: fixedGenerationTime)
            case .xlsx:
                return try toXlsxResponse(timestamp: timestamp)
            case .csv:
                return try toCsvResponse()
            case .flatbuffers:
                return try toFlatbuffersResponse(fixedGenerationTime: fixedGenerationTime)
            }
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
    func calculateQueryWeight(nVariablesModels: Int) -> Float {
        let referenceDays = 14
        let referenceVariables = 10
        // Sum up weights for each location. Technically each location can have a different time interval
        return results.reduce(0, {
            let nDomains = Float($1.results.count)
            let nDays = $1.time.range.durationSeconds / 86400
            let timeFraction = Float(nDays) / Float(referenceDays)
            let variablesFraction = Float(nVariablesModels) / Float(referenceVariables)
            let weight = max(variablesFraction, timeFraction * variablesFraction)
            return $0 + max(1, weight) * nDomains
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

enum ForecastResultFormat: String, Codable {
    case json
    case xlsx
    case csv
    case flatbuffers
}

/// Simplify flush commands
struct BufferAndWriter {
    let writer: BodyStreamWriter
    var buffer: ByteBuffer
    
    @inlinable init(writer: BodyStreamWriter) {
        self.writer = writer
        self.buffer = ByteBufferAllocator().buffer(capacity: 4*1024)
    }
    
    /// Check if enough data has been written to the buffer and flush if required
    @inlinable mutating func flushIfRequired() async throws {
        if buffer.writerIndex > 3*1024 {
            try await flush()
        }
    }
    
    @inlinable mutating func flush() async throws {
        guard buffer.writerIndex > 0 else {
            return
        }
        let bufferCopy = buffer
        let writer = writer
        try await writer.eventLoop.flatSubmit { writer.write(.buffer(bufferCopy)) }.get()
        buffer.moveWriterIndex(to: 0)
    }
    
    @inlinable mutating func end() async throws {
        let writer = writer
        try await writer.eventLoop.flatSubmit { writer.write(.end) }.get()
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
            var dateCalculated = -99999
            
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
                if dateCalculated != time / 86400 {
                    dateCalculated = time / 86400
                    gmtime_r(&time, &t)
                }
                let year = Int(t.tm_year+1900)
                let month = Int(t.tm_mon+1)
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
