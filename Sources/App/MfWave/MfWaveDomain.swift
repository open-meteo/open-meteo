import Foundation

/**
 Domain definition for MeteoFrance Wave models
 */
enum MfWaveDomain: String, CaseIterable, GenericDomain {
    case mfwave
    case mfcurrents
    case mfsst

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .mfwave:
            return .meteofrance_wave
        case .mfcurrents:
            return .meteofrance_currents
        case .mfsst:
            return .meteofrance_sea_surface_temperature
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        /// Note: sea land mask is slighly differnet for each model
        return domainRegistry
    }

    /// Number of time steps in each time series optimised file. 5 days more than each run.
    var omFileLength: Int {
        return (10 + 5) * 24 / dtHours
    }

    var dtSeconds: Int {
        switch self {
        case .mfwave:
            return 3 * 3600
        case .mfcurrents:
            return 3600
        case .mfsst:
            return 6 * 3600
        }
    }

    var grid: Gridable {
        switch self {
        case .mfwave, .mfsst, .mfcurrents:
            // Important: GRID needs to be aligned to center points by dx/2 and dy/2
            return RegularGrid(nx: 4320, ny: 2041, latMin: -80 + 1 / 24, lonMin: -180 + 1 / 24, dx: 1 / 12, dy: 1 / 12, searchRadius: 2)
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .mfwave:
            return 12 * 3600
        case .mfcurrents, .mfsst:
            return 24 * 3600
        }
    }

    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .mfwave:
            // Delay of 11 hours after initialisation
            return t.add(hours: -11).floor(toNearestHour: 12)
        case .mfcurrents, .mfsst:
            // Delay of 11 hours after initialisation
            return t.add(hours: -11).floor(toNearestHour: 24)
        }
    }

    var stepHoursPerFile: Int {
        switch self {
        case .mfwave:
            return 12 // 2 files per day
        case .mfcurrents:
            return 24 // 1 file per day
        case .mfsst:
            return 6 // 1 file per 6 hours
        }
    }
}
