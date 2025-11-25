import Foundation

/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMulti<Variable: GenericVariableMixable>: GenericReaderOptionalProtocol {
    typealias VariableOpt = Variable
    let reader: [any GenericReaderProtocol]

    var modelLat: Float {
        reader.last?.modelLat ?? .nan
    }
    var modelLon: Float {
        reader.last?.modelLon ?? .nan
    }
    var targetElevation: Float {
        reader.last?.targetElevation ?? .nan
    }
    var modelDtSeconds: Int {
        reader.first?.modelDtSeconds ?? 3600
    }
    var modelElevation: ElevationOrSea {
        reader.last?.modelElevation ?? .noData
    }

    public init(reader: [any GenericReaderProtocol]) {
        self.reader = reader
    }
    
    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.first?.getStatic(type: type)
    }

    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            let _ = try await prefetchData(variable: variable, time: time)
        }
    }
    
    func prefetchData(variable: Variable, time: TimerangeDtAndSettings) async throws -> Bool {
        for reader in reader {
            if try await reader.prefetchData(mixed: variable.rawValue, time: time) {
                break
            }
        }
        return true
    }

    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
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
                if let unit, [.wmoCode, .dimensionless].contains(unit) {
                    data?.integrateIfNaN(d.data)
                } else {
                    data?.integrateIfNaNSmooth(d.data)
                }
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

/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMultiSameType<Variable: GenericVariableMixable>: GenericReaderOptionalProtocol {
    let reader: [any GenericReaderOptionalProtocol<Variable>]

    var modelLat: Float {
        reader.last?.modelLat ?? .nan
    }
    var modelLon: Float {
        reader.last?.modelLon ?? .nan
    }
    var targetElevation: Float {
        reader.last?.targetElevation ?? .nan
    }
    var modelDtSeconds: Int {
        reader.first?.modelDtSeconds ?? 3600
    }
    var modelElevation: ElevationOrSea {
        reader.last?.modelElevation ?? .noData
    }
    
    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.last?.getStatic(type: type)
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
                if let unit, [.wmoCode, .dimensionless].contains(unit) {
                    data?.integrateIfNaN(d.data)
                } else {
                    data?.integrateIfNaNSmooth(d.data)
                }
                if data?.containsNaN() == false {
                    break
                }
            }
        }
        guard let data, let unit else {
            return nil
        }
        return DataAndUnit(data, unit)
    }
}
