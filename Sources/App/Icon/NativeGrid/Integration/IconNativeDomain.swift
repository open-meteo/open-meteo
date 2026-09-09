import OmFileFormat
import Vapor

/// An initialized native domain. Successful API loads retain static resources until restart.
struct IconNativeDomain: GenericDomain, CustomStringConvertible {
    let definition: IconNativeDomains
    let nativeGrid: IconNativeGrid
    let elevationFile: (any OmFileReaderArrayProtocol<Float>)?

    init(definition: IconNativeDomains, nativeGrid: IconNativeGrid, elevationFile: (any OmFileReaderArrayProtocol<Float>)? = nil) {
        self.definition = definition
        self.nativeGrid = nativeGrid
        self.elevationFile = elevationFile
    }

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
        if case .elevation = type, let elevationFile {
            return elevationFile
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
    init(definition: IconNativeDomains) async throws {
        let grid = try await definition.nativeGridFile.load()
        let payload = try? await OmFileSystemManager.instance.get(
            file: OmFileType.staticFile(domain: definition.domainRegistryStatic ?? definition.domainRegistry, variable: "HSURF"),
            client: .shared, logger: IconNativeDomains.logger
        )
        self.init(definition: definition, nativeGrid: IconNativeGrid(storage: grid.storage, elevationFile: payload?.reader), elevationFile: payload?.reader)
    }
}

actor IconNativeDomainCache {
    private enum State {
        case loading([CheckedContinuation<IconNativeDomain, any Error>])
        case loaded(IconNativeDomain)
        case error(any Error)
    }

    private var cache = [IconNativeDomains: State]()

    func load(_ definition: IconNativeDomains) async throws -> IconNativeDomain {
        // D2's hourly and quarter-hourly domains use exactly the same static resources.
        let resourceDefinition: IconNativeDomains = definition == .iconD2Native15min ? .iconD2Native : definition
        switch cache[resourceDefinition] {
        case .loaded(let domain):
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid, elevationFile: domain.elevationFile)
        case .loading(var continuations):
            let domain = try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
                cache[resourceDefinition] = .loading(continuations)
            }
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid, elevationFile: domain.elevationFile)
        case .error(let error):
            throw error
        case nil:
            cache[resourceDefinition] = .loading([])
        }
        do {
            let domain = try await IconNativeDomain(definition: resourceDefinition)
            guard case .loading(let continuations) = cache.removeValue(forKey: resourceDefinition) else {
                fatalError("Expected loading state")
            }

            cache[resourceDefinition] = .loaded(domain)
           
            for continuation in continuations {
                continuation.resume(returning: domain)
            }
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid, elevationFile: domain.elevationFile)
        } catch {
            guard case .loading(let continuations) = cache.removeValue(forKey: resourceDefinition) else {
                fatalError("Expected loading state")
            }
            for continuation in continuations {
                continuation.resume(throwing: error)
            }
            cache[resourceDefinition] = .error(error)
            throw error
        }
    }
}
