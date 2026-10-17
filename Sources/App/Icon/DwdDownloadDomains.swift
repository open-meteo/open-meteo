/// Resolved storage outputs. Only deterministic ICON global also produces regular-grid output.
struct DwdDownloadDomains: Sendable {
    let source: DwdModel
    let primary: any GenericDomain
    let remapped: (any GenericDomain)?
    let ensembleMean: (any GenericDomain)?
    let modelLevel: (any GenericDomain)?
    let fifteenMinute: (any GenericDomain)?

    let nativeDomain: IconNativeDomains?

    func isModelLevel(_ variable: any GenericVariable) -> Bool {
        (variable as? any DwdVariableDownloadable)?.getVarAndLevel(model: source)?.cat == "model-level"
    }

    init(_ domain: IconDomains) async throws {
        if domain == .icon {
            self = try await Self(IconNativeDomains.iconNative)
            return
        }
        self.source = .icon(domain)
        self.nativeDomain = nil
        self.primary = domain
        self.remapped = nil
        self.ensembleMean = domain.ensembleMeanDomain
        self.modelLevel = nil
        self.fifteenMinute = domain == .iconD2 ? IconDomains.iconD2_15min : nil
    }

    init(_ domain: IconNativeDomains, skipRegridding: Bool = false) async throws {
        self.init(domain, grid: try await domain.nativeGridFile.load(), skipRegridding: skipRegridding)
    }

    init(_ domain: IconNativeDomains, grid: IconNativeGrid, skipRegridding: Bool = false) {
        self.source = domain.sourceModel
        self.nativeDomain = domain
        self.primary = IconNativeDomain(definition: domain, nativeGrid: grid)
        self.modelLevel = domain.modelLevelDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        self.remapped = domain == .iconNative && !skipRegridding ? IconDomains.icon : nil
        self.ensembleMean = domain.ensembleMeanDomain.map { IconNativeDomain(definition: $0, nativeGrid: grid) }
        self.fifteenMinute = domain == .iconD2Native ? IconNativeDomain(definition: .iconD2Native15min, nativeGrid: grid) : nil
    }
}

