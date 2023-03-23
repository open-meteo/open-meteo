import Foundation


/// A generic reader that caches all file system reads
final class GenericReaderCached<Domain: GenericDomain, Variable: GenericVariable>: GenericReaderProtocol where Variable: Hashable {
    private var cache: [VariableAndTime: DataAndUnit]
    let reader: GenericReader<Domain, Variable>
    
    /// Used as key for cache
    struct VariableAndTime: Hashable {
        let variable: Variable
        let time: TimerangeDt
    }
    
    /// Elevation of the grid point
    var modelElevation: ElevationOrSea {
        return reader.modelElevation
    }
    
    /// The desired elevation. Used to correct temperature forecasts
    var targetElevation: Float {
        return reader.targetElevation
    }
    
    /// Latitude of the grid point
    var modelLat: Float {
        return reader.modelLat
    }
    
    /// Longitude of the grid point
    var modelLon: Float {
        return reader.modelLon
    }
    
    /// Longitude of the grid point
    var domain: Domain {
        return reader.domain
    }
    
    var modelDtSeconds: Int {
        return reader.modelDtSeconds
    }
    
    public init(reader: GenericReader<Domain, Variable>) {
        self.reader = reader
        self.cache = .init()
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        if let value = cache[VariableAndTime(variable: variable, time: time)] {
            return value
        }
        let data = try reader.get(variable: variable, time: time)
        cache[VariableAndTime(variable: variable, time: time)] = data
        return data
    }
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        return try reader.getStatic(type: type)
    }
    
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
}
