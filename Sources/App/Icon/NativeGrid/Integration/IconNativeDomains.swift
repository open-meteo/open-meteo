enum IconNativeDomains: String, CaseIterable {
    case iconNative = "icon-native"
    case iconD2Native = "icon-d2-native"
    case iconD2Native15min = "icon-d2-native-15min"

    /// Shared forecast metadata and variable mappings come from the corresponding regular domain.
    var sourceDomain: IconDomains {
        switch self {
        case .iconNative: return .icon
        case .iconD2Native: return .iconD2
        case .iconD2Native15min: return .iconD2_15min
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .iconNative: return .dwd_icon_global_native
        case .iconD2Native: return .dwd_icon_d2_native
        case .iconD2Native15min: return .dwd_icon_d2_native_15min
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        self == .iconD2Native15min ? .dwd_icon_d2_native : domainRegistry
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
        case .iconD2Native, .iconD2Native15min: return Self.d2GridFile
        }
    }

    private static let globalGridFile = IconNativeGridFile(registry: .dwd_icon_global_native, identity: .global)
    private static let d2GridFile = IconNativeGridFile(registry: .dwd_icon_d2_native, identity: .d2)

    func load(context: DomainInitContext) async throws -> IconNativeDomain {
        try await Self.domains.load(self, context: context)
    }

    private static let domains = IconNativeDomainCache()
}
