import Foundation

/**

 */
enum ArpaeDomain: String, GenericDomain, CaseIterable {
    case cosmo_2i
    case comos_2m
    
    var grid: Gridable {
        switch self {
        case .cosmo_2i:
            return RegularGrid(nx: 2048, ny: 1536, latMin: -89.941406, lonMin: -179.912109, dx: 360/2048, dy: 180/1536)
        case .comos_2m:
            return RegularGrid(nx: 800, ny: 600, latMin: -89.85, lonMin: -179.775, dx: 360/800, dy: 180/600)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .cosmo_2i:
            return .bom_access_global
        case .comos_2m:
            return .bom_access_global_ensemble
        }
    }
    
    var ensembleMembers: Int {
        return 1
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .cosmo_2i: return 3600
        case .comos_2m: return 3*3600
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
        case .cosmo_2i: return 240+48
        case .comos_2m: return (240+48) / 3
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .cosmo_2i:
            // Delay of 8:50 hours (0/12z) or 7:15 (6/18z) after initialisation with 4 runs a day
            return t.add(hours: -7).with(hour: ((t.hour - 7 + 24) % 24) / 6 * 6)
        case .comos_2m:
            // Delay of 14:15 hours, 4 runs
            return t.add(hours: -14).with(hour: ((t.hour - 14 + 24) % 24) / 6 * 6)
        }
    }
}
