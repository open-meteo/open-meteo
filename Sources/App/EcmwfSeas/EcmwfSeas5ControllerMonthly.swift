enum EcmwfSeasVariableMonthlyDerived: String, RawRepresentableString, GenericVariableMixable {
    case snowfall_mean
    case snowfall_anomaly
    case snow_depth_mean
    case snow_depth_anomaly
}

struct EcmwfSeas5ControllerMonthly: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariableMonthly>

    let options: GenericReaderOptions

    typealias Domain = EcmwfSeasDomain

    typealias Variable = VariableOrDerived<EcmwfSeasVariableMonthly, EcmwfSeasVariableMonthlyDerived>

    typealias Derived = EcmwfSeasVariableMonthlyDerived

    public init?(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, EcmwfSeasVariableMonthly>(domain: .seas5_monthly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    public init(gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, EcmwfSeasVariableMonthly>(domain: .seas5_monthly, position: gridpoint, options: options)
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

    func prefetchData(derived: EcmwfSeasVariableMonthlyDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .snowfall_mean:
            try await prefetchData(raw: .snowfall_water_equivalent_mean, time: time)
        case .snowfall_anomaly:
            try await prefetchData(raw: .snowfall_water_equivalent_anomaly, time: time)
        case .snow_depth_mean:
            try await prefetchData(raw: .snow_density_mean, time: time)
            try await prefetchData(raw: .snow_depth_water_equivalent_mean, time: time)
        case .snow_depth_anomaly:
            try await prefetchData(raw: .snow_density_mean, time: time)
            try await prefetchData(raw: .snow_depth_water_equivalent_anomaly, time: time)
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

    func get(derived: EcmwfSeasVariableMonthlyDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .snowfall_mean:
            let data = try await get(raw: .snowfall_water_equivalent_mean, time: time)
            return  DataAndUnit(data.data.map{$0 * 0.7}, .centimetre)
        case .snowfall_anomaly:
            let data = try await get(raw: .snowfall_water_equivalent_anomaly, time: time)
            return  DataAndUnit(data.data.map{$0 * 0.7}, .centimetre)
        case .snow_depth_mean:
            // water equivalent in millimetre, density in kg/m3
            let water = try await get(raw: .snow_depth_water_equivalent_mean, time: time)
            let density = try await get(raw: .snow_density_mean, time: time)
            return DataAndUnit(zip(water.data, density.data).map({$0/$1}), .metre)
        case .snow_depth_anomaly:
            let water = try await get(raw: .snow_depth_water_equivalent_anomaly, time: time)
            let density = try await get(raw: .snow_density_mean, time: time)
            return DataAndUnit(zip(water.data, density.data).map({$0/$1}), .metre)
        }
    }
}
