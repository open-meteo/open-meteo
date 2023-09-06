import Foundation
import FlatBuffers
import Vapor


extension ForecastapiResult {
    /// Convert data into a FlatBuffers scheme far fast binary encoding and transfer
    /// Data is using `size prefixed` flatbuffers to allow streaming of multiple messages for multiple locations
    func toFlatbuffersResponse() -> Response {
        let response = Response(body: .init(stream: { writer in
            _ = writer.eventLoop.performWithTask {
                // TODO make a good guess for the initial size
                var fbb = FlatBufferBuilder(initialSize: 1024)
                let currentWeather = self.current_weather.map { c in
                    com_openmeteo_api_result_CurrentWeather(time: Int64(c.time.timeIntervalSince1970), temperature: c.temperature, weathercode: c.weathercode, windspeed: c.windspeed, winddirection: c.winddirection)
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
                let nioBuffer = fbb.buffer.copyToNioByteBuffer()
                try await writer.eventLoop.flatSubmit { writer.write(.buffer(nioBuffer)) }.get()
                try await writer.eventLoop.flatSubmit { writer.write(.end) }.get()
                
                //fbb.clear()
                
                //let a = com_openmeteo_api_result_Result.init(builder.buffer, o: 0)
                /*var buf = fbb.buffer
                //let a = getPrefixedSizeRoot(byteBuffer: &buf) as com_openmeteo_api_result_Result
                //let a = try getCheckedPrefixedSizeRoot(byteBuffer: &buf) as com_openmeteo_api_result_Result
                let a = try getPrefixedSizeCheckedRoot(byteBuffer: &buf) as com_openmeteo_api_result_Result
                print(a.latitude)
                print(a.longitude)
                print(a.hasHourly)
                print(a.hourlyCount)*/
                
            }
        }, count: -1))
        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        //response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(formatedCoordinatesFilename).csv\"")
        return response
    }
}

fileprivate extension FlatBuffers.ByteBuffer {
    /// Copy data from Flatbuffers to NIO
    /// TODO figure out a way to do this zero copy
    func copyToNioByteBuffer() -> NIOCore.ByteBuffer {
        var nio = NIOCore.ByteBuffer()
        let ptr = UnsafeRawBufferPointer(start: memory.advanced(by: self.capacity - Int(self.size)), count: Int(size))
        nio.writeBytes(ptr)
        return nio
    }
}

fileprivate extension ApiSection {
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        return fbb.createVector(ofOffsets: columns.compactMap({ $0.toFlatbuffers(&fbb) }))
    }
}

fileprivate extension ApiColumn {
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset? {
        switch data {
        //case .string(_):
        //    return nil
        case .float(let data):
            return com_openmeteo_api_result_Variable.createVariable(&fbb, variableOffset: fbb.create(string: variable), unitOffset: fbb.create(string: unit.rawValue), valuesVectorOffset: fbb.createVector(data))
        //case .int(_):
        //    return nil
        case .timestamp(_):
            return nil
        }
    }
}
