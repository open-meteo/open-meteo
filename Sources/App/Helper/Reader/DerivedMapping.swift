import Foundation

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
    //case independent((TimerangeDtAndSettings) -> DataAndUnit)
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
            return DataAndUnit(Meteorology.windirectionFast(u: u.data, v: v.data), .degreeDirection)
        })
    }
    
    static func windSpeedSpread(u: Variable?, v: Variable?, uSpread: Variable?, vSpread: Variable?) -> Self? {
        guard let u, let v, let uSpread, let vSpread else {
            return nil
        }
        return .four(.raw(u), .raw(v), .raw(uSpread), .raw(vSpread), {u, v, σu, σv, _ -> DataAndUnit in
            /// Calculate propagation of uncertainty. See https://en.wikipedia.org/wiki/Propagation_of_uncertainty
            /// https://www.wolframalpha.com/input?i=Simplify%5BSqrt%5BFold%5B%231%2B%232+%26%2CD%5B%5B%2F%2Fmath%3Asqrt%28U*U%2BV*V%29%2F%2F%5D%2C%7B%7B%5B%2F%2Fmath%3AU%2CV%2F%2F%5D%7D%7D%5D%5E2*%7B%5B%2F%2Fmath%3Au%2Cv%2F%2F%5D%7D%5E2%5D%5D%5D
            /// Simplify[Sqrt[Fold[#1+#2 &,D[[//math:sqrt(U*U+V*V)//],{{[//math:U,V//]}}]^2*{[//math:u,v//]}^2]]]
            /// sqrt((u^2 U^2 + v^2 V^2)/(U^2 + V^2))
            let σr: [Float] = zip(zip(u.data, v.data), zip(σu.data, σv.data)).map { arg -> Float in
                let ((u, v), (σu, σv)) = arg
                if (u * u + v * v) == 0 {
                    return 0
                }
                return sqrt((u * u * σu * σu + v * v * σv * σv) / (u * u + v * v))
            }
            return DataAndUnit(σr, .metrePerSecond)
        })
    }
    
    static func windDirectionSpread(u: Variable?, v: Variable?, uSpread: Variable?, vSpread: Variable?) -> Self? {
        guard let u, let v, let uSpread, let vSpread else {
            return nil
        }
        return .four(.raw(u), .raw(v), .raw(uSpread), .raw(vSpread), {u, v, σu, σv, _ -> DataAndUnit in
            /// https://www.wolframalpha.com/input?i=Simplify%5BSqrt%5BFold%5B%231%2B%232+%26%2CD%5B%5B%2F%2Fmath%3Aatan2%28U%2CV%29*180%2FPI+%2B+180%2F%2F%5D%2C%7B%7B%5B%2F%2Fmath%3AU%2CV%2F%2F%5D%7D%7D%5D%5E2*%7B%5B%2F%2Fmath%3Au%2Cv%2F%2F%5D%7D%5E2%5D%5D%5D
            /// Simplify[Sqrt[Fold[#1+#2 &,D[[//math:atan2(U,V)*180/PI + 180//],{{[//math:U,V//]}}]^2*{[//math:u,v//]}^2]]]
            /// (180 sqrt((u^2 V^2 + U^2 v^2)/(U^2 + V^2)^2))/π
            let σ = zip(zip(u.data, v.data), zip(σu.data, σv.data)).map { arg -> Float in
                let ((u, v), (σu, σv)) = arg
                if (u * u + v * v) == 0 {
                    return 0
                }
                return sqrt((u * u * σv * σv + v * v * σu * σu) / ((u * u + v * v) * (u * u + v * v))) * 180 / .pi
            }
            return DataAndUnit(σ, .degreeDirection)
        })
    }
}

protocol GenericDeriverProtocol: GenericReaderOptionalProtocol {
    associatedtype Reader: GenericReaderProtocol
    
    var reader: Reader {get}
    func getDeriverMap(variable: VariableOpt) -> DerivedMapping<Reader.MixingVar>?
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
    
