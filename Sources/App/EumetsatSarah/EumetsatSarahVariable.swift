
enum EumetsatSarahVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
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
    
    var eumetsatName: String {
        switch self {
        case .shortwave_radiation:
            return "SIS"
        case .direct_radiation:
            return "SID"
        }
    }
    
    var eumetsatApiName: String {
        switch self {
        case .shortwave_radiation:
            return "SISin"
        case .direct_radiation:
            return "SIDin"
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
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


