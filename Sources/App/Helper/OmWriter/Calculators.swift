fileprivate struct MemberTimestamp: Hashable {
    let member: Int
    let timestamp: Timestamp
    
    init(_ member: Int, _ timestamp: Timestamp) {
        self.member = member
        self.timestamp = timestamp
    }
}

/// Calculate Relative humidity while downloading
actor RelativeHumidityCalculator {
    let outVariable: any GenericVariable
    fileprivate var dewpoint = [MemberTimestamp: Array2D]()
    fileprivate var temperature = [MemberTimestamp: Array2D]()
    
    init(outVariable: any GenericVariable) {
        self.outVariable = outVariable
    }
    
    func ingest(dewpoint: Array2D, member: Int, writer: OmSpatialTimestepWriter) async throws {
        guard let temperature = self.temperature.removeValue(forKey: MemberTimestamp(member, writer.time)) else {
            self.dewpoint[MemberTimestamp(member, writer.time)] = dewpoint
            return
        }
        let rh = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
        try await writer.write(member: member, variable: outVariable, data: rh)
    }
    
    func ingest(temperature: Array2D, member: Int, writer: OmSpatialTimestepWriter) async throws {
        guard let dewpoint = self.dewpoint.removeValue(forKey: MemberTimestamp(member, writer.time)) else {
            self.temperature[MemberTimestamp(member, writer.time)] = temperature
            return
        }
        let rh = zip(temperature.data, dewpoint.data).map(Meteorology.relativeHumidity)
        try await writer.write(member: member, variable: outVariable, data: rh)
    }
}


/// Calculate wind speed and direction from U/V components
/// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
actor WindSpeedCalculator<V: GenericVariable & Hashable> {
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
    
    private var u = [MemberTimestampVariable: Array2D]()
    private var v = [MemberTimestampVariable: Array2D]()
    
    init(trueNorth: [Float]? = nil) {
        self.trueNorth = trueNorth
    }
    
    func ingest(u: Array2D, member: Int, outSpeed: V, outDirection: V?, writer: OmSpatialTimestepWriter) async throws {
        guard let v = self.v.removeValue(forKey: MemberTimestampVariable(member, writer.time, outSpeed)) else {
            self.u[MemberTimestampVariable(member, writer.time, outSpeed)] = u
            return
        }
        return try await calculate(u: u, v: v, outSpeed: outSpeed, outDirection: outDirection, member: member, writer: writer)
    }
    
    func ingest(v: Array2D, member: Int, outSpeed: V, outDirection: V?, writer: OmSpatialTimestepWriter) async throws {
        guard let u = self.u.removeValue(forKey: MemberTimestampVariable(member, writer.time, outSpeed)) else {
            self.v[MemberTimestampVariable(member, writer.time, outSpeed)] = v
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
