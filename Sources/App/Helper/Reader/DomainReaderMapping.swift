import Foundation

extension MultiDomains {
    typealias ForecastReaderResult = (
        hourly: (any GenericReaderOptionalProtocol<ForecastVariable>)?,
        daily: (any GenericReaderOptionalProtocol<ForecastVariableDaily>)?,
        weekly: (any GenericReaderOptionalProtocol<ForecastVariableWeekly>)?,
        monthly: (any GenericReaderOptionalProtocol<ForecastVariableMonthly>)?
    )

    struct RawReaderDerivationGroup {
        typealias ReaderResult = (reader: any GenericReaderOptionalProtocol<ForecastVariable>, elevation: Float)

        let singleDomainSource: (any GenericDomain, any GenericVariable.Type)?
        private let makeReaderClosure: (Float, Float, Float, GridSelectionMode, GenericReaderOptions) async throws -> ReaderResult?

        init<Domain, Variable>(
            domains: [Domain],
            variableType: Variable.Type,
            derivationDomain: Domain,
            primaryDomain: Domain? = nil
        ) where
            Domain: GenericDomain,
            Variable: GenericVariable & Hashable
        {
            self.singleDomainSource = primaryDomain.map { ($0, variableType) }
            self.makeReaderClosure = { lat, lon, elevation, mode, options in
                var resolvedElevation = elevation
                var derivationDomainInitialized = false
                let initialized: [GenericReaderCached<Domain, Variable>] = try await domains.reversed().asyncCompactMap { domain in
                    guard let rawReader = try await GenericReader<Domain, Variable>(
                        domain: domain,
                        lat: lat,
                        lon: lon,
                        elevation: resolvedElevation,
                        mode: mode,
                        options: options
                    ) else {
                        return nil
                    }
                    let reader = GenericReaderCached(reader: rawReader)
                    if resolvedElevation.isNaN {
                        resolvedElevation = reader.resolvedTargetElevation
                    }
                    if domain.domainRegistry == derivationDomain.domainRegistry {
                        derivationDomainInitialized = true
                    }
                    return reader
                }.reversed()
                guard derivationDomainInitialized else {
                    return nil
                }
                let mixer = GenericReaderMixerSameVariableType(reader: initialized)
                let reader = VariableHourlyDeriver(
                    reader: mixer,
                    options: options,
                    domainRegistry: derivationDomain.domainRegistry
                )
                return (reader, resolvedElevation)
            }
        }

        init<PrimaryDomain, PrimaryVariable, SupplementalDomain, SupplementalVariable>(
            primary: (PrimaryDomain, PrimaryVariable.Type),
            supplemental: (SupplementalDomain, SupplementalVariable.Type)
        ) where
            PrimaryDomain: GenericDomain,
            PrimaryVariable: GenericVariable,
            SupplementalDomain: GenericDomain,
            SupplementalVariable: GenericVariable
        {
            self.singleDomainSource = nil
            self.makeReaderClosure = { lat, lon, elevation, mode, options in
                guard let primaryRawReader = try await GenericReader<PrimaryDomain, PrimaryVariable>(
                    domain: primary.0,
                    lat: lat,
                    lon: lon,
                    elevation: elevation,
                    mode: mode,
                    options: options
                ) else {
                    return nil
                }
                let primaryReader = GenericReaderCached(reader: primaryRawReader)
                let resolvedElevation = elevation.isFinite ? elevation : primaryReader.resolvedTargetElevation
                let supplementalReader = try await GenericReader<SupplementalDomain, SupplementalVariable>(
                    domain: supplemental.0,
                    lat: lat,
                    lon: lon,
                    elevation: resolvedElevation,
                    mode: mode,
                    options: options
                ).map { GenericReaderCached(reader: $0) }
                let rawReaders: [any GenericReaderProtocol] = [supplementalReader].compactMap { $0 } + [primaryReader]
                let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<PrimaryVariable, SupplementalVariable>>(
                    reader: rawReaders
                )
                let reader = VariableHourlyDeriver(
                    reader: mixer,
                    options: options,
                    domainRegistry: primary.0.domainRegistry
                )
                return (reader, resolvedElevation)
            }
        }

        func makeReader(
            lat: Float,
            lon: Float,
            elevation: Float,
            mode: GridSelectionMode,
            options: GenericReaderOptions
        ) async throws -> ReaderResult? {
            try await makeReaderClosure(lat, lon, elevation, mode, options)
        }
    }

    enum SupplementalGridpointPolicy: Equatable {
        case primaryOnly
        case alignedSupplemental
    }

