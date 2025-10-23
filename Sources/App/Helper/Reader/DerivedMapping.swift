/**
 Abstract derived variables into a graph. Allows recursive dependencies between variables. There is no protection against circular dependencies. The graph must be constructed without loops.
 */
indirect enum DerivedMapping<Variable>: GenericVariableMixable {
    enum RawOrMapped {
        case raw(Variable)
        case mapped(DerivedMapping)
    }
    
    case direct(Variable)
    case directShift24Hour(Variable)
    case independent((TimerangeDtAndSettings) -> DataAndUnit)
    case one(RawOrMapped, (DataAndUnit, TimerangeDtAndSettings) -> (DataAndUnit))
    case two(RawOrMapped, RawOrMapped, (DataAndUnit, DataAndUnit, TimerangeDtAndSettings) -> (DataAndUnit))
    case three(RawOrMapped, RawOrMapped, RawOrMapped, (DataAndUnit, DataAndUnit, DataAndUnit, TimerangeDtAndSettings) -> (DataAndUnit))
    case four(RawOrMapped, RawOrMapped, RawOrMapped, RawOrMapped, (DataAndUnit, DataAndUnit, DataAndUnit, DataAndUnit, TimerangeDtAndSettings) -> (DataAndUnit))
    
    case weatherCode(cloudcover: RawOrMapped, precipitation: Variable, convectivePrecipitation: Variable?, snowfallCentimeters: RawOrMapped, gusts: Variable?, cape: Variable?, liftedIndex: Variable?, visibilityMeters: Variable?, categoricalFreezingRain: Variable?)
    
    init?(rawValue: String) {
        fatalError("DerivedMapping must not be used via string initializer")
    }
    
    var rawValue: String {
        fatalError("DerivedMapping must not be used via string initializer")
    }
    
    static func windSpeed(u: Variable?, v: Variable?) -> Self? {
        guard let u, let v else {
            return nil
        }
        return .two(.raw(u), .raw(v), {u, v, _ in
            return DataAndUnit(zip(u.data, v.data).map(Meteorology.windspeed), .metrePerSecond)
        })
    }
    
    static func windSpeed(u: Variable?, v: Variable?, levelFrom: Float, levelTo: Float) -> Self? {
        guard let u, let v else {
            return nil
        }
        return .two(.raw(u), .raw(v), {u, v, _ in
            return DataAndUnit(Meteorology.windspeed(u: u.data, v: v.data, levelFrom: levelFrom, levelTo: levelTo), .metrePerSecond)
        })
    }
    
    static func windDirection(u: Variable?, v: Variable?) -> Self? {
        guard let u, let v else {
            return nil
        }
        return .two(.raw(u), .raw(v), {u, v, _ in
            return DataAndUnit(Meteorology.windirectionFast(u: u.data, v: v.data), .metrePerSecond)
        })
    }
}

protocol GenericDeriverProtocol: GenericReaderProtocol where MixingVar == DerivedMapping<Reader.MixingVar> {
    associatedtype SourceVariable
    associatedtype Reader: GenericReaderProtocol
    
    var reader: Reader {get}
    func getDeriverMap(variable: SourceVariable) -> MixingVar?
}

extension GenericDeriverProtocol {
    var modelLat: Float {
        reader.modelLat
    }

    var modelLon: Float {
        reader.modelLon
    }

    var modelElevation: ElevationOrSea {
        reader.modelElevation
    }

    var modelDtSeconds: Int {
        reader.modelDtSeconds
    }

