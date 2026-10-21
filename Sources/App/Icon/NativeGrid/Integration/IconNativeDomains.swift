import Logging

enum IconNativeDomains: String, CaseIterable, DomainDefinition {
    case iconNative = "icon-native"
    case iconEuNative = "icon-eu-native"
    case iconD2RucNative = "icon-d2-ruc-native"
    case iconD2RucNative15min = "icon-d2-ruc-native-15min"
    case iconD2RucNativeModelLevel = "icon-d2-ruc-native-model-level"
    case iconD2Native = "icon-d2-native"
    case iconD2Native15min = "icon-d2-native-15min"
    case iconEpsNative = "icon-eps-native"
    case iconEuEpsNative = "icon-eu-eps-native"
    case iconD2EpsNative = "icon-d2-eps-native"

    case iconEpsNativeEnsembleMean = "icon-eps-native-ensemble-mean"
    case iconEuEpsNativeEnsembleMean = "icon-eu-eps-native-ensemble-mean"
    case iconD2EpsNativeEnsembleMean = "icon-d2-eps-native-ensemble-mean"

    case iconNativeModelLevel = "icon-native-model-level"
    case iconEuNativeModelLevel = "icon-eu-native-model-level"
    case iconD2NativeModelLevel = "icon-d2-native-model-level"

    var downloadDomain: IconDownloadDomains {
        switch self {
        case .iconNative, .iconNativeModelLevel: return .icon
        case .iconEuNative, .iconEuNativeModelLevel: return .iconEu
        case .iconD2Native, .iconD2Native15min, .iconD2NativeModelLevel: return .iconD2
        case .iconD2RucNative, .iconD2RucNative15min, .iconD2RucNativeModelLevel: return .iconD2Ruc
        case .iconEpsNative, .iconEpsNativeEnsembleMean: return .iconEps
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean: return .iconEuEps
        case .iconD2EpsNative, .iconD2EpsNativeEnsembleMean: return .iconD2Eps
        }
    }

    var modelLevelDomain: Self? {
        switch self {
        case .iconNative: return .iconNativeModelLevel
        case .iconEuNative: return .iconEuNativeModelLevel
        case .iconD2RucNative: return .iconD2RucNativeModelLevel
        case .iconD2Native: return .iconD2NativeModelLevel
        default: return nil
        }
    }

    var modelLevelParent: Self? {
        switch self {
        case .iconNativeModelLevel: return .iconNative
        case .iconEuNativeModelLevel: return .iconEuNative
        case .iconD2RucNativeModelLevel: return .iconD2RucNative
        case .iconD2NativeModelLevel: return .iconD2Native
        default: return nil
        }
    }

    var quarterHourlyParent: Self? {
        switch self {
        case .iconD2Native15min: return .iconD2Native
        case .iconD2RucNative15min: return .iconD2RucNative
        default: return nil
        }
    }

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
        case .iconD2RucNative, .iconD2RucNative15min, .iconD2RucNativeModelLevel: return .iconD2
        case .iconNative, .iconNativeModelLevel: return .icon
        case .iconEuNative, .iconEuNativeModelLevel: return .iconEu
        case .iconD2Native, .iconD2NativeModelLevel: return .iconD2
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
        case .iconD2RucNative: return .dwd_icon_d2_ruc_native
        case .iconD2RucNative15min: return .dwd_icon_d2_ruc_native_15min
        case .iconD2RucNativeModelLevel: return .dwd_icon_d2_ruc_native_model_level
        case .iconNative: return .dwd_icon_global_native
        case .iconNativeModelLevel: return .dwd_icon_global_native_model_level
        case .iconEuNative: return .dwd_icon_eu_native
        case .iconEuNativeModelLevel: return .dwd_icon_eu_native_model_level
        case .iconD2Native: return .dwd_icon_d2_native
        case .iconD2NativeModelLevel: return .dwd_icon_d2_native_model_level
        case .iconD2Native15min: return .dwd_icon_d2_native_15min
        case .iconEpsNative: return .dwd_icon_global_eps_native
        case .iconEpsNativeEnsembleMean: return .dwd_icon_global_eps_native_ensemble_mean
        case .iconEuEpsNative: return .dwd_icon_eu_eps_native
        case .iconEuEpsNativeEnsembleMean: return .dwd_icon_eu_eps_native_ensemble_mean
        case .iconD2EpsNative: return .dwd_icon_d2_eps_native
        case .iconD2EpsNativeEnsembleMean: return .dwd_icon_d2_eps_native_ensemble_mean
        }
    }

    var dtSeconds: Int { quarterHourlyParent != nil ? 900 : sourceDomain.dtSeconds }
    var updateIntervalSeconds: Int { downloadDomain.updateIntervalSeconds }
    var masterTimeRange: Range<Timestamp>? { sourceDomain.masterTimeRange }
    var omFileLength: Int {
        switch self {
        case .iconD2RucNative15min: return (27 + 72) * 4 + 1
        case .iconD2RucNative, .iconD2RucNativeModelLevel: return 27 + 1 + 72
        default: return sourceDomain.omFileLength
        }
    }
    var countEnsembleMember: Int { sourceDomain.countEnsembleMember }
    var generateFullRun: Bool { sourceDomain.generateFullRun }
    var generateTimeSeries: Bool { sourceDomain.generateTimeSeries }

    var asyncGridRegistry: AsyncGridRegistry {
        switch self {
        case .iconNative, .iconNativeModelLevel:
            return .dwd_icon_global_native
        case .iconEuNative, .iconEuNativeModelLevel:
            return .dwd_icon_eu_native
        case .iconD2RucNative, .iconD2RucNative15min, .iconD2RucNativeModelLevel, .iconD2Native, .iconD2NativeModelLevel, .iconD2Native15min, .iconD2EpsNative, .iconD2EpsNativeEnsembleMean:
            return .dwd_icon_d2_native
        case .iconEpsNative, .iconEpsNativeEnsembleMean:
            return .dwd_icon_global_eps_native
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean:
            return .dwd_icon_eu_eps_native
        }
    }

    var gridRegistry: GridRegistry { .asynchronous(asyncGridRegistry) }

    func load() async throws -> IconNativeDomain {
        IconNativeDomain(
            definition: self,
            grid: try await asyncGridRegistry.load()
        )
    }

    func loadDomain() async throws -> any GenericDomain {
        try await load()
    }

    static let logger = Logger(label: "IconNativeDomain")
}
