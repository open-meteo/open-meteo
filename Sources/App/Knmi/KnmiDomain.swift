import Foundation

/**
 https://english.knmidata.nl/latest/newsletters/open-data-newsletter/2024/open-data-march-2024
 
 */
enum KnmiDomain: String, GenericDomain, CaseIterable {
    case harmonie_arome_europe
    case harmonie_arome_netherlands
    
    var grid: Gridable {
        switch self {
        case .harmonie_arome_europe:
            return ProjectionGrid(
                nx: 676,
                ny: 564,
                latitude: 39.740627...62.619324,
                longitude: -25.162262...38.75702,
                projection: RotatedLatLonProjection(latitude: -35, longitude: -8)
            )
        case .harmonie_arome_netherlands:
            return RegularGrid(nx: 390, ny: 390, latMin: 49, lonMin: 0, dx: 0.029, dy: 0.018)
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .knmi_harmonie_arome_europe
        case .harmonie_arome_netherlands:
            return .knmi_harmonie_arome_netherlands
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
        // 60 timesteps
        return 90
    }
    
    var ensembleMembers: Int {
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            return 1
        }
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            return 3600
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            // Delay of 2:30 hours after initialisation, updates every hour. Cronjob every x:35
            return t.add(hours: -2).floor(toNearestHour: 1)
        }
    }
}
