import Foundation

/**
https://registry.opendata.aws/met-office-global-deterministic/

 
 */
enum UkmoDomain: String, GenericDomain, CaseIterable {
    case global_deterministic_10km
    case uk_deterministic_10km
    case uk_deterministic_10km_15min
    
    var grid: Gridable {
        switch self {
        case .global_deterministic_10km:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90, lonMin: -180, dx: 0.09, dy: 0.09)
        case .uk_deterministic_10km, .uk_deterministic_10km_15min:
            return ProjectionGrid(
                nx: 676,
                ny: 564,
                latitude: 39.740627...62.619324,
                longitude: -25.162262...38.75702,
                projection: RotatedLatLonProjection(latitude: -35, longitude: -8)
            )
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .global_deterministic_10km:
            return .ukmo_global_deterministic_10km
        case .uk_deterministic_10km:
            return .ukmo_uk_deterministic_10km
        case .uk_deterministic_10km_15min:
            return .ukmo_uk_deterministic_10km_15min
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .global_deterministic_10km, .uk_deterministic_10km:
            return 3600
        case .uk_deterministic_10km_15min:
            return 900
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
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .global_deterministic_10km:
            // Delay of 10:00 hours after initialisation, updates every 6 hours
            return t.add(hours: -10).floor(toNearestHour: 6)
        case .uk_deterministic_10km, .uk_deterministic_10km_15min:
            // Delay of 8:00 hours after initialisation, updates every hour
            return t.add(hours: -8).floor(toNearestHour: 1)
        }
    }
}
