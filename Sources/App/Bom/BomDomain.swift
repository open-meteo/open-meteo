import Foundation

/**
 Weather forecast domains from the Australian Bureau of Meteorology (BOM)
 http://www.bom.gov.au/nwp/doc/access/NWPData.shtml
 
 No mesoscale model yet, only global
 */
enum BomDomain: String, GenericDomain, CaseIterable {
    case access_global
    case access_global_ensemble
    
    var grid: Gridable {
        switch self {
        case .access_global:
            return RegularGrid(nx: 2048, ny: 1536, latMin: -89.941406, lonMin: -179.912109, dx: 360/2048, dy: 180/1536)
        case .access_global_ensemble:
            return RegularGrid(nx: 800, ny: 600, latMin: -89.85, lonMin: -179.775, dx: 360/800, dy: 180/600)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .access_global:
            return .bom_access_global
        case .access_global_ensemble:
            return .bom_access_global_ensemble
        }
    }
    
    var ensembleMembers: Int {
        switch self {
        case .access_global_ensemble:
            return 17+1
        default:
            return 1
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .access_global: return 3600
        case .access_global_ensemble: return 3*3600
        }
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .access_global: return 240+48
        case .access_global_ensemble: return (240+48) / 3
        }
    }
    
    /// Last forecast hour per run
    /*func forecastHours(run: Int) -> Int {
        switch self {
        case .access_global:
            return (run % 12 == 6) ? 84 : 240
        }
    }*/
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .access_global:
            // Delay of 8:50 hours (0/12z) or 7:15 (6/18z) after initialisation with 4 runs a day
            return t.add(hours: -7).with(hour: ((t.hour - 7 + 24) % 24) / 6 * 6)
        case .access_global_ensemble:
            // Delay of 14:15 hours, 4 runs
            return t.add(hours: -14).with(hour: ((t.hour - 14 + 24) % 24) / 6 * 6)
        }
    }
}
