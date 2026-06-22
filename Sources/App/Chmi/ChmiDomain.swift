import Foundation
import OmFileFormat
import Vapor

/// ČHMÚ (Czech Hydrometeorological Institute) ALADIN models
/// Data: https://opendata.chmi.cz/meteorology/weather/nwp_aladin/
/// 72h hourly forecast, 4 runs/day (00/06/12/18 UTC)
enum ChmiDomain: String, GenericDomain, CaseIterable {
    case aladin_cz_1km
    case aladin_lambert_2_3km

    var domainRegistry: DomainRegistry {
        switch self {
        case .aladin_cz_1km:
            return .chmi_aladin_cz_1km
        case .aladin_lambert_2_3km:
            return .chmi_aladin_lambert_2_3km
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

    var lastRun: Timestamp {
        switch self {
        case .aladin_cz_1km:
            // Runs every 6 hours (00, 06, 12, 18 UTC). Files arrive roughly 3.5h after the run.
            return Timestamp.now().add(hours: -3).floor(toNearestHour: 6)
        case .aladin_lambert_2_3km:
            return Timestamp.now().add(-4 * 3600 - 23 * 60).floor(toNearestHour: 6)
        }
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
        case .aladin_lambert_2_3km:
            // Lambert Conformal Conic, Ni=1053, Nj=837, Dx=Dy=2325m.
            // First grid point: 38.599N, 1.334E. LaD=46.244°, LoV=17°. Earth radius=6371229m.
            return ProjectionGrid(
                nx: 1053,
                ny: 837,
                latitude: 38.599,
                longitude: 1.334,
                dx: 2325,
                dy: 2325,
                projection: LambertConformalConicProjection(λ0: 17, ϕ0: 46.244, ϕ1: 46.244, ϕ2: 46.244, radius: 6371229)
            )
        }
    }

    var updateIntervalSeconds: Int {
        return 21600 // 6 hours
    }
}
