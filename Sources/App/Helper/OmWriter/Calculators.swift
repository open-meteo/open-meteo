fileprivate struct MemberTimestamp: Hashable {
    let member: Int
    let timestamp: Timestamp
    
    init(_ member: Int, _ timestamp: Timestamp) {
        self.member = member
        self.timestamp = timestamp
    }
}

/// Use speed variable as hash to support different levels
fileprivate struct MemberTimestampVariable<V: Hashable>: Hashable {
    let member: Int
    let timestamp: Timestamp
    let variable: V
    
    init(_ member: Int, _ timestamp: Timestamp, _ variable: V) {
        self.member = member
        self.timestamp = timestamp
        self.variable = variable
    }
}

/// Calculate Relative humidity while downloading
struct RelativeHumidityCalculator {
    enum Input {
        case temperature(Array2D)
        case dewpoint(Array2D)
        
        var firstOrSecond: FirstSecond<Array2D> {
            switch self {
            case .temperature(let array2D):
                return .first(array2D)
            case .dewpoint(let array2D):
                return .second(array2D)
            }
        }
    }
    
    let outVariable: any GenericVariable
    fileprivate let data = CaptureTwo<MemberTimestamp, Array2D>()
    
    func ingest(_ value: Input, member: Int, writer: OmSpatialTimestepWriter) async throws {
        guard let (temperature, dewpoint) = await data.insert(value: value.firstOrSecond, key: MemberTimestamp(member, writer.time)) else {
            return
        }
        let rh = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
        try await writer.write(member: member, variable: outVariable, data: rh)
    }
}


/// Calculate wind speed and direction from U/V components
/// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
struct WindSpeedCalculator<V: GenericVariable & Hashable> {
    enum Input {
        case u(Array2D)
        case v(Array2D)
        
        var firstOrSecond: FirstSecond<Array2D> {
            switch self {
            case .u(let array2D):
                return .first(array2D)
            case .v(let array2D):
                return .second(array2D)
            }
        }
    }
    
    private let trueNorth: [Float]?
    
    private let data = CaptureTwo<MemberTimestampVariable<V>, Array2D>()
    
    init(trueNorth: [Float]? = nil) {
        self.trueNorth = trueNorth
    }
    
    func ingest(_ value: Input, member: Int, outSpeed: V, outDirection: V?, writer: OmSpatialTimestepWriter) async throws {
        guard let (u, v) = await data.insert(value: value.firstOrSecond, key: MemberTimestampVariable(member, writer.time, outSpeed)) else {
            return
        }
        let speed = zip(u.data, v.data).map(Meteorology.windspeed)
        try await writer.write(member: member, variable: outSpeed, data: speed)
        if let outDirection {
            var direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            if let trueNorth {
                direction = zip(direction, trueNorth).map({ ($0 - $1 + 360).truncatingRemainder(dividingBy: 360) })
            }
            try await writer.write(member: member, variable: outDirection, data: direction)
        }
    }
}


/// Calculate geometric vertical velocity
struct VerticalVelocityCalculator<V: GenericVariable & Hashable> {
    enum Input {
        case temperature(Array2D)
        case omega(Array2D)
        
        var firstOrSecond: FirstSecond<Array2D> {
            switch self {
            case .temperature(let array2D):
                return .first(array2D)
            case .omega(let array2D):
                return .second(array2D)
            }
        }
    }
    
    fileprivate let data = CaptureTwo<MemberTimestampVariable<V>, Array2D>()
    
    func ingest(_ value: Input, member: Int, pressureLevel: Float, outVariable: V, writer: OmSpatialTimestepWriter) async throws {
        guard let (temperature, omega) = await data.insert(value: value.firstOrSecond, key: MemberTimestampVariable(member, writer.time, outVariable)) else {
            return
        }
        let v = Meteorology.verticalVelocityPressureToGeometric(omega: omega.data, temperature: temperature.data, pressureLevel: pressureLevel)
        try await writer.write(member: member, variable: outVariable, data: v)
    }
}


enum FirstSecond<V> {
    case first(V)
    case second(V)
}

/// Store 2 values per key. If the first value is inserted, `nil` is returned. Once the second value is inserted, the first value is returned.
/// First and second are kept in order. It is safe to insert the first or the second value multiple times.
fileprivate actor CaptureTwo<Key: Hashable, Value> {
    private var data = [Key: FirstSecond<Value>]()
    
    func insert(value: FirstSecond<Value>, key: Key) -> (first: Value, second: Value)? {
        switch value {
        case .first(let first):
            guard case .second(let second) = data.removeValue(forKey: key) else {
                self.data[key] = value
                return nil
            }
            return (first, second)
        case .second(let second):
            guard case .first(let first) = data.removeValue(forKey: key) else {
                self.data[key] = value
                return nil
            }
            return (first, second)
        }
    }
}

//fileprivate actor CaptureThree<Key: Hashable, Value> {
//    private var first = [Key: Value]()
//    private var second = [Key: Value]()
//    private var third = [Key: Value]()
//    
//    func ingest(third: Value, key: Key) async -> (first: Value, second: Value, third: Value)? {
//        guard let firstKey = self.first.firstIndex(where: {$0.key == key}) else {
//            return nil
//        }
//        guard let secondKey = self.second.firstIndex(where: {$0.key == key}) else {
//            return nil
//        }
//        let first = self.first.remove(at: firstKey).value
//        let second = self.second.remove(at: secondKey).value
//        return (first, second, third)
//    }
//    
//    func ingest(second: Value, key: Key) async -> (first: Value, second: Value)? {
//        guard let first = self.first.removeValue(forKey: key) else {
//            self.second[key] = second
//            return nil
//        }
//        return (first, second)
//    }
//}
 
//fileprivate actor CaptureN<Key: Hashable, Value, let count: Int> {
//    private var values = [Key: InlineArray<count, Value?>]()
//    
//    func insert(value: Value, key: Key, position: Int) -> (InlineArray<count, Value>)? {
//        assert(position < count)
//        guard let values = self.values[key] else {
//            self.values[key] = .init({ $0 == position ? value : nil })
//            return nil
//        }
//        for i in values.indices {
//            guard i != position, values[i] != nil else {
//                self.values[key]?[position] = value
//                return nil
//            }
//        }
//        return .init({ $0 == position ? value : values[$0]! })
//    }
//}
