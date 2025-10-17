enum JaxaHimawariDomain: String, GenericDomain, CaseIterable {
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

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var hasYearlyFiles: Bool {
        switch self {
        case .himawari_10min:
            return true
        case .himawari_70e_10min:
            return false
        case .mtg_fci_10min:
            return false
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

    var grid: any Gridable {
        switch self {
        case .himawari_10min:
            return RegularGrid(nx: 2401, ny: 2401, latMin: -60, lonMin: 80, dx: 0.05, dy: 0.05)
        case .himawari_70e_10min:
            return RegularGrid(nx: 2801, ny: 2401, latMin: -60, lonMin: 70, dx: 0.05, dy: 0.05)
        case .mtg_fci_10min:
            return RegularGrid(nx: 2801, ny: 2401, latMin: -60, lonMin: -70, dx: 0.05, dy: 0.05)
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
}
