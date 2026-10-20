/// An initialized native domain retaining its grid mapping and decoded elevations until restart.
struct IconNativeDomain: GenericDomain, CustomStringConvertible {
    let definition: IconNativeDomains
    let grid: any Gridable

    init(definition: IconNativeDomains, nativeGrid: IconNativeGrid) {
        self.definition = definition
        self.grid = nativeGrid
    }

    init(definition: IconNativeDomains) async throws {
        self.definition = definition
        self.grid = try await definition.asyncGridRegistry.load()
    }

    var description: String { definition.rawValue }
    var domainRegistry: DomainRegistry { definition.domainRegistry }
    var gridRegistry: GridRegistry { definition.gridRegistry }
    var dtSeconds: Int { definition.dtSeconds }
    var updateIntervalSeconds: Int { definition.updateIntervalSeconds }
    var masterTimeRange: Range<Timestamp>? { definition.masterTimeRange }
    var omFileLength: Int { definition.omFileLength }
    var countEnsembleMember: Int { definition.countEnsembleMember }
    var generateFullRun: Bool { definition.generateFullRun }
    var generateTimeSeries: Bool { definition.generateTimeSeries }
}
