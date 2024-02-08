import Foundation

/// Represent a variable combined with a pressure level and helps decoding it
struct VariableAndMemberAndControl<Variable: RawRepresentableString>: RawRepresentableString {
    var variable: Variable
    var member: Int
    
    init(_ variable: Variable, _ member: Int) {
        self.variable = variable
        self.member = member
    }

    init?(rawValue: String) {
        guard
            let pos = rawValue.lastIndex(of: "_"),
                let startPos = rawValue.index(pos, offsetBy: 7, limitedBy: rawValue.endIndex),
                let member = Int(rawValue[startPos..<rawValue.endIndex])
        else {
            guard let variable = Variable(rawValue: rawValue) else {
                return nil
            }
            self.variable = variable
            self.member = 0
            return
        }
        guard let variable = Variable(rawValue: String(rawValue[rawValue.startIndex..<pos])) else {
            return nil
        }
        self.variable = variable
        self.member = member
    }
    
    var rawValue: String {
        if member == 0 {
            return variable.rawValue
        }
        return "\(variable.rawValue)_member\(member.zeroPadded(len: 2))"
    }
    
    init(from decoder: Decoder) throws {
        fatalError()
    }
    
    func encode(to encoder: Encoder) throws {
        var e = encoder.singleValueContainer()
        try e.encode(rawValue)
    }
}

extension VariableAndMemberAndControl: Hashable, Equatable where Variable: Hashable {
    
}

extension VariableAndMemberAndControl: GenericVariable where Variable: GenericVariable {
    /// Note: ensemble models use levels to encode different members, therefore the filename does not contain the member number
    var omFileName: (file: String, level: Int) {
        return (variable.omFileName.file, member)
    }
    
    var storePreviousForecast: Bool {
        variable.storePreviousForecast
    }
    
    var scalefactor: Float {
        variable.scalefactor
    }
    
    var interpolation: ReaderInterpolation {
        variable.interpolation
    }
    
    var unit: SiUnit {
        variable.unit
    }
    
    var isElevationCorrectable: Bool {
        variable.isElevationCorrectable
    }
}

extension VariableAndMemberAndControl: GenericVariableMixable where Variable: GenericVariableMixable {
    var requiresOffsetCorrectionForMixing: Bool {
        variable.requiresOffsetCorrectionForMixing
    }
}


struct VariableAndPreviousDay: RawRepresentableString {
    var variable: ForecastSurfaceVariable
    var previousDay: Int
    
    init(_ variable: ForecastSurfaceVariable, _ previousDay: Int) {
        self.variable = variable
        self.previousDay = previousDay
    }

    init?(rawValue: String) {
        guard
            let pos = rawValue.range(of: "_previous_day"),
            let previousDay = Int(rawValue[pos.upperBound..<rawValue.endIndex])
        else {
            guard let variable = ForecastSurfaceVariable(rawValue: rawValue) else {
                return nil
            }
            self.variable = variable
            self.previousDay = 0
            return
        }
        guard let variable = ForecastSurfaceVariable(rawValue: String(rawValue[rawValue.startIndex..<pos.lowerBound])) else {
            return nil
        }
        self.variable = variable
        self.previousDay = previousDay
    }
    
    var rawValue: String {
        if previousDay == 0 {
            return variable.rawValue
        }
        return "\(variable.rawValue)_previous_day\(previousDay)"
    }
    
    init(from decoder: Decoder) throws {
        fatalError()
    }
    
    func encode(to encoder: Encoder) throws {
        var e = encoder.singleValueContainer()
        try e.encode(rawValue)
    }
}

extension VariableAndPreviousDay: Hashable, Equatable {}

extension VariableAndPreviousDay: GenericVariableMixable {
    var requiresOffsetCorrectionForMixing: Bool {
        variable.requiresOffsetCorrectionForMixing
    }
}
