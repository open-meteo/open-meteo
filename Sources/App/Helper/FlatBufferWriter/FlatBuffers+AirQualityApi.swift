import Foundation
import FlatBuffers
import OpenMeteoSdk


extension CamsQuery.Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = CamsReader.MixingVar
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = openmeteo_sdk_AirQualityHourly.startAirQualityHourly(&fbb)
        openmeteo_sdk_AirQualityHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .raw(let v):
                switch v {
                case .pm10:
                    openmeteo_sdk_AirQualityHourly.add(pm10: offset, &fbb)
                case .pm2_5:
                    openmeteo_sdk_AirQualityHourly.add(pm25: offset, &fbb)
                case .dust:
                    openmeteo_sdk_AirQualityHourly.add(dust: offset, &fbb)
                case .aerosol_optical_depth:
                    openmeteo_sdk_AirQualityHourly.add(aerosolOpticalDepth: offset, &fbb)
                case .carbon_monoxide:
                    openmeteo_sdk_AirQualityHourly.add(carbonMonoxide: offset, &fbb)
                case .nitrogen_dioxide:
                    openmeteo_sdk_AirQualityHourly.add(nitrogenDioxide: offset, &fbb)
                case .ammonia:
                    openmeteo_sdk_AirQualityHourly.add(ammonia: offset, &fbb)
                case .ozone:
                    openmeteo_sdk_AirQualityHourly.add(ozone: offset, &fbb)
                case .sulphur_dioxide:
                    openmeteo_sdk_AirQualityHourly.add(sulphurDioxide: offset, &fbb)
                case .uv_index:
                    openmeteo_sdk_AirQualityHourly.add(uvIndex: offset, &fbb)
                case .uv_index_clear_sky:
                    openmeteo_sdk_AirQualityHourly.add(uvIndexClearSky: offset, &fbb)
                case .alder_pollen:
                    openmeteo_sdk_AirQualityHourly.add(alderPollen: offset, &fbb)
                case .birch_pollen:
                    openmeteo_sdk_AirQualityHourly.add(birchPollen: offset, &fbb)
                case .grass_pollen:
                    openmeteo_sdk_AirQualityHourly.add(grassPollen: offset, &fbb)
                case .mugwort_pollen:
                    openmeteo_sdk_AirQualityHourly.add(mugwortPollen: offset, &fbb)
                case .olive_pollen:
                    openmeteo_sdk_AirQualityHourly.add(olivePollen: offset, &fbb)
                case .ragweed_pollen:
                    openmeteo_sdk_AirQualityHourly.add(ragweedPollen: offset, &fbb)
                }
            case .derived(let v):
                switch v {
                case .european_aqi:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqi: offset, &fbb)
                case .european_aqi_pm2_5:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqiPm25: offset, &fbb)
                case .european_aqi_pm10:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqiPm10: offset, &fbb)
                case .european_aqi_no2:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqiNo2: offset, &fbb)
                case .european_aqi_o3:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqiO3: offset, &fbb)
                case .european_aqi_so2:
                    openmeteo_sdk_AirQualityHourly.add(europeanAqiSo2: offset, &fbb)
                case .us_aqi:
                    openmeteo_sdk_AirQualityHourly.add(usAqi: offset, &fbb)
                case .us_aqi_pm2_5:
                    openmeteo_sdk_AirQualityHourly.add(usAqiPm25: offset, &fbb)
                case .us_aqi_pm10:
                    openmeteo_sdk_AirQualityHourly.add(usAqiPm10: offset, &fbb)
                case .us_aqi_no2:
                    openmeteo_sdk_AirQualityHourly.add(usAqiNo2: offset, &fbb)
                case .us_aqi_o3:
                    openmeteo_sdk_AirQualityHourly.add(usAqiO3: offset, &fbb)
                case .us_aqi_so2:
                    openmeteo_sdk_AirQualityHourly.add(usAqiSo2: offset, &fbb)
                case .us_aqi_co:
                    openmeteo_sdk_AirQualityHourly.add(usAqiCo: offset, &fbb)
                case .is_day:
                    openmeteo_sdk_AirQualityHourly.add(isDay: offset, &fbb)
                }
            }
        }
        for (_, _) in offsets.pressure {
            fatalError("No pressure levels")
        }
        return openmeteo_sdk_AirQualityHourly.endAirQualityHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = openmeteo_sdk_AirQualityCurrent.startAirQualityCurrent(&fbb)
        openmeteo_sdk_AirQualityCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        openmeteo_sdk_AirQualityCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let surface):
                let offset = openmeteo_sdk_ValueAndUnit(value: column.value, unit: column.unit)
                switch surface {
                case .raw(let v):
                    switch v {
                    case .pm10:
                        openmeteo_sdk_AirQualityCurrent.add(pm10: offset, &fbb)
                    case .pm2_5:
                        openmeteo_sdk_AirQualityCurrent.add(pm25: offset, &fbb)
                    case .dust:
                        openmeteo_sdk_AirQualityCurrent.add(dust: offset, &fbb)
                    case .aerosol_optical_depth:
                        openmeteo_sdk_AirQualityCurrent.add(aerosolOpticalDepth: offset, &fbb)
                    case .carbon_monoxide:
                        openmeteo_sdk_AirQualityCurrent.add(carbonMonoxide: offset, &fbb)
                    case .nitrogen_dioxide:
                        openmeteo_sdk_AirQualityCurrent.add(nitrogenDioxide: offset, &fbb)
                    case .ammonia:
                        openmeteo_sdk_AirQualityCurrent.add(ammonia: offset, &fbb)
                    case .ozone:
                        openmeteo_sdk_AirQualityCurrent.add(ozone: offset, &fbb)
                    case .sulphur_dioxide:
                        openmeteo_sdk_AirQualityCurrent.add(sulphurDioxide: offset, &fbb)
                    case .uv_index:
                        openmeteo_sdk_AirQualityCurrent.add(uvIndex: offset, &fbb)
                    case .uv_index_clear_sky:
                        openmeteo_sdk_AirQualityCurrent.add(uvIndexClearSky: offset, &fbb)
                    case .alder_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(alderPollen: offset, &fbb)
                    case .birch_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(birchPollen: offset, &fbb)
                    case .grass_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(grassPollen: offset, &fbb)
                    case .mugwort_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(mugwortPollen: offset, &fbb)
                    case .olive_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(olivePollen: offset, &fbb)
                    case .ragweed_pollen:
                        openmeteo_sdk_AirQualityCurrent.add(ragweedPollen: offset, &fbb)
                    }
                case .derived(let v):
                    switch v {
                    case .european_aqi:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqi: offset, &fbb)
                    case .european_aqi_pm2_5:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqiPm25: offset, &fbb)
                    case .european_aqi_pm10:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqiPm10: offset, &fbb)
                    case .european_aqi_no2:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqiNo2: offset, &fbb)
                    case .european_aqi_o3:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqiO3: offset, &fbb)
                    case .european_aqi_so2:
                        openmeteo_sdk_AirQualityCurrent.add(europeanAqiSo2: offset, &fbb)
                    case .us_aqi:
                        openmeteo_sdk_AirQualityCurrent.add(usAqi: offset, &fbb)
                    case .us_aqi_pm2_5:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiPm25: offset, &fbb)
                    case .us_aqi_pm10:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiPm10: offset, &fbb)
                    case .us_aqi_no2:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiNo2: offset, &fbb)
                    case .us_aqi_o3:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiO3: offset, &fbb)
                    case .us_aqi_so2:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiSo2: offset, &fbb)
                    case .us_aqi_co:
                        openmeteo_sdk_AirQualityCurrent.add(usAqiCo: offset, &fbb)
                    case .is_day:
                        openmeteo_sdk_AirQualityCurrent.add(isDay: offset, &fbb)
                    }
                }
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return openmeteo_sdk_AirQualityCurrent.endAirQualityCurrent(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = openmeteo_sdk_AirQualityApiResponse.createAirQualityApiResponse(
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
    
    var flatBufferModel: openmeteo_sdk_AirQualityModel {
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
