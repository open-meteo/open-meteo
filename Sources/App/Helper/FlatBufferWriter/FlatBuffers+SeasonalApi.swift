import Foundation
import FlatBuffers
import OpenMeteoSdk


extension CfsVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature_2m:
            return .init(variable: .temperature, altitude: 2)
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .soil_moisture_0_to_10cm:
            return .init(variable: .soilMoisture, depth: 0, depthTo: 10)
        case .soil_moisture_10_to_40cm:
            return .init(variable: .soilMoisture, depth: 10, depthTo: 40)
        case .soil_moisture_40_to_100cm:
            return .init(variable: .soilMoisture, depth: 40, depthTo: 100)
        case .soil_moisture_100_to_200cm:
            return .init(variable: .soilMoisture, depth: 100, depthTo: 200)
        case .soil_temperature_0_to_10cm:
            return .init(variable: .soilTemperature, depth: 0, depthTo: 10)
        case .shortwave_radiation:
            return .init(variable: .shortwaveRadiation)
        case .cloudcover:
            return .init(variable: .cloudcover)
        case .wind_u_component_10m:
            return .init(variable: .undefined)
        case .wind_v_component_10m:
            return .init(variable: .undefined)
        case .precipitation:
            return .init(variable: .precipitation)
        case .showers:
            return .init(variable: .showers)
        case .relativehumidity_2m:
            return .init(variable: .relativehumidity, altitude: 2)
        case .pressure_msl:
            return .init(variable: .pressureMsl)
        }
    }
}


extension CfsVariableDerived: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .windspeed_10m:
            return .init(variable: .windspeed, altitude: 10)
        case .winddirection_10m:
            return .init(variable: .winddirection, altitude: 10)
        }
    }
}

extension DailyCfsVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .temperature_2m_max:
            return .init(variable: .temperature, aggregation: .maximum, altitude: 2)
        case .temperature_2m_min:
            return .init(variable: .temperature, aggregation: .minimum, altitude: 2)
        case .precipitation_sum:
            return .init(variable: .precipitation, aggregation: .sum)
        case .showers_sum:
            return .init(variable: .showers, aggregation: .sum)
        case .shortwave_radiation_sum:
            return .init(variable: .shortwaveRadiation, aggregation: .sum)
        case .windspeed_10m_max:
            return .init(variable: .windspeed, aggregation: .maximum, altitude: 10)
        case .winddirection_10m_dominant:
            return .init(variable: .winddirection, aggregation: .dominant, altitude: 2)
        case .precipitation_hours:
            return .init(variable: .precipitationHours)
        }
    }
}

extension SeasonalForecastDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = SeasonalForecastVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = DailyCfsVariable
    
    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case .cfsv2:
            return .cfsv2
        }
    }
    
    static var memberOffset: Int {
        return 1
    }
}
