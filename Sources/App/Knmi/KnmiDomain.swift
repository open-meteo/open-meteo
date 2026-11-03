import Foundation

/**
 https://english.knmidata.nl/latest/newsletters/open-data-newsletter/2024/open-data-march-2024
 
 */
enum KnmiDomain: String, SyncGridDomain, CaseIterable {
    case harmonie_arome_europe
    case harmonie_arome_netherlands

    var domainRegistry: DomainRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .knmi_harmonie_arome_europe
        case .harmonie_arome_netherlands:
            return .knmi_harmonie_arome_netherlands
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .knmi_harmonie_arome_europe
        case .harmonie_arome_netherlands:
            return .knmi_harmonie_arome_netherlands
        }
    }

    var dtSeconds: Int {
        return 1 * 3600
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        // 60 timesteps
        return 90
    }
    
    var countEnsembleMember: Int {
        return 1
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            return 3600
        }
    }

    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            // Delay of 2:30 hours after initialisation, updates every hour. Cronjob every x:35
            return t.add(hours: -2).floor(toNearestHour: 1)
        }
    }
}
