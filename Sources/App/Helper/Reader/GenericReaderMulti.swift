import Foundation


protocol MultiDomainMixerDomain: RawRepresentableString {
    var countEnsembleMember: Int { get }
    
    var genericDomain: GenericDomain? { get }
    
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> [any GenericReaderProtocol]
    
    func getReader(gridpoint: Int, options: GenericReaderOptions) throws -> (any GenericReaderProtocol)?
}

/// Combine multiple independent weather models, that may not have given forecast variable
struct GenericReaderMulti<Variable: GenericVariableMixable> {
    private let reader: [any GenericReaderProtocol]
    
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
    var modelElevation: ElevationOrSea {
        reader.last!.modelElevation
    }
    
    public init(domain: MultiDomainMixerDomain, reader: [any GenericReaderProtocol]) {
        self.reader = reader
        self.domain = domain
    }
    
    public init?(domain: MultiDomainMixerDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        let reader = try domain.getReader(lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        guard !reader.isEmpty else {
            return nil
        }
        self.domain = domain
        self.reader = reader
    }
    
    /// Return a reader for each grid-cell inside a bounding box
    public static func getReadersFor(domain: MultiDomainMixerDomain, box: BoundingBoxWGS84, options: GenericReaderOptions) throws -> [() throws -> (Self?)] {
        guard let grid = domain.genericDomain?.grid else {
            throw ForecastapiError.generic(message: "Bounbing box calls not supported for domain \(domain)")
        }
        guard let gridpoionts = (grid as? RegularGrid)?.findBox(boundingBox: box) else {
            throw ForecastapiError.generic(message: "Bounbing box calls not supported for grid of domain \(domain)")
        }
        print(gridpoionts)
        return gridpoionts.map( { gridpoint -> (() throws -> (Self?)) in
            return {
                guard let reader = try domain.getReader(gridpoint: gridpoint, options: options) else {
                    return nil
                }
                return Self.init(domain: domain, reader: [reader])
            }
        })
    }
    
    func prefetchData(variable: Variable, time: TimerangeDtAndSettings) throws {
        for reader in reader {
            if time.dtSeconds > reader.modelDtSeconds {
                /// 15 minutely domain while reading hourly data
                continue
            }
            if try reader.prefetchData(mixed: variable.rawValue, time: time) {
                break
            }
        }
    }
    
    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
    
    func get(variable: Variable, time: TimerangeDtAndSettings) throws -> DataAndUnit? {
        // Last reader return highest resolution data. therefore reverse iteration
        // Integrate now lower resolution models
        var data: [Float]? = nil
        var unit: SiUnit? = nil
        if variable.requiresOffsetCorrectionForMixing {
            for r in reader.reversed() {
                if time.dtSeconds > r.modelDtSeconds {
                    /// 15 minutely domain while reading hourly data
                    continue
                }
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
            data?.greater(than: 0)
        } else {
            // default case, just place new data in 1:1
            for r in reader.reversed() {
                if time.dtSeconds > r.modelDtSeconds {
                    /// 15 minutely domain while reading hourly data
                    continue
                }
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
extension GenericReaderProtocol {
    func get(mixed: String, time: TimerangeDtAndSettings) throws -> DataAndUnit? {
        guard let v = MixingVar(rawValue: mixed) else {
            return nil
        }
        return try self.get(variable: v, time: time)
    }
    
    func prefetchData(mixed: String, time: TimerangeDtAndSettings) throws -> Bool {
        guard let v = MixingVar(rawValue: mixed) else {
            return false
        }
        try self.prefetchData(variable: v, time: time)
        return true
    }
}
