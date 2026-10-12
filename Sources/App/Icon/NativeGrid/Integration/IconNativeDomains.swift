import Logging

enum IconNativeDomains: String, CaseIterable {
    case iconNative = "icon-native"
    case iconEuNative = "icon-eu-native"
    case iconD2Native = "icon-d2-native"
    case iconD2Native15min = "icon-d2-native-15min"
    case iconEpsNative = "icon-eps-native"
    case iconEuEpsNative = "icon-eu-eps-native"
    case iconD2EpsNative = "icon-d2-eps-native"

    case iconEpsNativeEnsembleMean = "icon-eps-native-ensemble-mean"
    case iconEuEpsNativeEnsembleMean = "icon-eu-eps-native-ensemble-mean"
    case iconD2EpsNativeEnsembleMean = "icon-d2-eps-native-ensemble-mean"

    var ensembleMeanDomain: Self? {
        switch self {
        case .iconEpsNative: return .iconEpsNativeEnsembleMean
        case .iconEuEpsNative: return .iconEuEpsNativeEnsembleMean
        case .iconD2EpsNative: return .iconD2EpsNativeEnsembleMean
        default: return nil
        }
    }

    /// Shared forecast metadata and variable mappings come from the corresponding regular domain.
    var sourceDomain: IconDomains {
        switch self {
        case .iconNative: return .icon
        case .iconEuNative: return .iconEu
        case .iconD2Native: return .iconD2
        case .iconD2Native15min: return .iconD2_15min
        case .iconEpsNative: return .iconEps
        case .iconEpsNativeEnsembleMean: return .iconEpsEnsembleMean
        case .iconEuEpsNative: return .iconEuEps
        case .iconEuEpsNativeEnsembleMean: return .iconEuEpsEnsembleMean
        case .iconD2EpsNative: return .iconD2Eps
        case .iconD2EpsNativeEnsembleMean: return .iconD2EpsEnsembleMean
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .iconNative: return .dwd_icon_global_native
        case .iconEuNative: return .dwd_icon_eu_native
        case .iconD2Native: return .dwd_icon_d2_native
        case .iconD2Native15min: return .dwd_icon_d2_native_15min
        case .iconEpsNative: return .dwd_icon_global_eps_native
        case .iconEpsNativeEnsembleMean: return .dwd_icon_global_eps_native_ensemble_mean
        case .iconEuEpsNative: return .dwd_icon_eu_eps_native
        case .iconEuEpsNativeEnsembleMean: return .dwd_icon_eu_eps_native_ensemble_mean
        case .iconD2EpsNative: return .dwd_icon_d2_eps_native
        case .iconD2EpsNativeEnsembleMean: return .dwd_icon_d2_eps_native_ensemble_mean
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .iconD2Native15min: return .dwd_icon_d2_native
        case .iconEpsNativeEnsembleMean: return .dwd_icon_global_eps_native
        case .iconEuEpsNativeEnsembleMean: return .dwd_icon_eu_eps_native
        case .iconD2EpsNativeEnsembleMean: return .dwd_icon_d2_eps_native
        default: return domainRegistry
        }
    }

    var dtSeconds: Int { sourceDomain.dtSeconds }
    var updateIntervalSeconds: Int { sourceDomain.updateIntervalSeconds }
    var hasYearlyFiles: Bool { sourceDomain.hasYearlyFiles }
    var masterTimeRange: Range<Timestamp>? { sourceDomain.masterTimeRange }
    var omFileLength: Int { sourceDomain.omFileLength }
    var countEnsembleMember: Int { sourceDomain.countEnsembleMember }
    var generateFullRun: Bool { sourceDomain.generateFullRun }
    var generateTimeSeries: Bool { sourceDomain.generateTimeSeries }

    var nativeGridFile: IconNativeGridFile {
        switch self {
        case .iconNative: return Self.globalGridFile
        case .iconEuNative: return Self.europeGridFile
        case .iconD2Native, .iconD2Native15min, .iconD2EpsNative, .iconD2EpsNativeEnsembleMean: return Self.d2GridFile
        case .iconEpsNative, .iconEpsNativeEnsembleMean: return Self.globalEnsembleGridFile
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean: return Self.europeEnsembleGridFile
        }
    }

    private static let globalGridFile = IconNativeGridFile(registry: .dwd_icon_global_native, identity: .global)
    private static let d2GridFile = IconNativeGridFile(registry: .dwd_icon_d2_native, identity: .d2)
    private static let europeGridFile = IconNativeGridFile(registry: .dwd_icon_eu_native, identity: .europe)
    private static let globalEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_global_eps_native, identity: .globalEnsemble)
    private static let europeEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_eu_eps_native, identity: .europeEnsemble)

    func load() async throws -> IconNativeDomain {
        try await Self.domains.load(self)
    }

    static let logger = Logger(label: "IconNativeDomain")
    private static let domains = IconNativeDomainCache()
}
