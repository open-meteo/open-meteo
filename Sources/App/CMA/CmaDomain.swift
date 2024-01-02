import Foundation

/**
 Weather forecast domains from the China Meteorological Administration (CMA)
 https://www.cma.gov.cn/en/forecast/highlight/202311/t20231117_5892086.html
 
 No mesoscale model yet, only global
 */
enum CmaDomain: String, GenericDomain, CaseIterable {
    case grapes_global
    
    var grid: Gridable {
        switch self {
        case .grapes_global:
            return RegularGrid(nx: 2880, ny: 1440, latMin: -89.9375, lonMin: -180, dx: 0.125, dy: 0.125)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .grapes_global:
            return .cma_grapes_global
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        return 3*3600
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
        case .grapes_global:
            return (run % 12 == 6) ? 120 : 240
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .grapes_global:
            // Delay of 4:20 hours after initialisation with 4 runs a day
            return t.with(hour: ((t.hour - 4 + 24) % 24) / 6 * 6)
        }
    }
}
