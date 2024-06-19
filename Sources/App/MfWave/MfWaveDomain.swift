import Foundation

/**
 Domain definition for MeteoFrance Wave models
 */
enum MfWaveDomain: String, CaseIterable, GenericDomain {
    case mfwave
    case mfcurrents
    
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
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    /// Number of time steps in each time series optimised file. 5 days more than each run.
    var omFileLength: Int {
        return (10 + 5) * 24 / dtHours
    }
    
    var dtSeconds: Int {
        switch self {
        case .mfwave:
            return 3*3600
        case .mfcurrents:
            return 3600
        }
    }
    
    var grid: Gridable {
        switch self {
        case .mfwave:
            return RegularGrid(nx: 4320, ny: 2041, latMin: -80, lonMin: -180, dx: 1/12, dy: 1/12, searchRadius: 2)
        case .mfcurrents:
            return RegularGrid(nx: 4320, ny: 2041, latMin: -80, lonMin: -180, dx: 1/12, dy: 1/12)
        }
    }
    
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .mfwave:
            // Delay of 11 hours after initialisation
            return t.add(hours: -11).floor(toNearestHour: 12)
        case .mfcurrents:
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
        }
    }
}
