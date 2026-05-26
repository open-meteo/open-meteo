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
            // the update interval is 6 hours, but 6z and 18z runs do not arrive in time
            // therefore, for now we only process 0z and 12z runs
            return 12 * 3600
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
        // Note that for weathernext ensemble forecast hour 0 is not included! 
        (0..<omFileLength).map { run.add(($0 + 1) * dtSeconds) }
    }

    /// Weathernext dissemination schedule: https://developers.google.com/weathernext/guides/dissemination
    /// We add 45 minutes for the Python processing for zarr to .om conversion
    /// 6 hours 50 min + 45 min ~ 8 hours
    /// When `--run` is not provided, the downloader will poll the marker file instead.
    var lastRun: Timestamp {
        let t = Timestamp.now()
        return t.add(hours: -8).floor(toNearest: self.updateIntervalSeconds)
    }

    /// Path to the marker file that signals the latest completed run.
    static let markerFilePath = "gs://om-weathernext/latestfinishedrun"

    /// Build the Zarr root path for a given run.
    /// Pattern: `weathernext_2_0_0/zarr/2025_to_present/{YYYYMMDD}_{HH}hr_01_preds/predictions.zarr/`
    static func zarrRunPath(server: String, run: Timestamp) -> String {
        let floored = run.floor(toNearest: 6 * 3600)
        return "\(server)\(floored.format_YYYYMMdd)_\(floored.hour.zeroPadded(len: 2))hr_01_preds/predictions.zarr/"
    }

    /// Build the Zarr success marker path for a given run.
    /// Pattern: `gs://weathernext/{server}{YYYYMMDD}_{HH}hr_01_preds/success`
    static func zarrSuccessPath(server: String, run: Timestamp) -> String {
        let floored = run.floor(toNearest: 6 * 3600)
        return "gs://weathernext/\(server)\(floored.format_YYYYMMdd)_\(floored.hour.zeroPadded(len: 2))hr_01_preds/success"
    }

    static func parseRunTimestampFromZarrPath(_ runDirName: String) throws -> Timestamp {
        let parts = runDirName.split(separator: "_")
        guard parts.count >= 3 else {
            throw WeatherNextDownloaderError.notImplemented("Invalid Zarr run directory: '\(runDirName)'")
        }
        let hourStr = String(parts[1].dropLast(2))
        let dateStr = String(parts[0])
        guard dateStr.count == 8 else {
            throw WeatherNextDownloaderError.notImplemented("Invalid Zarr run date: '\(dateStr)'")
        }
        let yearStr = String(dateStr.prefix(4))
        let monthStr = String(dateStr.dropFirst(4).prefix(2))
        let dayStr = String(dateStr.dropFirst(6).prefix(2))
        guard let year = Int(yearStr), let month = Int(monthStr), let day = Int(dayStr), let hour = Int(hourStr) else {
            throw WeatherNextDownloaderError.notImplemented("Could not parse Zarr run: '\(runDirName)'")
        }
        return Timestamp(year, month, day, hour)
    }

    /// Parse a WeatherNext marker string (e.g. `20260430_06hr_01_preds`) into a Timestamp.
    /// The format is `YYYYMMDD_HHhr_01_preds` where HH is the zero-padded hour (00–23).
    static func parseTimestampFromMarker(_ marker: String) throws -> Timestamp {
        guard marker.count >= 10 else {
            throw WeatherNextDownloaderError.notImplemented("Invalid marker format: '\(marker)'")
        }

        let yearStr  = String(marker.prefix(4))
        let monthStr = String(marker.dropFirst(4).prefix(2))
        let dayStr   = String(marker.dropFirst(6).prefix(2))
        let hourStr  = String(marker.dropFirst(9).prefix(2))

        guard let year  = Int(yearStr),
              let month = Int(monthStr),
              let day   = Int(dayStr),
              let hour  = Int(hourStr) else {
            throw WeatherNextDownloaderError.notImplemented("Could not parse marker: '\(marker)'")
        }

        return Timestamp(year, month, day, hour)
    }
}
