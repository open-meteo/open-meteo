import Logging

enum IconNativeDomains: String, CaseIterable {
    case aiconNative = "aicon"
    case aiconNativeModelLevel = "aicon-model-level"

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

    case iconNativeModelLevel = "icon-native-model-level"
    case iconEuNativeModelLevel = "icon-eu-native-model-level"
    case iconD2NativeModelLevel = "icon-d2-native-model-level"

    var modelLevelDomain: Self? {
        switch self {
        case .aiconNative: return .aiconNativeModelLevel
        case .iconNative: return .iconNativeModelLevel
        case .iconEuNative: return .iconEuNativeModelLevel
        case .iconD2Native: return .iconD2NativeModelLevel
        default: return nil
        }
    }

    var modelLevelParent: Self? {
        switch self {
        case .aiconNativeModelLevel: return .aiconNative
        case .iconNativeModelLevel: return .iconNative
        case .iconEuNativeModelLevel: return .iconEuNative
        case .iconD2NativeModelLevel: return .iconD2Native
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

    /// Forecast metadata and field URLs do not imply a regular-grid storage domain.
    var sourceModel: DwdModel {
        switch self {
        case .aiconNative, .aiconNativeModelLevel: return .aicon
        case .iconNative, .iconNativeModelLevel: return .icon(.icon)
        case .iconEuNative, .iconEuNativeModelLevel: return .icon(.iconEu)
        case .iconD2Native, .iconD2NativeModelLevel: return .icon(.iconD2)
        case .iconD2Native15min: return .icon(.iconD2_15min)
        case .iconEpsNative: return .icon(.iconEps)
        case .iconEpsNativeEnsembleMean: return .icon(.iconEpsEnsembleMean)
        case .iconEuEpsNative: return .icon(.iconEuEps)
        case .iconEuEpsNativeEnsembleMean: return .icon(.iconEuEpsEnsembleMean)
        case .iconD2EpsNative: return .icon(.iconD2Eps)
        case .iconD2EpsNativeEnsembleMean: return .icon(.iconD2EpsEnsembleMean)
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .aiconNative: return .dwd_aicon_global
        case .aiconNativeModelLevel: return .dwd_aicon_global_model_level
        case .iconNative: return .dwd_icon_global_native
        case .iconNativeModelLevel: return .dwd_icon_global_native_model_level
        case .iconEuNative: return .dwd_icon_eu_native
        case .iconEuNativeModelLevel: return .dwd_icon_eu_native_model_level
        case .iconD2Native: return .dwd_icon_d2_native
        case .iconD2NativeModelLevel: return .dwd_icon_d2_native_model_level
        case .iconD2Native15min: return .dwd_icon_d2_native_15min
        case .iconEpsNative: return .dwd_icon_eps_native
        case .iconEpsNativeEnsembleMean: return .dwd_icon_eps_native_ensemble_mean
        case .iconEuEpsNative: return .dwd_icon_eu_eps_native
        case .iconEuEpsNativeEnsembleMean: return .dwd_icon_eu_eps_native_ensemble_mean
        case .iconD2EpsNative: return .dwd_icon_d2_eps_native
        case .iconD2EpsNativeEnsembleMean: return .dwd_icon_d2_eps_native_ensemble_mean
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        if sourceModel == .aicon { return .dwd_icon_global_native }
        if let modelLevelParent { return modelLevelParent.domainRegistry }
        switch self {
        case .iconD2Native15min: return .dwd_icon_d2_native
        case .iconEpsNativeEnsembleMean: return .dwd_icon_eps_native
        case .iconEuEpsNativeEnsembleMean: return .dwd_icon_eu_eps_native
        case .iconD2EpsNativeEnsembleMean: return .dwd_icon_d2_eps_native
        default: return domainRegistry
        }
    }

    var dtSeconds: Int { sourceModel.dtSeconds }
    var updateIntervalSeconds: Int { sourceModel.updateIntervalSeconds }
    var hasYearlyFiles: Bool { sourceModel.hasYearlyFiles }
    var masterTimeRange: Range<Timestamp>? { sourceModel.masterTimeRange }
    var omFileLength: Int { sourceModel.omFileLength }
    var countEnsembleMember: Int { sourceModel.countEnsembleMember }
    var generateFullRun: Bool { sourceModel.generateFullRun }
    var generateTimeSeries: Bool { sourceModel.generateTimeSeries }

    var nativeGridFile: IconNativeGridFile {
        switch self {
        case .aiconNative, .aiconNativeModelLevel, .iconNative, .iconNativeModelLevel: return Self.globalGridFile
        case .iconEuNative, .iconEuNativeModelLevel: return Self.europeGridFile
        case .iconD2Native, .iconD2NativeModelLevel, .iconD2Native15min, .iconD2EpsNative, .iconD2EpsNativeEnsembleMean: return Self.d2GridFile
        case .iconEpsNative, .iconEpsNativeEnsembleMean: return Self.globalEnsembleGridFile
        case .iconEuEpsNative, .iconEuEpsNativeEnsembleMean: return Self.europeEnsembleGridFile
        }
    }

    private static let globalGridFile = IconNativeGridFile(registry: .dwd_icon_global_native, identity: .global)
    private static let d2GridFile = IconNativeGridFile(registry: .dwd_icon_d2_native, identity: .d2)
    private static let europeGridFile = IconNativeGridFile(registry: .dwd_icon_eu_native, identity: .europe)
    private static let globalEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_eps_native, identity: .globalEnsemble)
    private static let europeEnsembleGridFile = IconNativeGridFile(registry: .dwd_icon_eu_eps_native, identity: .europeEnsemble)

    /// Definitions sharing a mesh and elevation file also share their initialized cache entry.
    var staticResourceDomain: Self {
        if sourceModel == .aicon { return .iconNative }
        return modelLevelParent ?? (self == .iconD2Native15min ? .iconD2Native : self)
    }

    func load() async throws -> IconNativeDomain {
        try await Self.domains.load(self)
    }

    static let logger = Logger(label: "IconNativeDomain")
    private static let domains = IconNativeDomainCache()
}
