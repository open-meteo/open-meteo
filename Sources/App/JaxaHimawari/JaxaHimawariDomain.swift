enum JaxaHimawariDomain: String, SyncGridDomain, CaseIterable {
    case himawari_10min
    /// Extented domain area to 70E
    case himawari_70e_10min
    case mtg_fci_10min

    var domainRegistry: DomainRegistry {
        switch self {
        case .himawari_10min:
            return .jma_jaxa_himawari_10min
        case .himawari_70e_10min:
            return .jma_jaxa_himawari_70e_10min
        case .mtg_fci_10min:
            return .jma_jaxa_mtg_fci_10min
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .himawari_10min:
            return .jma_jaxa_himawari_10min
        case .himawari_70e_10min:
            return .jma_jaxa_himawari_70e_10min
        case .mtg_fci_10min:
            return .jma_jaxa_mtg_fci_10min
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        switch self {
        case .himawari_10min, .mtg_fci_10min, .himawari_70e_10min:
            return 600
        }
    }

    var updateIntervalSeconds: Int {
        return 24 * 3600
    }

    var omFileLength: Int {
        switch self {
        case .himawari_10min, .mtg_fci_10min, .himawari_70e_10min:
            return 6 * 24 * 2
        }
    }
    
    var countEnsembleMember: Int {
        return 1
    }
    
    var generateFullRun: Bool {
         return false
    }
}
