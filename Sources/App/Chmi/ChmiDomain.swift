import Foundation
import OmFileFormat
import Vapor

/// ČHMÚ (Czech Hydrometeorological Institute) ALADIN CZ 1km regional model
/// Data: https://opendata.chmi.cz/meteorology/weather/nwp_aladin/
/// 72h hourly forecast, 4 runs/day (00/06/12/18 UTC), regular lat/lon grid 501x290.
enum ChmiDomain: String, GenericDomain, CaseIterable {
    case aladin_cz_1km

    var domainRegistry: DomainRegistry {
        switch self {
        case .aladin_cz_1km:
            return .chmi_aladin_cz_1km
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var countEnsembleMember: Int {
        return 1
    }

    var hasYearlyFiles: Bool {
        return false
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

    /// Runs every 6 hours (00, 06, 12, 18 UTC). Files arrive roughly 3.5h after the run.
    var lastRun: Timestamp {
        return Timestamp.now().add(hours: -3).floor(toNearestHour: 6)
    }

    /// 72h forecast + 2 days buffer
    var omFileLength: Int {
        return 120
    }

    var grid: any Gridable {
        switch self {
        case .aladin_cz_1km:
            // regular_ll, Ni=501, Nj=290, south-to-north, west-to-east.
            // Corner coordinates from the GRIB header; dx/dy are derived to land the last
            // grid point on (51.098, 18.995).
            return RegularGrid(nx: 501, ny: 290, latitude: 48.5...51.098, longitude: 12.0...18.995)
        }
    }

    var updateIntervalSeconds: Int {
        return 21600 // 6 hours
    }
}
