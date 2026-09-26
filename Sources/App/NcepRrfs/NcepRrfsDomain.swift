// See docs/ncep-rrfs/README.md for RRFS products, GRIB inputs and processing details.

import Foundation

enum NcepRrfsDomain: String, CaseIterable, GenericDomain {
    case ncep_rrfs_conus
    case ncep_rrfs_north_america
    case ncep_rrfs_conus_15min
    case ncep_rrfs_conus_ensemble

    var domainRegistry: DomainRegistry { DomainRegistry(rawValue: rawValue)! }
    var domainRegistryStatic: DomainRegistry? { self == .ncep_rrfs_north_america ? .ncep_rrfs_north_america : .ncep_rrfs_conus }
    var dtSeconds: Int { self == .ncep_rrfs_conus_15min ? 900 : 3600 }
    var updateIntervalSeconds: Int { self == .ncep_rrfs_conus_15min ? 3600 : 21600 }
    var hasYearlyFiles: Bool { false }
    var masterTimeRange: Range<Timestamp>? { nil }
    var countEnsembleMember: Int { self == .ncep_rrfs_conus_ensemble ? 5 : 1 }
    var forecastHours: ClosedRange<Int> {
        switch self {
        case .ncep_rrfs_conus, .ncep_rrfs_north_america: return 0...84
        case .ncep_rrfs_conus_15min: return 1...18
        case .ncep_rrfs_conus_ensemble: return 0...60
        }
    }
    var omFileLength: Int {
        switch self {
        case .ncep_rrfs_conus, .ncep_rrfs_north_america: return 120 // 3.5 days hourly forecast, chunk 5 days
        case .ncep_rrfs_conus_15min: return 192 // 18 hours forecast, chunk 48 hours
        case .ncep_rrfs_conus_ensemble: return 96 // 2.5 days, chunk 4 days
        }
    }
    var lastRun: Timestamp { lastRun(now: .now()) }
    func lastRun(now: Timestamp) -> Timestamp {
        now.add(-3 * 3600 - 45 * 60).floor(toNearestHour: updateIntervalSeconds / 3600)
    }
    var grid: any Gridable {
        switch self {
        case .ncep_rrfs_north_america: return northAmericaGrid
        case .ncep_rrfs_conus, .ncep_rrfs_conus_15min, .ncep_rrfs_conus_ensemble: return conusGrid
        }
    }
    var conusGrid: ProjectionGrid<LambertConformalConicProjection> {
        ProjectionGrid(nx: 1799, ny: 1059, latitude: 21.1381, longitude: -122.72,
                       dx: 3000, dy: 3000,
                       projection: LambertConformalConicProjection(λ0: -97.5, ϕ0: 38.5, ϕ1: 38.5, ϕ2: 38.5, radius: 6371229))
    }

    /// GRIB coordinates are in rotated space; the projection uses the opposite pole convention.
    var northAmericaGrid: ProjectionGrid<RotatedLatLonProjection> {
        ProjectionGrid(nx: 1127, ny: 683,
                       latitudeProjectionOrigin: -36.9303, longitudeProjectionOrigin: -61,
                       dx: 0.1083, dy: 0.1083,
                       projection: RotatedLatLonProjection(latitude: 35, longitude: 67))
    }

    func gribUrls(run: Timestamp, forecastHour: Int, member: Int, server: String) -> [String] {
        let root = server.hasSuffix("/") ? String(server.dropLast()) : server
        let hour = forecastHour.zeroPadded(len: 3)
        let cycle = run.hh
        switch self {
        case .ncep_rrfs_north_america:
            return ["2dfld", "prslev"].map { "\(root)/rrfs.\(run.format_YYYYMMdd)/\(cycle)/rrfs.t\(cycle)z.\($0).13km.f\(hour).na.grib2" }
        case .ncep_rrfs_conus:
            return ["2dfld", "prslev"].map { "\(root)/rrfs.\(run.format_YYYYMMdd)/\(cycle)/rrfs.t\(cycle)z.\($0).3km.f\(hour).conus.grib2" }
        case .ncep_rrfs_conus_15min:
            return ["\(root)/rrfs.\(run.format_YYYYMMdd)/\(cycle)/rrfs.t\(cycle)z.2dfld.3km.subh.f\(hour).conus.grib2"]
        case .ncep_rrfs_conus_ensemble:
            let m = "m\((member + 1).zeroPadded(len: 3))"
            return ["2dfldnomads", "prslevnomads"].map { "\(root)/rrfsens.\(run.format_YYYYMMdd)/\(cycle)/\(m)/rrfs.t\(cycle)z.\(m).\($0).3km.f\(hour).conus.grib2" }
        }
    }
}
