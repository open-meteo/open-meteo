import Foundation

enum IconWaveVariableDaily: String, Codable {
    case wave_height_max
    case wind_wave_height_max
    case swell_wave_height_max
    
    case wave_direction_dominant
    case wind_wave_direction_dominant
    case swell_wave_direction_dominant
    
    case wave_period_max
    case wind_wave_period_max
    case wind_wave_peak_period_max
    case swell_wave_period_max
    case swell_wave_peak_period_max
    
}

extension IconWaveMixer {
    func get(variable: IconWaveVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(variable), time: time)
    }
    
    func prefetchData(variable: IconWaveVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(variable), time: time)
    }
    
    func getDaily(variable: IconWaveVariableDaily, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: 3600)
        switch variable {
        case .wave_height_max:
            let data = try get(variable: .wave_height, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .wind_wave_height_max:
            let data = try get(variable: .wind_wave_height, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .swell_wave_height_max:
            let data = try get(variable: .swell_wave_height, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .wave_direction_dominant:
            let data = try get(variable: .wave_direction, time: time)
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .wind_wave_direction_dominant:
            let data = try get(variable: .wind_wave_direction, time: time)
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .swell_wave_direction_dominant:
            let data = try get(variable: .swell_wave_direction, time: time)
            return DataAndUnit(data.data.mean(by: 24), data.unit)
        case .wave_period_max:
            let data = try get(variable: .wave_period, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .wind_wave_period_max:
            let data = try get(variable: .wind_wave_period, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .wind_wave_peak_period_max:
            let data = try get(variable: .wind_wave_peak_period, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .swell_wave_period_max:
            let data = try get(variable: .swell_wave_period, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .swell_wave_peak_period_max:
            let data = try get(variable: .swell_wave_peak_period, time: time)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        }
    }
    
    func prefetchData(variables: [IconWaveVariableDaily], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: 3600)
        for variable in variables {
            switch variable {
            case .wave_height_max:
                try prefetchData(variable: .wave_height, time: time)
            case .wind_wave_height_max:
                try prefetchData(variable: .wind_wave_height, time: time)
            case .swell_wave_height_max:
                try prefetchData(variable: .swell_wave_height, time: time)
            case .wave_direction_dominant:
                try prefetchData(variable: .wave_direction, time: time)
            case .wind_wave_direction_dominant:
                try prefetchData(variable: .wind_wave_direction, time: time)
            case .swell_wave_direction_dominant:
                try prefetchData(variable: .swell_wave_direction, time: time)
            case .wave_period_max:
                try prefetchData(variable: .wave_period, time: time)
            case .wind_wave_period_max:
                try prefetchData(variable: .wind_wave_period, time: time)
            case .wind_wave_peak_period_max:
                try prefetchData(variable: .wind_wave_peak_period, time: time)
            case .swell_wave_period_max:
                try prefetchData(variable: .swell_wave_period, time: time)
            case .swell_wave_peak_period_max:
                try prefetchData(variable: .swell_wave_peak_period, time: time)
            }
        }
    }
}
