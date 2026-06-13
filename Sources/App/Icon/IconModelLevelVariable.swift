import Foundation

/// Variables available on ICON native model (full) levels.
/// Currently only geometric height, derived on read from the static HHL stack.
enum IconModelLevelVariableType: String, CaseIterable, Sendable {
    /// Geometric height of the full level, above sea level (m)
    case height
    /// Geometric height of the full level, above the model surface (m)
    case height_agl
}

/// A variable on a native ICON model full level, named `<variable>_level<N>`
/// where `N` is the DWD-native full-level index (1 = model top, N = lowest layer near surface).
///
/// These are not stored as time-series `.om` files; `IconReader` intercepts them and computes
/// the value from the static `hhl.om` half-level stack (see `fullLevelHeightASL/AGL`).
struct IconModelLevelVariable: ModelLevelVariableRespresentable, IconVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: IconModelLevelVariableType
    let level: Int

    /// Placeholder — model-level height is computed, never read from a per-variable file.
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float { 1 }

    var interpolation: ReaderInterpolation { .linear }

    var unit: SiUnit { .metre }

    var isElevationCorrectable: Bool { false }

    var storePreviousForecast: Bool { false }

    // MARK: IconVariableDownloadable (heights are computed from static HHL, never downloaded)

    func skipHour(hour: Int, domain: IconDomains, forDownload: Bool, run: Timestamp) -> Bool { false }

    var multiplyAdd: (multiply: Float, add: Float)? { nil }

    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?)? { nil }
}
