enum EumetsatSarahDomain: String, SyncGridDomain, CaseIterable {
    case sarah3_30min

    var domainRegistry: DomainRegistry {
        switch self {
        case .sarah3_30min:
            return .eumetsat_sarah3_30min
        }
    }

    var syncGridRegistry: SyncGridRegistry { .eumetsat_sarah3_30min }
    
    var countEnsembleMember: Int {
        return 1
    }
    
    var generateFullRun: Bool {
         return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        switch self {
        case .sarah3_30min:
            return 1800
        }
    }

    var updateIntervalSeconds: Int {
        return 24 * 3600
    }

    var omFileLength: Int {
        switch self {
        case .sarah3_30min:
            return 2 * 24 * 7
        }
    }
}
