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
        // 60 timesteps
        return 90
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
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gdps, .ldps:
            // Delay of 2:30 hours after initialisation, updates every 3 hours. Cronjob every x:35
            return t.add(hours: -2).floor(toNearestHour: 3)
        }
    }
}
