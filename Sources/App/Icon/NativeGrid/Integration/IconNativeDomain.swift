import OmFileFormat
import Vapor

/// An initialized native domain. Successful API loads retain static resources until restart.
struct IconNativeDomain: GenericDomain, CustomStringConvertible {
    let definition: IconNativeDomains
    let nativeGrid: IconNativeGrid

    var grid: any Gridable { nativeGrid }
    var description: String { definition.rawValue }
    var domainRegistry: DomainRegistry { definition.domainRegistry }
    var domainRegistryStatic: DomainRegistry? { definition.domainRegistryStatic }
    var dtSeconds: Int { definition.dtSeconds }
    var updateIntervalSeconds: Int { definition.updateIntervalSeconds }
    var hasYearlyFiles: Bool { definition.hasYearlyFiles }
    var masterTimeRange: Range<Timestamp>? { definition.masterTimeRange }
    var omFileLength: Int { definition.omFileLength }
    var countEnsembleMember: Int { definition.countEnsembleMember }
    var generateFullRun: Bool { definition.generateFullRun }
    var generateTimeSeries: Bool { definition.generateTimeSeries }

    func getStaticFile(type: ReaderStaticVariable, httpClient: HTTPClient?, logger: Logger) async -> (any OmFileReaderArrayProtocol<Float>)? {
        if case .elevation = type, let payload = nativeGrid.elevationPayload {
            return payload.reader
        }
        let variable: String
        switch type {
        case .elevation: variable = "HSURF"
        case .soilType: variable = "soil_type"
        }
        return try? await OmFileSystemManager.instance.get(
            file: OmFileType.staticFile(domain: domainRegistryStatic ?? domainRegistry, variable: variable),
            client: httpClient, logger: logger
        )?.reader
    }
}

extension IconNativeDomain {
    init(definition: IconNativeDomains, context: DomainInitContext) async throws {
        let grid = try await definition.nativeGridFile.load(context: context)
        let payload = try? await OmFileSystemManager.instance.get(
            file: OmFileType.staticFile(domain: definition.domainRegistryStatic ?? definition.domainRegistry, variable: "HSURF"),
            client: context.httpClient, logger: context.logger
        )
        self.init(definition: definition, nativeGrid: IconNativeGrid(storage: grid.storage, elevationPayload: payload))
    }
}

actor IconNativeDomainCache {
    private var loading = [IconNativeDomains: Task<IconNativeDomain, any Error>]()

    func load(_ definition: IconNativeDomains, context: DomainInitContext) async throws -> IconNativeDomain {
        // D2's hourly and quarter-hourly domains use exactly the same static resources.
        let resourceDefinition: IconNativeDomains = definition == .iconD2Native15min ? .iconD2Native : definition
        let task: Task<IconNativeDomain, any Error>
        if let existing = loading[resourceDefinition] {
            task = existing
        } else {
            task = Task { try await IconNativeDomain(definition: resourceDefinition, context: context) }
            loading[resourceDefinition] = task
        }
        do {
            let domain = try await task.value
            // Do not pin an absent elevation file. A subsequent load may find it available.
            if domain.nativeGrid.elevationPayload == nil, loading[resourceDefinition] == task {
                loading[resourceDefinition] = nil
            }
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid)
        } catch {
            if loading[resourceDefinition] == task { loading[resourceDefinition] = nil }
            throw error
        }
    }
}
