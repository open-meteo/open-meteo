import Foundation
import FlatBuffers


extension CamsQuery.Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = CamsReader.MixingVar
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = com_openmeteo_AirQualityHourly.startAirQualityHourly(&fbb)
        com_openmeteo_AirQualityHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .raw(let v):
                switch v {
                case .pm10:
                    com_openmeteo_AirQualityHourly.add(pm10: offset, &fbb)
                case .pm2_5:
                    com_openmeteo_AirQualityHourly.add(pm25: offset, &fbb)
                case .dust:
                    com_openmeteo_AirQualityHourly.add(dust: offset, &fbb)
                case .aerosol_optical_depth:
                    com_openmeteo_AirQualityHourly.add(aerosolOpticalDepth: offset, &fbb)
                case .carbon_monoxide:
                    com_openmeteo_AirQualityHourly.add(carbonMonoxide: offset, &fbb)
                case .nitrogen_dioxide:
                    com_openmeteo_AirQualityHourly.add(nitrogenDioxide: offset, &fbb)
                case .ammonia:
                    com_openmeteo_AirQualityHourly.add(ammonia: offset, &fbb)
                case .ozone:
                    com_openmeteo_AirQualityHourly.add(ozone: offset, &fbb)
                case .sulphur_dioxide:
                    com_openmeteo_AirQualityHourly.add(sulphurDioxide: offset, &fbb)
                case .uv_index:
                    com_openmeteo_AirQualityHourly.add(uvIndex: offset, &fbb)
                case .uv_index_clear_sky:
                    com_openmeteo_AirQualityHourly.add(uvIndexClearSky: offset, &fbb)
                case .alder_pollen:
                    com_openmeteo_AirQualityHourly.add(alderPollen: offset, &fbb)
                case .birch_pollen:
                    com_openmeteo_AirQualityHourly.add(birchPollen: offset, &fbb)
                case .grass_pollen:
                    com_openmeteo_AirQualityHourly.add(grassPollen: offset, &fbb)
                case .mugwort_pollen:
                    com_openmeteo_AirQualityHourly.add(mugwortPollen: offset, &fbb)
                case .olive_pollen:
                    com_openmeteo_AirQualityHourly.add(olivePollen: offset, &fbb)
                case .ragweed_pollen:
                    com_openmeteo_AirQualityHourly.add(ragweedPollen: offset, &fbb)
                }
            case .derived(let v):
                switch v {
                case .european_aqi:
                    com_openmeteo_AirQualityHourly.add(europeanAqi: offset, &fbb)
                case .european_aqi_pm2_5:
                    com_openmeteo_AirQualityHourly.add(europeanAqiPm25: offset, &fbb)
                case .european_aqi_pm10:
                    com_openmeteo_AirQualityHourly.add(europeanAqiPm10: offset, &fbb)
                case .european_aqi_no2:
                    com_openmeteo_AirQualityHourly.add(europeanAqiNo2: offset, &fbb)
                case .european_aqi_o3:
                    com_openmeteo_AirQualityHourly.add(europeanAqiO3: offset, &fbb)
                case .european_aqi_so2:
                    com_openmeteo_AirQualityHourly.add(europeanAqiSo2: offset, &fbb)
                case .us_aqi:
                    com_openmeteo_AirQualityHourly.add(usAqi: offset, &fbb)
                case .us_aqi_pm2_5:
                    com_openmeteo_AirQualityHourly.add(usAqiPm25: offset, &fbb)
                case .us_aqi_pm10:
                    com_openmeteo_AirQualityHourly.add(usAqiPm10: offset, &fbb)
                case .us_aqi_no2:
                    com_openmeteo_AirQualityHourly.add(usAqiNo2: offset, &fbb)
                case .us_aqi_o3:
                    com_openmeteo_AirQualityHourly.add(usAqiO3: offset, &fbb)
                case .us_aqi_so2:
                    com_openmeteo_AirQualityHourly.add(usAqiSo2: offset, &fbb)
                case .us_aqi_co:
                    com_openmeteo_AirQualityHourly.add(usAqiCo: offset, &fbb)
                case .is_day:
                    com_openmeteo_AirQualityHourly.add(isDay: offset, &fbb)
                }
            }
        }
        for (_, _) in offsets.pressure {
            fatalError("No pressure levels")
        }
        return com_openmeteo_AirQualityHourly.endAirQualityHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = com_openmeteo_AirQualityCurrent.startAirQualityCurrent(&fbb)
        com_openmeteo_AirQualityCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        com_openmeteo_AirQualityCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let surface):
                let offset = com_openmeteo_ValueAndUnit(value: column.value, unit: column.unit)
                switch surface {
                case .raw(let v):
                    switch v {
                    case .pm10:
                        com_openmeteo_AirQualityCurrent.add(pm10: offset, &fbb)
                    case .pm2_5:
                        com_openmeteo_AirQualityCurrent.add(pm25: offset, &fbb)
                    case .dust:
                        com_openmeteo_AirQualityCurrent.add(dust: offset, &fbb)
                    case .aerosol_optical_depth:
                        com_openmeteo_AirQualityCurrent.add(aerosolOpticalDepth: offset, &fbb)
                    case .carbon_monoxide:
                        com_openmeteo_AirQualityCurrent.add(carbonMonoxide: offset, &fbb)
                    case .nitrogen_dioxide:
                        com_openmeteo_AirQualityCurrent.add(nitrogenDioxide: offset, &fbb)
                    case .ammonia:
                        com_openmeteo_AirQualityCurrent.add(ammonia: offset, &fbb)
                    case .ozone:
                        com_openmeteo_AirQualityCurrent.add(ozone: offset, &fbb)
                    case .sulphur_dioxide:
                        com_openmeteo_AirQualityCurrent.add(sulphurDioxide: offset, &fbb)
                    case .uv_index:
                        com_openmeteo_AirQualityCurrent.add(uvIndex: offset, &fbb)
                    case .uv_index_clear_sky:
                        com_openmeteo_AirQualityCurrent.add(uvIndexClearSky: offset, &fbb)
                    case .alder_pollen:
                        com_openmeteo_AirQualityCurrent.add(alderPollen: offset, &fbb)
                    case .birch_pollen:
                        com_openmeteo_AirQualityCurrent.add(birchPollen: offset, &fbb)
                    case .grass_pollen:
                        com_openmeteo_AirQualityCurrent.add(grassPollen: offset, &fbb)
                    case .mugwort_pollen:
                        com_openmeteo_AirQualityCurrent.add(mugwortPollen: offset, &fbb)
                    case .olive_pollen:
                        com_openmeteo_AirQualityCurrent.add(olivePollen: offset, &fbb)
                    case .ragweed_pollen:
                        com_openmeteo_AirQualityCurrent.add(ragweedPollen: offset, &fbb)
                    }
                case .derived(let v):
                    switch v {
                    case .european_aqi:
                        com_openmeteo_AirQualityCurrent.add(europeanAqi: offset, &fbb)
                    case .european_aqi_pm2_5:
                        com_openmeteo_AirQualityCurrent.add(europeanAqiPm25: offset, &fbb)
                    case .european_aqi_pm10:
                        com_openmeteo_AirQualityCurrent.add(europeanAqiPm10: offset, &fbb)
                    case .european_aqi_no2:
                        com_openmeteo_AirQualityCurrent.add(europeanAqiNo2: offset, &fbb)
                    case .european_aqi_o3:
                        com_openmeteo_AirQualityCurrent.add(europeanAqiO3: offset, &fbb)
                    case .european_aqi_so2:
                        com_openmeteo_AirQualityCurrent.add(europeanAqiSo2: offset, &fbb)
                    case .us_aqi:
                        com_openmeteo_AirQualityCurrent.add(usAqi: offset, &fbb)
                    case .us_aqi_pm2_5:
                        com_openmeteo_AirQualityCurrent.add(usAqiPm25: offset, &fbb)
                    case .us_aqi_pm10:
                        com_openmeteo_AirQualityCurrent.add(usAqiPm10: offset, &fbb)
                    case .us_aqi_no2:
                        com_openmeteo_AirQualityCurrent.add(usAqiNo2: offset, &fbb)
                    case .us_aqi_o3:
                        com_openmeteo_AirQualityCurrent.add(usAqiO3: offset, &fbb)
                    case .us_aqi_so2:
                        com_openmeteo_AirQualityCurrent.add(usAqiSo2: offset, &fbb)
                    case .us_aqi_co:
                        com_openmeteo_AirQualityCurrent.add(usAqiCo: offset, &fbb)
                    case .is_day:
                        com_openmeteo_AirQualityCurrent.add(isDay: offset, &fbb)
                    }
                }
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return com_openmeteo_AirQualityCurrent.endAirQualityCurrent(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = com_openmeteo_AirQualityApi.createAirQualityApi(
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
    
    var flatBufferModel: com_openmeteo_AirQualityModel {
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
