import Foundation

protocol MultiDomainMixerDomain: RawRepresentableString, GenericDomainProvider {
    var countEnsembleMember: Int { get }

    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> [any GenericReaderProtocol]

    func getReader(gridpoint: Int, options: GenericReaderOptions) async throws -> (any GenericReaderProtocol)?
}

/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMulti<Variable: GenericVariableMixable, Domain: MultiDomainMixerDomain>: GenericReaderProvider {
    let reader: [any GenericReaderProtocol]

    let domain: Domain

    var modelLat: Float {
        reader.last!.modelLat
    }
    var modelLon: Float {
        reader.last!.modelLon
    }
    var targetElevation: Float {
        reader.last!.targetElevation
    }
    var modelDtSeconds: Int {
        reader.first!.modelDtSeconds
    }
    var modelElevation: ElevationOrSea {
        reader.last!.modelElevation
    }

    public init(domain: Domain, reader: [any GenericReaderProtocol]) {
        self.reader = reader
        self.domain = domain
    }

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        let reader = try await domain.getReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        guard !reader.isEmpty else {
            return nil
        }
        self.domain = domain
        self.reader = reader
    }

    public init?(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        guard let reader = try await domain.getReader(gridpoint: gridpoint, options: options) else {
            return nil
        }
        self.domain = domain
        self.reader = [reader]
    }

    func prefetchData(variable: RawRepresentableString, time: TimerangeDtAndSettings) async throws {
        for reader in reader {
            if try await reader.prefetchData(mixed: variable.rawValue, time: time) {
                break
            }
        }
    }

    func prefetchData(variables: [RawRepresentableString], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            try await prefetchData(variable: variable, time: time)
        }
    }

    func get(variable: RawRepresentableString, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        // Last reader return highest resolution data. therefore reverse iteration
        // Integrate now lower resolution models
        var data: [Float]?
        var unit: SiUnit?
        for r in reader.reversed() {
            guard let d = try await r.get(mixed: variable.rawValue, time: time) else {
                continue
            }
            if data == nil {
                // first iteration
                data = d.data
                unit = d.unit
            } else {
                data?.integrateIfNaN(d.data)
            }
            if data?.containsNaN() == false {
                break
            }
        }
        guard let data, let unit else {
            return nil
        }
        return DataAndUnit(data, unit)
    }
}

/// Conditional conformace just use RawValue (String) to resolve `ForecastVariable` to a specific type
extension GenericReaderProtocol {
    func get(mixed: String, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let v = MixingVar(rawValue: mixed) else {
            return nil
        }
        return try await self.get(variable: v, time: time)
    }

    func prefetchData(mixed: String, time: TimerangeDtAndSettings) async throws -> Bool {
        guard let v = MixingVar(rawValue: mixed) else {
            return false
        }
        try await self.prefetchData(variable: v, time: time)
        return true
    }
}


protocol MultiDomainMixerDomainSameType<VariableHourly, VariableDaily, VariableMonthly>: RawRepresentableString, GenericDomainProvider {
    associatedtype VariableHourly: GenericVariableMixable
    associatedtype VariableDaily: GenericVariableMixable
    associatedtype VariableMonthly: GenericVariableMixable
    var countEnsembleMember: Int { get }

    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> (hourly: [any GenericReaderOptionalProtocol<VariableHourly>], daily: [any GenericReaderOptionalProtocol<VariableDaily>], monthly: [any GenericReaderOptionalProtocol<VariableMonthly>])

    func getReader(gridpoint: Int, options: GenericReaderOptions) async throws -> (hourly: [any GenericReaderOptionalProtocol<VariableHourly>], daily: [any GenericReaderOptionalProtocol<VariableDaily>], monthly: [any GenericReaderOptionalProtocol<VariableMonthly>])?
}



/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMultiSameType<Variable: GenericVariableMixable> {
    let reader: [any GenericReaderOptionalProtocol<Variable>]

    var modelLat: Float {
        reader.last!.modelLat
    }
    var modelLon: Float {
        reader.last!.modelLon
    }
    var targetElevation: Float {
        reader.last!.targetElevation
    }
    var modelDtSeconds: Int {
        reader.first!.modelDtSeconds
    }
    var modelElevation: ElevationOrSea {
        reader.last!.modelElevation
    }

    func prefetchData(variable: Variable, time: TimerangeDtAndSettings) async throws -> Bool {
        for reader in reader {
            if try await reader.prefetchData(variable: variable, time: time) {
                return true
            }
        }
        return false
    }

    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            let _ = try await prefetchData(variable: variable, time: time)
        }
    }

    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        // Last reader return highest resolution data. therefore reverse iteration
        // Integrate now lower resolution models
        var data: [Float]?
        var unit: SiUnit?
        for r in reader.reversed() {
            guard let d = try await r.get(variable: variable, time: time) else {
                continue
            }
            if data == nil {
                // first iteration
                data = d.data
                unit = d.unit
            } else {
                data?.integrateIfNaN(d.data)
            }
            if data?.containsNaN() == false {
                break
            }
        }
        guard let data, let unit else {
            return nil
        }
        return DataAndUnit(data, unit)
    }
}
