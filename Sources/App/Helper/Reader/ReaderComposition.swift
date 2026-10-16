import Foundation

/// Executable recursive composition. Children are ordered from lowest to highest priority.
/// Metadata follows the highest-priority bound child, independently of variable selection.
indirect enum ReaderComposition: GenericReaderOptionalProtocol {
    typealias VariableOpt = ForecastVariable

    case source(ForecastReaderLeaf)
    case combination(children: [ReaderComposition], contributors: [ReaderComposition], prefetchAll: Bool, smoothTransitions: Bool)

    static func alternatives(_ children: [Self], smoothTransitions: Bool) -> Self {
        combine(children, prefetchAll: false, smoothTransitions: smoothTransitions)
    }

    static func blend(_ children: [Self], smoothTransitions: Bool) -> Self {
        combine(children, prefetchAll: true, smoothTransitions: smoothTransitions)
    }

    private static func combine(_ children: [Self], prefetchAll: Bool, smoothTransitions: Bool) -> Self {
        // Smoothing is not associative. Preserve the original contributor order,
        // computing it once while binding rather than flattening for every read.
        let contributors = children.flatMap { child -> [Self] in
            if case .combination(_, let contributors, _, let smooth) = child, smooth == smoothTransitions {
                return contributors
            }
            return [child]
        }
        return .combination(children: children, contributors: contributors, prefetchAll: prefetchAll, smoothTransitions: smoothTransitions)
    }

    private var metadata: (any GenericReaderBaseProtocol)? {
        switch self {
        case .source(let reader): return reader
        case .combination(let children, _, _, _): return children.last
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
        case .combination(let children, _, _, _):
            return children.contains { $0.supports(variable) }
        }
    }

    func prefetchData(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> Bool {
        switch self {
        case .source(let reader):
            return try await reader.prefetchData(variable: variable, time: time)
        case .combination(let children, _, let prefetchAll, _):
            for child in children.reversed() where child.supports(variable) {
                _ = try await child.prefetchData(variable: variable, time: time)
                if !prefetchAll { break }
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
            for child in contributors.reversed() where child.supports(variable) {
                guard let data = try await child.get(variable: variable, time: time) else { continue }
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

/// Forecast composition. Typed derived/derive factories are leaves; alternatives and blend
/// combine their forecast outputs without changing their derivation order.
indirect enum ReaderSource {
    case reference(MultiDomains)
    case reader((Binding, GenericReaderOptions) async throws -> ReaderComposition?)
    /// Alternative representations: prefetch the last supporting child, read fallbacks on demand.
    case alternatives([ReaderSource], smoothTransitions: Bool = false, requireCoverage: Bool = false)
    /// Complementary model coverage: prefetch every supporting child.
    case blend([ReaderSource], smoothTransitions: Bool = false, requireCoverage: Bool = false)
    /// Optional branches contribute variables but cannot satisfy run availability.
    /// Point-only branches are omitted when binding a bounding-box output grid.
    case optional(ReaderSource, pointOnly: Bool = false)

    /// Join independently derived variable sets. Raw inputs remain separate.
    /// Derived outputs can overlap; the last supporting child retains priority.
    static func combineVariables(_ sources: [Self], smoothTransitions: Bool = false) -> Self {
        .alternatives(sources, smoothTransitions: smoothTransitions)
    }

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
        case .alternatives(let sources, let smooth, let requireCoverage), .blend(let sources, let smooth, let requireCoverage):
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
            guard !readers.isEmpty, !requireCoverage || covered else { return nil }
            readers.reverse()
            switch self {
            case .alternatives: return .alternatives(readers, smoothTransitions: smooth)
            default: return .blend(readers, smoothTransitions: smooth)
            }
        }
    }
}
