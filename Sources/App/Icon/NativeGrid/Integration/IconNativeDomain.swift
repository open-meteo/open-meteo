import OmFileFormat
import Vapor

/// An initialized native domain retaining its grid mapping and decoded elevations until restart.
struct IconNativeDomain: GenericDomain, CustomStringConvertible {
    let definition: IconNativeDomains
    let nativeGrid: IconNativeGrid

    init(definition: IconNativeDomains, nativeGrid: IconNativeGrid) {
        self.definition = definition
        self.nativeGrid = nativeGrid
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
}

extension IconNativeDomain {
    init(definition: IconNativeDomains) async throws {
        let grid = try await definition.nativeGridFile.load()
        let payload = try? await OmFileSystemManager.instance.get(
            file: OmFileType.staticFile(domain: definition.domainRegistryStatic ?? definition.domainRegistry, variable: "HSURF"),
            client: .shared, logger: IconNativeDomains.logger
        )
        let elevations: ElevationValues?
        if let payload {
            elevations = try await ElevationValues(decoded: payload.reader.read(), expectedCount: grid.nx)
        } else {
            elevations = nil
        }
        self.init(definition: definition, nativeGrid: IconNativeGrid(storage: grid.storage, elevations: elevations))
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
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid)
        case .loading(var continuations):
            let domain = try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
                cache[resourceDefinition] = .loading(continuations)
            }
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid)
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
            return IconNativeDomain(definition: definition, nativeGrid: domain.nativeGrid)
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
