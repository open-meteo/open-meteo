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
    
    /// Name used on the dwd open data server
    var netcdfName: String {
        switch self {
        case .wave_height:
            return "VHM0"
        case .wave_period:
            return "VTM10"
        case .wave_direction:
            return "VMDR"
        case .wind_wave_height:
            return "VHM0_WW"
        case .wind_wave_period:
            return "VTM01_WW"
        case .wind_wave_direction:
            return "VMDR_WW"
        case .swell_wave_height:
            return "VHM0_SW1"
        case .swell_wave_period:
            return "VTM01_SW1"
        case .swell_wave_direction:
            return "VMDR_SW1"
        }
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
