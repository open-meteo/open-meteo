import Foundation

/**
Italian ARPAE models from MISTRAL https://meteohub.mistralportal.it/app/datasets
 */
enum ArpaeDomain: String, GenericDomain, CaseIterable {
    case cosmo_2i
    case cosmo_2i_ruc
    case cosmo_5m
    
    var grid: Gridable {
        switch self {
        case .cosmo_2i, .cosmo_2i_ruc:
            return ProjectionGrid(
                nx: 576, 
                ny: 701,
                latitude: 34.39697...47.973446,
                longitude: 5.443863...21.491043,
                projection: RotatedLatLonProjection(latitude: -47, longitude: 10)
            )
        case .cosmo_5m:
            return ProjectionGrid(
                nx: 1083, 
                ny: 559,
                latitude: 25.821411...49.898006,
                longitude: -17.5374...47.080597,
                projection: RotatedLatLonProjection(latitude: -47, longitude: 10)
            )
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .cosmo_2i:
            return .arpae_cosmo_2i
        case.cosmo_2i_ruc:
            return .arpae_cosmo_2i_ruc
        case .cosmo_5m:
            return .arpae_cosmo_5m
        }
    }
    
    var apiName: String {
        switch self {
        case .cosmo_2i:
            return "COSMO-2I"
        case .cosmo_2i_ruc:
            return "COSMO-2I-RUC"
        case .cosmo_5m:
            return "COSMO-5M"
        }
    }
    
    var ensembleMembers: Int {
        return 1
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        return 3600
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .cosmo_2i: return 48+48
        case .cosmo_2i_ruc: return 18+24
        case .cosmo_5m: return 72+48
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .cosmo_2i:
            // Delay of 4:50 hours after initialisation with 2 runs a day
            return t.add(hours: -3).with(hour: ((t.hour - 3 + 24) % 24) / 12 * 12)
        case .cosmo_2i_ruc:
            // Delay of 3:20 hours after initialisation with 8 runs a day
            return t.add(hours: -3).with(hour: ((t.hour - 3 + 24) % 24) / 3 * 3)
        case .cosmo_5m:
            // Delay of 3:55 hours, 2 runs
            return t.add(hours: -3).with(hour: ((t.hour - 3 + 24) % 24) / 12 * 12)
        }
    }
}
