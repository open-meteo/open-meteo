enum EumetsatLsaSafDomain: String, GenericDomain, CaseIterable {
    case msg
    case iodc
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .msg:
            return .eumetsat_lsa_saf_msg_15min
        case .iodc:
            return .eumetsat_lsa_saf_iodc_15min
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
        case .msg, .iodc:
            return 15*60
        }
    }
    
    var grid: any Gridable {
        switch self {
        case .msg:
            return RegularGrid(nx: 3201, ny: 3201, latMin: -80, lonMin: -80, dx: 0.05, dy: 0.05)
        case .iodc:
            return RegularGrid(nx: 3201, ny: 3201, latMin: -80, lonMin: -40, dx: 0.05, dy: 0.05)
        }
        
    }
    
    var updateIntervalSeconds: Int {
        return 24*3600
    }
    
    var omFileLength: Int {
        switch self {
        case .msg, .iodc:
            // 3 days per file
            return 4*24*3
        }
    }
}
