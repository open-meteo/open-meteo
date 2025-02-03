
enum EumetsatLsaSafVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case shortwave_radiation
    case direct_radiation
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_missing_not_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}


