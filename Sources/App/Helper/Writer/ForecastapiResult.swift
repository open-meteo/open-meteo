
import Foundation
import Vapor


enum ApiArray {
    //case string([String])
    case float([Float])
    //case int([Int])
    case timestamp([Timestamp])
    
    var count: Int {
        switch self {
        //case .string(let a):
        //    return a.count
        case .float(let a):
            return a.count
        //case .int(let a):
        //    return a.count
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

extension Array where Element == () throws -> ForecastapiResult {
    func response(format: ForecastResultFormat, timestamp: Timestamp = .now()) -> EventLoopFuture<Response> {
        return ForecastapiController.runLoop.next().submit {
            switch format {
            case .json:
                return try toJsonResponse()
            case .xlsx:
                // TODO: Multi location support
                return try first!().toXlsxResponse(timestamp: timestamp)
            case .csv:
                // TODO: Multi location support
                return try first!().toCsvResponse()
            case .flatbuffers:
                return try toFlatbuffersResponse()
            }
        }
    }
}

/**
 Store the result of a API forecast result and converion to JSON
 */
struct ForecastapiResult {
    let latitude: Float
    let longitude: Float
    
    /// Desired elevation from a DEM. Used in statistical downscaling
    let elevation: Float?
    
    let generationtime_ms: Double
    let timezone: TimezoneWithOffset
    let current_weather: CurrentWeather?
    let sections: [ApiSection]
    let timeformat: Timeformat
    
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
    
    func response(format: ForecastResultFormat, timestamp: Timestamp = .now()) throws -> EventLoopFuture<Response> {
        let res: [() throws -> (ForecastapiResult)] = [{return self}]
        return res.response(format: format, timestamp: timestamp)
    }
    
    /// e.g. `52.52N13.42E38m`
    var formatedCoordinatesFilename: String {
        let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
        let ele = elevation.map { $0.isFinite ? String(format: "%.0fm", $0) : "" } ?? ""
        return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
    }
    
    /// Streaming CSV format. Once 3kb of text is accumulated, flush to next handler -> response compressor
    fileprivate func toCsvResponse() -> Response {
        let response = Response(body: .init(stream: { writer in
            _ = writer.eventLoop.performWithTask {
                var b = BufferAndWriter(writer: writer)
                
                b.buffer.writeString("latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation\n")
                let elevation = elevation.map({ $0.isFinite ? "\($0)" : "NaN" }) ?? "NaN"
                b.buffer.writeString("\(latitude),\(longitude),\(elevation),\(utc_offset_seconds),\(timezone.identifier),\(timezone.abbreviation)\n")
                
                if let current_weather = current_weather {
                    b.buffer.writeString("\n")
                    b.buffer.writeString("current_weather_time,temperature (\(current_weather.temperature_unit.rawValue)),windspeed (\(current_weather.windspeed_unit.rawValue)),winddirection (\(current_weather.winddirection_unit.rawValue)),weathercode (\(current_weather.weathercode_unit.rawValue)),is_day\n")
                    b.buffer.writeString(current_weather.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: false))
                    let ww = current_weather.weathercode.isFinite ? String(format: "%.0f", current_weather.weathercode) : "NaN"
                    let winddirection = current_weather.winddirection.isFinite ? String(format: "%.0f", current_weather.winddirection) : "NaN"
                    let is_day = current_weather.is_day.isFinite ? String(format: "%.0f", current_weather.is_day) : "NaN"
                    b.buffer.writeString(",\(current_weather.temperature),\(current_weather.windspeed),\(winddirection),\(ww),\(is_day)\n")
                }
                
                for section in sections {
                    // empy line between sections
                    b.buffer.writeString("\n")
                    
                    b.buffer.writeString("time")
                    for e in section.columns {
                        b.buffer.writeString(",\(e.variable) (\(e.unit.rawValue))")
                    }
                    b.buffer.writeString("\n")
                    for (i, time) in section.time.itterate(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: false, onlyDate: section.time.dtSeconds == 86400).enumerated() {
                        b.buffer.writeString(time)
                        for e in section.columns {
                            switch e.data {
                            /*case .string(let a):
                                b.buffer.writeString(",")
                                b.buffer.writeString(a[i])*/
                            case .float(let a):
                                if a[i].isFinite {
                                    b.buffer.writeString(",\(String(format: "%.\(e.unit.significantDigits)f", a[i]))")
                                } else {
                                    b.buffer.writeString(",NaN")
                                }
                            /*case .int(let a):
                                b.buffer.writeString(",\(a[i])")*/
                            case .timestamp(let a):
                                switch timeformat {
                                case .iso8601:
                                    b.buffer.writeString(",\(a[i].add(utc_offset_seconds).iso8601_YYYY_MM_dd_HH_mm)")
                                case .unixtime:
                                    b.buffer.writeString(",\(a[i].timeIntervalSince1970)")
                                }
                            }
                        }
                        b.buffer.writeString("\n")
                        try await b.flushIfRequired()
                    }
                }
                try await b.flush()
                try await b.end()
            }
            
        }, count: -1))

        response.headers.replaceOrAdd(name: .contentType, value: "text/csv; charset=utf-8")
        //response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(formatedCoordinatesFilename).csv\"")
        return response
    }
    
    fileprivate func toXlsxResponse(timestamp: Timestamp) throws -> Response {
        let sheet = try XlsxWriter()
        sheet.startRow()
        sheet.write("latitude")
        sheet.write("longitude")
        sheet.write("elevation")
        sheet.write("utc_offset_seconds")
        sheet.write("timezone")
        sheet.write("timezone_abbreviation")
        sheet.endRow()
        sheet.startRow()
        sheet.write(latitude)
        sheet.write(longitude)
        sheet.write(elevation ?? .nan)
        sheet.write(utc_offset_seconds)
        sheet.write(timezone.identifier)
        sheet.write(timezone.abbreviation)
        sheet.endRow()
        
        if let current_weather = current_weather {
            sheet.startRow()
            sheet.endRow()
            sheet.startRow()
            sheet.write("current_weather_time")
            sheet.write("temperature (\(current_weather.temperature_unit.rawValue))")
            sheet.write("windspeed (\(current_weather.windspeed_unit.rawValue))")
            sheet.write("winddirection (\(current_weather.winddirection_unit.rawValue))")
            sheet.write("weathercode (\(current_weather.weathercode_unit.rawValue))")
            sheet.write("is_day")
            sheet.endRow()
            sheet.startRow()
            sheet.writeTimestamp(current_weather.time.add(utc_offset_seconds))
            sheet.write(current_weather.temperature)
            sheet.write(current_weather.windspeed)
            sheet.write(current_weather.winddirection)
            sheet.write(current_weather.weathercode)
            sheet.write(current_weather.is_day)
            sheet.endRow()
        }
        
        for section in sections {
            sheet.startRow()
            sheet.endRow()
            sheet.startRow()
            sheet.write("time")
            for e in section.columns {
                sheet.write("\(e.variable) (\(e.unit.rawValue))")
            }
            sheet.endRow()
            for (i, time) in section.time.enumerated() {
                sheet.startRow()
                sheet.writeTimestamp(time.add(utc_offset_seconds))
                for e in section.columns {
                    switch e.data {
                    /*case .string(let a):
                        sheet.write(a[i])*/
                    case .float(let a):
                        sheet.write(a[i])
                    /*case .int(let a):
                        sheet.write(a[i])*/
                    case .timestamp(let a):
                        sheet.writeTimestamp(a[i].add(utc_offset_seconds))
                    }
                }
                sheet.endRow()
            }
        }
        
        let data = sheet.write(timestamp: timestamp)
        let response = Response(body: .init(buffer: data))
        response.headers.replaceOrAdd(name: .contentType, value: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(formatedCoordinatesFilename).xlsx\"")
        return response
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
