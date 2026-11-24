import Foundation

struct VariableAndPreviousDay: RawRepresentableString {
    enum Percentile: String {
        case p10, p25, p50, p75, p90
    }

    var variable: ForecastSurfaceVariable
    var previousDay: Int
    var percentile: Percentile?

    init(_ variable: ForecastSurfaceVariable, _ previousDay: Int) {
        self.variable = variable
        self.previousDay = previousDay
    }

    init?(rawValue: String) {
        guard
            let pos = rawValue.range(of: "_previous_day"),
            let previousDay = Int(rawValue[pos.upperBound..<rawValue.endIndex])
        else {
            if let variable = ForecastSurfaceVariable(rawValue: rawValue) {
                self.init(variable, 0)
                return
            }
            guard let native = WeatherNext3Variable(rawValue: rawValue),
                  let percentile = Percentile(rawValue: native.statistic.rawValue),
                  let variable = ForecastSurfaceVariable(rawValue: native.field.rawValue) else {
                return nil
            }
            self.init(variable, 0)
            self.percentile = percentile
            return
        }
        guard let variable = ForecastSurfaceVariable(rawValue: String(rawValue[rawValue.startIndex..<pos.lowerBound])) else {
            return nil
        }
        self.init(variable, previousDay)
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
