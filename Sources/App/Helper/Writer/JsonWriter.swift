import Foundation
import Vapor

extension BodyStreamWriter {
    /// Execute async code and capture any errors. In case of error, print the error to the output stream
    func submit(_ task: @escaping () async throws -> Void) {
        _ = eventLoop.performWithTask { try await task() }
            .flatMapError({ error in
                write(.buffer(.init(string: "Unexpected error while streaming data: \(error)")))
                    .flatMap({write(.error(error))})
        })
    }
}

extension ForecastapiResultSet {
    /**
     Stream a potentially very large resultset to the client. The JSON file could easily be 20 MB.
     Instead of generating a massive string in memory, we only allocate 18kb and flush every time the buffer exceeds 16kb.
     Memory footprint is therefore much smaller and fits better into L2/L3 caches.
     Additionally code is fully async, to not block the a thread for almost a second to generate a JSON response...
     */
    func toJsonResponse(fixedGenerationTime: Double?) throws -> Response {
        // First excution outside stream, to capture potential errors better
        //var first = try self.first?()
        if results.count > 1000 {
            throw ForecastapiError.generic(message: "Only up to 1000 locations can be requested at once")
        }
        let response = Response(body: .init(stream: { writer in
            writer.submit {
                var b = BufferAndWriter(writer: writer)
                /// For multiple locations, create an array of results
                let isMultiPoint = results.count > 1
                if isMultiPoint {
                    b.buffer.writeString("[")
                }
                /*if let first {
                    try await first.streamJsonResponse(to: &b)
                }
                first = nil*/
                for (i,location) in results.enumerated() {
                    if i != 0 {
                        b.buffer.writeString(",")
                    }
                    try await location.streamJsonResponse(to: &b, timeformat: timeformat, fixedGenerationTime: fixedGenerationTime)
                }
                if isMultiPoint {
                    b.buffer.writeString("]")
                }
                try await b.flush()
                try await b.end()
            }
        }))
        response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        return response
    }
}

extension ForecastapiResultMulti {
    fileprivate func streamJsonResponse(to b: inout BufferAndWriter, timeformat: Timeformat, fixedGenerationTime: Double?) async throws {
        let generationTimeStart = Date()
        guard let first = results.first else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        let current_weather = try first.current_weather?()
        let current = try first.current?()
        let sections = try runAllSections()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        b.buffer.writeString("""
        {"latitude":\(first.latitude),"longitude":\(first.longitude),"generationtime_ms":\(generationTimeMs),"utc_offset_seconds":\(utc_offset_seconds),"timezone":"\(timezone.identifier)","timezone_abbreviation":"\(timezone.abbreviation)"
        """)
        if let elevation = first.elevation, elevation.isFinite {
            b.buffer.writeString(",\"elevation\":\(elevation)")
        }
        if let current_weather = current_weather {
            let ww = current_weather.weathercode.isFinite ? String(format: "%.0f", current_weather.weathercode) : "null"
            let is_day = current_weather.is_day.isFinite ? String(format: "%.0f", current_weather.is_day) : "null"
            let winddirection = current_weather.winddirection.isFinite ? String(format: "%.0f", current_weather.winddirection) : "null"
            let windspeed = current_weather.windspeed.isFinite ? "\(current_weather.windspeed)" : "null"
            let temperature = current_weather.temperature.isFinite ? "\(current_weather.temperature)" : "null"
            b.buffer.writeString("""
                ,"current_weather":{"temperature":\(temperature),"windspeed":\(windspeed),"winddirection":\(winddirection),"weathercode":\(ww),"is_day":\(is_day),"time":
                """)
            b.buffer.writeString(current_weather.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: true))
            b.buffer.writeString("}")
        }
        
        if let current {
            b.buffer.writeString(",\"\(current.name)_units\":")
            b.buffer.writeString("{")
            switch timeformat {
            case .iso8601:
                b.buffer.writeString("\"time\":\"\(SiUnit.iso8601.abbreviation)\"")
            case .unixtime:
                b.buffer.writeString("\"time\":\"\(SiUnit.unixtime.abbreviation)\"")
            }
            for e in current.columns {
                b.buffer.writeString(",\"\(e.variable)\":\"\(e.unit.abbreviation)\"")
            }
            b.buffer.writeString("}")
            b.buffer.writeString(",\"\(current.name)_interval_seconds\":\(current.dtSeconds)")
            b.buffer.writeString(",\"\(current.name)\":")
            b.buffer.writeString("{")
            b.buffer.writeString("\"time\":")
            b.buffer.writeString(current.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: true))
            
            /// Write data
            for e in current.columns {
                let format = "%.\(e.unit.significantDigits)f"
                b.buffer.writeString(",")
                b.buffer.writeString("\"\(e.variable)\":\(e.value.isFinite ? String(format: format, e.value) : "null")")
            }
            b.buffer.writeString("}")
            try await b.flushIfRequired()
        }
        
        /// process sections like hourly or daily
        for section in sections {
            b.buffer.writeString(",\"\(section.name)_units\":")
            b.buffer.writeString("{")
            switch timeformat {
            case .iso8601:
                b.buffer.writeString("\"time\":\"\(SiUnit.iso8601.abbreviation)\"")
            case .unixtime:
                b.buffer.writeString("\"time\":\"\(SiUnit.unixtime.abbreviation)\"")
            }
            for e in section.columns {
                b.buffer.writeString(",\"\(e.variable)\":\"\(e.unit.abbreviation)\"")
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
                case .float(let floats):
                    let format = "%.\(e.unit.significantDigits)f"
                    for v in floats {
                        if firstValue {
                            firstValue = false
                        } else {
                            b.buffer.writeString(",")
                        }
                        if v.isFinite {
                            b.buffer.writeString(String(format: format, v))
                        } else {
                            b.buffer.writeString("null")
                        }
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
    }
}
