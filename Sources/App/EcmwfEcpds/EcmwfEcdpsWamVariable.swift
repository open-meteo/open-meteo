enum EcmwfEcdpsWamVariable: String, CaseIterable, GenericVariable {
    case wave_direction
    case wave_height
    case wave_period
    case wave_peak_period
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wave_height:
            return 50 // 0.02m resolution
        case .wave_period, .wave_peak_period:
            return 20 // 0.05s resolution
        case .wave_direction:
            return 1
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .wave_height:
            return .linear
        case .wave_period, .wave_peak_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wave_direction:
            return .linearDegrees
        }
    }
    var unit: SiUnit {
        switch self {
        case .wave_height:
            return .metre
        case .wave_period, .wave_peak_period:
            return .seconds
        case .wave_direction:
            return .degreeDirection
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        switch self {
        case .wave_direction, .wave_height, .wave_period, .wave_peak_period:
            return true
        }
    }
    
    var gribCode: String {
        switch self {
        case .wave_direction:
            return "mwd"
        case .wave_height:
            return "swh" // Significant height of combined wind waves and swell
        case .wave_period:
            return "mwp"
        case .wave_peak_period:
            return "pp1d"
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        default:
            return nil
        }
    }
}
