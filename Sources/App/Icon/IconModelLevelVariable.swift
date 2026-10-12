/// Variables stored separately because their delivery can lag behind surface and pressure fields.
struct IconModelLevelVariable: GenericVariable {
    let variable: IconSurfaceVariable

    init?(rawValue: String) {
        guard let variable = IconSurfaceVariable(rawValue: rawValue),
              variable.getVarAndLevel(domain: .icon)?.cat == "model-level" else {
            return nil
        }
        self.variable = variable
    }

    var rawValue: String { variable.rawValue }
    var omFileName: (file: String, level: Int) { variable.omFileName }
    var scalefactor: Float { variable.scalefactor }
    var interpolation: ReaderInterpolation { variable.interpolation }
    var unit: SiUnit { variable.unit }
    var isElevationCorrectable: Bool { variable.isElevationCorrectable }
    var storePreviousForecast: Bool { variable.storePreviousForecast }
}
