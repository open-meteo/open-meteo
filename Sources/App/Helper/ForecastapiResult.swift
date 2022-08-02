
import Foundation
import Vapor


enum ApiArray {
    case string([String])
    case float([Float])
    case int([Int])
    case timestamp([Timestamp])
    
    var count: Int {
        switch self {
        case .string(let a):
            return a.count
        case .float(let a):
            return a.count
        case .int(let a):
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
}

/// Simplify flush commands
fileprivate struct BufferAndWriter {
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

/**
 Store the result of a API forecast result and converion to JSON
 */
struct ForecastapiResult {
    let latitude: Float
    let longitude: Float
    let elevation: Float?
    let generationtime_ms: Double
    let utc_offset_seconds: Int
    let current_weather: CurrentWeather?
    let sections: [ApiSection]
    let timeformat: Timeformat
    
    struct CurrentWeather {
        let temperature: Float
        let windspeed: Float
        let winddirection: Float
        let weathercode: Float
        let temperature_unit: SiUnit
        let windspeed_unit: SiUnit
        let winddirection_unit: SiUnit
        let weathercode_unit: SiUnit
        let time: Timestamp
    }
    
    func response(format: ForecastResultFormat, timestamp: Timestamp = .now()) throws -> Response {
        switch format {
        case .json:
            return toJsonResponse()
        case .xlsx:
            return try toXlsxResponse(timestamp: timestamp)
        case .csv:
            return toCsvResponse()
        }
    }
    
    /// e.g. `52.52N13.42E38m`
    var formatedCoordinatesFilename: String {
        let lat = latitude < 0 ? String(format: "%.2fS", abs(latitude)) : String(format: "%.2fN", latitude)
        let ele = elevation.map { $0.isNaN ? "" : String(format: "%.0fm", $0) } ?? ""
        return longitude < 0 ? String(format: "\(lat)%.2fW\(ele)", abs(longitude)) : String(format: "\(lat)%.2fE\(ele)", longitude)
    }
    
    /// Streaming CSV format. Once 3kb of text is accumulated, flush to next handler -> response compressor
    private func toCsvResponse() -> Response {
        let response = Response(body: .init(stream: { writer in
            _ = writer.eventLoop.performWithTask {
                var b = BufferAndWriter(writer: writer)
                
                b.buffer.writeString("latitude,longitude,elevation,utc_offset_seconds\n")
                let ele = elevation.map({ $0.isNaN ? "NaN" : "\($0)" }) ?? "NaN"
                b.buffer.writeString("\(latitude),\(longitude),\(ele),\(utc_offset_seconds)\n")
                
                if let current_weather = current_weather {
                    b.buffer.writeString("\n")
                    b.buffer.writeString("current_weather_time,temperature (\(current_weather.temperature_unit.rawValue)),windspeed (\(current_weather.windspeed_unit.rawValue)),winddirection (\(current_weather.winddirection_unit.rawValue)),weathercode (\(current_weather.weathercode_unit.rawValue))\n")
                    b.buffer.writeString(current_weather.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: false))
                    b.buffer.writeString(",\(current_weather.temperature),\(current_weather.windspeed),\(current_weather.winddirection),\(current_weather.weathercode)\n")
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
                            case .string(let a):
                                b.buffer.writeString(",")
                                b.buffer.writeString(a[i])
                            case .float(let a):
                                if a[i].isNaN {
                                    b.buffer.writeString(",NaN")
                                } else {
                                    b.buffer.writeString(",\(a[i])")
                                }
                            case .int(let a):
                                b.buffer.writeString(",\(a[i])")
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
    
    private func toXlsxResponse(timestamp: Timestamp) throws -> Response {
        let sheet = try XlsxWriter()
        sheet.startRow()
        sheet.write("latitude")
        sheet.write("longitude")
        sheet.write("elevation")
        sheet.write("utc_offset_seconds")
        sheet.endRow()
        sheet.startRow()
        sheet.write(latitude)
        sheet.write(longitude)
        sheet.write(elevation ?? .nan)
        sheet.write(utc_offset_seconds)
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
            sheet.endRow()
            sheet.startRow()
            sheet.writeTimestamp(current_weather.time.add(utc_offset_seconds))
            sheet.write(current_weather.temperature)
            sheet.write(current_weather.windspeed)
            sheet.write(current_weather.winddirection)
            sheet.write(current_weather.weathercode)
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
                    case .string(let a):
                        sheet.write(a[i])
                    case .float(let a):
                        sheet.write(a[i])
                    case .int(let a):
                        sheet.write(a[i])
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
    
    /**
     Stream a potentially very large resultset to the client. The JSON file could easily be 20 MB.
     Instead of generating a massive string in memory, we only allocate 18kb and flush every time the buffer exceeds 16kb.
     Memory footprint is therefore much smaller and fits better into L2/L3 caches.
     Additionally code is fully async, to not block the a thread for almost a second to generate a JSON response...
     */
    private func toJsonResponse() -> Response {
        let response = Response(body: .init(stream: { writer in
            _ = writer.eventLoop.performWithTask {
                var b = BufferAndWriter(writer: writer)

                b.buffer.writeString("""
                {"latitude":\(latitude),"longitude":\(longitude),"generationtime_ms":\(generationtime_ms),"utc_offset_seconds":\(utc_offset_seconds)
                """)
                if let elevation = elevation, !elevation.isNaN {
                    b.buffer.writeString(",\"elevation\":\(elevation)")
                }
                if let current_weather = current_weather {
                    b.buffer.writeString("""
                        ,"current_weather":{"temperature":\(current_weather.temperature),"windspeed":\(current_weather.windspeed),"winddirection":\(current_weather.winddirection),"weathercode":\(current_weather.weathercode),"time":
                        """)
                    b.buffer.writeString(current_weather.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: true))
                    b.buffer.writeString("}")
                }
                
                /// process sections like hourly or daily
                for section in sections {
                    b.buffer.writeString(",\"\(section.name)_units\":")
                    b.buffer.writeString("{")
                    switch timeformat {
                    case .iso8601:
                        b.buffer.writeString("\"time\":\"\(SiUnit.iso8601.rawValue)\",")
                    case .unixtime:
                        b.buffer.writeString("\"time\":\"\(SiUnit.unixtime.rawValue)\",")
                    }
                    
                    var firstKey = true
                    for e in section.columns {
                        if firstKey {
                            firstKey = false
                        } else {
                            b.buffer.writeString(",")
                        }
                        b.buffer.writeString("\"\(e.variable)\":\"\(e.unit.rawValue)\"")
                        try await b.flushIfRequired()
                    }
                    b.buffer.writeString("}")
                    b.buffer.writeString(",\"\(section.name)\":")
                    b.buffer.writeString("{")
                    b.buffer.writeString("\"time\":[")
                    
                    // Write time axis
                    var firstValue = true
                    for time in section.time.itterate(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: true, onlyDate: section.time.dtSeconds == 86400) {
                        if firstValue {
                            firstValue = false
                        } else {
                            b.buffer.writeString(",")
                        }
                        b.buffer.writeString(time)
                        try await b.flushIfRequired()
                    }
                    b.buffer.writeString("]")
                    
                    /// Write data
                    for e in section.columns {
                        b.buffer.writeString(",")
                        b.buffer.writeString("\"\(e.variable)\":")
                        b.buffer.writeString("[")
                        var firstValue = true
                        switch e.data {
                        case .string(let strings):
                            for v in strings {
                                if firstValue {
                                    firstValue = false
                                } else {
                                    b.buffer.writeString(",")
                                }
                                b.buffer.writeString("\"\(v)\"")
                                try await b.flushIfRequired()
                            }
                        case .float(let floats):
                            for v in floats {
                                if firstValue {
                                    firstValue = false
                                } else {
                                    b.buffer.writeString(",")
                                }
                                if v.isNaN {
                                    b.buffer.writeString("null")
                                } else {
                                    b.buffer.writeString("\(v)")
                                }
                                try await b.flushIfRequired()
                            }
                        case .int(let ints):
                            for v in ints {
                                if firstValue {
                                    firstValue = false
                                } else {
                                    b.buffer.writeString(",")
                                }
                                b.buffer.writeString("\(v)")
                                try await b.flushIfRequired()
                            }
                        case .timestamp(let timestamps):
                            for time in timestamps.itterate(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: true, onlyDate: false) {
                                if firstValue {
                                    firstValue = false
                                } else {
                                    b.buffer.writeString(",")
                                }
                                b.buffer.writeString(time)
                                try await b.flushIfRequired()
                            }
                        }
                        b.buffer.writeString("]")
                        try await b.flushIfRequired()
                    }
                    b.buffer.writeString("}")
                }
                b.buffer.writeString("}")
                try await b.flush()
                try await b.end()
            }
            
        }, count: -1))

        response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        return response
    }
}

fileprivate extension Timestamp {
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

fileprivate extension Sequence where Element == Timestamp {
    /// includes quotes characters if `quotedString` is true
    func itterateIso8601(utc_offset_seconds: Int, quotedString: Bool, onlyDate: Bool) -> AnySequence<String> {
        return AnySequence<String> { () -> AnyIterator<String> in
            var itterator = self.makeIterator()
            var t = tm()
            var dateCalculated = 0
            
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
                
                let hour = time % 86400 / 3600
                let minute = time % 3600 / 60
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
