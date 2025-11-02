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
