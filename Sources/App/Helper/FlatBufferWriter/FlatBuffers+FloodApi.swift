import Foundation
import FlatBuffers
import OpenMeteoSdk


extension GlofasDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = GloFasVariableOrDerived
    
    var flatBufferModel: openmeteo_sdk_FloodModel {
        switch self {
        case .best_match:
            return .bestMatch
        case .seamless_v3:
            return .glofasSeamlessV3
        case .forecast_v3:
            return .glofasForecastV3
        case .consolidated_v3:
            return .glofasConsolidatedV3
        case .seamless_v4:
            return .glofasSeamlessV4
        case .forecast_v4:
            return .glofasForecastV4
        case .consolidated_v4:
            return .glofasConsolidatedV4
        }
    }
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets: [Offset] = section.columns.map { v in
            switch v.variable {
            case .raw(_):
                /// ensemble data `river_dischage`
                let oo = v.variables.enumerated().map { (member, data) in
                    openmeteo_sdk_ValuesAndMember.createValuesAndMember(&fbb, member: Int32(member), valuesVectorOffset: data.expectFloatArray(&fbb))
                }
                return openmeteo_sdk_ValuesUnitAndMember.createValuesUnitAndMember(&fbb, unit: v.unit, valuesVectorOffset: fbb.createVector(ofOffsets: oo))
            case .derived(_):
                /// Single e.g. `river_dischage_max`
                switch v.variables[0] {
                case .float(let float):
                    return openmeteo_sdk_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: fbb.createVector(float), unit: v.unit)
                case .timestamp(let time):
                    return fbb.createVector(time.map({$0.timeIntervalSince1970}))
                }
            }
        }
        
        let start = openmeteo_sdk_FloodDaily.startFloodDaily(&fbb)
        openmeteo_sdk_FloodDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .derived(let v):
                switch v {
                case .river_discharge_mean:
                    openmeteo_sdk_FloodDaily.add(riverDischargeMean: offset, &fbb)
                case .river_discharge_min:
                    openmeteo_sdk_FloodDaily.add(riverDischargeMin: offset, &fbb)
                case .river_discharge_max:
                    openmeteo_sdk_FloodDaily.add(riverDischargeMax: offset, &fbb)
                case .river_discharge_median:
                    openmeteo_sdk_FloodDaily.add(riverDischargeMedian: offset, &fbb)
                case .river_discharge_p25:
                    openmeteo_sdk_FloodDaily.add(riverDischargeP25: offset, &fbb)
                case .river_discharge_p75:
                    openmeteo_sdk_FloodDaily.add(riverDischargeP75: offset, &fbb)
                }
            case .raw(let v):
                switch v {
                case .river_discharge:
                    openmeteo_sdk_FloodDaily.add(riverDischarge: offset, &fbb)
                }
            }
        }
        return openmeteo_sdk_FloodDaily.endFloodDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = openmeteo_sdk_FloodApiResponse.createFloodApiResponse(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: timezone.identifier == "GMT" ? Offset() : fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: timezone.abbreviation == "GMT" ? Offset() : fbb.create(string: timezone.abbreviation),
            dailyOffset: daily
        )
        fbb.finish(offset: result, addPrefix: true)
    }
}