    enum DomainReaderMapping {
        case single(any GenericDomain, any GenericVariable.Type)
        case multiple([(any GenericDomain, any GenericVariable.Type)])
        /// Mixes raw fields within each group, then places derived groups above supplemental readers.
        case mixedBeforeDerivation(
            groups: [RawReaderDerivationGroup],
            supplemental: [(any GenericDomain, any GenericVariable.Type)]
        )
        case singleWithPrecipitationProbability(any GenericDomain, any GenericVariable.Type, precipitationProb: any GenericDomain)
        case multipleWithPrecipitationProbability([(any GenericDomain, any GenericVariable.Type)], precipitationProb: any GenericDomain)
        case seamlessLocal(
            global: [(any GenericDomain, any GenericVariable.Type)],
            local: [(any GenericDomain, any GenericVariable.Type)],
            precipitationProb: (any GenericDomain)?
        )
        /// Derives each domain independently, then mixes supplemental results by priority.
        case singleWithSupplementalDomains(
            any GenericDomain,
            any GenericVariable.Type,
            lowerPriority: [(any GenericDomain, any GenericVariable.Type)],
            higherPriority: [(any GenericDomain, any GenericVariable.Type)],
            precipitationProb: (any GenericDomain)?,
            gridpointPolicy: SupplementalGridpointPolicy
        )

        private static func makeDomainReaders(
            sources: [(any GenericDomain, any GenericVariable.Type)],
            lat: Float,
            lon: Float,
            elevation: Float,
            mode: GridSelectionMode,
            options: GenericReaderOptions
        ) async throws -> (readers: [any GenericReaderOptionalProtocol<ForecastVariable>], elevation: Float) {
            var elevation = elevation
            let readers: [any GenericReaderOptionalProtocol<ForecastVariable>] = try await sources.reversed().asyncCompactMap { source in
                guard let reader = try await source.0.makeDerivedHourly(variableType: source.1, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                    return nil
                }
                if elevation.isNaN {
                    elevation = reader.resolvedTargetElevation
                }
                return reader
            }.reversed()
            return (readers, elevation)
        }

        var singleDomain: (any GenericDomain)? {
            switch self {
            case .single(let domain, _),
                 .singleWithPrecipitationProbability(let domain, _, _),
                 .singleWithSupplementalDomains(let domain, _, _, _, _, _):
                return domain
            case .mixedBeforeDerivation(let groups, _):
                return groups.count == 1 ? groups.first?.singleDomainSource?.0 : nil
            default:
                return nil
            }
        }

