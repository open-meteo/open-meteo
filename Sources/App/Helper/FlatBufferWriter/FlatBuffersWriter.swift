import Foundation
import FlatBuffers
import Vapor
import OpenMeteoSdk


extension ForecastapiResult {
    /// Convert data into a FlatBuffers scheme far fast binary encoding and transfer
    /// Each `ForecastapiResult` is converted indifuavually into an flatbuffer message -> very long time-series require a lot of memory
    /// Data is using `size prefixed` flatbuffers to allow streaming of multiple messages for multiple locations
    func toFlatbuffersResponse(fixedGenerationTime: Double?) throws -> Response {
        // First excution outside stream, to capture potential errors better
        //var first = try self.first?()
        if results.count > 1000 {
            throw ForecastapiError.generic(message: "Only up to 1000 locations can be requested at once")
        }
        let response = Response(body: .init(stream: { writer in
            writer.submit {
                // TODO: Zero-copy for flatbuffer to NIO bytebuffer conversion. Probably writing an optimised flatbuffer encoder would be better.
                // TODO: Estimate initial buffer size
                let initialSize = Int32(4096) // Int32(((first?.estimatedFlatbufferSize ?? 4096)/4096+1)*4096)
                var fbb = FlatBufferBuilder(initialSize: initialSize)
                var b = BufferAndWriter(writer: writer)
                //if let first {
                //    first.writeToFlatbuffer(&fbb)
                //    b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                //    fbb.clear()
                //}
                //first = nil
                //try await b.flushIfRequired()
                for location in results {
                    for model in location.results {
                        try model.writeToFlatbuffer(&fbb, timezone: location.timezone, fixedGenerationTime: fixedGenerationTime)
                        b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                        fbb.clear()
                        try await b.flushIfRequired()
                    }
                }
                try await b.flush()
                try await b.end()
            }
        }))
        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        return response
    }
}

fileprivate extension FlatBuffers.ByteBuffer {
    /// Create a pointer to the data region. Flatbuffer is filling the buffer backwards.
    var unsafeRawBufferPointer: UnsafeRawBufferPointer {
        .init(start: memory.advanced(by: self.capacity - Int(self.size)), count: Int(size))
    }
}

/// Encode meta data for flatbuffer variables
struct FlatBufferVariableMeta {
    let variable: openmeteo_sdk_Variable
    let aggregation: openmeteo_sdk_Aggregation
    let altitude: Int16
    let pressureLevel: Int16
    let depth: Int16
    let depthTo: Int16
    
    init(variable: openmeteo_sdk_Variable, aggregation: openmeteo_sdk_Aggregation = .none_, altitude: Int16 = 0, pressureLevel: Int16 = 0, depth: Int16 = 0, depthTo: Int16 = 0) {
        self.variable = variable
        self.aggregation = aggregation
        self.altitude = altitude
        self.pressureLevel = pressureLevel
        self.depth = depth
        self.depthTo = depthTo
    }
    
    fileprivate func encodeToFlatBuffers(_ fbb: inout FlatBufferBuilder) {
        openmeteo_sdk_Series.add(variable: variable, &fbb)
        openmeteo_sdk_Series.add(aggregation: aggregation, &fbb)
        openmeteo_sdk_Series.add(altitude: altitude, &fbb)
        openmeteo_sdk_Series.add(pressureLevel: pressureLevel, &fbb)
        openmeteo_sdk_Series.add(depth: depth, &fbb)
        openmeteo_sdk_Series.add(depthTo: depthTo, &fbb)
    }
}

extension VariableOrDerived: FlatBuffersVariable where Raw: FlatBuffersVariable, Derived: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .raw(let raw):
            return raw.getFlatBuffersMeta()
        case .derived(let derived):
            return derived.getFlatBuffersMeta()
        }
    }
}

