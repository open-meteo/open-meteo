import Foundation

enum IconWaveVariableDaily: String, RawRepresentableString, DailyVariableCalculatable {
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

    var aggregation: DailyAggregation<MarineVariable> {
        switch self {
        case .wave_height_max:
            return .max(.wave_height)
        case .wind_wave_height_max:
            return .max(.wind_wave_height)
        case .swell_wave_height_max:
            return .max(.swell_wave_height)
        case .wave_direction_dominant:
            return .dominantDirection(velocity: .wave_height, direction: .wave_direction)
        case .wind_wave_direction_dominant:
            return .dominantDirection(velocity: .wind_wave_height, direction: .wind_wave_direction)
        case .swell_wave_direction_dominant:
            return .dominantDirection(velocity: .swell_wave_height, direction: .swell_wave_direction)
        case .wave_period_max:
            return .max(.wave_period)
        case .wind_wave_period_max:
            return .max(.wind_wave_period)
        case .wind_wave_peak_period_max:
            return .max(.wind_wave_peak_period)
        case .swell_wave_period_max:
            return .max(.swell_wave_peak_period)
        case .swell_wave_peak_period_max:
            return .max(.swell_wave_peak_period)
        }
    }
}
