/// RUC interval maxima must remain maxima when quarter-hour output is aggregated to hours.
struct IconRucVariable: GenericVariable, GenericVariableMixable, Hashable {
    let variable: IconVariable

    init?(rawValue: String) {
        guard let variable = IconVariable(rawValue: rawValue) else { return nil }
        self.variable = variable
    }

    var rawValue: String { variable.rawValue }
    var omFileName: (file: String, level: Int) { variable.omFileName }
    var scalefactor: Float { variable.scalefactor }
    var unit: SiUnit { variable.unit }
    var isElevationCorrectable: Bool { variable.isElevationCorrectable }
    var storePreviousForecast: Bool { variable.storePreviousForecast }
    var interpolation: ReaderInterpolation {
        switch variable {
        case .surface(.updraft), .surface(.wind_gusts_10m): return .backwards_max
        default: return variable.interpolation
        }
    }
}
