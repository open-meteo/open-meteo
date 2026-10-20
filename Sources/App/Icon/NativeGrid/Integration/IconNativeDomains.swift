import Logging

enum IconNativeDomains: String, CaseIterable {
    case aiconNative = "aicon"

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

    var downloadDomain: IconDownloadDomains {
        switch self {
        case .aiconNative: return .aicon
        case .iconNative, .iconNativeModelLevel: return .icon
        case .iconEuNative, .iconEuNativeModelLevel: return .iconEu
        case .iconD2Native, .iconD2Native15min, .iconD2NativeModelLevel: return .iconD2
        case .iconD2RucNative, .iconD2RucNative15min, .iconD2RucNativeModelLevel: return .iconD2Ruc
        case .iconEpsNative, .iconEpsNativeEnsembleMean: return .iconEps
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean: return .iconEuEps
        case .iconD2EpsNative, .iconD2EpsNativeEnsembleMean: return .iconD2Eps
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .aiconNative: return .dwd_aicon_global
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

    var domainRegistryStatic: DomainRegistry? {
        // Domains sharing a native grid also share its elevation and other static fields.
        nativeGridFile.registry
    }

    var dtSeconds: Int {
        if self == .aiconNative { return 3 * 3600 }
        return quarterHourlyParent != nil ? 900 : 3600
    }
    var updateIntervalSeconds: Int { downloadDomain.updateIntervalSeconds }
    var masterTimeRange: Range<Timestamp>? { sourceDomain.masterTimeRange }
    var omFileLength: Int {
        switch self {
        case .aiconNative: return 84
        case .iconNative, .iconNativeModelLevel, .iconEpsNative, .iconEpsNativeEnsembleMean:
            return 180 + 1 + 3 * 24
        case .iconEuNative, .iconEuNativeModelLevel, .iconEuEpsNative, .iconEuEpsNativeEnsembleMean:
            return 120 + 1 + 3 * 24
        case .iconD2Native, .iconD2NativeModelLevel, .iconD2EpsNative, .iconD2EpsNativeEnsembleMean:
            return 48 + 1 + 3 * 24
        case .iconD2Native15min: return 48 * 4 + 3 * 24
        case .iconD2RucNative15min: return (27 + 72) * 4 + 1
        case .iconD2RucNative, .iconD2RucNativeModelLevel: return 27 + 1 + 72
        }
    }
    var countEnsembleMember: Int {
        switch self {
        case .iconEpsNativeEnsembleMean, .iconEuEpsNativeEnsembleMean, .iconD2EpsNativeEnsembleMean: return 1
        default: return downloadDomain.countEnsembleMember
        }
    }
    var generateFullRun: Bool { countEnsembleMember == 1 }
    var generateTimeSeries: Bool { true }

    var nativeGridFile: IconNativeGridFile {
        switch self {
        case .aiconNative, .iconNative, .iconNativeModelLevel: return Self.globalGridFile
        case .iconEuNative, .iconEuNativeModelLevel: return Self.europeGridFile
        case .iconD2RucNative, .iconD2RucNative15min, .iconD2RucNativeModelLevel, .iconD2Native, .iconD2NativeModelLevel, .iconD2Native15min, .iconD2EpsNative, .iconD2EpsNativeEnsembleMean: return Self.d2GridFile
        case .iconEpsNative, .iconEpsNativeEnsembleMean: return Self.globalEnsembleGridFile
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean: return Self.europeEnsembleGridFile
        }
    }

    private static let globalGridFile = IconNativeGridFile(registry: .dwd_icon_global_native, identity: .global)
    private static let d2GridFile = IconNativeGridFile(registry: .dwd_icon_d2_native, identity: .d2)
    private static let europeGridFile = IconNativeGridFile(registry: .dwd_icon_eu_native, identity: .europe)
    private static let globalEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_global_eps_native, identity: .globalEnsemble)
    private static let europeEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_eu_eps_native, identity: .europeEnsemble)

    /// Definitions sharing a mesh and elevation file also share their initialized cache entry.
    var staticResourceDomain: Self {
        if self == .aiconNative { return .iconNative }
        return modelLevelParent ?? quarterHourlyParent ?? self
    }

    func load() async throws -> IconNativeDomain {
        try await Self.domains.load(self)
    }

    static let logger = Logger(label: "IconNativeDomain")
    private static let domains = IconNativeDomainCache()
}

extension DomainTimeSeriesMetadata {
    init(_ domain: IconNativeDomains) {
        self.dtSeconds = domain.dtSeconds
        self.omFileLength = domain.omFileLength
        self.updateIntervalSeconds = domain.updateIntervalSeconds
    }
}
