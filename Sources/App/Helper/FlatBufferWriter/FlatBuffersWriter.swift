import Foundation
import FlatBuffers
import Vapor

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
                        try Model.writeToFlatbuffer(section: model, &fbb, timezone: location.timezone, fixedGenerationTime: fixedGenerationTime)
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

extension ForecastapiResult {
    /// Encodes daily data to eigher `ValuesAndUnit` or just plain `int64` for timestamps (e.g. sunrise/set)
    static func encode(section: ApiSection<Model.DailyVariable>, _ fbb: inout FlatBufferBuilder) -> [Offset] {
        let offsets: [Offset] = section.columns.map { v in
            switch v.variables[0] {
            case .float(let float):
                return com_openmeteo_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: fbb.createVector(float), unit: v.unit)
            case .timestamp(let time):
                return fbb.createVector(time.map({$0.timeIntervalSince1970}))
            }
        }
        return offsets
    }
    
    /// Encodes hourly/minutely data
    static func encode(section: ApiSection<SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> (surface: [(variable: Model.HourlyVariable, offset: Offset)], pressure: [(variable: Model.HourlyPressureType, offset: Offset)]) {
        var surfaces = [(variable: Model.HourlyVariable, offset: Offset)]()
        surfaces.reserveCapacity(section.columns.count)
        var pressures = [(variable: Model.HourlyPressureType, unit: SiUnit, offsets: [Offset])]()
        
        for v in section.columns {
            switch v.variable {
            case .surface(let surface):
                let offset = com_openmeteo_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: v.variables[0].expectFloatArray(&fbb), unit: v.unit)
                surfaces.append((surface, offset))
            case .pressure(let pressure):
                let offset = com_openmeteo_ValuesAndLevel.createValuesAndLevel(&fbb, level: Int32(pressure.level), valuesVectorOffset: v.variables[0].expectFloatArray(&fbb))
                if let pos = pressures.firstIndex(where: {$0.variable == pressure.variable}) {
                    pressures[pos].offsets.append(offset)
                } else {
                    pressures.append((pressure.variable, v.unit, [offset]))
                }
            }
        }
        
        let pressureVectors: [(variable: Model.HourlyPressureType, offset: Offset)] = pressures.map { (variable, unit, offsets) in
            return (variable, com_openmeteo_ValuesUnitPressureLevel.createValuesUnitPressureLevel(&fbb, unit: unit, valuesVectorOffset: fbb.createVector(ofOffsets: offsets)))
        }
        
        return (surfaces, pressureVectors)
    }
    
    /// Encode hourly variable for surface and pressure variables
    static func encodeEnsemble(section: ApiSection<SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> (surface: [(variable: Model.HourlyVariable, offset: Offset)], pressure: [(variable: Model.HourlyPressureType, offset: Offset)]) {
        var surfaces = [(variable: Model.HourlyVariable, offset: Offset)]()
        surfaces.reserveCapacity(section.columns.count)
        var pressures = [(variable: Model.HourlyPressureType, unit: SiUnit, offsets: [Offset])]()
        
        for v in section.columns {
            switch v.variable {
            case .surface(let surface):
                let oo = v.variables.enumerated().map { (member, data) in
                    return com_openmeteo_ValuesAndMember.createValuesAndMember(&fbb, member: Int32(member + Model.memberOffset), valuesVectorOffset: data.expectFloatArray(&fbb))
                }
                let offset = com_openmeteo_ValuesUnitAndMember.createValuesUnitAndMember(&fbb, unit: v.unit, valuesVectorOffset: fbb.createVector(ofOffsets: oo))
                surfaces.append((surface, offset))
            case .pressure(let pressure):
                let oo = v.variables.enumerated().map { (member, data) in
                    return com_openmeteo_ValuesAndMember.createValuesAndMember(&fbb, member: Int32(member + Model.memberOffset), valuesVectorOffset: data.expectFloatArray(&fbb))
                }
                let offset = com_openmeteo_ValuesAndLevelAndMember.createValuesAndLevelAndMember(&fbb, level: Int32(pressure.level), valuesVectorOffset: fbb.createVector(ofOffsets: oo))
                if let pos = pressures.firstIndex(where: {$0.variable == pressure.variable}) {
                    pressures[pos].offsets.append(offset)
                } else {
                    pressures.append((pressure.variable, v.unit, [offset]))
                }
            }
        }
        
        let pressureVectors: [(variable: Model.HourlyPressureType, offset: Offset)] = pressures.map { (variable, unit, offsets) in
            return (variable, com_openmeteo_ValuesUnitPressureLevelAndMember.createValuesUnitPressureLevelAndMember(&fbb, unit: unit, valuesVectorOffset: fbb.createVector(ofOffsets: offsets)))
        }
        
        return (surfaces, pressureVectors)
    }
    
    /// Encodes daily data to eigher `ValuesAndUnit` or just plain `int64` for timestamps (e.g. sunrise/set)
    static func encodeEnsemble(section: ApiSection<Model.DailyVariable>, _ fbb: inout FlatBufferBuilder) -> [Offset] {
        let offsets: [Offset] = section.columns.map { v in
            let oo = v.variables.enumerated().map { (member, array) in
                switch array {
                case .float(let float):
                    return com_openmeteo_ValuesAndMember.createValuesAndMember(&fbb, member: Int32(member + Model.memberOffset), valuesVectorOffset: fbb.createVector(float))
                case .timestamp(let time):
                    return fbb.createVector(time.map({$0.timeIntervalSince1970}))
                }
            }
            return com_openmeteo_ValuesUnitAndMember.createValuesUnitAndMember(&fbb, unit: v.unit, valuesVectorOffset: fbb.createVector(ofOffsets: oo))
        }
        return offsets
    }
}

extension ApiArray {
    func expectFloatArray(_ fbb: inout FlatBuffers.FlatBufferBuilder) -> Offset {
        switch self {
        case .float(let array):
            return fbb.createVector(array)
        case .timestamp(_):
            fatalError("Expected float array and not timestamps")
        }
    }
}

extension ApiSection {
    func timeFlatBuffers() -> com_openmeteo_TimeRange {
        return .init(
            start: Int64(time.range.lowerBound.timeIntervalSince1970),
            end: Int64(time.range.upperBound.timeIntervalSince1970),
            interval: Int32(Int64(time.dtSeconds))
        )
    }
}
