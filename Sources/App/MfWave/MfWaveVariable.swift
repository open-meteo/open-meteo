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
    case sea_level_height_msl
    case invert_barometer_height
    
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
        case .sea_level_height_msl, .invert_barometer_height:
            return .metre
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .ocean_u_current, .ocean_v_current:
            return 20 // 0.05 ms (~0.1 knots)
        case .sea_level_height_msl, .invert_barometer_height:
            return 100 // 1cm res
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .ocean_u_current, .ocean_v_current:
            return .hermite(bounds: nil)
        case .sea_level_height_msl, .invert_barometer_height:
            return .hermite(bounds: nil)
        }
    }
}


enum MfCurrentVariableDerived: String, CaseIterable, GenericVariableMixable {
    case ocean_current_velocity
    case ocean_current_direction
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct MfCurrentReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = MfWaveDomain
    typealias Variable = MfCurrentVariable
    typealias Derived = MfCurrentVariableDerived
    typealias MixingVar = VariableOrDerived<MfCurrentVariable, MfCurrentVariableDerived>
    
    let reader: GenericReaderCached<MfWaveDomain, Variable>
    
    func get(raw: MfCurrentVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: MfCurrentVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func get(derived: MfCurrentVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .ocean_current_velocity:
            let u = try get(raw: .ocean_u_current, time: time).data
            let v = try get(raw: .ocean_v_current, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .ocean_current_direction:
            let u = try get(raw: .ocean_u_current, time: time).data
            let v = try get(raw: .ocean_v_current, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v).map {
                ($0+180).truncatingRemainder(dividingBy: 360)
            }
            return DataAndUnit(direction, .degreeDirection)
        }
    }
    
    func prefetchData(derived: MfCurrentVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .ocean_current_direction, .ocean_current_velocity:
            try prefetchData(raw: .ocean_u_current, time: time)
            try prefetchData(raw: .ocean_v_current, time: time)
        }
    }
}

/// Converts negative wave direction to positive
struct MfWaveReader: GenericReaderProtocol {
    typealias Domain = MfWaveDomain
    typealias MixingVar = MfWaveVariable
    
    let reader: GenericReader<MfWaveDomain, MfWaveVariable>
    
    var modelLat: Float {
        return reader.modelLat
    }
    
    var modelLon: Float {
        return reader.modelLon
    }
    
    var modelElevation: ElevationOrSea {
        return reader.modelElevation
    }
    
    var targetElevation: Float {
        return reader.targetElevation
    }
    
    var modelDtSeconds: Int {
        return reader.modelDtSeconds
    }
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        return try reader.getStatic(type: type)
    }
    
    func get(variable: MfWaveVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let data = try reader.get(variable: variable, time: time)
        switch variable {
        case .wave_direction, .wind_wave_direction, .swell_wave_direction:
            let direction = data.data.map {
                ($0+180).truncatingRemainder(dividingBy: 360)
            }
            return DataAndUnit(direction, .degreeDirection)
        default:
            return data
        }
    }
    
    func prefetchData(variable: MfWaveVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
}




enum MfSSTVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case sea_surface_temperature
    
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
        case .sea_surface_temperature:
            return .celsius
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .sea_surface_temperature:
            return 20
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .sea_surface_temperature:
            return .hermite(bounds: nil)
        }
    }
}
