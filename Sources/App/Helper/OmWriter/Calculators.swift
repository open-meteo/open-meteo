fileprivate struct MemberTimestamp: Hashable {
    let member: Int
    let timestamp: Timestamp
    
    init(_ member: Int, _ timestamp: Timestamp) {
        self.member = member
        self.timestamp = timestamp
    }
}

/// Calculate Relative humidity while downloading
struct RelativeHumidityCalculator {
    let outVariable: any GenericVariable
    fileprivate let data = CaptureTwo<MemberTimestamp, Array2D>()
    
    func ingest(dewpoint: Array2D, member: Int, writer: OmSpatialTimestepWriter) async throws {
        guard let temperature = await data.insert(second: dewpoint, key: MemberTimestamp(member, writer.time)) else {
            return
        }
        let rh = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
        try await writer.write(member: member, variable: outVariable, data: rh)
    }
    
    func ingest(temperature: Array2D, member: Int, writer: OmSpatialTimestepWriter) async throws {
        guard let dewpoint = await data.insert(first: temperature, key: MemberTimestamp(member, writer.time)) else {
            return
        }
        let rh = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
        try await writer.write(member: member, variable: outVariable, data: rh)
    }
}


/// Calculate wind speed and direction from U/V components
/// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
struct WindSpeedCalculator<V: GenericVariable & Hashable> {
    private let trueNorth: [Float]?
    
    /// Use speed variable as hash to support different levels
    private struct MemberTimestampVariable: Hashable {
        let member: Int
        let timestamp: Timestamp
        let variable: V
        
        init(_ member: Int, _ timestamp: Timestamp, _ variable: V) {
            self.member = member
            self.timestamp = timestamp
            self.variable = variable
        }
    }
    
    private let data = CaptureTwo<MemberTimestampVariable, Array2D>()
    
    init(trueNorth: [Float]? = nil) {
        self.trueNorth = trueNorth
    }
    
    func ingest(u: Array2D, member: Int, outSpeed: V, outDirection: V?, writer: OmSpatialTimestepWriter) async throws {
        guard let v = await data.insert(first: u, key: MemberTimestampVariable(member, writer.time, outSpeed)) else {
            return
        }
        return try await calculate(u: u, v: v, outSpeed: outSpeed, outDirection: outDirection, member: member, writer: writer)
    }
    
    func ingest(v: Array2D, member: Int, outSpeed: V, outDirection: V?, writer: OmSpatialTimestepWriter) async throws {
        guard let u = await data.insert(second: v, key: MemberTimestampVariable(member, writer.time, outSpeed)) else {
            return
        }
        return try await calculate(u: u, v: v, outSpeed: outSpeed, outDirection: outDirection, member: member, writer: writer)
    }
    
    private func calculate(u: Array2D, v: Array2D, outSpeed: V, outDirection: V?, member: Int, writer: OmSpatialTimestepWriter) async throws {
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


/// Store 2 values per key. If the first value is inserted, `nil` is returned. Once the second value is inserted, the first value is returned.
/// First and second are kept in order. It is safe to insert the first or the second value multiple times.
fileprivate actor CaptureTwo<Key: Hashable, Value> {
    private enum FirstSecond {
        case first(Value)
        case second(Value)
    }
    
    private var data = [Key: FirstSecond]()
    
    func insert(first: Value, key: Key) async -> Value? {
        guard case .second(let second) = data.removeValue(forKey: key) else {
            self.data[key] = .first(first)
            return nil
        }
        return second
    }
    
    func insert(second: Value, key: Key) async -> Value? {
        guard case .first(let first) = data.removeValue(forKey: key) else {
            self.data[key] = .second(second)
            return nil
        }
        return first
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