        func getReaders(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> ForecastReaderResult? {
            switch self {
            case .single(let domain, let variable):
                return try await domain.makeGenericHourlyDaily(variableType: variable, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            case .singleWithPrecipitationProbability(let domain, let variable, let precipitationProb):
                let forecast = try await Self.makeDomainReaders(sources: [(domain, variable)], lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                guard let reader = forecast.readers.first else {
                    return nil
                }
                let prob = try await precipitationProb.makeHourlyReader(variableType: ProbabilityVariable.self, lat: lat, lon: lon, elevation: forecast.elevation, mode: mode, options: options)?.asOptionalReader
                return MultiDomains.hourlyToMultiSameType([prob].compactMap { $0 } + [reader])
            case .multipleWithPrecipitationProbability(let domains, precipitationProb: let precipitationProb):
                let forecast = try await Self.makeDomainReaders(sources: domains, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                let probability = try await precipitationProb.makeHourlyReader(variableType: ProbabilityVariable.self, lat: lat, lon: lon, elevation: forecast.elevation, mode: mode, options: options)?.asOptionalReader
                return MultiDomains.hourlyToMultiSameType([probability].compactMap { $0 } + forecast.readers)
            case .multiple(let domains):
                let forecast = try await Self.makeDomainReaders(sources: domains, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                return MultiDomains.hourlyToMultiSameType(forecast.readers)
            case .mixedBeforeDerivation(let groups, let supplemental):
                var resolvedElevation = elevation
                let derivedGroupReaders: [any GenericReaderOptionalProtocol<ForecastVariable>] = try await groups.reversed().asyncCompactMap { group in
                    guard let result = try await group.makeReader(
                        lat: lat,
                        lon: lon,
                        elevation: resolvedElevation,
                        mode: mode,
                        options: options
                    ) else {
                        return nil
                    }
                    resolvedElevation = result.elevation
                    return result.reader
                }.reversed()
                let supplementalReaders = try await Self.makeDomainReaders(sources: supplemental, lat: lat, lon: lon, elevation: resolvedElevation, mode: mode, options: options)
                guard !derivedGroupReaders.isEmpty || !supplementalReaders.readers.isEmpty else {
                    return nil
                }
                return MultiDomains.hourlyToMultiSameType(
                    supplementalReaders.readers + derivedGroupReaders,
                    prefetchAllReaders: true
                )
            case .seamlessLocal(let global, let local, let precipitationProb):
                let localForecast = try await Self.makeDomainReaders(sources: local, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                guard !localForecast.readers.isEmpty else {
                    return nil
                }
                let globalForecast = try await Self.makeDomainReaders(sources: global, lat: lat, lon: lon, elevation: localForecast.elevation, mode: mode, options: options)
                let probability = try await precipitationProb?.makeHourlyReader(variableType: ProbabilityVariable.self, lat: lat, lon: lon, elevation: globalForecast.elevation, mode: mode, options: options)?.asOptionalReader
                return MultiDomains.hourlyToMultiSameType([probability].compactMap { $0 } + globalForecast.readers + localForecast.readers)
            case .singleWithSupplementalDomains(let domain, let variable, let lowerPriority, let higherPriority, let precipitationProb, _):
                let sources = lowerPriority + [(domain, variable)] + higherPriority
                let forecast = try await Self.makeDomainReaders(sources: sources, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
                guard !forecast.readers.isEmpty else {
                    return nil
                }
                let probability = try await precipitationProb?.makeHourlyReader(variableType: ProbabilityVariable.self, lat: lat, lon: lon, elevation: forecast.elevation, mode: mode, options: options)?.asOptionalReader
                return MultiDomains.hourlyToMultiSameType([probability].compactMap { $0 } + forecast.readers)
            }
        }

        func getReaders(gridpoint: Int, options: GenericReaderOptions) async throws -> ForecastReaderResult {
            switch self {
            case .single(let domain, let variable),
                 .singleWithPrecipitationProbability(let domain, let variable, _):
                return try await domain.makeGenericHourlyDaily(variableType: variable, position: gridpoint, options: options)
            case .singleWithSupplementalDomains(let domain, let variable, let lowerPriority, let higherPriority, _, let gridpointPolicy):
                switch gridpointPolicy {
                case .primaryOnly:
                    return try await domain.makeGenericHourlyDaily(variableType: variable, position: gridpoint, options: options)
                case .alignedSupplemental:
                    let sources = lowerPriority + [(domain, variable)] + higherPriority
                    let readers: [any GenericReaderOptionalProtocol<ForecastVariable>] = try await sources.asyncCompactMap { source in
                        let result = try await source.0.makeGenericHourlyDaily(
                            variableType: source.1,
                            position: gridpoint,
                            options: options
                        )
                        return result.hourly
                    }
                    return MultiDomains.hourlyToMultiSameType(readers) ?? (nil, nil, nil, nil)
                }
            case .mixedBeforeDerivation(let groups, _):
                guard groups.count == 1,
                      let group = groups.first,
                      let (domain, variable) = group.singleDomainSource
                else {
                    return (nil, nil, nil, nil)
                }
                let primary = try await domain.makeGenericHourlyDaily(variableType: variable, position: gridpoint, options: options)
                guard let primary = primary.hourly,
                      let result = try await group.makeReader(
                        lat: primary.modelLat,
                        lon: primary.modelLon,
                        elevation: primary.resolvedTargetElevation,
                        mode: .nearest,
                        options: options
                      )
                else {
                    return (nil, nil, nil, nil)
                }
                return withDaily(result.reader)
            case .multiple, .multipleWithPrecipitationProbability, .seamlessLocal:
                return (nil, nil, nil, nil)
            }
        }

        private func withDaily<Reader: GenericReaderOptionalProtocol>(_ reader: Reader) -> ForecastReaderResult where Reader.VariableOpt == ForecastVariable {
            (reader, reader.makeDailyAggregator(useModelProvidedMinMax: false), nil, nil)
        }

    }

    static func hourlyToMultiSameType(
        _ readers: [any GenericReaderOptionalProtocol<ForecastVariable>],
        prefetchAllReaders: Bool = false
    ) -> ForecastReaderResult? {
        guard !readers.isEmpty else {
            return nil
        }
        let hourly = GenericReaderMultiSameType<ForecastVariable>(reader: readers, prefetchAllReaders: prefetchAllReaders)
        return (hourly, hourly.makeDailyAggregator(useModelProvidedMinMax: false), nil, nil)
    }

    static func hourlyToMultiSameType(
        _ readers: [(any GenericReaderOptionalProtocol<ForecastVariable>)?],
        prefetchAllReaders: Bool = false
    ) -> ForecastReaderResult? {
        hourlyToMultiSameType(readers.compactMap { $0 }, prefetchAllReaders: prefetchAllReaders)
    }
}
