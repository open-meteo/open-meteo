import Foundation

enum MfWaveVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case wave_height
    case wave_period
    case wave_direction
    case wind_wave_height
    case wind_wave_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_direction
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    /// Si unit
    var unit: SiUnit {
        switch self {
        case .wave_height:
            return .metre
        case .wave_period:
            return .seconds
        case .wave_direction:
            return .degreeDirection
        case .wind_wave_height:
            return .metre
        case .wind_wave_period:
            return .seconds
        case .wind_wave_direction:
            return .degreeDirection
        case .swell_wave_height:
            return .metre
        case .swell_wave_period:
            return .seconds
        case .swell_wave_direction:
            return .degreeDirection
        }
    }
    
    var scalefactor: Float {
        let period: Float = 20 // 0.05s resolution
        let height: Float = 50 // 0.002m resolution
        let direction: Float = 1
        switch self {
        case .wave_height:
            return height
        case .wave_period:
            return period
        case .wave_direction:
            return direction
        case .wind_wave_height:
            return height
        case .wind_wave_period:
            return period
        case .wind_wave_direction:
            return direction
        case .swell_wave_height:
            return height
        case .swell_wave_period:
            return period
        case .swell_wave_direction:
            return direction
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .wave_height:
            return .linear
        case .wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wave_direction:
            return .linearDegrees
        case .wind_wave_height:
            return .linear
        case .wind_wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wind_wave_direction:
            return .linearDegrees
        case .swell_wave_height:
            return .linear
        case .swell_wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .swell_wave_direction:
            return .linearDegrees
        }
    }
}

enum MfCurrentVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case ocean_u_current
    case ocean_v_current
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    /// Si unit
    var unit: SiUnit {
        switch self {
        case .ocean_u_current, .ocean_v_current:
            return .metrePerSecond
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .ocean_u_current, .ocean_v_current:
            return 100
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .ocean_u_current, .ocean_v_current:
            return .hermite(bounds: nil)
        }
    }
}