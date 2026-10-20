import Foundation

enum KmaDomain: String, SyncGridDomain, CaseIterable {
    case gdps
    case ldps

    var domainRegistry: DomainRegistry {
        switch self {
        case .gdps:
            return .kma_gdps
        case .ldps:
            return .kma_ldps
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .gdps:
            return .kma_gdps
        case .ldps:
            return .kma_ldps
        }
    }

    var dtSeconds: Int {
        switch self {
        case .gdps:
            return 3 * 3600
        case .ldps:
            return 1 * 3600
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        switch self {
        case .gdps:
            // 96 steps per run + 2 days extra
            return 96 + 16
        case .ldps:
            // 49 hours per run + 1 day extra
            return 48 + 24
        }
    }
    
    var countEnsembleMember: Int {
        return 1
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .gdps, .ldps:
            return 6 * 3600
        }
    }

    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gdps, .ldps:
            // Delay of 3:20 hours after initialisation, updates every 6 hours. Cronjob every x:20
            // LDPS 3:40 delay
            return t.add(hours: -3).floor(toNearestHour: 6)
        }
    }
}
