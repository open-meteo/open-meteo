enum EumetsatSarahVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case shortwave_radiation
    case direct_radiation
    case shortwave_radiation_corrected
    case direct_radiation_corrected

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_corrected, .direct_radiation_corrected:
            return 1
        }
    }

    var eumetsatName: String {
        switch self {
        case .shortwave_radiation, .shortwave_radiation_corrected:
            return "SIS"
        case .direct_radiation, .direct_radiation_corrected:
            return "SID"
        }
    }

    var eumetsatApiName: String {
        switch self {
        case .shortwave_radiation, .shortwave_radiation_corrected:
            return "SISin"
        case .direct_radiation, .direct_radiation_corrected:
            return "SIDin"
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_corrected, .direct_radiation_corrected:
            return .solar_backwards_missing_not_averaged
        }
    }

    var unit: SiUnit {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_corrected, .direct_radiation_corrected:
            return .wattPerSquareMetre
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return false
    }
}
