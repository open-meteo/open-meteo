import Foundation
import FlatBuffers


extension Cmip6Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = Cmip6VariableOrDerivedPostBias
  
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encode(section: section, &fbb)
        let start = com_openmeteo_ClimateDaily.startClimateDaily(&fbb)
        com_openmeteo_ClimateDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .raw(let v):
                switch v {
                case .raw(let v):
                    switch v {
                    case .temperature_2m_min:
                        com_openmeteo_ClimateDaily.add(temperature2mMin: offset, &fbb)
                    case .temperature_2m_max:
                        com_openmeteo_ClimateDaily.add(temperature2mMax: offset, &fbb)
                    case .temperature_2m_mean:
                        com_openmeteo_ClimateDaily.add(temperature2mMean: offset, &fbb)
                    case .pressure_msl_mean:
                        com_openmeteo_ClimateDaily.add(pressureMslMean: offset, &fbb)
                    case .cloudcover_mean:
                        com_openmeteo_ClimateDaily.add(cloudcoverMean: offset, &fbb)
                    case .precipitation_sum:
                        com_openmeteo_ClimateDaily.add(precipitationSum: offset, &fbb)
                    case .snowfall_water_equivalent_sum:
                        com_openmeteo_ClimateDaily.add(snowfallWaterEquivalentSum: offset, &fbb)
                    case .relative_humidity_2m_min:
                        com_openmeteo_ClimateDaily.add(relativeHumidity2mMin: offset, &fbb)
                    case .relative_humidity_2m_max:
                        com_openmeteo_ClimateDaily.add(relativeHumidity2mMax: offset, &fbb)
                    case .relative_humidity_2m_mean:
                        com_openmeteo_ClimateDaily.add(relativeHumidity2mMean: offset, &fbb)
                    case .windspeed_10m_mean:
                        com_openmeteo_ClimateDaily.add(windspeed10mMean: offset, &fbb)
                    case .windspeed_10m_max:
                        com_openmeteo_ClimateDaily.add(windspeed10mMax: offset, &fbb)
                    case .soil_moisture_0_to_10cm_mean:
                        com_openmeteo_ClimateDaily.add(soilMoisture0To10cmMean: offset, &fbb)
                    case .shortwave_radiation_sum:
                        com_openmeteo_ClimateDaily.add(shortwaveRadiationSum: offset, &fbb)
                    }
                case .derived(let v):
                    switch v {
                    case .et0_fao_evapotranspiration_sum:
                        com_openmeteo_ClimateDaily.add(et0FaoEvapotranspirationSum: offset, &fbb)
                    case .leaf_wetness_probability_mean:
                        com_openmeteo_ClimateDaily.add(leafWetnessProbabilityMean: offset, &fbb)
                    case .soil_moisture_0_to_100cm_mean:
                        com_openmeteo_ClimateDaily.add(soilMoisture0To100cmMean:  offset, &fbb)
                    case .soil_moisture_0_to_7cm_mean:
                        com_openmeteo_ClimateDaily.add(soilMoisture0To7cmMean: offset, &fbb)
                    case .soil_moisture_7_to_28cm_mean:
                        com_openmeteo_ClimateDaily.add(soilMoisture7To28cmMean: offset, &fbb)
                    case .soil_moisture_28_to_100cm_mean:
                        com_openmeteo_ClimateDaily.add(soilMoisture28To100cmMean: offset, &fbb)
                    case .soil_temperature_0_to_100cm_mean:
                        com_openmeteo_ClimateDaily.add(soilTemperature0To100cmMean: offset, &fbb)
                    case .soil_temperature_0_to_7cm_mean:
                        com_openmeteo_ClimateDaily.add(soilTemperature0To7cmMean: offset, &fbb)
                    case .soil_temperature_7_to_28cm_mean:
                        com_openmeteo_ClimateDaily.add(soilTemperature7To28cmMean: offset, &fbb)
                    case .soil_temperature_28_to_100cm_mean:
                        com_openmeteo_ClimateDaily.add(soilTemperature28To100cmMean: offset, &fbb)
                    case .vapor_pressure_deficit_max:
                        com_openmeteo_ClimateDaily.add(vaporPressureDeficitMax: offset, &fbb)
                    case .windgusts_10m_mean:
                        com_openmeteo_ClimateDaily.add(windgusts10mMean: offset, &fbb)
                    case .windgusts_10m_max:
                        com_openmeteo_ClimateDaily.add(windgusts10mMax: offset, &fbb)
                    }
                }
            case .derived(let v):
                switch v {
                case .snowfall_sum:
                    com_openmeteo_ClimateDaily.add(snowfallSum: offset, &fbb)
                case .rain_sum:
                    com_openmeteo_ClimateDaily.add(rainSum: offset, &fbb)
                case .dewpoint_2m_max:
                    com_openmeteo_ClimateDaily.add(dewpoint2mMax: offset, &fbb)
                case .dewpoint_2m_min:
                    com_openmeteo_ClimateDaily.add(dewpoint2mMin: offset, &fbb)
                case .dewpoint_2m_mean:
                    com_openmeteo_ClimateDaily.add(dewpoint2mMean: offset, &fbb)
                case .growing_degree_days_base_0_limit_50:
                    com_openmeteo_ClimateDaily.add(growingDegreeDaysBase0Limit50: offset, &fbb)
                case .soil_moisture_index_0_to_10cm_mean:
                    com_openmeteo_ClimateDaily.add(soilMoistureIndex0To10cmMean: offset, &fbb)
                case .soil_moisture_index_0_to_100cm_mean:
                    com_openmeteo_ClimateDaily.add(soilMoistureIndex0To100cmMean: offset, &fbb)
                case .daylight_duration:
                    com_openmeteo_ClimateDaily.add(daylightDuration: offset, &fbb)
                case .windspeed_2m_max:
                    com_openmeteo_ClimateDaily.add(windspeed2mMax: offset, &fbb)
                case .windspeed_2m_mean:
                    com_openmeteo_ClimateDaily.add(windspeed2mMean: offset, &fbb)
                }
            }
        }
        return com_openmeteo_ClimateDaily.endClimateDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = com_openmeteo_ClimateApi.createClimateApi(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            dailyOffset: daily
        )
        fbb.finish(offset: result, addPrefix: true)
    }
    
    var flatBufferModel: com_openmeteo_ClimateModel {
        switch self {
        case .CMCC_CM2_VHR4:
            return .cmccCm2Vhr4
        case .FGOALS_f3_H_highresSST:
            return .fgoalsF3HHighressst
        case .FGOALS_f3_H:
            return .fgoalsF3H
        case .HiRAM_SIT_HR:
            return .hiramSitHr
        case .MRI_AGCM3_2_S:
            return .mriAgcm32S
        case .EC_Earth3P_HR:
            return .ecEarth3pHr
        case .MPI_ESM1_2_XR:
            return .mpiEsm12Xr
        case .NICAM16_8S:
            return .nicam168s
        }
    }
}
