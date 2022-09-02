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
        /// Last reader return highest resolution data
        guard let highestResolutionData = try reader.last?.get(variable: variable) else {
            fatalError()
        }
        if !highestResolutionData.data.containsNaN() {
            return highestResolutionData
        }
        
        // Integrate now lower resolution models
        var data = highestResolutionData.data
        if variable.requiresOffsetCorrectionForMixing {
            data.deltaEncode()
            for r in reader.reversed().dropFirst() {
                let d = try r.get(variable: variable)
                data.integrateIfNaNDeltaCoded(d.data)
                
                if !data.containsNaN() {
                    break
                }
            }
            // undo delta operation
            data.deltaDecode()
            return DataAndUnit(data, highestResolutionData.unit)
        }
        
        // default case, just place new data in 1:1
        for r in reader.reversed() {
            let d = try r.get(variable: variable)
            data.integrateIfNaN(d.data)
            
            if !data.containsNaN() {
                break
            }
        }
        return DataAndUnit(data, highestResolutionData.unit)
    }
}

fileprivate extension Array where Element == Float {
    mutating func integrateIfNaN(_ other: [Float]) {
        for x in other.indices {
            if other[x].isNaN || !self[x].isNaN {
                continue
            }
            self[x] = other[x]
        }
    }
    mutating func integrateIfNaNDeltaCoded(_ other: [Float]) {
        for x in other.indices {
            if other[x].isNaN || !self[x].isNaN {
                continue
            }
            if x > 0 {
                self[x] = other[x-1] - other[x]
            } else {
                self[x] = other[x]
            }
        }
    }
}
