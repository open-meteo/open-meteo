import Foundation
import FlatBuffers
import OpenMeteo


extension CamsQuery.Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = CamsReader.MixingVar
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = AirQualityHourly.startAirQualityHourly(&fbb)
        AirQualityHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .raw(let v):
                switch v {
                case .pm10:
                    AirQualityHourly.add(pm10: offset, &fbb)
                case .pm2_5:
                    AirQualityHourly.add(pm25: offset, &fbb)
                case .dust:
                    AirQualityHourly.add(dust: offset, &fbb)
                case .aerosol_optical_depth:
                    AirQualityHourly.add(aerosolOpticalDepth: offset, &fbb)
                case .carbon_monoxide:
                    AirQualityHourly.add(carbonMonoxide: offset, &fbb)
                case .nitrogen_dioxide:
                    AirQualityHourly.add(nitrogenDioxide: offset, &fbb)
                case .ammonia:
                    AirQualityHourly.add(ammonia: offset, &fbb)
                case .ozone:
                    AirQualityHourly.add(ozone: offset, &fbb)
                case .sulphur_dioxide:
                    AirQualityHourly.add(sulphurDioxide: offset, &fbb)
                case .uv_index:
                    AirQualityHourly.add(uvIndex: offset, &fbb)
                case .uv_index_clear_sky:
                    AirQualityHourly.add(uvIndexClearSky: offset, &fbb)
                case .alder_pollen:
                    AirQualityHourly.add(alderPollen: offset, &fbb)
                case .birch_pollen:
                    AirQualityHourly.add(birchPollen: offset, &fbb)
                case .grass_pollen:
                    AirQualityHourly.add(grassPollen: offset, &fbb)
                case .mugwort_pollen:
                    AirQualityHourly.add(mugwortPollen: offset, &fbb)
                case .olive_pollen:
                    AirQualityHourly.add(olivePollen: offset, &fbb)
                case .ragweed_pollen:
                    AirQualityHourly.add(ragweedPollen: offset, &fbb)
                }
            case .derived(let v):
                switch v {
                case .european_aqi:
                    AirQualityHourly.add(europeanAqi: offset, &fbb)
                case .european_aqi_pm2_5:
                    AirQualityHourly.add(europeanAqiPm25: offset, &fbb)
                case .european_aqi_pm10:
                    AirQualityHourly.add(europeanAqiPm10: offset, &fbb)
                case .european_aqi_no2:
                    AirQualityHourly.add(europeanAqiNo2: offset, &fbb)
                case .european_aqi_o3:
                    AirQualityHourly.add(europeanAqiO3: offset, &fbb)
                case .european_aqi_so2:
                    AirQualityHourly.add(europeanAqiSo2: offset, &fbb)
                case .us_aqi:
                    AirQualityHourly.add(usAqi: offset, &fbb)
                case .us_aqi_pm2_5:
                    AirQualityHourly.add(usAqiPm25: offset, &fbb)
                case .us_aqi_pm10:
                    AirQualityHourly.add(usAqiPm10: offset, &fbb)
                case .us_aqi_no2:
                    AirQualityHourly.add(usAqiNo2: offset, &fbb)
                case .us_aqi_o3:
                    AirQualityHourly.add(usAqiO3: offset, &fbb)
                case .us_aqi_so2:
                    AirQualityHourly.add(usAqiSo2: offset, &fbb)
                case .us_aqi_co:
                    AirQualityHourly.add(usAqiCo: offset, &fbb)
                case .is_day:
                    AirQualityHourly.add(isDay: offset, &fbb)
                }
            }
        }
        for (_, _) in offsets.pressure {
            fatalError("No pressure levels")
        }
        return AirQualityHourly.endAirQualityHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = AirQualityCurrent.startAirQualityCurrent(&fbb)
        AirQualityCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        AirQualityCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let surface):
                let offset = ValueAndUnit(value: column.value, unit: column.unit)
                switch surface {
                case .raw(let v):
                    switch v {
                    case .pm10:
                        AirQualityCurrent.add(pm10: offset, &fbb)
                    case .pm2_5:
                        AirQualityCurrent.add(pm25: offset, &fbb)
                    case .dust:
                        AirQualityCurrent.add(dust: offset, &fbb)
                    case .aerosol_optical_depth:
                        AirQualityCurrent.add(aerosolOpticalDepth: offset, &fbb)
                    case .carbon_monoxide:
                        AirQualityCurrent.add(carbonMonoxide: offset, &fbb)
                    case .nitrogen_dioxide:
                        AirQualityCurrent.add(nitrogenDioxide: offset, &fbb)
                    case .ammonia:
                        AirQualityCurrent.add(ammonia: offset, &fbb)
                    case .ozone:
                        AirQualityCurrent.add(ozone: offset, &fbb)
                    case .sulphur_dioxide:
                        AirQualityCurrent.add(sulphurDioxide: offset, &fbb)
                    case .uv_index:
                        AirQualityCurrent.add(uvIndex: offset, &fbb)
                    case .uv_index_clear_sky:
                        AirQualityCurrent.add(uvIndexClearSky: offset, &fbb)
                    case .alder_pollen:
                        AirQualityCurrent.add(alderPollen: offset, &fbb)
                    case .birch_pollen:
                        AirQualityCurrent.add(birchPollen: offset, &fbb)
                    case .grass_pollen:
                        AirQualityCurrent.add(grassPollen: offset, &fbb)
                    case .mugwort_pollen:
                        AirQualityCurrent.add(mugwortPollen: offset, &fbb)
                    case .olive_pollen:
                        AirQualityCurrent.add(olivePollen: offset, &fbb)
                    case .ragweed_pollen:
                        AirQualityCurrent.add(ragweedPollen: offset, &fbb)
                    }
                case .derived(let v):
                    switch v {
                    case .european_aqi:
                        AirQualityCurrent.add(europeanAqi: offset, &fbb)
                    case .european_aqi_pm2_5:
                        AirQualityCurrent.add(europeanAqiPm25: offset, &fbb)
                    case .european_aqi_pm10:
                        AirQualityCurrent.add(europeanAqiPm10: offset, &fbb)
                    case .european_aqi_no2:
                        AirQualityCurrent.add(europeanAqiNo2: offset, &fbb)
                    case .european_aqi_o3:
                        AirQualityCurrent.add(europeanAqiO3: offset, &fbb)
                    case .european_aqi_so2:
                        AirQualityCurrent.add(europeanAqiSo2: offset, &fbb)
                    case .us_aqi:
                        AirQualityCurrent.add(usAqi: offset, &fbb)
                    case .us_aqi_pm2_5:
                        AirQualityCurrent.add(usAqiPm25: offset, &fbb)
                    case .us_aqi_pm10:
                        AirQualityCurrent.add(usAqiPm10: offset, &fbb)
                    case .us_aqi_no2:
                        AirQualityCurrent.add(usAqiNo2: offset, &fbb)
                    case .us_aqi_o3:
                        AirQualityCurrent.add(usAqiO3: offset, &fbb)
                    case .us_aqi_so2:
                        AirQualityCurrent.add(usAqiSo2: offset, &fbb)
                    case .us_aqi_co:
                        AirQualityCurrent.add(usAqiCo: offset, &fbb)
                    case .is_day:
                        AirQualityCurrent.add(isDay: offset, &fbb)
                    }
                }
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return AirQualityCurrent.endAirQualityCurrent(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = AirQualityApiResponse.createAirQualityApiResponse(
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
    
    var flatBufferModel: AirQualityModel {
        switch self {
        case .auto:
            return .bestMatch
        case .cams_global:
            return .camsEurope
        case .cams_europe:
            return .camsGlobal
        }
    }
}
