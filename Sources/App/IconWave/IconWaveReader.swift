import Foundation

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer {
    let reader: [IconWaveReader]
    let modelLat: Float
    let modelLon: Float
    let time: TimerangeDt
    
    public init(lat: Float, lon: Float, time: Range<Timestamp>) throws {
        let hourly = time.range(dtSeconds: 3600)
        reader = try IconWaveDomain.allCases.compactMap {
            return try IconWaveReader(domain: $0, lat: lat, lon: lon, elevation: .nan, mode: .sea, time: hourly)
        }
        guard let highresModel = reader.last else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        self.time = hourly
        modelLat = highresModel.modelLat
        modelLon = highresModel.modelLon
    }
    
    func prefetchData(variables: [IconWaveVariable]) throws {
        try variables.forEach { variable in
            try reader.forEach { reader in
                try reader.prefetchData(variable: variable)
            }
        }
    }
    
    func get(variable: IconWaveVariable) throws -> DataAndUnit {
        // Read data from available domains
        let datas = try reader.map {
            try $0.get(variable: variable)
        }
        // global domain
        var first = datas.first!
        // default case, just place new data in 1:1
        for d in datas.dropFirst() {
            for x in d.indices {
                if d[x].isNaN {
                    continue
                }
                first[x] = d[x]
            }
        }
        return DataAndUnit(first, variable.unit)
    }
}



