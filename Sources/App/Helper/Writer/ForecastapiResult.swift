
import Foundation
import Vapor


/**
 Store the result of a API forecast result and converion to JSON
 */
struct ForecastapiResult {
    let latitude: Float
    let longitude: Float
    
    /// Desired elevation from a DEM. Used in statistical downscaling
    let elevation: Float?
    
    let timezone: TimezoneWithOffset
    
    let prefetch: (() throws -> ())
    let current_weather: (() throws -> CurrentWeather)?
    let hourly: (() throws -> ApiSection)?
    let daily: (() throws -> ApiSection)?
    let sixHourly: (() throws -> ApiSection)?
    let minutely15: (() throws -> ApiSection)?
    
    func runAllSections() throws -> [ApiSection] {
        return [try minutely15?(), try hourly?(), try sixHourly?(), try daily?()].compactMap({$0})
    }
    
    var utc_offset_seconds: Int {
        timezone.utcOffsetSeconds
    }
    
    struct CurrentWeather {
        let temperature: Float
        let windspeed: Float
        let winddirection: Float
        let weathercode: Float
        let is_day: Float
        let temperature_unit: SiUnit
        let windspeed_unit: SiUnit
        let winddirection_unit: SiUnit
        let weathercode_unit: SiUnit
        let time: Timestamp
    }
    
    /// e.g. `52.52N13.42E38m`
    var formatedCoordinatesFilename: String {
        let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
        let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
        return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
    }
}



/// Stores the API output for multiple locations
struct ForecastapiResultSet {
    let timeformat: Timeformat
    let results: [ForecastapiResult]
    
    /// Output the given result set with a specified format
    /// timestamp and fixedGenerationTime are used to overwrite dynamic fields in unit tests
    func response(format: ForecastResultFormat, timestamp: Timestamp = .now(), fixedGenerationTime: Double? = nil) -> EventLoopFuture<Response> {
        return ForecastapiController.runLoop.next().submit {
            for location in results {
                try location.prefetch()
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

struct ApiColumn {
    let variable: String
    let unit: SiUnit
    let data: ApiArray
}

struct ApiSection {
    // e.g. hourly or daily
    let name: String
    let time: TimerangeDt
    let columns: [ApiColumn]
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
