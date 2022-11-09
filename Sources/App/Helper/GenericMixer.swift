import Foundation

protocol GenericVariableMixable {
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool { get }
}

/// Mix differnet domains together, that offer the same or similar variable set
protocol GenericReaderMixer {
    associatedtype Reader: GenericReaderMixable
    
    var reader: [Reader] { get }
    init(reader: [Reader])
}

/// Requirements to the reader in order to mix. Could be a GenericReaderDerived or just GenericReader
protocol GenericReaderMixable {
    associatedtype MixingVar: GenericVariableMixable
    associatedtype Domain
    
    var modelLat: Float { get }
    var modelLon: Float { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
    
    func get(variable: MixingVar, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(variable: MixingVar, time: TimerangeDt) throws

    init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws
}

extension GenericReaderMixer {
    var modelLat: Float {
        reader.last!.modelLat
    }
    var modelLon: Float {
        reader.last!.modelLon
    }
    var targetElevation: Float {
        reader.last!.targetElevation
    }
    var modelDtSeconds: Int {
        reader.first!.modelDtSeconds
    }
    
    public init?(domains: [Reader.Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        let reader = try domains.compactMap {
            try Reader(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode)
        }
        guard !reader.isEmpty else {
            return nil
        }
        self.init(reader: reader)
    }
    
    func prefetchData(variable: Reader.MixingVar, time: TimerangeDt) throws {
        for reader in reader {
            try reader.prefetchData(variable: variable, time: time)
        }
    }
    
    func prefetchData(variables: [Reader.MixingVar], time: TimerangeDt) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
    
    func get(variable: Reader.MixingVar, time: TimerangeDt) throws -> DataAndUnit {
        /// Last reader return highest resolution data
        guard let highestResolutionData = try reader.last?.get(variable: variable, time: time) else {
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
                let d = try r.get(variable: variable, time: time)
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
            let d = try r.get(variable: variable, time: time)
            data.integrateIfNaN(d.data)
            
            if !data.containsNaN() {
                break
            }
        }
        return DataAndUnit(data, highestResolutionData.unit)
    }
}

extension VariableOrDerived: GenericVariableMixable where Raw: GenericVariableMixable, Derived: GenericVariableMixable {
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .raw(let raw):
            return raw.requiresOffsetCorrectionForMixing
        case .derived(let derived):
            return derived.requiresOffsetCorrectionForMixing
        }
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
