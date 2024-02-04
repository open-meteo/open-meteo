import Foundation
import SwiftPFor2D


enum EcmwfDomain: String, GenericDomain {
    case ifs04
    case ifs04_ensemble
    
    case ifs025
    case ifs025_ensemble
    
    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch run {
        case 0,12: return Array(stride(from: 0, through: 144, by: 3)) + Array(stride(from: 150, through: isEnsemble ? 360 : 240, by: 6))
        case 6,18: return Array(stride(from: 0, through: isEnsemble ? 144 : 90, by: 3))
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
        return 3*3600
    }
    
    var grid: Gridable {
        switch self {
        case .ifs04, .ifs04_ensemble:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 360/900, dy: 180/450)
        case .ifs025, .ifs025_ensemble:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 360/1440, dy: 180/721)
        }
        
    }
    
    var ensembleMembers: Int {
        switch self {
        case .ifs04, .ifs025:
            return 1
        case .ifs04_ensemble, .ifs025_ensemble:
            return 50+1
        }
    }
    
    
    var isEnsemble: Bool {
        return ensembleMembers > 1
    }
}
