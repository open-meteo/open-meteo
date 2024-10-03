import Foundation
import FlatBuffers
import OpenMeteoSdk


extension MarineVariable: FlatBuffersVariable {
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
        case .ocean_current_velocity:
            return .init(variable: .oceanCurrentVelocity)
        case .ocean_current_direction:
            return .init(variable: .oceanCurrentDirection)
        }
    }
}

extension IconWaveVariableDaily: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .wave_height_max:
            return .init(variable: .waveHeight, aggregation: .maximum)
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
    typealias HourlyVariable = MarineVariable

    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias HourlyHeightType = ForecastHeightVariableType

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
        case .ecmwf_wam025_ensemble:
            return .ecmwfWam025Ensemble
        case .meteofrance_wave:
            return .meteofranceWave
        case .meteofrance_currents:
            return .meteofranceCurrents
        case .ncep_gfswave025:
            return .ncepGfswave025
        case .ncep_gfswave016:
            // TODO register GFSwave 016
            return .ncepGfswave025
        case .ncep_gefswave025:
            return .ncepGefswave025
        }
    }
}
