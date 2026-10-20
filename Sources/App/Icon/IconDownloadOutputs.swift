/// Resolved storage outputs. Only deterministic ICON global also produces regular-grid output.
struct IconDownloadOutputs: Sendable {
    let downloadDomain: IconDownloadDomains
    let primary: any GenericDomain
    let remapped: IconDomains?
    let ensembleMean: (any GenericDomain)?
    let modelLevel: (any GenericDomain)?
    let fifteenMinute: (any GenericDomain)?

    let nativeDomain: IconNativeDomains

    init(_ domain: IconNativeDomains, skipRegridding: Bool = false) async throws {
        self.init(domain, grid: try await domain.nativeGridFile.load(), skipRegridding: skipRegridding)
    }

    init(_ domain: IconNativeDomains, grid: IconNativeGrid, skipRegridding: Bool = false) {
        self.downloadDomain = domain.downloadDomain
        self.nativeDomain = domain
        self.primary = IconNativeDomain(definition: domain, nativeGrid: grid)
        self.modelLevel = domain.modelLevelDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        self.remapped = domain == .iconNative && !skipRegridding ? IconDomains.icon : nil
        self.ensembleMean = domain.ensembleMeanDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        self.fifteenMinute = domain == .iconD2RucNative ? IconNativeDomain(definition: .iconD2RucNative15min, nativeGrid: grid) : domain == .iconD2Native ? IconNativeDomain(definition: .iconD2Native15min, nativeGrid: grid) : nil
    }
}

