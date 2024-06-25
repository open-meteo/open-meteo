import Foundation

enum KnmiDomain: String, GenericDomain, CaseIterable {
    case harmonie_arome_europe
    
    var grid: Gridable {
        switch self {
        case .harmonie_arome_europe:
            return RegularGrid(nx: 2880, ny: 1440, latMin: -89.9375, lonMin: -180, dx: 0.125, dy: 0.125)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .knmi_harmonie_arome_europe
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        return 1*3600
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        return 120
    }
    
    /// Last forecast hour per run
    func forecastHours(run: Int) -> Int {
        switch self {
        case .harmonie_arome_europe:
            return (run % 12 == 6) ? 120 : 240
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe:
            // Delay of 4:20 hours after initialisation with 4 runs a day
            return t.with(hour: ((t.hour - 4 + 24) % 24) / 6 * 6)
        }
    }
}
