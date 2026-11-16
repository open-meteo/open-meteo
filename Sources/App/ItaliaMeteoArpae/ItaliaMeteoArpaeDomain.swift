import Foundation

enum ItaliaMeteoArpaeDomain: String, SyncGridDomain, CaseIterable {
    case icon_2i

    var domainRegistry: DomainRegistry {
        switch self {
        case .icon_2i:
            return .italia_meteo_arpae_icon_2i
        }
    }

    var syncGridRegistry: SyncGridRegistry { .italia_meteo_arpae_icon_2i }

    var dtSeconds: Int {
        switch self {
        case .icon_2i:
            return 3600
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        switch self {
        case .icon_2i:
            // 72 steps per run + 24 hours extra
            return 72 + 24
        }
    }

    var countEnsembleMember: Int {
        return 1
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .icon_2i:
            return 12 * 3600
        }
    }

    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .icon_2i:
            // Delay of 2:35 hours after initialisation, updates every 12 hours. Cronjob every x:30
            return t.add(hours: -2).floor(toNearestHour: 12)
        }
    }
}