extension ApiArray {
    func encodeFlatBuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        switch self {
        case .float(let values):
            return fbb.createVector(values)
        case .timestamp(let values):
            return fbb.createVector(values.map({Int64($0.timeIntervalSince1970)}))
        }
    }
}

extension ApiSection where Variable: FlatBuffersVariable {
    func encodeFlatBuffers(_ fbb: inout FlatBufferBuilder, memberOffset: Int) -> Offset {
        let offsets = fbb.createVector(ofOffsets: self.columns.flatMap { c -> [Offset] in
            return c.variables.enumerated().map { (member,v) in
                let data = v.encodeFlatBuffers(&fbb)
                let series = openmeteo_sdk_Series.startSeries(&fbb)
                c.variable.getFlatBuffersMeta().encodeToFlatBuffers(&fbb)
                openmeteo_sdk_Series.add(unit: c.unit, &fbb)
                if c.variables.count > 1 {
                    openmeteo_sdk_Series.add(ensembleMember: Int16(member + memberOffset), &fbb)
                }
                switch v {
                case .float(_):
                    openmeteo_sdk_Series.addVectorOf(values: data, &fbb)
                case .timestamp(_):
                    openmeteo_sdk_Series.addVectorOf(valuesInt64: data, &fbb)
                }
                return openmeteo_sdk_Series.endSeries(&fbb, start: series)
            }
        })
        return openmeteo_sdk_SeriesAndTime.createSeriesAndTime(
            &fbb,
            start: Int64(time.range.lowerBound.timeIntervalSince1970),
            end: Int64(time.range.upperBound.timeIntervalSince1970),
            interval: Int32(time.dtSeconds), 
            seriesVectorOffset: offsets
        )
    }
}

extension ApiSectionSingle where Variable: FlatBuffersVariable {
    func encodeFlatBuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = fbb.createVector(ofOffsets: self.columns.map { c -> Offset in
            let series = openmeteo_sdk_Series.startSeries(&fbb)
            c.variable.getFlatBuffersMeta().encodeToFlatBuffers(&fbb)
            openmeteo_sdk_Series.add(unit: c.unit, &fbb)
            openmeteo_sdk_Series.add(value: c.value, &fbb)
            return openmeteo_sdk_Series.endSeries(&fbb, start: series)
        })
        return openmeteo_sdk_SeriesAndTime.createSeriesAndTime(
            &fbb,
            start: Int64(time.timeIntervalSince1970),
            end: Int64(time.timeIntervalSince1970 + dtSeconds),
            interval: Int32(dtSeconds),
            seriesVectorOffset: offsets
        )
    }
}

extension ForecastapiResult.PerModel {
    func writeToFlatbuffer(_ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try hourly?()).map { $0.encodeFlatBuffers(&fbb, memberOffset: Model.memberOffset) } ?? Offset()
        let minutely15 = (try minutely15?()).map { $0.encodeFlatBuffers(&fbb, memberOffset: Model.memberOffset) } ?? Offset()
        let sixHourly = (try sixHourly?()).map { $0.encodeFlatBuffers(&fbb, memberOffset: Model.memberOffset) } ?? Offset()
        let daily = (try daily?()).map { $0.encodeFlatBuffers(&fbb, memberOffset: Model.memberOffset) } ?? Offset()
        let current = (try current?()).map { $0.encodeFlatBuffers(&fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = openmeteo_sdk_ApiResponse.createApiResponse (
            &fbb,
            latitude: latitude,
            longitude: longitude,
            elevation: elevation ?? .nan,
            model: model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: timezone.identifier == "GMT" ? Offset() : fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: timezone.abbreviation == "GMT" ? Offset() : fbb.create(string: timezone.abbreviation),
            currentOffset: current, 
            dailyOffset: daily,
            hourlyOffset: hourly,
            sixHourlyOffset: sixHourly,
            minutely15Offset: minutely15
        )
        fbb.finish(offset: result, addPrefix: true)
    }
}


