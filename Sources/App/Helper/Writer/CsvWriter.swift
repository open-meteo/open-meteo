import Foundation
import Vapor


extension ForecastapiResult {
    /// Streaming CSV format. Once 3kb of text is accumulated, flush to next handler -> response compressor
    func toCsvResponse() throws -> Response {
        if results.count > 1000 {
            throw ForecastapiError.generic(message: "Only up to 1000 locations can be requested at once")
        }
        let response = Response(body: .init(stream: { writer in
            _ = writer.eventLoop.performWithTask {
                var b = BufferAndWriter(writer: writer)
                let multiLocation = results.count > 1
                
                if results.count == 1, let location = results.first, let first = location.results.first {
                    b.buffer.writeString("latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation\n")
                    let elevation = first.elevation.map({ $0.isFinite ? "\($0)" : "NaN" }) ?? "NaN"
                    b.buffer.writeString("\(first.latitude),\(first.longitude),\(elevation),\(location.utc_offset_seconds),\(location.timezone.identifier),\(location.timezone.abbreviation)\n")
                } else {
                    b.buffer.writeString("location_id,latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation\n")
                    for (i, location) in results.enumerated() {
                        guard let first = location.results.first else {
                            continue
                        }
                        let elevation = first.elevation.map({ $0.isFinite ? "\($0)" : "NaN" }) ?? "NaN"
                        b.buffer.writeString("\(i+1),\(first.latitude),\(first.longitude),\(elevation),\(location.utc_offset_seconds),\(location.timezone.identifier),\(location.timezone.abbreviation)\n")
                    }
                }
                for (i, location) in results.enumerated() {
                    try await location.current?().writeCsv(into: &b, timeformat: timeformat, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
                }
                for (i, location) in results.enumerated() {
                    try await location.minutely15?().writeCsv(into: &b, timeformat: timeformat, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
                }
                for (i, location) in results.enumerated() {
                    try await location.hourly?().writeCsv(into: &b, timeformat: timeformat, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
                }
                for (i, location) in results.enumerated() {
                    try await location.sixHourly?().writeCsv(into: &b, timeformat: timeformat, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
                }
                for (i, location) in results.enumerated() {
                    try await location.daily?().writeCsv(into: &b, timeformat: timeformat, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
                }
                try await b.flush()
                try await b.end()
            }
            
        }, count: -1))

        response.headers.replaceOrAdd(name: .contentType, value: "text/csv; charset=utf-8")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(results.first?.results.first?.formatedCoordinatesFilename ?? "").csv\"")
        return response
    }
}

extension ApiSectionSingle {
    fileprivate func writeCsv(into b: inout BufferAndWriter, timeformat: Timeformat, utc_offset_seconds: Int, location_id: Int?) async throws {
        if location_id == nil || location_id == 0 {
            b.buffer.writeString("\n")
            if location_id != nil {
                b.buffer.writeString("location_id,time")
            } else {
                b.buffer.writeString("time")
            }
            
            for e in columns {
                b.buffer.writeString(",\(e.variable) (\(e.unit.abbreviation))")
            }
            b.buffer.writeString("\n")
        }
        
        let time = self.time.formated(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: false)
        if let location_id {
            b.buffer.writeString("\(location_id+1),")
        }
        b.buffer.writeString(time)
        for e in columns {
            if e.value.isFinite {
                b.buffer.writeString(",\(String(format: "%.\(e.unit.significantDigits)f", e.value))")
            } else {
                b.buffer.writeString(",NaN")
            }
        }
        b.buffer.writeString("\n")
        try await b.flushIfRequired()
    }
}


extension ApiSectionString {
    /// Write a single API section into the output buffer
    fileprivate func writeCsv(into b: inout BufferAndWriter, timeformat: Timeformat, utc_offset_seconds: Int, location_id: Int?) async throws {
        if location_id == nil || location_id == 0 {
            b.buffer.writeString("\n")
            if location_id != nil {
                b.buffer.writeString("location_id,time")
            } else {
                b.buffer.writeString("time")
            }
            
            for e in columns {
                b.buffer.writeString(",\(e.variable) (\(e.unit.abbreviation))")
            }
            b.buffer.writeString("\n")
        }
        
        for (i, time) in time.itterate(format: timeformat, utc_offset_seconds: utc_offset_seconds, quotedString: false, onlyDate: time.dtSeconds == 86400).enumerated() {
            if let location_id {
                b.buffer.writeString("\(location_id+1),")
            }
            b.buffer.writeString(time)
            for e in columns {
                switch e.data {
                case .float(let a):
                    if a[i].isFinite {
                        b.buffer.writeString(",\(String(format: "%.\(e.unit.significantDigits)f", a[i]))")
                    } else {
                        b.buffer.writeString(",NaN")
                    }
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
}
