import Foundation

/**
 https://opendatadocs.dmi.govcloud.dk/Data/Forecast_Data_Weather_Model_HARMONIE_DINI_IG
 
 */
enum KmaDomain: String, GenericDomain, CaseIterable {
    case gdps
    case ldps
    
    var grid: Gridable {
        switch self {
        case .gdps:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90, lonMin: -180, dx: 360/2560, dy: 180/1920)
        case .ldps:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90, lonMin: -180, dx: 360/2560, dy: 180/1920)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .gdps:
            return .kma_gdps
        case .ldps:
            return .kma_ldps
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .gdps:
            return 3*3600
        case .ldps:
            return 1*3600
        }
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .gdps:
            // 96 steps per run + 2 days extra
            return 96 + 16
        case .ldps:
            // 49 hours per run + 1 day extra
            return 48 + 24
        }
    }
    
    var ensembleMembers: Int {
        return 1
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .gdps, .ldps:
            return 6*3600
        }
    }
    
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gdps, .ldps:
            // Delay of 3:20 hours after initialisation, updates every 6 hours. Cronjob every x:20
            // LDPS 3:40 delay
            return t.add(hours: -3).floor(toNearestHour: 6)
        }
    }
}
