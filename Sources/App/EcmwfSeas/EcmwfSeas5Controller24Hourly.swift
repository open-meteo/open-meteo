enum EcmwfSeasVariable24HourlySingleLevelDerived: String, RawRepresentableString, GenericVariableMixable {
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    //case shortwave_radiation_sum
    //case precipitation_sum

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

    public init?(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: .seas5_24hourly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    public init(gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: .seas5_24hourly, position: gridpoint, options: options)
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
        let time24hAgo = time.with(time: time.time.add(-86400))
        switch derived {
        case .temperature_2m_max:
            try await prefetchData(raw: .temperature_max24h_2m, time: time24hAgo)
        case .temperature_2m_min:
            try await prefetchData(raw: .temperature_min24h_2m, time: time24hAgo)
        case .temperature_2m_mean:
            try await prefetchData(raw: .temperature_mean24h_2m, time: time24hAgo)
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
        let time24hAgo = time.with(time: time.time.add(-86400))
        switch derived {
        case .temperature_2m_max:
            return try await get(raw: .temperature_max24h_2m, time: time24hAgo)
        case .temperature_2m_min:
            return try await get(raw: .temperature_min24h_2m, time: time24hAgo)
        case .temperature_2m_mean:
            return try await get(raw: .temperature_mean24h_2m, time: time24hAgo)
        }
    }
}
