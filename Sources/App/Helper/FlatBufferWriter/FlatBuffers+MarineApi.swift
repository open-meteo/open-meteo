import Foundation
import FlatBuffers
import OpenMeteo


extension IconWaveDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = IconWaveVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = IconWaveVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = MarineHourly.startMarineHourly(&fbb)
        MarineHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .wave_height:
                MarineHourly.add(waveHeight: offset, &fbb)
            case .wave_period:
                MarineHourly.add(wavePeriod: offset, &fbb)
            case .wave_direction:
                MarineHourly.add(waveDirection: offset, &fbb)
            case .wind_wave_height:
                MarineHourly.add(windWaveHeight: offset, &fbb)
            case .wind_wave_period:
                MarineHourly.add(windWavePeriod: offset, &fbb)
            case .wind_wave_peak_period:
                MarineHourly.add(windWavePeakPeriod: offset, &fbb)
            case .wind_wave_direction:
                MarineHourly.add(windWaveDirection: offset, &fbb)
            case .swell_wave_height:
                MarineHourly.add(swellWaveHeight: offset, &fbb)
            case .swell_wave_period:
                MarineHourly.add(swellWavePeriod: offset, &fbb)
            case .swell_wave_peak_period:
                MarineHourly.add(swellWavePeakPeriod: offset, &fbb)
            case .swell_wave_direction:
                MarineHourly.add(swellWaveDirection: offset, &fbb)
            }
        }
        for (_, _) in offsets.pressure {
            fatalError("No pressure levels")
        }
        return MarineHourly.endMarineHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = MarineCurrent.startMarineCurrent(&fbb)
        MarineCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        MarineCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let v):
                let offset = ValueAndUnit(value: column.value, unit: column.unit)
                switch v {
                case .wave_height:
                    MarineCurrent.add(waveHeight: offset, &fbb)
                case .wave_period:
                    MarineCurrent.add(wavePeriod: offset, &fbb)
                case .wave_direction:
                    MarineCurrent.add(waveDirection: offset, &fbb)
                case .wind_wave_height:
                    MarineCurrent.add(windWaveHeight: offset, &fbb)
                case .wind_wave_period:
                    MarineCurrent.add(windWavePeriod: offset, &fbb)
                case .wind_wave_peak_period:
                    MarineCurrent.add(windWavePeakPeriod: offset, &fbb)
                case .wind_wave_direction:
                    MarineCurrent.add(windWaveDirection: offset, &fbb)
                case .swell_wave_height:
                    MarineCurrent.add(swellWaveHeight: offset, &fbb)
                case .swell_wave_period:
                    MarineCurrent.add(swellWavePeriod: offset, &fbb)
                case .swell_wave_peak_period:
                    MarineCurrent.add(swellWavePeakPeriod: offset, &fbb)
                case .swell_wave_direction:
                    MarineCurrent.add(swellWaveDirection: offset, &fbb)
                }
                
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return MarineCurrent.endMarineCurrent(&fbb, start: start)
    }
    
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encode(section: section, &fbb)
        let start = MarineDaily.startMarineDaily(&fbb)
        MarineDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .wave_height_max:
                MarineDaily.add(waveHeightMax: offset, &fbb)
            case .wind_wave_height_max:
                MarineDaily.add(windWaveHeightMax: offset, &fbb)
            case .swell_wave_height_max:
                MarineDaily.add(swellWaveHeightMax: offset, &fbb)
            case .wave_direction_dominant:
                MarineDaily.add(waveDirectionDominant: offset, &fbb)
            case .wind_wave_direction_dominant:
                MarineDaily.add(windWaveDirectionDominant: offset, &fbb)
            case .swell_wave_direction_dominant:
                MarineDaily.add(swellWaveDirectionDominant: offset, &fbb)
            case .wave_period_max:
                MarineDaily.add(wavePeriodMax: offset, &fbb)
            case .wind_wave_period_max:
                MarineDaily.add(windWavePeriodMax: offset, &fbb)
            case .wind_wave_peak_period_max:
                MarineDaily.add(windWavePeakPeriodMax: offset, &fbb)
            case .swell_wave_period_max:
                MarineDaily.add(swellWaveHeightMax: offset, &fbb)
            case .swell_wave_peak_period_max:
                MarineDaily.add(swellWavePeakPeriodMax: offset, &fbb)
            }
        }
        return MarineDaily.endMarineDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = MarineApiResponse.createMarineApiResponse(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: timezone.identifier == "GMT" ? Offset() : fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: timezone.abbreviation == "GMT" ? Offset() : fbb.create(string: timezone.abbreviation),
            hourlyOffset: hourly,
            currentOffset: current
        )
        fbb.finish(offset: result, addPrefix: true)
    }
    
    var flatBufferModel: MarineModel {
        switch self {
        case.best_match:
            return .bestMatch
        case .gwam:
            return .gwam
        case .ewam:
            return .ewam
        }
    }
}
