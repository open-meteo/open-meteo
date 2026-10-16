import Foundation

/// Type erasure at the derivation boundary preserves ForecastVariable as the input type.
struct ForecastReaderLeaf: GenericReaderOptionalProtocol {
    typealias VariableOpt = ForecastVariable
    let metadata: any GenericReaderBaseProtocol
    let supports: (ForecastVariable) -> Bool
    private let read: (ForecastVariable, TimerangeDtAndSettings) async throws -> DataAndUnit?
    private let prefetch: (ForecastVariable, TimerangeDtAndSettings) async throws -> Bool

    init<R: GenericReaderProtocol>(_ reader: VariableHourlyDeriver<R>) {
        metadata = reader
        supports = { reader.getDeriverMap(variable: $0) != nil }
        read = { try await reader.get(variable: $0, time: $1) }
        prefetch = { try await reader.prefetchData(variable: $0, time: $1) }
    }

    init<R: GenericReaderProtocol>(raw: R, field: ForecastSurfaceVariable, variable: R.MixingVar) {
        metadata = raw
        let accepts: (ForecastVariable) -> Bool = {
            guard case .surface(let surface) = $0 else { return false }
            return surface.variable == field && surface.previousDay == 0
        }
        supports = accepts
        read = { forecast, time in
            guard accepts(forecast) else { return nil }
            return try await raw.get(variable: variable, time: time)
        }
        prefetch = { forecast, time in
            guard accepts(forecast) else { return false }
            try await raw.prefetchData(variable: variable, time: time)
            return true
        }
    }

    var modelLat: Float { metadata.modelLat }
    var modelLon: Float { metadata.modelLon }
    var modelElevation: ElevationOrSea { metadata.modelElevation }
    var targetElevation: Float { metadata.targetElevation }
    var modelDtSeconds: Int { metadata.modelDtSeconds }
    func getStatic(type: ReaderStaticVariable) async throws -> Float? { try await metadata.getStatic(type: type) }
    func get(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? { try await read(variable, time) }
    func prefetchData(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> Bool { try await prefetch(variable, time) }
}

/// Joins disjoint raw schemas before derivation (GFS surface and upper-air fields).
/// Variable cases select their owning reader; no string conversion or second mixer.
struct RawReaderUnion<P: GenericReaderProtocol, S: GenericReaderProtocol>: GenericReaderProtocol
where P.MixingVar: GenericVariable, S.MixingVar: GenericVariable {
    typealias MixingVar = VariableSchemaUnion<P.MixingVar, S.MixingVar>
    let primary: P
    let supplemental: S?

    var modelLat: Float { primary.modelLat }
    var modelLon: Float { primary.modelLon }
    var modelElevation: ElevationOrSea { primary.modelElevation }
    var targetElevation: Float { primary.targetElevation }
    var modelDtSeconds: Int { primary.modelDtSeconds }
    func getStatic(type: ReaderStaticVariable) async throws -> Float? { try await primary.getStatic(type: type) }
    func get(variable: MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .primary(let variable): return try await primary.get(variable: variable, time: time)
        case .supplemental(let variable):
            return try await supplemental?.get(variable: variable, time: time)
                ?? DataAndUnit(Array(repeating: .nan, count: time.time.count), variable.unit)
        }
    }
    func prefetchData(variable: MixingVar, time: TimerangeDtAndSettings) async throws {
        switch variable {
        case .primary(let variable): try await primary.prefetchData(variable: variable, time: time)
        case .supplemental(let variable): try await supplemental?.prefetchData(variable: variable, time: time)
        }
    }
}

extension ReaderSource {
    static func domain<D: GenericDomain, V: GenericVariable>(_ domain: D, _ schema: V.Type) -> Self {
        .reader { binding, options in
            guard let raw = try await binding.reader(domain, schema, options) else { return nil }
            return .source(ForecastReaderLeaf(VariableHourlyDeriver(reader: raw, options: options, domainRegistry: domain.domainRegistry)))
        }
    }

    /// Mix typed raw inputs with the existing mixer, then derive once.
    /// Normal requests require the derivation domain's coverage; explicit runs may
    /// use another generation. This eligibility rule belongs to this reader factory.
    static func derive<D: GenericDomain, V: GenericVariable>(domains: [D], variable: V.Type, derivationDomain: D) -> Self {
        .reader { binding, options in
            var next = binding
            var readers: [GenericReaderCached<D, V>] = []
            var available = false
            var covered = false
            var unavailable: ForecastApiError?
            for domain in domains.reversed() {
                do {
                    let raw = try await next.reader(domain, variable, options)
                    available = true
                    guard let raw else { continue }
                    readers.append(raw)
                    if domain.domainRegistry == derivationDomain.domainRegistry { covered = true }
                    if next.elevation.isNaN { next.elevation = raw.resolvedTargetElevation }
                } catch let error as ForecastApiError {
                    guard case .modelRunUnavailable = error else { throw error }
                    unavailable = unavailable ?? error
                }
            }
            if !available, let unavailable { throw unavailable }
            guard !readers.isEmpty, covered || options.run != nil else { return nil }
            let raw = GenericReaderMixerSameVariableType(reader: Array(readers.reversed()))
            return .source(ForecastReaderLeaf(VariableHourlyDeriver(reader: raw, options: options, domainRegistry: derivationDomain.domainRegistry)))
        }
    }

    static func derive<P: GenericDomain, PV: GenericVariable, S: GenericDomain, SV: GenericVariable>(
        primary: (P, PV.Type), supplemental: (S, SV.Type)
    ) -> Self {
        .reader { binding, options in
            guard let primaryReader = try await binding.reader(primary.0, primary.1, options) else { return nil }
            var next = binding
            if next.elevation.isNaN { next.elevation = primaryReader.resolvedTargetElevation }
            let secondary: GenericReaderCached<S, SV>?
            do {
                secondary = try await next.reader(supplemental.0, supplemental.1, options)
            } catch ForecastApiError.modelRunUnavailable {
                secondary = nil
            }
            let raw = RawReaderUnion(primary: primaryReader, supplemental: secondary)
            return .source(ForecastReaderLeaf(VariableHourlyDeriver(reader: raw, options: options, domainRegistry: primary.0.domainRegistry)))
        }
    }

    static func field<D: GenericDomain, V: GenericVariable>(_ domain: D, _ field: ForecastSurfaceVariable, _ variable: V) -> Self {
        .reader { binding, options in
            guard let raw = try await binding.reader(domain, V.self, options) else { return nil }
            return .source(ForecastReaderLeaf(raw: raw, field: field, variable: variable))
        }
    }
}

extension ReaderSource.Binding {
    func reader<D: GenericDomain, V: GenericVariable>(_ domain: D, _ schema: V.Type, _ options: GenericReaderOptions) async throws -> GenericReaderCached<D, V>? {
        let raw: GenericReader<D, V>
        if let output = outputGrid {
            try await options.validateRun(domain: domain)
            let position = output.domain.domainRegistry == domain.domainRegistry
                ? output.position : domain.grid.findPoint(lat: latitude, lon: longitude)
            guard let position else { return nil }
            raw = try await GenericReader(domain: domain, position: position, modelCoordinates: (latitude, longitude), options: options)
        } else {
            guard let reader = try await GenericReader<D, V>(domain: domain, lat: latitude, lon: longitude,
                elevation: elevation, mode: mode, options: options) else { return nil }
            raw = reader
        }
        return GenericReaderCached(reader: raw)
    }
}
