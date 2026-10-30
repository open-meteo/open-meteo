/// Weather-domain metadata paired with an already loaded native grid.
struct IconNativeDomain: GenericDomain, CustomStringConvertible {
    let definition: IconNativeDomains
    let grid: any Gridable

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
