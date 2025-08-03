
/**
 BoM (Australia) -> currently unavailable due to model upgrades
 IAP-CAS (China)
 CMA (China)
 ECCC (Canada)
 ECMWF
 UKMO (U.K.)
 ISAC-CNR (Italy)
 NCEP (U.S.A.)
 Meteo-France (France)
 KMA (Korea)
 HMCR (Russia)
 JMA (Japan)
 CPTEC (Brasil)
 */
enum S2S6HourlyDomain: String, GenericDomain, CaseIterable {
    case iap_cas
    case cma
    case eccc
    case ecmwf
    case ukmo
    case isac_cnr
    case ncep
    case meteo_france
    case kma
    case hmcr
    case jma
    case cptec
    
    var grid: any Gridable {
        return RegularGrid(nx: 240, ny: 121, latMin: -90, lonMin: -180, dx: 1.5, dy: 1.5, searchRadius: 0)
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .iap_cas:
            return .s2s_iap_cas_6hourly
        case .cma:
            return .s2s_cma_6hourly
        case .eccc:
            return .s2s_eccc_6hourly
        case .ecmwf:
            return .s2s_ecmwf_6hourly
        case .ukmo:
            return .s2s_ukmo_6hourly
        case .isac_cnr:
            return .s2s_isac_cnr_6hourly
        case .ncep:
            return .s2s_ncep_6hourly
        case .meteo_france:
            return .s2s_meteo_france_6hourly
        case .kma:
            return .s2s_kma_6hourly
        case .hmcr:
            return .s2s_hmcr_6hourly
        case .jma:
            return .s2s_jma_6hourly
        case .cptec:
            return .s2s_cptec_6hourly
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int{
        return 6*3600
    }
    
    var updateIntervalSeconds: Int {
        return 6*3600
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        return 90 * 24 / 6
    }
}

struct S2SDailyDomain: GenericDomain {
    let domain: S2S6HourlyDomain
    
    var grid: any Gridable {
        domain.grid
    }
    
    var domainRegistry: DomainRegistry {
        switch domain {
        case .iap_cas:
            return .s2s_iap_cas_daily
        case .cma:
            return .s2s_cma_daily
        case .eccc:
            return .s2s_eccc_daily
        case .ecmwf:
            return .s2s_ecmwf_daily
        case .ukmo:
            return .s2s_ukmo_daily
        case .isac_cnr:
            return .s2s_isac_cnr_daily
        case .ncep:
            return .s2s_ncep_daily
        case .meteo_france:
            return .s2s_meteo_france_daily
        case .kma:
            return .s2s_kma_daily
        case .hmcr:
            return .s2s_hmcr_daily
        case .jma:
            return .s2s_jma_daily
        case .cptec:
            return .s2s_cptec_daily
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        domain.domainRegistryStatic
    }
    
    var dtSeconds: Int {
        return 24*3600
    }
    
    var updateIntervalSeconds: Int {
        return domain.updateIntervalSeconds
    }
    
    var hasYearlyFiles: Bool {
        return domain.hasYearlyFiles
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        return 120
    }
}



