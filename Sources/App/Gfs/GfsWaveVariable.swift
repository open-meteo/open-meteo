import Foundation

enum GfsWaveVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case wave_height
    case wave_period
    case wave_direction
    case wind_wave_height
    case wind_wave_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_direction
    case secondary_swell_wave_height
    case secondary_swell_wave_period
    case secondary_swell_wave_direction
    case tertiary_swell_wave_height
    case tertiary_swell_wave_period
    case tertiary_swell_wave_direction

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
        case .swell_wave_height, .secondary_swell_wave_height, .tertiary_swell_wave_height:
            return .metre
        case .swell_wave_period, .secondary_swell_wave_period, .tertiary_swell_wave_period:
            return .seconds
        case .swell_wave_direction, .secondary_swell_wave_direction, .tertiary_swell_wave_direction:
            return .degreeDirection
        }
    }

    var scalefactor: Float {
        let period: Float = 20 // 0.05s resolution
        let height: Float = 50 // 0.02m resolution
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
        case .swell_wave_height, .secondary_swell_wave_height, .tertiary_swell_wave_height:
            return height
        case .swell_wave_period, .secondary_swell_wave_period, .tertiary_swell_wave_period:
            return period
        case .swell_wave_direction, .secondary_swell_wave_direction, .tertiary_swell_wave_direction:
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
        case .swell_wave_height, .secondary_swell_wave_height, .tertiary_swell_wave_height:
            return .linear
        case .swell_wave_period, .secondary_swell_wave_period, .tertiary_swell_wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .swell_wave_direction, .secondary_swell_wave_direction, .tertiary_swell_wave_direction:
            return .linearDegrees
        }
    }
}

extension GfsWaveVariable: GfsVariableDownloadable {
    func gribIndexName(for domain: GfsDomain, timestep: Int?) -> String? {
        switch self {
        case .wave_height:
            return ":HTSGW:surface:"
        case .wave_period:
            return ":PERPW:surface:"
        case .wave_direction:
            return ":DIRPW:surface:"
        case .wind_wave_height:
            return ":WVHGT:surface:"
        case .wind_wave_period:
            return ":WVPER:surface:"
        case .wind_wave_direction:
            return ":WVDIR:surface:"
        case .swell_wave_height:
            return ":SWELL:1 in sequence:"
        case .swell_wave_period:
            return ":SWPER:1 in sequence:"
        case .swell_wave_direction:
            return "SWDIR:1 in sequence:"
        case .secondary_swell_wave_height:
            return ":SWELL:2 in sequence:"
        case .secondary_swell_wave_period:
            return ":SWPER:2 in sequence:"
        case .secondary_swell_wave_direction:
            return "SWDIR:2 in sequence:"
        case .tertiary_swell_wave_height:
            return ":SWELL:3 in sequence:"
        case .tertiary_swell_wave_period:
            return ":SWPER:3 in sequence:"
        case .tertiary_swell_wave_direction:
            return "SWDIR:3 in sequence:"
        }
    }

    func skipHour0(for domain: GfsDomain) -> Bool {
        return false
    }

    func multiplyAdd(domain: GfsDomain) -> (multiply: Float, add: Float)? {
        return nil
    }
}
