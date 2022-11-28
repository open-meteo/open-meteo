import Foundation


protocol MultiDomainMixerDomain: RawRepresentableString {
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable]
}

/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMulti<Variable: GenericVariableMixable> {
    private let reader: [any GenericReaderMixable]
    
    let domain: MultiDomainMixerDomain
    
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
    var modelElevation: Float {
        reader.last!.modelElevation
    }
    
    public init?(domain: MultiDomainMixerDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        let reader = try domain.getReader(lat: lat, lon: lon, elevation: elevation, mode: mode)
        guard !reader.isEmpty else {
            return nil
        }
        self.domain = domain
        self.reader = reader
    }
    
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        for reader in reader {
            if try reader.prefetchData(mixed: variable.rawValue, time: time) {
                break
            }
        }
    }
    
    func prefetchData(variables: [Variable], time: TimerangeDt) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit? {
        // Last reader return highest resolution data. therefore reverse iteration
        // Integrate now lower resolution models
        var data: [Float]? = nil
        var unit: SiUnit? = nil
        if variable.requiresOffsetCorrectionForMixing {
            for r in reader.reversed() {
                guard let d = try r.get(mixed: variable.rawValue, time: time) else {
                    continue
                }
                if data == nil {
                    // first iteration
                    data = d.data
                    unit = d.unit
                    data?.deltaEncode()
                } else {
                    data?.integrateIfNaNDeltaCoded(d.data)
                }
                if data?.containsNaN() == false {
                    break
                }
            }
            // undo delta operation
            data?.deltaDecode()

        } else {
            // default case, just place new data in 1:1
            for r in reader.reversed() {
                guard let d = try r.get(mixed: variable.rawValue, time: time) else {
                    continue
                }
                if data == nil {
                    // first iteration
                    data = d.data
                    unit = d.unit
                } else {
                    data?.integrateIfNaN(d.data)
                }
                if data?.containsNaN() == false {
                    break
                }
            }
        }
        guard let data, let unit else {
            return nil
        }
        return DataAndUnit(data, unit)
    }
}

/// Conditional conformace just use RawValue (String) to resolve `ForecastVariable` to a specific type
fileprivate extension GenericReaderMixable {
    func get(mixed: String, time: TimerangeDt) throws -> DataAndUnit? {
        guard let v = MixingVar(rawValue: mixed) else {
            return nil
        }
        return try self.get(variable: v, time: time)
    }
    
    func prefetchData(mixed: String, time: TimerangeDt) throws -> Bool {
        guard let v = MixingVar(rawValue: mixed) else {
            return false
        }
        try self.prefetchData(variable: v, time: time)
        return true
    }
}
