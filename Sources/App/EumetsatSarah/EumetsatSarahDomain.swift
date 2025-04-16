enum EumetsatSarahDomain: String, GenericDomain, CaseIterable {
    case sarah3_30min

    var domainRegistry: DomainRegistry {
        switch self {
        case .sarah3_30min:
            return .eumetsat_sarah3_30min
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var hasYearlyFiles: Bool {
        return true
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

    var grid: any Gridable {
        return RegularGrid(nx: 2600, ny: 2600, latMin: -65, lonMin: -65, dx: 0.05, dy: 0.05)
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
