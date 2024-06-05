import Foundation
import FlatBuffers
import OpenMeteoSdk


extension IconWaveVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .wave_height:
            return .init(variable: .waveHeight)
        case .wave_period:
            return .init(variable: .wavePeriod)
        case .wave_direction:
            return .init(variable: .waveDirection)
        case .wind_wave_height:
            return .init(variable: .windWaveHeight)
        case .wind_wave_period:
            return .init(variable: .windWavePeriod)
        case .wind_wave_peak_period:
            return .init(variable: .windWavePeakPeriod)
        case .wind_wave_direction:
            return .init(variable: .windWaveDirection)
        case .swell_wave_height:
            return .init(variable: .swellWaveHeight)
        case .swell_wave_period:
            return .init(variable: .swellWavePeriod)
        case .swell_wave_peak_period:
            return .init(variable: .swellWavePeakPeriod)
        case .swell_wave_direction:
            return .init(variable: .swellWaveDirection)
        }
    }
}

extension IconWaveVariableDaily: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .wave_height_max:
            return .init(variable: .windWaveHeight, aggregation: .maximum)
        case .wind_wave_height_max:
            return .init(variable: .windWaveHeight, aggregation: .maximum)
        case .swell_wave_height_max:
            return .init(variable: .swellWaveHeight, aggregation: .maximum)
        case .wave_direction_dominant:
            return .init(variable: .waveDirection, aggregation: .dominant)
        case .wind_wave_direction_dominant:
            return .init(variable: .windWaveDirection, aggregation: .dominant)
        case .swell_wave_direction_dominant:
            return .init(variable: .swellWaveDirection, aggregation: .dominant)
        case .wave_period_max:
            return .init(variable: .wavePeriod, aggregation: .maximum)
        case .wind_wave_period_max:
            return .init(variable: .windWavePeriod, aggregation: .maximum)
        case .wind_wave_peak_period_max:
            return .init(variable: .windWavePeakPeriod, aggregation: .maximum)
        case .swell_wave_period_max:
            return .init(variable: .swellWavePeriod, aggregation: .maximum)
        case .swell_wave_peak_period_max:
            return .init(variable: .swellWavePeakPeriod, aggregation: .maximum)
        }
    }
}

extension IconWaveDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = IconWaveVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = IconWaveVariableDaily
    
    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case.best_match:
            return .bestMatch
        case .gwam:
            return .gwam
        case .ewam:
            return .ewam
        case .era5_ocean:
            return .era5Ocean
        case .ecmwf_wam025:
            return .ecmwfWam025
        }
    }
}
