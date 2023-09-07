import Foundation
import FlatBuffers
import Vapor

extension Array where Element == () throws -> ForecastapiResult {
    /// Convert data into a FlatBuffers scheme far fast binary encoding and transfer
    /// Each `ForecastapiResult` is converted indifuavually into an flatbuffer message -> very long time-series require a lot of memory
    /// Data is using `size prefixed` flatbuffers to allow streaming of multiple messages for multiple locations
    func toFlatbuffersResponse() throws -> Response {
        // First excution outside stream, to capture potential errors better
        var first = try self.first?()
        
        let response = Response(body: .init(stream: { writer in
            writer.submit {
                // TODO: Zero-copy for flatbuffer to NIO bytebuffer conversion. Probably writing an optimised flatbuffer encoder would be better.
                let initialSize = Int32(((first?.estimatedFlatbufferSize ?? 4096)/4096+1)*4096)
                var fbb = FlatBufferBuilder(initialSize: initialSize)
                var b = BufferAndWriter(writer: writer)
                if let first {
                    first.writeToFlatbuffer(&fbb)
                    b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                    fbb.clear()
                }
                first = nil
                try await b.flushIfRequired()
                for closure in self.dropFirst() {
                    let result = try closure()
                    result.writeToFlatbuffer(&fbb)
                    b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                    fbb.clear()
                    try await b.flushIfRequired()
                }
                try await b.flush()
                try await b.end()
            }
        }))
        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        return response
    }
}

fileprivate extension ForecastapiResult {
    /// Write data into `FlatBufferBuilder` and finish the message
    func writeToFlatbuffer(_ fbb: inout FlatBufferBuilder) {
        let currentWeather = self.current_weather.map { c in
            com_openmeteo_api_result_CurrentWeather(
                time: Int64(c.time.timeIntervalSince1970),
                temperature: c.temperature,
                weathercode: c.weathercode,
                windspeed: c.windspeed,
                winddirection: c.winddirection,
                isDay: c.is_day
            )
        }
        let time = self.sections.first?.time.range.lowerBound.timeIntervalSince1970 ?? 0
        let hourly = self.sections.first(where: {$0.name == "hourly"})?.toFlatbuffers(&fbb) ?? Offset()
        let daily = self.sections.first(where: {$0.name == "daily"})?.toFlatbuffers(&fbb) ?? Offset()
        let minutely15 = self.sections.first(where: {$0.name == "minutely_15"})?.toFlatbuffers(&fbb) ?? Offset()
        let result = com_openmeteo_api_result_Result.createResult(
            &fbb,
            latitude: self.latitude,
            longitude: self.longitude,
            elevation: self.elevation ?? .nan,
            generationtimeMs: Float32(self.generationtime_ms),
            utcOffsetSeconds: Int32(self.utc_offset_seconds),
            timezoneOffset: fbb.create(string: self.timezone.identifier),
            timezoneAbbreviationOffset: fbb.create(string: self.timezone.abbreviation() ?? ""),
            currentWeather: currentWeather,
            timeStart: Int64(time),
            dailyVectorOffset: daily,
            hourlyVectorOffset: hourly,
            minutely15VectorOffset: minutely15
        )
        fbb.finish(offset: result, addPrefix: true)
    }
    
    /// Roughly estimate the required size to keep the flatbuffer message in memory. Overestimation is expected.
    var estimatedFlatbufferSize: Int {
        let dataSize = 24 + sections.reduce(0, {$0 + $1.estimatedFlatbufferSize})
        return dataSize + 512
    }
}

fileprivate extension FlatBuffers.ByteBuffer {
    /// Create a pointer to the data region. Flatbuffer is filling the buffer backwards.
    var unsafeRawBufferPointer: UnsafeRawBufferPointer {
        .init(start: memory.advanced(by: self.capacity - Int(self.size)), count: Int(size))
    }
}

fileprivate extension ApiSection {
    var estimatedFlatbufferSize: Int {
        24 + columns.reduce(0, {$0 + $1.unit.rawValue.count + $1.variable.count + $1.data.count * 4 + 24})
    }
        
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        return fbb.createVector(ofOffsets: columns.compactMap({ $0.toFlatbuffers(&fbb, timerange: time) }))
    }
}

fileprivate extension ApiColumn {
    
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder, timerange: TimerangeDt) -> Offset? {
        switch data {
        //case .string(_):
        //    return nil
        case .float(let data):
            return com_openmeteo_api_result_Variable.createVariable(&fbb, variableOffset: fbb.create(string: variable), unitOffset: fbb.create(string: unit.rawValue), valuesVectorOffset: fbb.createVector(data))
        //case .int(_):
        //    return nil
        case .timestamp(let times):
            /// only used for sunrise / sunset
            /// convert unixtimestamp to seconds after midnight
            let secondsAfterMidnight = zip(timerange, times).map { (midnight, time) in
                return Float(time.timeIntervalSince1970 - midnight.timeIntervalSince1970)
            }
            return com_openmeteo_api_result_Variable.createVariable(&fbb, variableOffset: fbb.create(string: variable), unitOffset: fbb.create(string: unit.rawValue), valuesVectorOffset: fbb.createVector(secondsAfterMidnight))
        }
    }
}