    var targetElevation: Float {
        reader.targetElevation
    }
    
    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.getStatic(type: type)
    }
    
    func get(variable: SourceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let mapping = getDeriverMap(variable: variable) else {
            return nil
        }
        return try await get(variable: mapping, time: time)
    }
    
    func prefetchData(variable: SourceVariable, time: TimerangeDtAndSettings) async throws {
        guard let mapping = getDeriverMap(variable: variable) else {
            return
        }
        try await prefetchData(variable: mapping, time: time)
    }
    
    private func get(mapping: MixingVar.RawOrMapped, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch mapping {
        case .raw(let variable):
            return try await reader.get(variable: variable, time: time)
        case .mapped(let derivedMapping):
            return try await get(variable: derivedMapping, time: time)
        }
    }
    
    fileprivate func get(variable: Reader.MixingVar?, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let variable else {
            return nil
        }
        return try await get(variable: variable, time: time)
    }
    
    func get(variable: MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .direct(let variable):
            return try await reader.get(variable: variable, time: time)
        case .directShift24Hour(let variable):
            return try await reader.get(variable: variable, time: time.with(time: time.time.add(-86400)))
        case .independent(let fn):
            return fn(time)
        case .one(let a, let fn):
            let a = try await get(mapping: a, time: time)
            return fn(a, time)
        case .two(let a, let b, let fn):
            let a = try await get(mapping: a, time: time)
            let b = try await get(mapping: b, time: time)
            return fn(a, b, time)
        case .three(let a, let b, let c, let fn):
            let a = try await get(mapping: a, time: time)
            let b = try await get(mapping: b, time: time)
            let c = try await get(mapping: c, time: time)
            return fn(a, b, c, time)
        case .four(let a, let b, let c, let d, let fn):
            let a = try await get(mapping: a, time: time)
            let b = try await get(mapping: b, time: time)
            let c = try await get(mapping: c, time: time)
            let d = try await get(mapping: d, time: time)
            return fn(a, b, c, d, time)
        case .weatherCode(cloudcover: let cloudcover, precipitation: let precipitation, convectivePrecipitation: let convectivePrecipitation, snowfallCentimeters: let snowfallCentimeters, gusts: let gusts, cape: let cape, liftedIndex: let liftedIndex, visibilityMeters: let visibilityMeters, categoricalFreezingRain: let categoricalFreezingRain):
            
            let cloudcover = try await get(mapping: cloudcover, time: time)
            let snowfall = try await get(mapping: snowfallCentimeters, time: time)
            let precipitation = try await reader.get(variable: precipitation, time: time)
            
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover.data,
                precipitation: precipitation.data,
                convectivePrecipitation: try await get(variable: convectivePrecipitation, time: time)?.data,
                snowfallCentimeters: snowfall.data,
                gusts: try await get(variable: gusts, time: time)?.data,
                cape: try await get(variable: cape, time: time)?.data,
                liftedIndex: try await get(variable: liftedIndex, time: time)?.data,
                visibilityMeters: try await get(variable: visibilityMeters, time: time)?.data,
                categoricalFreezingRain: try await get(variable: categoricalFreezingRain, time: time)?.data,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        }
    }
    
    private func prefetchData(mapping: MixingVar.RawOrMapped, time: TimerangeDtAndSettings) async throws {
        switch mapping {
        case .raw(let variable):
            try await prefetchData(variable: variable, time: time)
        case .mapped(let derivedMapping):
            try await prefetchData(variable: derivedMapping, time: time)
        }
    }
    
    fileprivate func prefetchData(variable: Reader.MixingVar?, time: TimerangeDtAndSettings) async throws {
        guard let variable else {
            return
        }
        return try await prefetchData(variable: variable, time: time)
    }
    
    func prefetchData(variable: MixingVar, time: TimerangeDtAndSettings) async throws {
        switch variable {
        case .direct(let variable):
            try await prefetchData(variable: variable, time: time)
        case .directShift24Hour(let variable):
            try await prefetchData(variable: variable, time: time.with(time: time.time.add(-86400)))
        case .independent(_):
            break
        case .one(let a, _):
            try await prefetchData(mapping: a, time: time)
        case .two(let a, let b, _):
            try await prefetchData(mapping: a, time: time)
            try await prefetchData(mapping: b, time: time)
        case .three(let a, let b, let c, _):
            try await prefetchData(mapping: a, time: time)
            try await prefetchData(mapping: b, time: time)
            try await prefetchData(mapping: c, time: time)
        case .four(let a, let b, let c, let d, _):
            try await prefetchData(mapping: a, time: time)
            try await prefetchData(mapping: b, time: time)
            try await prefetchData(mapping: c, time: time)
            try await prefetchData(mapping: d, time: time)
        case .weatherCode(cloudcover: let cloudcover, precipitation: let precipitation, convectivePrecipitation: let convectivePrecipitation, snowfallCentimeters: let snowfallCentimeters, gusts: let gusts, cape: let cape, liftedIndex: let liftedIndex, visibilityMeters: let visibilityMeters, categoricalFreezingRain: let categoricalFreezingRain):
            try await prefetchData(mapping: cloudcover, time: time)
            try await prefetchData(mapping: snowfallCentimeters, time: time)
            try await prefetchData(variable: precipitation, time: time)
            try await prefetchData(variable: convectivePrecipitation, time: time)
            try await prefetchData(variable: gusts, time: time)
            try await prefetchData(variable: cape, time: time)
            try await prefetchData(variable: liftedIndex, time: time)
            try await prefetchData(variable: visibilityMeters, time: time)
            try await prefetchData(variable: categoricalFreezingRain, time: time)
        }
    }
}
