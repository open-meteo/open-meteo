/// A domain whose grid prerequisites have completed before synchronous processing.
struct ResolvedDomain: GridDomain, CustomStringConvertible {
    private let original: any GenericDomain
    let grid: any Gridable

    init(_ domain: any GenericDomain, context: DomainInitContext) async throws {
        if let resolved = domain as? ResolvedDomain {
            self = resolved
            return
        }
        self.grid = try await domain.getGrid(context: context)
        self.original = domain
    }

    func getGrid(context: DomainInitContext) async throws -> any Gridable { grid }

    var description: String { String(describing: original) }
    var domainRegistry: DomainRegistry { original.domainRegistry }
    var domainRegistryStatic: DomainRegistry? { original.domainRegistryStatic }
    var dtSeconds: Int { original.dtSeconds }
    var updateIntervalSeconds: Int { original.updateIntervalSeconds }
    var hasYearlyFiles: Bool { original.hasYearlyFiles }
    var masterTimeRange: Range<Timestamp>? { original.masterTimeRange }
    var omFileLength: Int { original.omFileLength }
    var countEnsembleMember: Int { original.countEnsembleMember }
    var generateFullRun: Bool { original.generateFullRun }
    var generateTimeSeries: Bool { original.generateTimeSeries }
}
