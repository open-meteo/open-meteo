import Foundation


/// Represent a variable combined with a pressure level and helps decoding it
protocol PressureVariableRespresentable: RawRepresentable where RawValue == String, Variable.RawValue == String {
    associatedtype Variable: RawRepresentable
    
    var variable: Variable { get }
    var level: Int { get }
    
    init(variable: Variable, level: Int)
}

extension PressureVariableRespresentable {
    init?(rawValue: String) {
        guard let pos = rawValue.lastIndex(of: "_"), let posEnd = rawValue[pos..<rawValue.endIndex].range(of: "hPa") else {
            return nil
        }
        let variableString = rawValue[rawValue.startIndex ..< pos]
        guard let variable = Variable(rawValue: String(variableString)) else {
            return nil
        }
        
        let start = rawValue.index(after: pos)
        let levelString = rawValue[start..<posEnd.lowerBound]
        guard let level = Int(levelString) else {
            return nil
        }
        self.init(variable: variable, level: level)
    }
    
    var rawValue: String {
        return "\(variable.rawValue)_\(level)hPa"
    }
    
    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let initialised = Self.init(rawValue: s) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize \(Self.self) from invalid String value \(s)", underlyingError: nil))
        }
        self = initialised
    }
    
    func encode(to encoder: Encoder) throws {
        var e = encoder.singleValueContainer()
        try e.encode(rawValue)
    }
}

protocol RawRepresentableString {
    init?(rawValue: String)
    var rawValue: String { get }
}

/// Enum with surface and pressure variable
enum SurfaceAndPressureVariable<Surface: RawRepresentableString, Pressure: RawRepresentableString>: RawRepresentableString {
    case surface(Surface)
    case pressure(Pressure)
    
    init?(rawValue: String) {
        if let variable = Pressure(rawValue: rawValue) {
            self = .pressure(variable)
            return
        }
        if let variable = Surface(rawValue: rawValue) {
            self = .surface(variable)
            return
        }
        return nil
    }
    
    var rawValue: String {
        switch self {
        case .surface(let variable): return variable.rawValue
        case .pressure(let variable): return variable.rawValue
        }
    }
}

extension SurfaceAndPressureVariable: Hashable, Equatable where Pressure: Hashable, Surface: Hashable {
    
}

extension SurfaceAndPressureVariable: GenericVariable where Surface: GenericVariable, Pressure: GenericVariable {
    var asGenericVariable: GenericVariable {
        switch self {
        case .surface(let surface):
            return surface
        case .pressure(let pressure):
            return pressure
        }
    }
    
    var omFileName: (file: String, level: Int) {
        asGenericVariable.omFileName
    }
    
    var scalefactor: Float {
        asGenericVariable.scalefactor
    }
    
    var interpolation: ReaderInterpolation {
        asGenericVariable.interpolation
    }
    
    var unit: SiUnit {
        asGenericVariable.unit
    }
    
    var isElevationCorrectable: Bool {
        asGenericVariable.isElevationCorrectable
    }
}

extension SurfaceAndPressureVariable: GenericVariableMixable where Surface: GenericVariableMixable, Pressure: GenericVariableMixable {
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .surface(let surface):
            return surface.requiresOffsetCorrectionForMixing
        case .pressure(let pressure):
            return pressure.requiresOffsetCorrectionForMixing
        }
    }
}

enum VariableOrDerived<Raw: RawRepresentableString, Derived: RawRepresentableString>: RawRepresentableString {
    case raw(Raw)
    case derived(Derived)
    
    init?(rawValue: String) {
        if let val = Raw.init(rawValue: rawValue) {
            self = .raw(val)
            return
        }
        if let val = Derived.init(rawValue: rawValue) {
            self = .derived(val)
            return
        }
        return nil
    }
    
    var rawValue: String {
        switch self {
        case .raw(let raw):
            return raw.rawValue
        case .derived(let derived):
            return derived.rawValue
        }
    }
    
    var name: String {
        switch self {
        case .raw(let variable): return variable.rawValue
        case .derived(let variable): return variable.rawValue
        }
    }
}
