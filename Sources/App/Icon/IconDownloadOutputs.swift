/// Resolved storage outputs. Only deterministic ICON global also produces regular-grid output.
struct IconDownloadOutputs: Sendable {
    var downloadDomain: IconDownloadDomains { nativeDomain.downloadDomain }
    let primary: IconNativeDomain
    let remapped: IconDomains?
    let ensembleMean: IconNativeDomain?
    let modelLevel: IconNativeDomain?
    let fifteenMinute: IconNativeDomain?

    let nativeDomain: IconNativeDomains

    init(_ domain: IconNativeDomains, skipRegridding: Bool = false) async throws {
        self.init(domain, grid: try await IconNativeGridFile.forGrid(domain.asyncGridRegistry).load(), skipRegridding: skipRegridding)
    }

    init(_ domain: IconNativeDomains, grid: IconNativeGrid, skipRegridding: Bool = false) {
        self.nativeDomain = domain
        self.primary = IconNativeDomain(definition: domain, nativeGrid: grid)
        self.modelLevel = domain.modelLevelDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        self.remapped = domain == .iconNative && !skipRegridding ? IconDomains.icon : nil
        self.ensembleMean = domain.ensembleMeanDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        switch domain {
        case .iconD2RucNative:
            self.fifteenMinute = IconNativeDomain(definition: .iconD2RucNative15min, nativeGrid: grid)
        case .iconD2Native:
            self.fifteenMinute = IconNativeDomain(definition: .iconD2Native15min, nativeGrid: grid)
        default:
            self.fifteenMinute = nil
        }
    }
}

