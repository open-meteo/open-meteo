import Foundation
import SwiftPFor2D


enum EcmwfDomain: String, GenericDomain {
    case ifs04
    case ifs04_ensemble
    
    case ifs025
    case ifs025_ensemble
    
    case aifs025
    
    func getDownloadForecastSteps(run: Int) -> [Int] {
        if self == .aifs025 {
            return Array(stride(from: 0, through: 360, by: dtHours))
        }
        switch run {
        case 0,12: return Array(stride(from: 0, through: 144, by: dtHours)) + Array(stride(from: 150, through: isEnsemble ? 360 : 240, by: 6*3600))
        case 6,18: return Array(stride(from: 0, through: isEnsemble ? 144 : 90, by: dtHours))
        default: fatalError("Invalid run")
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .ifs04:
            return .ecmwf_ifs04
        case .ifs04_ensemble:
            return .ecmwf_ifs04_ensemble
        case .ifs025:
            return .ecmwf_ifs025
        case .ifs025_ensemble:
            return .ecmwf_ifs025_ensemble
        case .aifs025:
            return .ecmwf_aifs025
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        // 104
        return (240 + 3*24) / dtHours
    }
    
    var dtSeconds: Int {
        switch self {
        case .ifs04:
            return 3*3600
        case .ifs04_ensemble:
            return 3*3600
        case .ifs025:
            return 3*3600
        case .ifs025_ensemble:
            return 3*3600
        case .aifs025:
            return 6*3600
        }
        
    }
    
    var grid: Gridable {
        switch self {
        case .ifs04, .ifs04_ensemble:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 360/900, dy: 180/450)
        case .ifs025, .ifs025_ensemble:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 360/1440, dy: 180/(721-1))
        case .aifs025:
            return GaussianGrid(type: .n320)
        }
        
    }
    
    var ensembleMembers: Int {
        switch self {
        case .ifs04, .ifs025:
            return 1
        case .ifs04_ensemble, .ifs025_ensemble:
            return 50+1
        case .aifs025:
            return 1
        }
    }
    
    
    var isEnsemble: Bool {
        return ensembleMembers > 1
    }
}
