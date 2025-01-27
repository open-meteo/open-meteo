
/**
 Definition of GEM domains from the Canadian Weather Service
 */
enum EumetsatSarahDomain: String, GenericDomain, CaseIterable {
    case sarah3_30minutely
    case sarah3_daily
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .sarah3_30minutely:
            return .eumetsat_sarah3_30minutely
        case .sarah3_daily:
            return .eumetsat_sarah3_daily
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
    
    var dtSeconds: Int {
        switch self {
        case .sarah3_30minutely:
            return 1800
        case .sarah3_daily:
            return 24*3600
        }
    }
    
    var grid: any Gridable {
        return RegularGrid(nx: 2600, ny: 2600, latMin: -65, lonMin: -65, dx: 0.05, dy: 0.05)
    }
    
    var updateIntervalSeconds: Int {
        return 24*3600
    }
    
    var omFileLength: Int {
        switch self {
        case .sarah3_30minutely:
            return 2*24*7
        case .sarah3_daily:
            return 30
        }
    }
    
}
