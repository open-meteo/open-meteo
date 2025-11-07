import Foundation
import Vapor
import OpenMeteoSdk

typealias GloFasVariableMember = GloFasVariable

struct GloFasMixer: GenericReaderMixer {
    let reader: [GloFasReader]

    static func makeReader(domain: GloFasReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GloFasReader? {
        return try await GloFasReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}

enum GlofasDerivedVariable: String, CaseIterable, GenericVariableMixable {
    case river_discharge_mean
    case river_discharge_min
    case river_discharge_max
    case river_discharge_median
    case river_discharge_p25
    case river_discharge_p75
}

typealias GloFasVariableOrDerived = VariableOrDerived<GloFasVariable, GlofasDerivedVariable>
typealias GloFasVariableOrDerivedMember = VariableOrDerived<GloFasVariableMember, GloFasReader.Derived>

struct GloFasReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<GloFasDomain, GloFasVariableMember>

    typealias Domain = GloFasDomain

    typealias Variable = GloFasVariableMember

    typealias Derived = GlofasDerivedVariable

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }

    func prefetchData(derived: GlofasDerivedVariable, time: TimerangeDtAndSettings) async throws {
        for member in 0..<51 {
            try await reader.prefetchData(variable: .river_discharge, time: time.with(ensembleMember: member))
        }
    }

    func get(derived: GlofasDerivedVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        let data = try await (0..<51).asyncMap({
            try await reader.get(variable: .river_discharge, time: time.with(ensembleMember: $0)).data
        })
        if data[0].onlyNaN() {
            return DataAndUnit(data[0], .cubicMetrePerSecond)
        }
        switch derived {
        case .river_discharge_mean:
            return DataAndUnit((0..<time.time.count).map { t in
                data.reduce(0, { $0 + $1[t] }) / Float(data.count)
            }, .cubicMetrePerSecond)
        case .river_discharge_min:
            return DataAndUnit((0..<time.time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] < $0 ? $1[t] : $0 })
            }, .cubicMetrePerSecond)
        case .river_discharge_max:
            return DataAndUnit((0..<time.time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] > $0 ? $1[t] : $0 })
            }, .cubicMetrePerSecond)
        case .river_discharge_median:
            return DataAndUnit((0..<time.time.count).map { t in
                data.map({ $0[t] }).sorted().interpolateLinear(Int(Float(data.count) * 0.5), (Float(data.count) * 0.5).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        case .river_discharge_p25:
            return DataAndUnit((0..<time.time.count).map { t in
                data.map({ $0[t] }).sorted().interpolateLinear(Int(Float(data.count) * 0.25), (Float(data.count) * 0.25).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        case .river_discharge_p75:
            return DataAndUnit((0..<time.time.count).map { t in
                data.map({ $0[t] }).sorted().interpolateLinear(Int(Float(data.count) * 0.75), (Float(data.count) * 0.75).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        }
    }
}
