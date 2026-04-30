import Foundation

/**
 Google DeepMind WeatherNext-2 domains.

 Source layout:
 `gs://om-weathernext/output/{modelrun-in-iso8601}/{timestamp-in-iso8601}.om`

 The source files are already preprocessed OM files and currently represent a
 global regular latitude/longitude grid with dimensions:
 - members: 64
 - latitude: 721
 - longitude: 1440

 Notes:
 - The grid is 0.25° regular lat/lon.
 - The downloader skeleton is expected to ingest per-timestep spatial OM files
   and then convert them into the code base's standard run/chunk layout.
 - We model the native ensemble domain and a derived ensemble-mean domain
   separately, following existing code base conventions.
 */
enum WeatherNextDomain: String, GenericDomain, CaseIterable {
    /// Native 64-member WeatherNext-2 ensemble
    case weathernext_global

    /// Derived ensemble mean / spread product
    case weathernext_global_ensemble_mean

    var grid: any Gridable {
        switch self {
        case .weathernext_global, .weathernext_global_ensemble_mean:
            return RegularGrid(
                nx: 1440,
                ny: 721,
                latMin: -90,
                lonMin: -180,
                dx: 0.25,
                dy: 0.25
            )
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .weathernext_global:
            return .google_weathernext_global_ensemble
        case .weathernext_global_ensemble_mean:
            return .google_weathernext_global_ensemble_mean
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .weathernext_global:
            return .ecmwf_ifs025
        case .weathernext_global_ensemble_mean:
            return .ecmwf_ifs025
        }
    }

    var dtSeconds: Int {
        switch self {
        case .weathernext_global, .weathernext_global_ensemble_mean:
            return 6 * 3600
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .weathernext_global, .weathernext_global_ensemble_mean:
            return 6 * 3600
        }
    }

    var hasYearlyFiles: Bool {
        false
    }

    var masterTimeRange: Range<Timestamp>? {
        nil
    }

    var omFileLength: Int {
        switch self {
        case .weathernext_global, .weathernext_global_ensemble_mean:
            return 60
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .weathernext_global:
            return 64
        case .weathernext_global_ensemble_mean:
            return 1
        }
    }

    var ensembleMeanDomain: WeatherNextDomain? {
        switch self {
        case .weathernext_global:
            return .weathernext_global_ensemble_mean
        case .weathernext_global_ensemble_mean:
            return nil
        }
    }

    func forecastTimestamps(for run: Timestamp) -> [Timestamp] {
        (0..<omFileLength).map { run.add(($0 + 1) * dtSeconds) }
    }

    /// Placeholder until the actual publication delay is validated.
    var lastRun: Timestamp {
        let t = Timestamp.now()
        return t.add(hours: -18).floor(toNearestHour: 6)
    }
}
