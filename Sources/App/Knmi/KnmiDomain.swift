import Foundation

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
        // TODO check!
        return 120
    }
    
    var ensembleMembers: Int {
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            return 1
        }
    }
    
    /// Last forecast hour per run
    func forecastHours(run: Int) -> Int {
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            return (run % 12 == 6) ? 120 : 240
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe, .harmonie_arome_netherlands:
            // Delay of 4:20 hours after initialisation with 4 runs a day
            return t.with(hour: ((t.hour - 4 + 24) % 24) / 6 * 6)
        }
    }
}
