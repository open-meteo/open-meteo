import Foundation

struct VariableAndPreviousDay: RawRepresentableString {
    var variable: ForecastSurfaceVariable
    var previousDay: Int
    var percentile: WeatherNext3Variable.Statistic? = nil

    init(_ variable: ForecastSurfaceVariable, _ previousDay: Int) {
        self.variable = variable
        self.previousDay = previousDay
    }

    init?(rawValue: String) {
        if let native = WeatherNext3Variable(rawValue: rawValue), native.statistic != .mean,
            let variable = ForecastSurfaceVariable(rawValue: native.field.rawValue) {
            self.variable = variable
            self.previousDay = 0
            self.percentile = native.statistic
            return
        }
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
        if let percentile {
            return variable.rawValue + "_" + percentile.rawValue
        }
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
}
