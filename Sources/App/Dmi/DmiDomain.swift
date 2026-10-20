import Foundation

/**
 https://opendatadocs.dmi.govcloud.dk/Data/Forecast_Data_Weather_Model_HARMONIE_DINI_IG
 
 */
enum DmiDomain: String, SyncGridDomain, CaseIterable {
    case harmonie_arome_europe

    var countEnsembleMember: Int {
        return 1
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .dmi_harmonie_arome_europe
        }
    }

    var syncGridRegistry: SyncGridRegistry { .dmi_harmonie_arome_europe }

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

    var ensembleMembers: Int {
        switch self {
        case .harmonie_arome_europe:
            return 1
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .harmonie_arome_europe:
            return 3 * 3600
        }
    }

    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe:
            // Delay of 2:30 hours after initialisation, updates every 3 hours. Cronjob every x:35
            return t.add(hours: -2).floor(toNearestHour: 3)
        }
    }
}
