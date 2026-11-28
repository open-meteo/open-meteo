import Foundation
import Vapor
import NIOConcurrencyHelpers
import OmFileFormat

/**
 ICON Domains including ensemble
 */
enum IconDomains: String, CaseIterable, SyncGridDomain {
    /// hourly data until forecast hour 78, then 3 h until 180
    case icon
    case iconEu = "icon-eu"
    case iconD2 = "icon-d2"
    case iconD2_15min = "icon-d2-15min"
    case iconEps = "icon-eps"
    case iconEuEps = "icon-eu-eps"
    case iconD2Eps = "icon-d2-eps"
    
    case iconEpsEnsembleMean = "icon-eps-ensemble-mean"
    case iconEuEpsEnsembleMean = "icon-eu-eps-ensemble-mean"
    case iconD2EpsEnsembleMean = "icon-d2-epss-ensemble-mean"

    var ensembleMeanDomain: Self? {
        switch self {
        case .iconEps:
            return .iconEpsEnsembleMean
        case .iconEuEps:
            return .iconEuEpsEnsembleMean
        case .iconD2Eps:
            return .iconD2EpsEnsembleMean
        default:
            return nil
        }
    }
    
    var dtSeconds: Int {
        if self == .iconD2_15min {
            return 3600 / 4
        }
        return 3600
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .icon:
            return .dwd_icon
        case .iconEu:
            return .dwd_icon_eu
        case .iconD2:
            return .dwd_icon_d2
        case .iconD2_15min:
            return .dwd_icon_d2_15min
        case .iconEps:
            return .dwd_icon_eps
        case .iconEuEps:
            return .dwd_icon_eu_eps
        case .iconD2Eps:
            return .dwd_icon_d2_eps
        case .iconEpsEnsembleMean:
            return .dwd_icon_eps_ensemble_mean
        case .iconEuEpsEnsembleMean:
            return .dwd_icon_eu_eps_ensemble_mean
        case .iconD2EpsEnsembleMean:
            return .dwd_icon_d2_eps_ensemble_mean
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .icon:
            return .dwd_icon
        case .iconEu:
            return .dwd_icon_eu
        case .iconD2, .iconD2_15min:
            return .dwd_icon_d2
        case .iconEps, .iconEpsEnsembleMean:
            return .dwd_icon_eps
        case .iconEuEps, .iconEuEpsEnsembleMean:
            return .dwd_icon_eu_eps
        case .iconD2Eps, .iconD2EpsEnsembleMean:
            return .dwd_icon_d2_eps
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    /// How many hourly timesteps to keep in each compressed chunk
    var omFileLength: Int {
        switch self {
        case .icon, .iconEps, .iconEpsEnsembleMean:
            return 180 + 1 + 3 * 24
        case .iconEu, .iconEuEps, .iconEuEpsEnsembleMean:
            return 120 + 1 + 3 * 24
        case .iconD2, .iconD2Eps, .iconD2EpsEnsembleMean:
            return 48 + 1 + 3 * 24
        case .iconD2_15min:
            return 48 * 4 + 3 * 24
        }
    }

    var downloadDomain: IconDownloadDomains {
        switch self {
        case .icon: return .icon
        case .iconEu: return .iconEu
        case .iconD2, .iconD2_15min: return .iconD2
        case .iconEps, .iconEpsEnsembleMean: return .iconEps
        case .iconEuEps, .iconEuEpsEnsembleMean: return .iconEuEps
        case .iconD2Eps, .iconD2EpsEnsembleMean: return .iconD2Eps
        }
    }

    var updateIntervalSeconds: Int { downloadDomain.updateIntervalSeconds }

    var countEnsembleMember: Int {
        switch self {
        case .iconEpsEnsembleMean, .iconEuEpsEnsembleMean, .iconD2EpsEnsembleMean: return 1
        default: return downloadDomain.countEnsembleMember
        }
    }

    var sourceGridIdentity: IconNativeGridIdentity {
        IconNativeGridFile.forGrid(nativeDomain.asyncGridRegistry).identity
    }

    var nativeDomain: IconNativeDomains {
        switch self {
        case .icon: return .iconNative
        case .iconEu: return .iconEuNative
        case .iconD2: return .iconD2Native
        case .iconD2_15min: return .iconD2Native15min
        case .iconEps, .iconEpsEnsembleMean: return .iconEpsNative
        case .iconEuEps, .iconEuEpsEnsembleMean: return .iconEuEpsNative
        case .iconD2Eps, .iconD2EpsEnsembleMean: return .iconD2EpsNative
        }
    }

    /// ICON uses 1.5°C melting point temperature: https://gitlab.dkrz.de/icon/icon-model/-/blob/release-2024.01-public/src/atm_phy_nwp/mo_nh_interface_nwp.f90?ref_type=heads#L2232
    static let tMelt = Float(1.5)
}
