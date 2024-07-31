import Foundation

/**
https://registry.opendata.aws/met-office-global-deterministic/

 
 */
enum UkmoDomain: String, GenericDomain, CaseIterable {
    case global_deterministic_10km
    case uk_deterministic_2km
    case uk_deterministic_2km_15min
    
    var grid: Gridable {
        switch self {
        case .global_deterministic_10km:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90, lonMin: -180, dx: 360/2560, dy: 180/1920)
        case .uk_deterministic_2km, .uk_deterministic_2km_15min:
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
        case .uk_deterministic_2km:
            return .ukmo_uk_deterministic_2km
        case .uk_deterministic_2km_15min:
            return .ukmo_uk_deterministic_2km_15min
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .global_deterministic_10km, .uk_deterministic_2km:
            return 3600
        case .uk_deterministic_2km_15min:
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
        switch self {
        case .global_deterministic_10km:
            return 168 + 1 + 24
        case .uk_deterministic_2km:
            return 55 + 24
        case .uk_deterministic_2km_15min:
            return 55*4 + 24
        }
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
        case .uk_deterministic_2km, .uk_deterministic_2km_15min:
            // Delay of 8:00 hours after initialisation, updates every hour
            return t.add(hours: -8).floor(toNearestHour: 1)
        }
    }
    
    var modelNameOnS3: String {
        switch self {
        case .global_deterministic_10km:
            return "global-deterministic-10km"
        case .uk_deterministic_2km, .uk_deterministic_2km_15min:
            return "uk-deterministic-2km"
        }
    }
    
    /**
     Return forecast hours for each run as a unix Timestamp. Works better for 15 minutely steps.
     */
    func forecastSteps(run: Timestamp) -> [Timestamp] {
        switch self {
        case .global_deterministic_10km:
            if run.hour % 12 == 6 {
                // shortend run
                return (Array(0..<54) + stride(from: 54, through: 60, by: 3)).map({run.add(hours: $0)})
            }
            return (Array(0..<54) + stride(from: 54, to: 144, by: 3) + stride(from: 144, through: 168, by: 6)).map({run.add(hours: $0)})
        case .uk_deterministic_2km:
            return TimerangeDt(start: run, nTime: 55, dtSeconds: 3600).map({$0})
        case .uk_deterministic_2km_15min:
            return TimerangeDt(start: run, nTime: 55*4, dtSeconds: 900).map({$0})
        }
    }
}
