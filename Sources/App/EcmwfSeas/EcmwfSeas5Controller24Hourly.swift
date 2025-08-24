enum EcmwfSeasVariable24HourlySingleLevelDerived: String, RawRepresentableString, GenericVariableMixable {
    case temperature_2m_max

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct EcmwfSeas5Controller24Hourly: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariable24HourlySingleLevel>

    let options: GenericReaderOptions

    typealias Domain = EcmwfSeasDomain

    typealias Variable = VariableOrDerived<EcmwfSeasVariable24HourlySingleLevel, EcmwfSeasVariable24HourlySingleLevelDerived>

    typealias Derived = EcmwfSeasVariable24HourlySingleLevelDerived

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: domain, position: gridpoint, options: options)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try await prefetchData(raw: v, time: time)
            case .derived(let v):
                try await prefetchData(derived: v, time: time)
            }
        }
    }

    func prefetchData(derived: EcmwfSeasVariable24HourlySingleLevelDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .temperature_2m_max:
            try await prefetchData(raw: .temperature_2m_max24h, time: time)
        }
    }

    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try await get(raw: variable, time: time)
        case .derived(let variable):
            return try await get(derived: variable, time: time)
        }
    }

    func get(derived: EcmwfSeasVariable24HourlySingleLevelDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .temperature_2m_max:
            return try await get(raw: .temperature_2m_max24h, time: time)
        }
    }
}
