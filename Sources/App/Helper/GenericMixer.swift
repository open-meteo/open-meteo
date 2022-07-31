import Foundation


protocol GenericVariableMixing: GenericVariable {
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool { get }
}

struct GenericReaderMixer<Domain: GenericDomain, Variable: GenericVariableMixing> {
    let reader: [GenericReader<Domain, Variable>]
    
    var modelLat: Float {
        reader.last!.modelLat
    }
    var modelLon: Float {
        reader.last!.modelLon
    }
    var targetElevation: Float {
        reader.last!.targetElevation
    }
    var time: TimerangeDt {
        reader.last!.time
    }
    
    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, time: TimerangeDt) throws {
        reader = try domains.compactMap {
            try GenericReader(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode, time: time)
        }
        guard !reader.isEmpty else {
            return nil
        }
    }
    
    func prefetchData(variable: Variable) throws {
        for reader in reader {
            try reader.prefetchData(variable: variable)
        }
    }
    
    func prefetchData(variables: [Variable]) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable)
        }
    }
    
    func get(variable: Variable) throws -> DataAndUnit {
        // Read data from available domains
        let datas = try reader.map {
            try $0.get(variable: variable)
        }
        // icon global
        var first = datas.first!.data
        
        if variable.requiresOffsetCorrectionForMixing {
            // For soil moisture, we have to correct offsets at model mixing
            // The first value stays the start value, afterwards only deltas are used
            // In the end, the lower-resolution model, just gets corrected by the offset to a higher resolution domain
            // An alternative implementation would be to check exactly at model mixing offsets and correct it there
            for x in (1..<first.count).reversed() {
                first[x] = first[x-1] - first[x]
            }
            // integrate other models, but use convert to delta
            for d in datas.dropFirst() {
                for x in d.data.indices.reversed() {
                    if d.data[x].isNaN {
                        continue
                    }
                    if x > 0 {
                        first[x] = d.data[x-1] - d.data[x]
                    } else {
                        first[x] = d.data[x]
                    }
                }
            }
            // undo delta operation
            for x in 1..<first.count {
                first[x] = first[x-1] - first[x]
            }
        } else {
            // default case, just place new data in 1:1
            for d in datas.dropFirst() {
                for x in d.data.indices {
                    if d.data[x].isNaN {
                        continue
                    }
                    first[x] = d.data[x]
                }
            }
        }
        
        return DataAndUnit(first, datas.first!.unit)
    }
}
