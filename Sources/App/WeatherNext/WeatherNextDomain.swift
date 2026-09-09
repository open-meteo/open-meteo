import Foundation

/**
 Google DeepMind WeatherNext-2 domains.

 The source files are zarr files with the following structure:
 gcloud storage cat gs://weathernext/weathernext_2_0_0/zarr/2025_to_present/20260331_06hr_01_preds/predictions.zarr/2m_temperature/.zarray
 {
   "shape": [
     64, // members
     60, // timesteps
     721, // lat
     1440 // lon
   ],
   "chunks": [
     1,
     1,
     721,
     1440
   ],
   "dtype": "<f4",
   "fill_value": "NaN",
   "order": "C",
   "filters": null,
   "dimension_separator": ".",
   "compressor": {
     "id": "blosc",
     "cname": "lz4",
     "clevel": 5,
     "shuffle": 1,
     "blocksize": 0
   },
   "zarr_format": 2
 }
 
 Notes:
 - The grid is 0.25° regular lat/lon from 0 to 360 degrees, -90 to 90 degrees -> We remap to -180 to 180 longitude.
 - Static files come from ecmwf_ifs025, which weathernext is based on. The grids of both outputs have to be the same.
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
            return .google_weathernext2_ensemble
        case .weathernext_global_ensemble_mean:
            return .google_weathernext2_ensemble_mean
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
    /// 6 hours 50 min ~ 7 hours
    /// When `--run` is not provided, the downloader will poll the marker file instead.
    var lastRun: Timestamp {
        let t = Timestamp.now()
        return t.add(hours: -7).floor(toNearest: self.updateIntervalSeconds)
    }

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
}