    func get(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let mapping = getDeriverMap(variable: variable) else {
            return nil
        }
        return try await get(variable: mapping, time: time)
    }
    
    func prefetchData(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> Bool {
        guard let mapping = getDeriverMap(variable: variable) else {
            return false
        }
        try await prefetchData(variable: mapping, time: time)
        return true
    }
    
    fileprivate func get(mapping: DerivedMapping<Reader.MixingVar>.RawOrMapped, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
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
        return try await reader.get(variable: variable, time: time)
    }
    
    fileprivate func get(variable: DerivedMapping<Reader.MixingVar>, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .direct(let variable):
            return try await reader.get(variable: variable, time: time)
        case .directShift24Hour(let variable):
            return try await reader.get(variable: variable, time: time.with(time: time.time.add(-86400)))
//        case .independent(let fn):
//            return fn(time)
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
    
    fileprivate func prefetchData(mapping: DerivedMapping<Reader.MixingVar>.RawOrMapped, time: TimerangeDtAndSettings) async throws {
        switch mapping {
        case .raw(let variable):
            try await reader.prefetchData(variable: variable, time: time)
        case .mapped(let derivedMapping):
            try await prefetchData(variable: derivedMapping, time: time)
        }
    }
    
    fileprivate func prefetchData(variable: Reader.MixingVar?, time: TimerangeDtAndSettings) async throws {
        guard let variable else {
            return
        }
        return try await reader.prefetchData(variable: variable, time: time)
    }
    
    fileprivate func prefetchData(variable: DerivedMapping<Reader.MixingVar>, time: TimerangeDtAndSettings) async throws {
        switch variable {
        case .direct(let variable):
            try await prefetchData(variable: variable, time: time)
        case .directShift24Hour(let variable):
            try await prefetchData(variable: variable, time: time.with(time: time.time.add(-86400)))
//        case .independent(_):
//            break
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


protocol GenericDeriverOptionalProtocol: GenericReaderOptionalProtocol {
    associatedtype ReaderVariable: GenericVariableMixable
    
    var reader: any GenericReaderOptionalProtocol<ReaderVariable> {get}
    func getDeriverMap(variable: VariableOpt) -> DerivedMapping<ReaderVariable>?
}

extension GenericDeriverOptionalProtocol {
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
    
    func get(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let mapping = getDeriverMap(variable: variable) else {
            return nil
        }
        return try await get(variable: mapping, time: time)
    }
    
    func prefetchData(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> Bool {
        guard let mapping = getDeriverMap(variable: variable) else {
            return false
        }
        return try await prefetchData(variable: mapping, time: time)
    }
    
    fileprivate func get(variable: ReaderVariable?, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        guard let variable else {
            return nil
        }
        return try await reader.get(variable: variable, time: time)
    }
    
    fileprivate func get(mapping: DerivedMapping<ReaderVariable>.RawOrMapped, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        switch mapping {
        case .raw(let variable):
            return try await reader.get(variable: variable, time: time)
        case .mapped(let derivedMapping):
            return try await get(variable: derivedMapping, time: time)
        }
    }
    
    
    fileprivate func get(variable: DerivedMapping<ReaderVariable>, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        switch variable {
        case .direct(let variable):
            return try await reader.get(variable: variable, time: time)
        case .directShift24Hour(let variable):
            return try await reader.get(variable: variable, time: time.with(time: time.time.add(-86400)))
//        case .independent(let fn):
//            return fn(time)
        case .one(let a, let fn):
            guard let a = try await get(mapping: a, time: time) else {
                return nil
            }
            return fn(a, time)
        case .two(let a, let b, let fn):
            guard
                let a = try await get(mapping: a, time: time),
                let b = try await get(mapping: b, time: time) else {
                return nil
            }
            return fn(a, b, time)
        case .three(let a, let b, let c, let fn):
            guard
                let a = try await get(mapping: a, time: time),
                let b = try await get(mapping: b, time: time),
                let c = try await get(mapping: c, time: time) else {
                return nil
            }
            return fn(a, b, c, time)
        case .four(let a, let b, let c, let d, let fn):
            guard
                let a = try await get(mapping: a, time: time),
                let b = try await get(mapping: b, time: time),
                let c = try await get(mapping: c, time: time),
                let d = try await get(mapping: d, time: time) else {
                return nil
            }
            return fn(a, b, c, d, time)
        case .weatherCode(cloudcover: let cloudcover, precipitation: let precipitation, convectivePrecipitation: let convectivePrecipitation, snowfallCentimeters: let snowfallCentimeters, gusts: let gusts, cape: let cape, liftedIndex: let liftedIndex, visibilityMeters: let visibilityMeters, categoricalFreezingRain: let categoricalFreezingRain):
            
            guard
                let cloudcover = try await get(mapping: cloudcover, time: time),
                let snowfall = try await get(mapping: snowfallCentimeters, time: time),
                let precipitation = try await reader.get(variable: precipitation, time: time) else {
                return nil
            }
            
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
    
    fileprivate func prefetchData(mapping: DerivedMapping<ReaderVariable>.RawOrMapped, time: TimerangeDtAndSettings) async throws -> Bool {
        switch mapping {
        case .raw(let variable):
            try await reader.prefetchData(variable: variable, time: time)
        case .mapped(let derivedMapping):
            try await prefetchData(variable: derivedMapping, time: time)
        }
    }
    
    fileprivate func prefetchData(variable: ReaderVariable?, time: TimerangeDtAndSettings) async throws -> Bool {
        guard let variable else {
            return false
        }
        return try await reader.prefetchData(variable: variable, time: time)
    }
    
    fileprivate func prefetchData(variable: DerivedMapping<ReaderVariable>, time: TimerangeDtAndSettings) async throws -> Bool {
        switch variable {
        case .direct(let variable):
            return try await prefetchData(variable: variable, time: time)
        case .directShift24Hour(let variable):
            return try await prefetchData(variable: variable, time: time.with(time: time.time.add(-86400)))
//        case .independent(_):
//            return true
        case .one(let a, _):
            return try await prefetchData(mapping: a, time: time)
        case .two(let a, let b, _):
            let a = try await prefetchData(mapping: a, time: time)
            let b = try await prefetchData(mapping: b, time: time)
            return a && b
        case .three(let a, let b, let c, _):
            let a = try await prefetchData(mapping: a, time: time)
            let b = try await prefetchData(mapping: b, time: time)
            let c = try await prefetchData(mapping: c, time: time)
            return a && b && c
        case .four(let a, let b, let c, let d, _):
            let a = try await prefetchData(mapping: a, time: time)
            let b = try await prefetchData(mapping: b, time: time)
            let c = try await prefetchData(mapping: c, time: time)
            let d = try await prefetchData(mapping: d, time: time)
            return a && b && c && d
        case .weatherCode(cloudcover: let cloudcover, precipitation: let precipitation, convectivePrecipitation: let convectivePrecipitation, snowfallCentimeters: let snowfallCentimeters, gusts: let gusts, cape: let cape, liftedIndex: let liftedIndex, visibilityMeters: let visibilityMeters, categoricalFreezingRain: let categoricalFreezingRain):
            let a = try await prefetchData(mapping: cloudcover, time: time)
            let b = try await prefetchData(mapping: snowfallCentimeters, time: time)
            let c = try await prefetchData(variable: precipitation, time: time)
            let _ = try await prefetchData(variable: convectivePrecipitation, time: time)
            let _ = try await prefetchData(variable: gusts, time: time)
            let _ = try await prefetchData(variable: cape, time: time)
            let _ = try await prefetchData(variable: liftedIndex, time: time)
            let _ = try await prefetchData(variable: visibilityMeters, time: time)
            let _ = try await prefetchData(variable: categoricalFreezingRain, time: time)
            return a && b && c
        }
    }
}
