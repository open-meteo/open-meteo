import Foundation
import OmFileFormat
import Vapor

/// ČHMÚ (Czech Hydrometeorological Institute) ALADIN models
/// Data: https://opendata.chmi.cz/meteorology/weather/nwp_aladin/
/// 72h hourly forecast, 4 runs/day (00/06/12/18 UTC)
enum ChmiDomain: String, SyncGridDomain, CaseIterable {
    case aladin_cz_1km
    case aladin_central_europe_2km

    var domainRegistry: DomainRegistry {
        switch self {
        case .aladin_cz_1km:
            return .chmi_aladin_cz_1km
        case .aladin_central_europe_2km:
            return .chmi_aladin_central_europe_2km
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .aladin_cz_1km:
            return .chmi_aladin_cz_1km
        case .aladin_central_europe_2km:
            return .chmi_aladin_central_europe_2km
        }
    }

    var countEnsembleMember: Int {
        return 1
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        return 3600
    }

    var isGlobal: Bool {
        return false
    }

    var lastRun: Timestamp {
        // Runs every 6 hours (00, 06, 12, 18 UTC). Files arrive roughly 3.5h after the run.
        return Timestamp.now().add(-3 * 3600 - 30 * 60).floor(toNearestHour: 6)
    }

    /// 72h forecast + 2 days buffer
    var omFileLength: Int {
        return 120
    }

    var updateIntervalSeconds: Int {
        return 21600 // 6 hours
    }
}
