enum JaxaHimawariDomain: String, GenericDomain, CaseIterable {
    case himawari_10min
    case himawari_hourly
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .himawari_10min:
            return .jma_jaxa_himawari_10min
        case .himawari_hourly:
            return .jma_jaxa_himawari_hourly
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
        case .himawari_10min:
            return 600
        case .himawari_hourly:
            return 3600
        }
    }
    
    var grid: any Gridable {
        return RegularGrid(nx: 2401, ny: 2401, latMin: -60, lonMin: 80, dx: 0.05, dy: 0.05)
    }
    
    var updateIntervalSeconds: Int {
        return 24*3600
    }
    
    var omFileLength: Int {
        switch self {
        case .himawari_10min:
            return 6*24*2
        case .himawari_hourly:
            return 24*7
        }
    }
}
