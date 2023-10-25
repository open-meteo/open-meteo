import Foundation
import FlatBuffers
import OpenMeteoSdk


extension Cmip6Variable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .pressure_msl_mean:
            return .init(variable: .pressureMsl, aggregation: .mean)
        case .cloudcover_mean:
            return .init(variable: .cloudCover, aggregation: .mean)
        case .precipitation_sum:
            return .init(variable: .precipitation, aggregation: .sum)
        case .snowfall_water_equivalent_sum:
            return .init(variable: .snowfallWaterEquivalent, aggregation: .sum)
        case .relative_humidity_2m_min:
            return .init(variable: .relativeHumidity, aggregation: .minimum, altitude: 2)
        case .relative_humidity_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .relative_humidity_2m_mean:
            return .init(variable: .temperature, aggregation: .mean, altitude: 2)
        case .windspeed_10m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
        case .windspeed_10m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 10)
        case .soil_moisture_0_to_10cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 10)
        case .shortwave_radiation_sum:
            return .init(variable: .shortwaveRadiation, aggregation: .sum)
        }
    }
}

extension Cmip6VariableDerivedPostBiasCorrection: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .snowfall_sum:
            return .init(variable: .snowfall, aggregation: .sum)
        case .rain_sum:
            return .init(variable: .rain, aggregation: .sum)
        case .dewpoint_2m_max, .dew_point_2m_max:
            return .init(variable: .dewPoint, aggregation: .maximum, altitude: 2)
        case .dewpoint_2m_min, .dew_point_2m_min:
            return .init(variable: .dewPoint, aggregation: .minimum, altitude: 2)
        case .dewpoint_2m_mean, .dew_point_2m_mean:
            return .init(variable: .dewPoint, aggregation: .mean, altitude: 2)
        case .growing_degree_days_base_0_limit_50:
            return .init(variable: .growingDegreeDays)
        case .soil_moisture_index_0_to_10cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 0, depthTo: 10)
        case .soil_moisture_index_0_to_100cm_mean:
            return .init(variable: .soilMoistureIndex, aggregation: .mean, depth: 0, depthTo: 100)
        case .daylight_duration:
            return .init(variable: .daylightDuration)
        case .windspeed_2m_max, .wind_speed_2m_max:
            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 2)
        case .windspeed_2m_mean, .wind_speed_2m_mean:
            return .init(variable: .windSpeed, aggregation: .mean, altitude: 2)
        case .vapour_pressure_deficit_max:
            return .init(variable: .vapourPressureDeficit, aggregation: .maximum)
        case .wind_gusts_10m_mean:
            return .init(variable: .windGusts, aggregation: .mean, altitude: 10)
        case .wind_gusts_10m_max:
            return .init(variable: .windGusts, aggregation: .maximum, altitude: 10)
        }
    }
}

extension Cmip6VariableDerivedBiasCorrected: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .et0_fao_evapotranspiration_sum:
            return .init(variable: .et0FaoEvapotranspiration, aggregation: .sum)
        case .leaf_wetness_probability_mean:
            return .init(variable: .leafWetnessProbability, aggregation: .mean)
        case .soil_moisture_0_to_100cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 100)
        case .soil_moisture_0_to_7cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_moisture_7_to_28cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_moisture_28_to_100cm_mean:
            return .init(variable: .soilMoisture, aggregation: .mean, depth: 28, depthTo: 100)
        case .soil_temperature_0_to_100cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 100)
        case .soil_temperature_0_to_7cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 7)
        case .soil_temperature_7_to_28cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 7, depthTo: 28)
        case .soil_temperature_28_to_100cm_mean:
            return .init(variable: .soilTemperature, aggregation: .mean, depth: 28, depthTo: 100)
        case .vapor_pressure_deficit_max:
            return .init(variable: .vapourPressureDeficit, aggregation: .maximum)
        case .windgusts_10m_mean:
            return .init(variable: .windGusts, aggregation: .mean, altitude: 10)
        case .windgusts_10m_max:
            return .init(variable: .windGusts, aggregation: .maximum, altitude: 10)
        }
    }
}

extension Cmip6Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = Cmip6VariableOrDerivedPostBias
    
    var flatBufferModel: openmeteo_sdk_Model {
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
