import Foundation
import OmFileFormat

/**
 AICON domain - DWD's AI-based weather prediction model
 
 AICON (AI ICON) is a machine-learning-based variant of the ICON model developed at DWD.
 It operates on the same global R3B7 grid as ICON global (≈13km resolution) and produces
 3-hourly forecasts up to 180 hours lead time, initialized 4 times per day (0/6/12/18 UTC).

 Data is available at:
 https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/
 
 The URL structure is:
 - Surface variables:  .../p/{VAR}/r/{YYYY-MM-DDTHH:00}/s/PT{HHH}H00M.grib2
 - Model-level variables: .../p/{VAR}/lvt1/150/lv1/{LEVEL}/r/{YYYY-MM-DDTHH:00}/s/PT{HHH}H00M.grib2
 
 AICON model levels (13 levels) map to ICON global model levels:
   AICON 1  → ICON level  49  (≈21115m)
   AICON 2  → ICON level  57  (≈16694m)
   AICON 3  → ICON level  64  (≈14088m)
   AICON 4  → ICON level  70  (≈12283m)
   AICON 5  → ICON level  75  (≈10783m)
   AICON 6  → ICON level  79  (≈ 9583m)
   AICON 7  → ICON level  86  (≈ 7483m)
   AICON 8  → ICON level  91  (≈ 5983m)
   AICON 9  → ICON level  96  (≈ 4483m)
   AICON 10 → ICON level 101  (≈ 3037m)
   AICON 11 → ICON level 108  (≈ 1421m)
   AICON 12 → ICON level 112  (≈  739m)
   AICON 13 → ICON level 119  (≈   42m)
 */
enum AiconDomain: String, CaseIterable, GenericDomain {

    case aicon_global = "aicon"

    var dtSeconds: Int {
        return 3 * 3600
    }

    var countEnsembleMember: Int { return 1 }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .aicon_global:
            return .dwd_aicon_global
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        // Reuse ICON global static files (elevation, land-sea mask)
        // since AICON uses the same R3B7 grid
        switch self {
        case .aicon_global:
            return .dwd_icon
        }
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    /// Number of hourly timesteps to keep in each compressed chunk.
    /// AICON runs to 180h, stored at 3h resolution → 60 steps + buffer.
    var omFileLength: Int {
        switch self {
        case .aicon_global:
            // 180h / 3h = 60 steps per run + rolling buffer of 3 days
            return 60 + 3 * 8
        }
    }

    /// 3-hourly forecast steps: 3, 6, 9, … 180
    var forecastSteps: [Int] {
        return Array(stride(from: 3, through: 180, by: 3))
    }

    /// Number of forecast steps
    var forecastLength: Int {
        return forecastSteps.count
    }

    /// AICON model level indices (1-based, 1…13)
    var modelLevels: [Int] {
        return Array(1...13)
    }

    /// Update interval: AICON runs 4 times per day (0, 6, 12, 18 UTC)
    var updateIntervalSeconds: Int {
        return 6 * 3600
    }

    /// The grid is identical to ICON global regular lat-lon output (R3B7 remapped)
    var grid: any Gridable {
        switch self {
        case .aicon_global:
            // Same as ICON global regular-lat-lon grid
            return RegularGrid(nx: 2879, ny: 1441, latMin: -90, lonMin: -180, dx: 0.125, dy: 0.125)
        }
    }

    /// Base URL for AICON open data
    var serverBaseUrl: String {
        return "http://opendata.dwd.de/weather/nwp/v1/m/aicon/p"
    }

    /// Format a run timestamp into the server's directory name: "2026-03-16T12:00"
    func runDirectoryName(run: Timestamp) -> String {
        return run.iso8601_YYYY_MM_dd_HH_mm
    }

    /// Format a forecast lead-time in hours into the server's filename part: "PT003H00M"
    func leadTimeFileName(hours: Int) -> String {
        return String(format: "PT%03dH00M", hours)
    }

    /// Build the download URL for a surface variable at a given run and forecast hour.
    ///
    /// Pattern: `{base}/{VAR}/r/{run-dir}/s/{lead}.grib2`
    func surfaceVariableUrl(variable: String, run: Timestamp, forecastHours: Int) -> String {
        let runDir = runDirectoryName(run: run)
        let lead = leadTimeFileName(hours: forecastHours)
        return "\(serverBaseUrl)/\(variable)/r/\(runDir)/s/\(lead).grib2"
    }

    /// Build the download URL for a model-level variable at a given run, forecast hour and level.
    ///
    /// Pattern: `{base}/{VAR}/lvt1/150/lv1/{LEVEL}/r/{run-dir}/s/{lead}.grib2`
    ///
    /// The `lvt1/150` segment is a fixed part of the AICON server path for model-level data
    /// (level type 1, version 150).
    func modelLevelVariableUrl(variable: String, level: Int, run: Timestamp, forecastHours: Int) -> String {
        let runDir = runDirectoryName(run: run)
        let lead = leadTimeFileName(hours: forecastHours)
        return "\(serverBaseUrl)/\(variable)/lvt1/150/lv1/\(level)/r/\(runDir)/s/\(lead).grib2"
    }
}

extension AiconDomain {
    /// The most recent completed model run available on the server.
    /// AICON runs at 0, 6, 12, 18 UTC with roughly a 2-hour delay.
    var lastRun: Timestamp {
        let now = Timestamp.now()
        // Allow 2 hours of production time before considering a run complete
        return now.with(hour: ((now.hour - 2 + 24) % 24) / 6 * 6)
    }
}
