import Foundation

/**
Italian ARPAE models from MISTRAL https://meteohub.mistralportal.it/app/datasets
 */
@available(*, deprecated)
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
    
    var updateIntervalSeconds: Int {
        switch self {
        case .cosmo_2i:
            return 12*3600
        case .cosmo_2i_ruc:
            return 3*3600
        case .cosmo_5m:
            return 12*3600
        }
    }
}
