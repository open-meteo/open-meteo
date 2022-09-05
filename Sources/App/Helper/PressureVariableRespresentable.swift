import Foundation


/// Represent a variable combined with a pressure level and helps decoding it
protocol PressureVariableRespresentable: RawRepresentable, Codable where RawValue == String, Variable.RawValue == String {
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

/// Enum with surface and pressure variable
enum SurfaceAndPressureVariable<Surface, Pressure>: Codable, RawRepresentable where Surface: Codable, Surface: RawRepresentable, Pressure: Codable, Pressure: RawRepresentable, Surface.RawValue == Pressure.RawValue {
    
    case surface(Surface)
    case pressure(Pressure)
    
    init?(rawValue: Surface.RawValue) {
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
    
    init(from decoder: Decoder) throws {
        do {
            let variable = try Pressure(from: decoder)
            self = .pressure(variable)
            return
        } catch {
            let variable = try Surface(from: decoder)
            self = .surface(variable)
            return
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .surface(let value):
            try value.encode(to: encoder)
        case .pressure(let value):
            try value.encode(to: encoder)
        }
    }
    
    var rawValue: Surface.RawValue {
        switch self {
        case .surface(let variable): return variable.rawValue
        case .pressure(let variable): return variable.rawValue
        }
    }
}

extension SurfaceAndPressureVariable: Hashable, Equatable where Pressure: Hashable, Surface: Hashable {
    
}

extension SurfaceAndPressureVariable: GenericVariableMixing, GenericVariable where Surface: GenericVariableMixing, Pressure: GenericVariableMixing {
    var asGenericVariable: GenericVariableMixing {
        switch self {
        case .surface(let surface):
            return surface
        case .pressure(let pressure):
            return pressure
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        asGenericVariable.requiresOffsetCorrectionForMixing
    }
    
    var omFileName: String {
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


enum VariableOrDerived<Raw, Derived>: Codable where Raw: Codable, Raw: RawRepresentable, Derived: Codable, Derived: RawRepresentable, Raw.RawValue == Derived.RawValue {
    case raw(Raw)
    case derived(Derived)
    
    init(from decoder: Decoder) throws {
        do {
            let variable = try Derived(from: decoder)
            self = .derived(variable)
            return
        } catch {
            let variable = try Raw(from: decoder)
            self = .raw(variable)
            return
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .raw(let value):
            try value.encode(to: encoder)
        case .derived(let value):
            try value.encode(to: encoder)
        }
    }
    
    var name: Raw.RawValue {
        switch self {
        case .raw(let variable): return variable.rawValue
        case .derived(let variable): return variable.rawValue
        }
    }
}
