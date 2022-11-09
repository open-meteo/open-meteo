import Foundation


/// A generic reader that caches all file system reads
final class GenericReaderCached<Domain: GenericDomain, Variable: GenericVariable> where Variable: Hashable {
    private var cache: [Variable: DataAndUnit]
    let reader: GenericReader<Domain, Variable>
    
    /// Elevation of the grid point
    var modelElevation: Float {
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
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = reader
        self.cache = .init()
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        if let value = cache[variable] {
            return value
        }
        let data = try reader.get(variable: variable, time: time)
        cache[variable] = data
        return data
    }
    
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
}
