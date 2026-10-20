enum EumetsatLsaSafDomain: String, SyncGridDomain, CaseIterable {
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

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .msg:
            return .eumetsat_lsa_saf_msg_15min
        case .iodc:
            return .eumetsat_lsa_saf_iodc_15min
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        switch self {
        case .msg, .iodc:
            return 15 * 60
        }
    }
    
    var generateFullRun: Bool {
         return false
    }
    
    var countEnsembleMember: Int {
        return 1
    }

    var updateIntervalSeconds: Int {
        return 24 * 3600
    }

    var omFileLength: Int {
        switch self {
        case .msg, .iodc:
            // 3 days per file
            return 4 * 24 * 3
        }
    }
}
