import Foundation

/// Controls prefetching only; reads always fill gaps from lower-priority sources.
enum ReaderPrefetchPolicy {
    /// Prefetch only the last source whose variable definition supports the requested variable.
    case preferred
    /// Prefetch all sources whose variable definitions support the requested variable.
    case all
}

/// Executable recursive composition. Sources are ordered from lowest to highest priority.
/// Metadata follows the highest-priority bound source, independently of variable selection.
indirect enum ReaderComposition: GenericReaderOptionalProtocol {
    typealias VariableOpt = ForecastVariable

    case source(ForecastReaderLeaf)
    case combination(sources: [ReaderComposition], contributors: [ReaderComposition], prefetch: ReaderPrefetchPolicy, smoothTransitions: Bool)

    static func mix(_ sources: [Self], prefetch: ReaderPrefetchPolicy, smoothTransitions: Bool) -> Self {
        // Smoothing is not associative. Preserve the original contributor order,
        // computing it once while binding rather than flattening for every read.
        let contributors = sources.flatMap { source -> [Self] in
            if case .combination(_, let contributors, _, let smooth) = source, smooth == smoothTransitions {
                return contributors
            }
            return [source]
        }
        return .combination(sources: sources, contributors: contributors, prefetch: prefetch, smoothTransitions: smoothTransitions)
    }

    private var metadata: (any GenericReaderBaseProtocol)? {
        switch self {
        case .source(let reader): return reader
        case .combination(let sources, _, _, _): return sources.last
        }
    }

    var modelLat: Float { metadata?.modelLat ?? .nan }
    var modelLon: Float { metadata?.modelLon ?? .nan }
    var modelElevation: ElevationOrSea { metadata?.modelElevation ?? .noData }
    var targetElevation: Float { metadata?.targetElevation ?? .nan }
    var modelDtSeconds: Int { metadata?.modelDtSeconds ?? 3600 }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        try await metadata?.getStatic(type: type)
    }

    var asOptionalReader: any GenericReaderOptionalProtocol<ForecastVariable> { self }

    func supports(_ variable: ForecastVariable) -> Bool {
        switch self {
        case .source(let reader): return reader.supports(variable)
        case .combination(let sources, _, _, _):
            return sources.contains { $0.supports(variable) }
        }
    }

    func prefetchData(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> Bool {
        switch self {
        case .source(let reader):
            return try await reader.prefetchData(variable: variable, time: time)
        case .combination(let sources, _, let prefetch, _):
            for source in sources.reversed() where source.supports(variable) {
                _ = try await source.prefetchData(variable: variable, time: time)
                if prefetch == .preferred { break }
            }
        }
        return supports(variable)
    }

    func get(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        let result: DataAndUnit?
        switch self {
        case .source(let reader):
            result = try await reader.get(variable: variable, time: time)
        case .combination(_, let contributors, _, let smooth):
            var combined: DataAndUnit?
            for source in contributors.reversed() where source.supports(variable) {
                guard let data = try await source.get(variable: variable, time: time) else { continue }
                if !smooth, let preferred = combined {
                    var values = preferred.data
                    values.integrateIfNaN(data.data)
                    combined = DataAndUnit(values, preferred.unit)
                } else {
                    combined = combined?.combined(withLowerPriority: data) ?? data
                }
                if combined?.data.containsNaN() == false { break }
            }
            result = combined
        }
        return result
    }
}

/// Forecast composition. Typed domain and raw-combination factories are leaves; mix combines
/// their forecast outputs without changing their derivation order.
indirect enum ReaderSource {
    case reference(MultiDomains)
    case reader((Binding, GenericReaderOptions) async throws -> ReaderComposition?)
    /// Sources ordered from lowest to highest priority. For each variable, read the last
    /// supporting source first, then fill missing values from earlier sources.
    /// The prefetch policy controls which sources are prepared, without changing read behavior.
    case mix([ReaderSource], prefetch: ReaderPrefetchPolicy, smoothTransitions: Bool = false)
    /// Supplement a composition without establishing its coverage or run availability.
    /// At least one NON-optional sibling must cover the location; optional data alone
    /// cannot make the composition available. Missing runs are ignored for this branch,
    /// but other errors propagate. Used on its own, this wrapper only tolerates missing runs.
    /// Point-only branches are omitted when binding a bounding-box output grid.
    case optional(ReaderSource, pointOnly: Bool = false)

    struct Binding {
        enum ElevationPolicy {
            case inheritFromPreferredSource
            case independentSources
        }

        let latitude: Float
        let longitude: Float
        var elevation: Float
        let mode: GridSelectionMode
        /// Bounding-box cells retain their output coordinates and terrain semantics.
        var outputGrid: (domain: any GenericDomain, position: Int)? = nil
        var elevationPolicy: ElevationPolicy = .inheritFromPreferredSource
        var references: Set<MultiDomains> = []
    }

    private var isOptional: Bool {
        if case .optional = self { return true }
        return false
    }

    func bind(_ binding: Binding, options: GenericReaderOptions) async throws -> ReaderComposition? {
        switch self {
        case .reference(let model):
            var next = binding
            guard next.references.insert(model).inserted else {
                throw ForecastApiError.generic(message: "Circular reader definition for \(model.rawValue)")
            }
            guard let mapping = try await model.getDomainAndVariable() else {
                throw ForecastApiError.generic(message: "No declarative reader definition for \(model.rawValue)")
            }
            return try await mapping.readerSource.bind(next, options: options)
        case .reader(let bind):
            return try await bind(binding, options)
        case .optional(let source, let pointOnly):
            if pointOnly && binding.outputGrid != nil { return nil }
            do {
                return try await source.bind(binding, options: options)
            } catch ForecastApiError.modelRunUnavailable {
                return nil
            }
        case .mix(let sources, let prefetch, let smooth):
            var elevation = binding.elevation
            var available = false
            var covered = false
            var unavailable: ForecastApiError?
            var readers: [ReaderComposition] = []
            for source in sources.reversed() {
                do {
                    var next = binding
                    next.elevation = elevation
                    let reader = try await source.bind(next, options: options)
                    if !source.isOptional { available = true }
                    guard let reader else { continue }
                    if !source.isOptional { covered = true }
                    readers.append(reader)
                    if elevation.isNaN, binding.elevationPolicy == .inheritFromPreferredSource {
                        elevation = reader.resolvedTargetElevation
                    }
                } catch let error as ForecastApiError {
                    guard case .modelRunUnavailable = error else { throw error }
                    unavailable = unavailable ?? error
                }
            }
            if !available, let unavailable { throw unavailable }
            guard covered else { return nil }
            readers.reverse()
            return .mix(readers, prefetch: prefetch, smoothTransitions: smooth)
        }
    }
}
